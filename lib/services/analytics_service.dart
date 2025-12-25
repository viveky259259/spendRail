import 'package:flutter/material.dart';
import 'package:spendrail_worker_app/models/transaction_model.dart';

class AnalyticsData {
  final Map<TransactionCategory, double> spendingByCategory;
  final double totalSpent;
  final int transactionCount;
  
  AnalyticsData({
    required this.spendingByCategory,
    required this.totalSpent,
    required this.transactionCount,
  });
}

class AnalyticsService {
  AnalyticsData calculateAnalytics(List<TransactionModel> transactions) {
    final completedTransactions = transactions
      .where((t) => t.status == TransactionStatus.payment_completed)
      .toList();
    
    final spendingByCategory = <TransactionCategory, double>{};
    double totalSpent = 0;
    
    for (final transaction in completedTransactions) {
      spendingByCategory[transaction.category] = 
        (spendingByCategory[transaction.category] ?? 0) + transaction.amount;
      totalSpent += transaction.amount;
    }
    
    return AnalyticsData(
      spendingByCategory: spendingByCategory,
      totalSpent: totalSpent,
      transactionCount: completedTransactions.length,
    );
  }
  
  String exportToCSV(List<TransactionModel> transactions) {
    final buffer = StringBuffer();
    buffer.writeln('Date,Amount,Category,Status,Note');
    
    for (final transaction in transactions) {
      final date = transaction.createdAt.toIso8601String();
      final amount = transaction.amount.toStringAsFixed(2);
      final category = transaction.category.name;
      final status = transaction.status.name;
      final note = transaction.note ?? '';
      
      buffer.writeln('$date,$amount,$category,$status,"$note"');
    }
    
    return buffer.toString();
  }
  
  Color getCategoryColor(TransactionCategory category) {
    switch (category) {
      case TransactionCategory.food:
        return const Color(0xFFFF6B6B);
      case TransactionCategory.travel:
        return const Color(0xFF4ECDC4);
      case TransactionCategory.supplies:
        return const Color(0xFFFFE66D);
      case TransactionCategory.other:
        return const Color(0xFF95E1D3);
    }
  }
}
