import 'package:cloud_firestore/cloud_firestore.dart';

enum ApprovalStatus { pending, approved, rejected }

class ApprovalRequestModel {
  final String id;
  final String userId;
  final double amount;
  final String currency;
  final String? note;
  final String? voiceNoteUrl;
  final ApprovalStatus status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  ApprovalRequestModel({
    required this.id,
    required this.userId,
    required this.amount,
    this.currency = 'INR',
    this.note,
    this.voiceNoteUrl,
    this.status = ApprovalStatus.pending,
    this.approvedBy,
    this.approvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ApprovalRequestModel.fromJson(Map<String, dynamic> json) => ApprovalRequestModel(
    id: json['id'] as String,
    userId: json['userId'] as String,
    amount: (json['amount'] as num).toDouble(),
    currency: json['currency'] as String? ?? 'INR',
    note: json['note'] as String?,
    voiceNoteUrl: json['voiceNoteUrl'] as String?,
    status: ApprovalStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => ApprovalStatus.pending,
    ),
    approvedBy: json['approvedBy'] as String?,
    approvedAt: json['approvedAt'] != null
      ? (json['approvedAt'] as Timestamp).toDate()
      : null,
    createdAt: (json['createdAt'] as Timestamp).toDate(),
    updatedAt: (json['updatedAt'] as Timestamp).toDate(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'amount': amount,
    'currency': currency,
    'note': note,
    'voiceNoteUrl': voiceNoteUrl,
    'status': status.name,
    'approvedBy': approvedBy,
    'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  ApprovalRequestModel copyWith({
    String? id,
    String? userId,
    double? amount,
    String? currency,
    String? note,
    String? voiceNoteUrl,
    ApprovalStatus? status,
    String? approvedBy,
    DateTime? approvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ApprovalRequestModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    note: note ?? this.note,
    voiceNoteUrl: voiceNoteUrl ?? this.voiceNoteUrl,
    status: status ?? this.status,
    approvedBy: approvedBy ?? this.approvedBy,
    approvedAt: approvedAt ?? this.approvedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
