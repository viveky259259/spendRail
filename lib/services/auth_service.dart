import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendrail_worker_app/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  Future<UserModel?> getCurrentUserData() async {
    try {
      final user = currentUser;
      if (user == null) return null;
      
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;
      
      return UserModel.fromJson({...doc.data()!, 'id': doc.id});
    } catch (e) {
      debugPrint('Error getting current user data: $e');
      return null;
    }
  }
  
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      debugPrint('Sign in error: $e');
      rethrow;
    }
  }
  
  Future<UserCredential> registerWithEmail(String email, String password, String name) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      
      final now = DateTime.now();
      final userData = UserModel(
        id: credential.user!.uid,
        email: email,
        name: name,
        preferredLanguage: 'en',
        createdAt: now,
        updatedAt: now,
      );
      
      await _firestore.collection('users').doc(credential.user!.uid).set(userData.toJson());
      
      return credential;
    } catch (e) {
      debugPrint('Registration error: $e');
      rethrow;
    }
  }
  
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Password reset error: $e');
      rethrow;
    }
  }
  
  Future<void> updateUserLanguage(String languageCode) async {
    try {
      final user = currentUser;
      if (user == null) return;
      
      await _firestore.collection('users').doc(user.uid).update({
        'preferredLanguage': languageCode,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Update language error: $e');
      rethrow;
    }
  }
  
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }
}

final authServiceProvider = Provider((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

final currentUserDataProvider = FutureProvider<UserModel?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.getCurrentUserData();
});
