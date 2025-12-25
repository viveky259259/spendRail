import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendrail_worker_app/models/approval_request_model.dart';

class ApprovalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Future<String> createApprovalRequest({
    required String userId,
    required double amount,
    required String currency,
    String? note,
    String? voiceNoteUrl,
  }) async {
    try {
      final now = DateTime.now();
      final request = ApprovalRequestModel(
        id: '',
        userId: userId,
        amount: amount,
        currency: currency,
        note: note,
        voiceNoteUrl: voiceNoteUrl,
        createdAt: now,
        updatedAt: now,
      );
      
      final docRef = await _firestore.collection('requests').add(request.toJson());
      return docRef.id;
    } catch (e) {
      debugPrint('Create approval request error: $e');
      rethrow;
    }
  }
  
  Stream<ApprovalRequestModel> listenToApprovalRequest(String requestId) {
    return _firestore.collection('requests').doc(requestId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        throw Exception('Request not found');
      }
      return ApprovalRequestModel.fromJson({...snapshot.data()!, 'id': snapshot.id});
    });
  }
  
  Future<List<ApprovalRequestModel>> getUserApprovalRequests(String userId, {int limit = 50}) async {
    try {
      final snapshot = await _firestore
        .collection('requests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
      
      return snapshot.docs
        .map((doc) => ApprovalRequestModel.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
    } catch (e) {
      debugPrint('Get approval requests error: $e');
      return [];
    }
  }
  
  Future<void> cancelApprovalRequest(String requestId) async {
    try {
      await _firestore.collection('requests').doc(requestId).update({
        'status': ApprovalStatus.rejected.name,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Cancel approval request error: $e');
      rethrow;
    }
  }
}

final approvalServiceProvider = Provider((ref) => ApprovalService());
