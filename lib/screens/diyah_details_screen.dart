import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../models/diyah_model.dart';
import '../models/member_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/member_tile.dart';
import '../widgets/smart_search_bar.dart';

class DiyahDetailsScreen extends StatefulWidget {
  final Diyah diyah;

  const DiyahDetailsScreen({super.key, required this.diyah});

  @override
  State<DiyahDetailsScreen> createState() => _DiyahDetailsScreenState();
}

class _DiyahDetailsScreenState extends State<DiyahDetailsScreen> {
  late Diyah _diyah;
  List<Member> _allMembers = [];
  List<Member> _filteredMembers = [];
  Set<int> _paidMemberIds = {};
  Set<int> _eligibleMemberIds = {};
  bool _isLoading = true;
  String _searchQuery = "";
  String _roleFilter = 'الكل'; // 'الكل', 'وجهاء', 'أعضاء'
  String _paymentFilter = 'الكل'; // 'الكل', 'دافعين', 'غير دافعين'

  @override
  void initState() {
    super.initState();
    _diyah = widget.diyah;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final members = await ApiService.getMembers();
      final status = await ApiService.getDiyahPaymentStatus(_diyah.id!);
      
      if (!mounted) return;
      setState(() {
        _allMembers = members;
        _paidMemberIds = status['paid']!.toSet();
        _eligibleMemberIds = status['eligible']!.toSet();
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      // Base pool: only members who were present when diyah was created (eligible)
      final eligibleMembers = _allMembers.where((m) => _eligibleMemberIds.contains(m.id)).toList();

      _filteredMembers = eligibleMembers.where((m) {
        final matchesSearch = SmartSearchBar.matches(m.fullName, _searchQuery) || 
                             SmartSearchBar.matches(m.phone, _searchQuery);
        
        bool roleMatch = true;
        if (_roleFilter == 'وجهاء') roleMatch = m.isWajeeh;
        if (_roleFilter == 'أعضاء') roleMatch = !m.isWajeeh;

        bool paymentMatch = true;
        if (_paymentFilter == 'دافعين') {
          paymentMatch = _paidMemberIds.contains(m.id);
        } else if (_paymentFilter == 'غير دافعين') {
          // Only eligible members who haven't paid
          paymentMatch = !_paidMemberIds.contains(m.id);
        }

        return matchesSearch && roleMatch && paymentMatch;
      }).toList();
    });
  }

