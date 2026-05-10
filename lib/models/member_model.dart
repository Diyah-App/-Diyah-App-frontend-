class Member {
  final int? id;
  final String fullName;
  final String phone;
  final bool isWajeeh;
  final int? wajeehId;
  final String? wajeehName;
  final String role;
  final DateTime? createdAt;

  Member({
    this.id,
    required this.fullName,
    required this.phone,
    this.isWajeeh = false,
    this.wajeehId,
    this.wajeehName,
    this.role = 'member',
    this.createdAt,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'],
      fullName: json['full_name'],
      phone: json['phone'],
      isWajeeh: json['is_wajeeh'] ?? false,
      wajeehId: json['wajeeh_id'],
      wajeehName: json['wajeeh_name'],
      role: json['role'] ?? 'member',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'is_wajeeh': isWajeeh,
      'wajeeh_id': wajeehId,
      'role': role,
    };
  }
}
