import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:spendrail_worker_app/features/analytics/analytics_screen.dart';
import 'package:spendrail_worker_app/features/approval/request_approval_screen.dart';
import 'package:spendrail_worker_app/features/auth/forgot_password_screen.dart';
import 'package:spendrail_worker_app/features/auth/login_screen.dart';
import 'package:spendrail_worker_app/features/auth/register_screen.dart';
import 'package:spendrail_worker_app/features/history/history_screen.dart';
import 'package:spendrail_worker_app/features/home/home_screen.dart';
import 'package:spendrail_worker_app/features/payment/payment_form_screen.dart';
import 'package:spendrail_worker_app/features/payment/payment_processing_screen.dart';
import 'package:spendrail_worker_app/features/payment/qr_scanner_screen.dart';
import 'package:spendrail_worker_app/features/profile/profile_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.login,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => const NoTransitionPage(child: LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        pageBuilder: (context, state) => const NoTransitionPage(child: RegisterScreen()),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgot-password',
        pageBuilder: (context, state) => const NoTransitionPage(child: ForgotPasswordScreen()),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        pageBuilder: (context, state) => const NoTransitionPage(child: HomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.profile,
        name: 'profile',
        pageBuilder: (context, state) => const NoTransitionPage(child: ProfileScreen()),
      ),
      GoRoute(
        path: AppRoutes.scanQr,
        name: 'scan-qr',
        pageBuilder: (context, state) => const NoTransitionPage(child: QrScannerScreen()),
      ),
      GoRoute(
        path: AppRoutes.paymentForm,
        name: 'payment-form',
        pageBuilder: (context, state) {
          final qrData = state.extra as String;
          return NoTransitionPage(child: PaymentFormScreen(qrData: qrData));
        },
      ),
      GoRoute(
        path: AppRoutes.paymentProcessing,
        name: 'payment-processing',
        pageBuilder: (context, state) {
          final firebaseId = state.extra as String;
          return NoTransitionPage(child: PaymentProcessingScreen(firebaseId: firebaseId));
        },
      ),
      GoRoute(
        path: AppRoutes.requestApproval,
        name: 'request-approval',
        pageBuilder: (context, state) => const NoTransitionPage(child: RequestApprovalScreen()),
      ),
      GoRoute(
        path: AppRoutes.history,
        name: 'history',
        pageBuilder: (context, state) => const NoTransitionPage(child: HistoryScreen()),
      ),
      GoRoute(
        path: AppRoutes.analytics,
        name: 'analytics',
        pageBuilder: (context, state) => const NoTransitionPage(child: AnalyticsScreen()),
      ),
    ],
  );
}

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/';
  static const String profile = '/profile';
  static const String scanQr = '/scan-qr';
  static const String paymentForm = '/payment-form';
  static const String paymentProcessing = '/payment-processing';
  static const String requestApproval = '/request-approval';
  static const String history = '/history';
  static const String analytics = '/analytics';
}
