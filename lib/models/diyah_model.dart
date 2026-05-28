class Diyah {
  final int? id;
  final String title;
  final String? description;
  final double amount;
  final DateTime? manualDate;
  final DateTime createdAt;
  final bool isFinished;
  final bool isFullyPaid;
  final int? causedById;
  final String? causedByName;
  final int totalMembersCount;
  final double sharePerMember;
  final double? roundedShare;
  final double? ownerPercentage;
  final double paidFromOldDiyahFund;
  final double? memberPayment;
  final double? memberShare;

  Diyah({
    this.id,
    required this.title,
    this.description,
    required this.amount,
    this.manualDate,
    required this.createdAt,
    this.isFinished = false,
    this.isFullyPaid = false,
    this.causedById,
    this.causedByName,
    this.totalMembersCount = 1,
    this.sharePerMember = 0.0,
    this.roundedShare,
    this.ownerPercentage,
    this.paidFromOldDiyahFund = 0.0,
    this.memberPayment,
    this.memberShare,
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
      isFullyPaid: json['is_fully_paid'] ?? false,
      causedById: json['caused_by_id'],
      causedByName: json['caused_by_name'],
      totalMembersCount: json['total_members_count'] ?? 0,
      sharePerMember: (json['share_per_member'] as num?)?.toDouble() ?? 0.0,
      roundedShare: (json['rounded_share'] as num?)?.toDouble(),
      ownerPercentage: (json['owner_percentage'] as num?)?.toDouble(),
      paidFromOldDiyahFund: (json['paid_from_old_diyah_fund'] as num?)?.toDouble() ?? 0.0,
      memberPayment: (json['member_payment'] as num?)?.toDouble(),
      memberShare: (json['member_share'] as num?)?.toDouble(),
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
      'is_fully_paid': isFullyPaid,
      'caused_by_id': causedById,
      'rounded_share': roundedShare,
      'owner_percentage': ownerPercentage,
      'member_payment': memberPayment,
      'member_share': memberShare,
    };
  }
}
