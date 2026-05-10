class Diyah {
  final int? id;
  final String title;
  final String? description;
  final double amount;
  final DateTime? manualDate;
  final DateTime createdAt;
  final bool isFinished;
  final int? causedById;
  final String? causedByName;
  final int totalMembersCount;
  final double sharePerMember;

  Diyah({
    this.id,
    required this.title,
    this.description,
    required this.amount,
    this.manualDate,
    required this.createdAt,
    this.isFinished = false,
    this.causedById,
    this.causedByName,
    this.totalMembersCount = 1,
    this.sharePerMember = 0.0,
  });

  factory Diyah.fromJson(Map<String, dynamic> json) {
    return Diyah(
      id: json['id'],
      title: json['title'] ?? 'بدون عنوان',
      description: json['description'],
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      manualDate: json['manual_date'] != null ? DateTime.tryParse(json['manual_date']) : null,
      createdAt: json['created_at'] != null ? (DateTime.tryParse(json['created_at']) ?? DateTime.now()) : DateTime.now(),
      isFinished: json['is_finished'] ?? false,
      causedById: json['caused_by_id'],
      causedByName: json['caused_by_name'],
      totalMembersCount: json['total_members_count'] ?? 0,
      sharePerMember: (json['share_per_member'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'amount': amount,
      'manual_date': manualDate?.toIso8601String(),
      'is_finished': isFinished,
      'caused_by_id': causedById,
    };
  }
}
