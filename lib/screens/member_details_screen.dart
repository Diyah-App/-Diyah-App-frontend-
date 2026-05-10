import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart' as intl;
import '../models/member_model.dart';
import '../models/diyah_model.dart';
import '../services/api_service.dart';
import '../widgets/smart_search_bar.dart';
import '../widgets/member_tile.dart';
import 'diyah_details_screen.dart';

class MemberDetailsScreen extends StatefulWidget {
  final Member member;

  const MemberDetailsScreen({super.key, required this.member});

  @override
  State<MemberDetailsScreen> createState() => _MemberDetailsScreenState();
}

class _MemberDetailsScreenState extends State<MemberDetailsScreen> {
  late Member _member;
  List<Diyah> _caused = [];
  List<Diyah> _paid = [];
  List<Diyah> _pending = [];
  List<Diyah> _notLiable = [];
  List<Member> _followers = [];
  bool _isLoading = true;
  String _causedSearch = "";
  String _paidSearch = "";
  String _pendingSearch = "";
  String _notLiableSearch = "";
  String _followersSearch = "";

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await ApiService.getMemberHistory(_member.id!);
      final allMembers = await ApiService.getMembers();
      if (!mounted) return;

      // Followers = members whose wajeehId matches this member's id
      // Exclude the wajeeh himself and ensure wajeehId is not null
      final followers = allMembers.where((m) {
        return m.wajeehId != null && 
               m.wajeehId == _member.id && 
               m.id != _member.id;
      }).toList();

      setState(() {
        _caused = history['caused'] ?? [];
        _paid = history['paid'] ?? [];
        _pending = history['not_paid'] ?? [];
        _notLiable = history['not_liable'] ?? [];
        _followers = followers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _makeCall() async {
    final Uri launchUri = Uri(scheme: 'tel', path: _member.phone);
    if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('ملف العضو')),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildStatsSection(),
                  const SizedBox(height: 24),
                  if (_member.isWajeeh) ...[
                    _buildFollowersSection(),
                    const SizedBox(height: 24),
                  ],
                  _buildDiyahHistorySection('ديات هو صاحبها', _caused, Colors.red, _causedSearch, (val) => setState(() => _causedSearch = val)),
                  _buildDiyahHistorySection('ديات تم تسديدها', _paid, Colors.green, _paidSearch, (val) => setState(() => _paidSearch = val)),
                  _buildDiyahHistorySection('ديات قيد التحصيل (مشمول)', _pending, Colors.orange, _pendingSearch, (val) => setState(() => _pendingSearch = val)),
                  _buildDiyahHistorySection('ديات قديمة (غير مشمول)', _notLiable, Colors.blueGrey, _notLiableSearch, (val) => setState(() => _notLiableSearch = val)),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        CircleAvatar(
          radius: 40, 
          backgroundColor: _member.isWajeeh ? Colors.amber.shade100 : Colors.blue.shade100, 
          child: Icon(
            _member.isWajeeh ? Icons.star : Icons.person, 
            size: 40, 
            color: _member.isWajeeh ? Colors.amber : Colors.blue
          )
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_member.fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            _buildRoleBadge(),
          ],
        ),
        Text(_member.phone, style: const TextStyle(color: Colors.grey)),
        IconButton(icon: const Icon(Icons.call, color: Colors.green), onPressed: _makeCall),
      ],
    );
  }

  Widget _buildRoleBadge() {
    String adminRoleName = "";
    Color adminRoleColor = Colors.transparent;

    if (_member.role == 'sheikh') {
      adminRoleName = "شيخ";
      adminRoleColor = Colors.orange.shade800;
    } else if (_member.role == 'admin') {
      adminRoleName = "مشرف";
      adminRoleColor = Colors.red.shade700;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (adminRoleName.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: adminRoleColor.withAlpha(40),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: adminRoleColor.withAlpha(60)),
            ),
            child: Text(
              adminRoleName,
              style: TextStyle(
                fontSize: 12,
                color: adminRoleColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _member.isWajeeh ? Colors.amber.withAlpha(50) : Colors.blue.withAlpha(50),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            _member.isWajeeh ? 'وجيه' : 'عضو',
            style: TextStyle(
              fontSize: 12,
              color: _member.isWajeeh ? Colors.amber.shade900 : Colors.blue.shade900,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatCard('صاحب الدية', _caused.length.toString(), Colors.red),
        _buildStatCard('المدفوعة', _paid.length.toString(), Colors.green),
        _buildStatCard('المتبقية', _pending.length.toString(), Colors.orange),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildDiyahHistorySection(String title, List<Diyah> diyahs, Color color, String currentSearch, Function(String) onSearchChanged) {
    final filtered = diyahs.where((d) => 
      SmartSearchBar.matches(d.title, currentSearch)
    ).toList();

    return ExpansionTile(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(10)),
            child: Text(diyahs.length.toString(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
      children: [
        if (diyahs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SmartSearchBar(
              hintText: 'بحث في هذه القائمة...',
              onChanged: onSearchChanged,
            ),
          ),
        if (filtered.isEmpty && diyahs.isNotEmpty)
          const ListTile(title: Text('لا توجد نتائج تطابق بحثك', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
        if (diyahs.isEmpty)
          const ListTile(title: Text('لا يوجد سجل حالياً'))
        else
          ...filtered.map((d) => ListTile(
            title: Text(d.title),
            subtitle: Text('الإجمالي: ${intl.NumberFormat('#,###').format(d.amount)} | حصتك: ${intl.NumberFormat('#,###').format(d.sharePerMember)} د.ع'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => DiyahDetailsScreen(diyah: d)),
              );
            },
          )),
      ],
    );
  }

  Widget _buildFollowersSection() {
    final filtered = _followers.where((m) => 
      SmartSearchBar.matches(m.fullName, _followersSearch) || 
      SmartSearchBar.matches(m.phone, _followersSearch)
    ).toList();

    return ExpansionTile(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('الأعضاء التابعين', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(color: Colors.blueGrey.withAlpha(30), borderRadius: BorderRadius.circular(10)),
            child: Text(_followers.length.toString(), style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
      children: [
        if (_followers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SmartSearchBar(
              hintText: 'بحث في التابعين...',
              onChanged: (val) => setState(() => _followersSearch = val),
            ),
          ),
        if (filtered.isEmpty && _followers.isNotEmpty)
          const ListTile(title: Text('لا توجد نتائج تطابق بحثك', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
        if (_followers.isEmpty)
          const ListTile(title: Text('لا يوجد تابعين حالياً'))
        else
          ...filtered.map((m) => MemberTile(
            member: m,
            onRefresh: _loadHistory,
          )),
      ],
    );
  }
}
