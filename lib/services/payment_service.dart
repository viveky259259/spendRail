import 'dart:async';
import 'package:dio/dio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendrail_worker_app/models/transaction_model.dart';

class PaymentService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // SpendRail backend base (provided by user)
  static const String _apiBaseUrl = 'https://spendrail.onrender.com/api/v1';
  static const Duration _paymentTimeout = Duration(minutes: 5);

  void _logDioFailure(String context, DioException e, {Object? payload}) {
    try {
      final req = e.requestOptions;
      final res = e.response;
      debugPrint('[API ERROR] $context');
      debugPrint('  → ${req.method} ${req.baseUrl.isNotEmpty ? req.baseUrl : ''}${req.path}');
      if (payload != null) debugPrint('  Payload: $payload');
      debugPrint('  DioException.type: ${e.type}');
      if (e.message != null) debugPrint('  Message: ${e.message}');
      if (res != null) {
        debugPrint('  Status: ${res.statusCode}');
        debugPrint('  Response data: ${res.data}');
      }
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
        final response = await _dio.post(
          '$_apiBaseUrl/transcationApproval',
          data: {'firebaseId': firebaseId},
        );

        if (response.statusCode != 200) {
          debugPrint('[API FAILURE] POST $_apiBaseUrl/transcationApproval');
          debugPrint('  Status: ${response.statusCode}');
          debugPrint('  Body: ${response.data}');
          throw Exception('Spend approval request failed');
        }
      } on DioException catch (e) {
        _logDioFailure('Spend approval API call failed', e, payload: {'firebaseId': firebaseId});
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
  
  Stream<TransactionModel> listenToTransaction(String firebaseId) {
    return _firestore.collection('transactions').doc(firebaseId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        throw Exception('Transaction not found');
      }
      return TransactionModel.fromJson({...snapshot.data()!, 'id': snapshot.id});
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
  
  Future<List<TransactionModel>> getUserTransactions(String userId, {int limit = 50}) async {
    try {
      final snapshot = await _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
      
      return snapshot.docs
        .map((doc) => TransactionModel.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
    } catch (e) {
      debugPrint('Get transactions error: $e');
      return [];
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
      Query query = _firestore.collection('transactions').where('userId', isEqualTo: userId);
      
      if (category != null) {
        query = query.where('category', isEqualTo: category.name);
      }
      
      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      
      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }
      
      final snapshot = await query.orderBy('createdAt', descending: true).get();
      
      List<TransactionModel> transactions = snapshot.docs
        .map((doc) => TransactionModel.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
        .toList();
      
      if (searchQuery != null && searchQuery.isNotEmpty) {
        transactions = transactions.where((t) => 
          t.qrData.toLowerCase().contains(searchQuery.toLowerCase()) ||
          (t.note?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false)
        ).toList();
      }
      
      return transactions;
    } catch (e) {
      debugPrint('Search transactions error: $e');
      return [];
    }
  }
}

final paymentServiceProvider = Provider((ref) => PaymentService());