  Future<void> _togglePayment(int memberId) async {
    final wasPaid = _paidMemberIds.contains(memberId);
    setState(() {
      if (wasPaid) {
        _paidMemberIds.remove(memberId);
      } else {
        _paidMemberIds.add(memberId);
      }
      _applyFilters();
    });

    try {
      if (!mounted) return;
      await ApiService.updateDiyahPayments(_diyah.id!, _paidMemberIds.toList());
      if (!mounted) return;
      final member = _allMembers.firstWhere((m) => m.id == memberId);
      NotificationService().addNotification(
        title: 'تعديل سداد',
        message: 'تم تحديث حالة دفع ${member.fullName} لدية ${_diyah.title}',
        type: NotificationType.diyah,
        entityId: _diyah.id,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في المزامنة: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل الدية'),
          actions: [
            const NotificationBadgeIcon(),
            IconButton(
              icon: Icon(_diyah.isFinished ? Icons.check_circle : Icons.circle_outlined, color: Colors.white),
              tooltip: _diyah.isFinished ? 'إعادة فتح' : 'إنهاء الدية',
              onPressed: () async {
                final updated = Diyah(
                  id: _diyah.id,
                  title: _diyah.title,
                  amount: _diyah.amount,
                  description: _diyah.description,
                  manualDate: _diyah.manualDate,
                  createdAt: _diyah.createdAt,
                  causedById: _diyah.causedById,
                  isFinished: !_diyah.isFinished,
                  totalMembersCount: _diyah.totalMembersCount,
                  sharePerMember: _diyah.sharePerMember,
                );
                await ApiService.updateDiyah(updated);
                NotificationService().addNotification(
                  title: updated.isFinished ? 'إغلاق دية' : 'إعادة فتح دية',
                  message: 'تم تغيير حالة الدية: ${updated.title}',
                  type: NotificationType.diyah,
                  entityId: updated.id,
                );
                setState(() => _diyah = updated);
              },
            ),
          ],
        ),
        body: _isLoading ? const Center(child: CircularProgressIndicator()) : Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 16),
                    _buildDiyahStats(),
                    if (_diyah.description != null && _diyah.description!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildDescriptionCard(),
                    ],
                    const SizedBox(height: 16),
                    _buildResponsibleCard(),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('إدارة سداد الأعضاء', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    SmartSearchBar(
                      hintText: 'بحث في الأعضاء...',
                      onChanged: (val) {
                        _searchQuery = val;
                        _applyFilters();
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildFilterRow(),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredMembers.length,
                      itemBuilder: (ctx, index) {
                        final member = _filteredMembers[index];
                        final isPaid = _paidMemberIds.contains(member.id);
                        
                        // Calculate group share if wajeeh
                        int? followersCount;
                        if (member.isWajeeh) {
                          followersCount = _allMembers.where((m) => m.wajeehId == member.id).length;
                        }

                        return MemberTile(
                          member: member,
                          subtitleOverride: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (member.isWajeeh) ...[
                                Text('حصة الوجيه: ${intl.NumberFormat('#,###').format(_diyah.sharePerMember)} د.ع', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                Text('حصة المجموعة (${followersCount! + 1}): ${intl.NumberFormat('#,###').format(_diyah.sharePerMember * (followersCount + 1))} د.ع', 
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue)),
                              ] else ...[
                                Text('حصة العضو: ${intl.NumberFormat('#,###').format(_diyah.sharePerMember)} د.ع', 
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green)),
                                Text(member.phone, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ],
                          ),
                          trailing: Switch(
                            value: isPaid,
                            activeTrackColor: Colors.green.shade400,
                            activeColor: Colors.green.shade900,
                            onChanged: (_) => _togglePayment(member.id!),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['الكل', 'وجهاء', 'أعضاء'].map((type) {
            final isSelected = _roleFilter == type;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text(type, style: const TextStyle(fontSize: 12)),
                selected: isSelected,
                onSelected: (val) {
                  setState(() {
                    _roleFilter = type;
                    _applyFilters();
                  });
                },
              ),
            );
          }).toList(),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['الكل', 'دافعين', 'غير دافعين'].map((type) {
            final isSelected = _paymentFilter == type;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text(type, style: const TextStyle(fontSize: 12)),
                selected: isSelected,
                selectedColor: Colors.green.withAlpha(50),
                checkmarkColor: Colors.green,
                onSelected: (val) {
                  setState(() {
                    _paymentFilter = type;
                    _applyFilters();
                  });
                },
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHeaderCard() {
    final color = _diyah.isFinished ? Colors.green.shade700 : Colors.red.shade700;
    final fmt = intl.NumberFormat('#,###');
    final dateFmt = intl.DateFormat('yyyy-MM-dd');

    return Card(
      margin: EdgeInsets.zero,   // full width — padding comes from the parent
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Row 1: Title ──────────────────────────────────
            Row(
              children: [
                if (_diyah.isFinished)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.check_circle, color: Colors.white, size: 18),
                  ),
                Expanded(
                  child: Text(
                    _diyah.title,
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 10),

            // ── Row 2: Total amount  |  Share per member ─────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('المبلغ الإجمالي', style: TextStyle(fontSize: 11, color: Colors.white60)),
                      const SizedBox(height: 2),
                      Text(
                        '${fmt.format(_diyah.amount)} د.ع',
                        style: const TextStyle(fontSize: 15, color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 36, color: Colors.white24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('حصة الفرد', style: TextStyle(fontSize: 11, color: Colors.white60)),
                      const SizedBox(height: 2),
                      Text(
                        '${fmt.format(_diyah.sharePerMember)} د.ع',
                        style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 8),

            // ── Row 3: Creation date  |  Event date ──────────
            Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_circle_outline, size: 13, color: Colors.white54),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'تاريخ الإضافة: ${dateFmt.format(_diyah.createdAt)}',
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 28, color: Colors.white24),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.event_note, size: 13, color: Colors.white54),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'تاريخ الواقعة: ${dateFmt.format(_diyah.manualDate ?? _diyah.createdAt)}',
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsibleCard() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.warning, color: Colors.red),
        title: const Text('صاحب الدية'),
        subtitle: Text(_diyah.causedByName ?? "غير محدد"),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: const Text('وصف الدية', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_diyah.description ?? '', style: const TextStyle(fontSize: 14, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildDiyahStats() {
    final totalEligible = _eligibleMemberIds.length;
    final paidCount = _paidMemberIds.length;
    final remainingCount = totalEligible - _paidMemberIds.intersection(_eligibleMemberIds).length;

    final filteredTotal = _filteredMembers.length;
    final filteredWajeehs = _filteredMembers.where((m) => m.isWajeeh).length;
    final filteredMembersCount = filteredTotal - filteredWajeehs;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('المشمولين', totalEligible, Colors.blue),
                _buildStatColumn('المسددين', paidCount, Colors.green),
                _buildStatColumn('المتبقي', remainingCount, Colors.red),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('نتائج الفلترة:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                Text('وجهاء: $filteredWajeehs | أعضاء: $filteredMembersCount', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, int value, Color color) {
    return Column(
      children: [
        Text(value.toString(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}
