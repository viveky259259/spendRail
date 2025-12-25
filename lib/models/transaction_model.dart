import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionStatus { processing, completed, disapproved, timeout }

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
    this.status = TransactionStatus.processing,
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
    status: TransactionStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => TransactionStatus.processing,
    ),
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
