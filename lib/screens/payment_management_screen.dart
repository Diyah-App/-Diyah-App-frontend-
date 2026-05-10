import 'package:flutter/material.dart';
import '../models/member_model.dart';
import '../models/diyah_model.dart';
import '../services/api_service.dart';
import '../widgets/smart_search_bar.dart';

import '../services/notification_service.dart';
import '../services/auth_service.dart';

class PaymentManagementScreen extends StatefulWidget {
  final Diyah diyah;

  const PaymentManagementScreen({super.key, required this.diyah});

  @override
  State<PaymentManagementScreen> createState() => _PaymentManagementScreenState();
}

class _PaymentManagementScreenState extends State<PaymentManagementScreen> {
  List<Member> _allMembers = [];
  Set<int> _paidMemberIds = {};
  Set<int> _eligibleMemberIds = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      var members = await ApiService.getMembers();
      final status = await ApiService.getDiyahPaymentStatus(widget.diyah.id!);
      if (!mounted) return;
      setState(() {
        _allMembers = members;
        _paidMemberIds = status['paid']!.toSet();
        _eligibleMemberIds = status['eligible']!.toSet();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في التحميل: $e')));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncPayments() async {
    setState(() => _isSaving = true);
    try {
      await ApiService.updateDiyahPayments(widget.diyah.id!, _paidMemberIds.toList());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في المزامنة: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _togglePayment(int memberId) async {
    final member = _allMembers.firstWhere((m) => m.id == memberId);
    
    // Check permissions
    if (AuthService.role == 'wajeeh') {
      if (member.id != AuthService.currentUserId && member.wajeehId != AuthService.currentUserId) {
        return; // Wajeeh can only toggle their own members
      }
    }

    bool wasPaid = _paidMemberIds.contains(memberId);
    setState(() {
      if (wasPaid) {
        _paidMemberIds.remove(memberId);
      } else {
        _paidMemberIds.add(memberId);
      }
    });
    
    NotificationService().addNotification(
      title: 'تحديث دفع',
      message: '${wasPaid ? "إلغاء دفع" : "تأكيد دفع"} حصة العضو: ${member.fullName}',
    );
    
    await _syncPayments();
  }

  Future<void> _selectAll() async {
    setState(() {
      for (var m in _allMembers) {
        if (AuthService.role == 'wajeeh') {
          if (m.id != AuthService.currentUserId && m.wajeehId != AuthService.currentUserId) continue;
        }
        _paidMemberIds.add(m.id!);
      }
    });
    NotificationService().addNotification(
      title: 'تحصيل جماعي',
      message: 'تم تحديد الأعضاء كدافعين لدية ${widget.diyah.title}',
      type: NotificationType.diyah,
      entityId: widget.diyah.id,
    );
    await _syncPayments();
  }

  Future<void> _deselectAll() async {
    setState(() {
      for (var m in _allMembers) {
        if (AuthService.role == 'wajeeh') {
          if (m.id != AuthService.currentUserId && m.wajeehId != AuthService.currentUserId) continue;
        }
        _paidMemberIds.remove(m.id!);
      }
    });
    NotificationService().addNotification(
      title: 'إلغاء تسديد جماعي',
      message: 'تم إلغاء تسديد الدية لجميع الأعضاء في ${widget.diyah.title}',
      type: NotificationType.diyah,
      entityId: widget.diyah.id,
    );
    await _syncPayments();
  }

  @override
  Widget build(BuildContext context) {
    List<Member> filteredMembers = _allMembers.where((m) {
      final matchesName = SmartSearchBar.matches(m.fullName, _searchQuery);
      final matchesPhone = SmartSearchBar.matches(m.phone, _searchQuery);
      return matchesName || matchesPhone;
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('تحصيل: ${widget.diyah.title}'),
          actions: [
            const NotificationBadgeIcon(),
            if (_isSaving) 
              const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))),
            TextButton(
              onPressed: _allMembers.where((m) {
                 if (AuthService.role == 'wajeeh') {
                    return m.id == AuthService.currentUserId || m.wajeehId == AuthService.currentUserId;
                 }
                 return true;
              }).every((m) => _paidMemberIds.contains(m.id)) ? _deselectAll : _selectAll,
              child: Text(
                _allMembers.where((m) {
                 if (AuthService.role == 'wajeeh') {
                    return m.id == AuthService.currentUserId || m.wajeehId == AuthService.currentUserId;
                 }
                 return true;
              }).every((m) => _paidMemberIds.contains(m.id)) ? 'إلغاء الكل' : 'تحديد الكل',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SmartSearchBar(
                    hintText: 'بحث بالاسم أو رقم الهاتف...',
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('تم التحصيل من: ${_paidMemberIds.intersection(_eligibleMemberIds).length} / ${_eligibleMemberIds.length}', 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      if (_isSaving) const Text('جاري الحفظ...', style: TextStyle(color: Colors.blue, fontSize: 12)),
                    ],
                  ),
                ),
                if (_allMembers.length > _eligibleMemberIds.length)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                    child: Text('* يوجد ${_allMembers.length - _eligibleMemberIds.length} أعضاء جدد غير مشمولين بهذه الدية.', 
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredMembers.length,
                    itemBuilder: (ctx, index) {
                      final member = filteredMembers[index];
                      final isPaid = _paidMemberIds.contains(member.id);
                      final canEdit = (AuthService.role == 'owner' || AuthService.role == 'sheikh' || AuthService.role == 'admin') ||
                                      (AuthService.role == 'wajeeh' && (member.id == AuthService.currentUserId || member.wajeehId == AuthService.currentUserId));

                      return CheckboxListTile(
                        title: Text(member.fullName, style: TextStyle(fontWeight: FontWeight.bold, color: canEdit ? Colors.black : Colors.grey[600])),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('رقم الهاتف: ${member.phone}', style: const TextStyle(fontSize: 13)),
                            Text(member.isWajeeh ? 'الحالة: وجيه' : 'الحالة: عضو (تابع لـ: ${member.wajeehName ?? "لا يوجد"})', 
                              style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                          ],
                        ),
                        secondary: CircleAvatar(
                          backgroundColor: member.isWajeeh ? Colors.amber.shade100 : Colors.blue.shade50,
                          child: Icon(member.isWajeeh ? Icons.star : Icons.person, color: member.isWajeeh ? Colors.amber : Colors.blue),
                        ),
                        value: isPaid,
                        activeColor: Colors.green,
                        onChanged: canEdit ? (_) => _togglePayment(member.id!) : null,
                      );
                    },
                  ),
                ),
              ],
            ),
      ),
    );
  }
}
