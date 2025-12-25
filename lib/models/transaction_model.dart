import 'package:cloud_firestore/cloud_firestore.dart';

// App-wide transaction lifecycle statuses
// Note: Keep legacy values for backward compatibility via parser
enum TransactionStatus {
  waiting_on_approval,
  waiting_on_manual_approval,
  transaction_approved, // approved, ready for payment processing
  payment_in_progress,
  payment_completed,
  payment_declined,
  transaction_disapproved, // maps from server disapproved variants
  timeout, // client-side timeout fallback
}

enum TransactionCategory { food, travel, supplies, other }

class TransactionModel {
  final String id;
  final String userId;
  final double amount;
  final String qrData;
  final String? note;
  final String? voiceNoteUrl;
  final TransactionStatus status;
  final TransactionCategory category;
  final DateTime createdAt;
  final DateTime updatedAt;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.qrData,
    this.note,
    this.voiceNoteUrl,
    this.status = TransactionStatus.waiting_on_approval,
    this.category = TransactionCategory.other,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) => TransactionModel(
    id: json['id'] as String,
    userId: json['userId'] as String,
    amount: (json['amount'] as num).toDouble(),
    qrData: json['qrData'] as String,
    note: json['note'] as String?,
    voiceNoteUrl: json['voiceNoteUrl'] as String?,
    status: _parseStatus(json['status'] as String?),
    category: TransactionCategory.values.firstWhere(
      (e) => e.name == json['category'],
      orElse: () => TransactionCategory.other,
    ),
    createdAt: (json['createdAt'] as Timestamp).toDate(),
    updatedAt: (json['updatedAt'] as Timestamp).toDate(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'amount': amount,
    'qrData': qrData,
    'note': note,
    'voiceNoteUrl': voiceNoteUrl,
    'status': status.name,
    'category': category.name,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  TransactionModel copyWith({
    String? id,
    String? userId,
    double? amount,
    String? qrData,
    String? note,
    String? voiceNoteUrl,
    TransactionStatus? status,
    TransactionCategory? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TransactionModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    amount: amount ?? this.amount,
    qrData: qrData ?? this.qrData,
    note: note ?? this.note,
    voiceNoteUrl: voiceNoteUrl ?? this.voiceNoteUrl,
    status: status ?? this.status,
    category: category ?? this.category,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

TransactionStatus _parseStatus(String? raw) {
  // Normalize for safety
  final value = (raw ?? '').trim();
  // Direct enum match
  for (final s in TransactionStatus.values) {
    if (s.name == value) return s;
  }
  // Legacy -> new mappings
  switch (value) {
    case 'processing':
      return TransactionStatus.waiting_on_approval;
    case 'completed':
      return TransactionStatus.payment_completed;
    case 'disapproved':
      return TransactionStatus.transaction_disapproved;
  }
  // Common misspelling from backend
  if (value == 'transacation_disapproved') {
    return TransactionStatus.transaction_disapproved;
  }
  // Fallback to waiting_on_approval
  return TransactionStatus.waiting_on_approval;
}
