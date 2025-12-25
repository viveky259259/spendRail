import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendrail_worker_app/models/transaction_model.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

class PaymentService {
  final http.Client _client = http.Client();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // SpendRail backend base (provided by user)
  static const String _apiBaseUrl = 'https://spendrail.onrender.com/api/v1';
  static const Duration _paymentTimeout = Duration(minutes: 5);
  static const Duration _requestTimeout = Duration(seconds: 20);

  void _logHttpFailure(String context, http.Response response,
      {Object? payload, String? url}) {
    try {
      debugPrint('[API ERROR] $context');
      if (url != null) {
        debugPrint('  → URL: $url');
      }
      if (payload != null) debugPrint('  Payload: $payload');
      debugPrint('  Status: ${response.statusCode}');
      debugPrint('  Response body: ${response.body}');
    } catch (logErr) {
      debugPrint('Failed to log API error: $logErr');
    }
  }

  Future<String> initiatePayment({
    required String userId,
    required double amount,
    required String qrData,
    String? note,
    String? voiceNoteUrl,
  }) async {
    // Step 1: Create a new transaction document in Firestore
    try {
      final now = DateTime.now();
      final txData = <String, dynamic>{
        'userId': userId,
        'amount': amount,
        'qrData': qrData,
        'note': note,
        'voiceNoteUrl': voiceNoteUrl,
        // Initial state: waiting for automated or manual approval
        'status': TransactionStatus.waiting_on_approval.name,
        'category': TransactionCategory.other.name,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      final docRef = await _firestore.collection('transactions').add(txData);
      // Store the generated id back into the document for convenience
      await docRef.update({'id': docRef.id});

      final firebaseId = docRef.id;

      // Step 2: Call SpendRail API to trigger spend approval using firebaseId
      try {
        final url = '$_apiBaseUrl/firebase/validate';
        final response = await _client
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'firebase_id': firebaseId}),
            )
            .timeout(_requestTimeout);

        if (response.statusCode != 200) {
          _logHttpFailure('Spend approval API call failed', response,
              payload: {'firebaseId': firebaseId}, url: url);
          throw Exception('Spend approval request failed');
        }
      } on TimeoutException {
        debugPrint('Spend approval API timeout');
        rethrow;
      } catch (e) {
        debugPrint('Spend approval API unexpected error: $e');
        // Surface the error to caller so UI can notify the user
        rethrow;
      }

      return firebaseId;
    } catch (e) {
      debugPrint('Payment initiation error: $e');
      rethrow;
    }
  }

  /// Uploads an invoice image to Firebase Storage, updates the Firestore transaction
  /// document with the invoiceUrl, and then calls the SpendRail categorize endpoint.
  /// Returns the uploaded invoice URL when successful.
  Future<String?> uploadInvoiceAndCategorize({
    required String firebaseId,
    required String userId,
    required Uint8List data,
    required String filename,
  }) async {
    try {
      // Determine extension and content type
      final lower = filename.toLowerCase();
      String ext = '.jpg';
      String contentType = 'image/jpeg';
      if (lower.endsWith('.png')) {
        ext = '.png';
        contentType = 'image/png';
      } else if (lower.endsWith('.jpeg') || lower.endsWith('.jpg')) {
        ext = '.jpg';
        contentType = 'image/jpeg';
      } else if (lower.endsWith('.webp')) {
        ext = '.webp';
        contentType = 'image/webp';
      }

      // Upload to Storage
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('invoices/$userId/${firebaseId}_$stamp$ext');

      final task = await storageRef.putData(
        data,
        SettableMetadata(contentType: contentType),
      );
      final invoiceUrl = await task.ref.getDownloadURL();

      // Update transaction document
      await _firestore.collection('transactions').doc(firebaseId).update({
        'invoiceUrl': invoiceUrl,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Call categorize endpoint (URL provided by user)
      final categorizeUrl =
          'https://spendrail.onrender.com/api/v1/api/v1/images/categorize/firebase';
      try {
        final response = await _client
            .post(
              Uri.parse(categorizeUrl),
              headers: {'Content-Type': 'application/json', 'accept': 'application/json'},
              body: jsonEncode({'firebase_id': firebaseId}),
            )
            .timeout(_requestTimeout);

        if (response.statusCode != 200) {
          _logHttpFailure('Invoice categorize API call failed', response,
              payload: {'firebaseId': firebaseId}, url: categorizeUrl);
        }
      } on TimeoutException {
        debugPrint('Invoice categorize API timeout');
      } catch (e) {
        debugPrint('Invoice categorize API unexpected error: $e');
      }

      return invoiceUrl;
    } catch (e) {
      debugPrint('uploadInvoiceAndCategorize error: $e');
      rethrow;
    }
  }

  Stream<TransactionModel> listenToTransaction(String firebaseId) {
    return _firestore
        .collection('transactions')
        .doc(firebaseId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        throw Exception('Transaction not found');
      }
      return TransactionModel.fromJson(
          {...snapshot.data()!, 'id': snapshot.id});
    }).timeout(
      _paymentTimeout,
      onTimeout: (sink) {
        sink.addError(TimeoutException('Payment timeout'));
      },
    );
  }

  Future<TransactionModel> waitForPaymentCompletion(String firebaseId) async {
    try {
      final completer = Completer<TransactionModel>();
      StreamSubscription? subscription;

      subscription = listenToTransaction(firebaseId).listen(
        (transaction) {
          if (transaction.status == TransactionStatus.payment_completed ||
              transaction.status == TransactionStatus.payment_declined ||
              transaction.status == TransactionStatus.transaction_disapproved) {
            subscription?.cancel();
            completer.complete(transaction);
          }
        },
        onError: (error) {
          subscription?.cancel();
          if (error is TimeoutException) {
            completer.completeError(error);
          } else {
            completer.completeError(Exception('Payment failed'));
          }
        },
      );

      return await completer.future;
    } catch (e) {
      debugPrint('Payment completion error: $e');
      rethrow;
    }
  }

  Future<List<TransactionModel>> getUserTransactions(String userId,
      {int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map(
              (doc) => TransactionModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('Get transactions error: $e');
      return [];
    }
  }

  /// Update the status of a transaction in Firebase (for mock payment processing)
  Future<void> updateTransactionStatus(String firebaseId, TransactionStatus status) async {
    try {
      await _firestore.collection('transactions').doc(firebaseId).update({
        'status': status.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('Update transaction status error: $e');
      rethrow;
    }
  }

  Future<List<TransactionModel>> searchTransactions({
    required String userId,
    String? searchQuery,
    TransactionCategory? category,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId);

      if (category != null) {
        query = query.where('category', isEqualTo: category.name);
      }

      if (startDate != null) {
        query = query.where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.orderBy('createdAt', descending: true).get();

      List<TransactionModel> transactions = snapshot.docs
          .map((doc) => TransactionModel.fromJson(
              {...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();

      if (searchQuery != null && searchQuery.isNotEmpty) {
        transactions = transactions
            .where((t) =>
                t.qrData.toLowerCase().contains(searchQuery.toLowerCase()) ||
                (t.note?.toLowerCase().contains(searchQuery.toLowerCase()) ??
                    false))
            .toList();
      }

      return transactions;
    } catch (e) {
      debugPrint('Search transactions error: $e');
      return [];
    }
  }
}

final paymentServiceProvider = Provider((ref) => PaymentService());
