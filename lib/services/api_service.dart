import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/member_model.dart';
import '../models/diyah_model.dart';
import '../utils/constants.dart';
import 'auth_service.dart';

class ApiService {
  static String get baseUrl => AppConstants.baseUrl;

  static Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'X-App-Token': AppConstants.appToken,
    };
    if (AuthService.currentUserId != null) {
      headers['X-User-Id'] = AuthService.currentUserId.toString();
    }
    return headers;
  }

  static Future<void> updateFcmToken(String fcmToken) async {
    final userId = AuthService.currentUserId;
    if (userId == null) return;
    try {
      await http.put(
        Uri.parse('$baseUrl/members/$userId/fcm-token'),
        headers: _getHeaders(),
        body: json.encode({'fcm_token': fcmToken}),
      );
    } catch (e) {
      print('Failed to update FCM token: $e');
    }
  }

  // --- Members ---
  static Future<List<Member>> getMembers() async {
    final response = await http.get(Uri.parse('$baseUrl/members'), headers: _getHeaders());
    if (response.statusCode == 200) {
      List data = json.decode(response.body);
      return data.map((m) => Member.fromJson(m)).toList();
    }
    throw Exception('Failed to load members');
  }

  static Future<Member> addMember(Member member, {String? password}) async {
    final body = member.toJson();
    if (password != null) body['password'] = password;
    final response = await http.post(
      Uri.parse('$baseUrl/members'),
      headers: _getHeaders(),
      body: json.encode(body),
    );
    if (response.statusCode == 201) {
      return Member.fromJson(json.decode(response.body)['member']);
    }
    throw Exception('Failed to add member');
  }

  static Future<void> updateMember(Member member, {String? password, int? transferWajeehId}) async {
    final body = member.toJson();
    if (password != null) body['password'] = password;
    if (transferWajeehId != null) body['transfer_wajeeh_id'] = transferWajeehId;
    final response = await http.put(
      Uri.parse('$baseUrl/members/${member.id}'),
      headers: _getHeaders(),
      body: json.encode(body),
    );
    if (response.statusCode != 200) throw Exception('Failed to update member');
  }

  static Future<void> deleteMember(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/members/$id'), headers: _getHeaders());
    if (response.statusCode != 200) throw Exception('Failed to delete member');
  }

  static Future<List<Member>> getWajeehs() async {
    final response = await http.get(Uri.parse('$baseUrl/wajeehs'), headers: _getHeaders());
    if (response.statusCode == 200) {
      List data = json.decode(response.body);
      return data.map((m) => Member.fromJson(m)).toList();
    }
    throw Exception('Failed to load wajeehs');
  }

  static Future<List<Member>> getWajeehMembers(int wajeehId) async {
    final response = await http.get(Uri.parse('$baseUrl/wajeehs/$wajeehId/members'), headers: _getHeaders());
    if (response.statusCode == 200) {
      List data = json.decode(response.body);
      return data.map((m) => Member.fromJson(m)).toList();
    }
    throw Exception('Failed to load wajeeh members');
  }

  static Future<Map<String, List<Diyah>>> getMemberHistory(int memberId) async {
    final response = await http.get(Uri.parse('$baseUrl/members/$memberId/history'), headers: _getHeaders());
    if (response.statusCode == 200) {
      Map<String, dynamic> data = json.decode(response.body);
      return {
        'caused':      (data['caused']      as List? ?? []).map((d) => Diyah.fromJson(d)).toList(),
        'paid':        (data['paid']        as List? ?? []).map((d) => Diyah.fromJson(d)).toList(),
        'not_paid':    (data['not_paid']    as List? ?? []).map((d) => Diyah.fromJson(d)).toList(),
        'not_liable':  (data['not_liable']  as List? ?? []).map((d) => Diyah.fromJson(d)).toList(),
      };
    }
    throw Exception('Failed to load member history');
  }

  static Future<void> changeUserRole(int memberId, String role, {String? password}) async {
    final body = {'role': role};
    if (password != null) body['password'] = password;
    final response = await http.put(
      Uri.parse('$baseUrl/members/$memberId/role'),
      headers: _getHeaders(),
      body: json.encode(body),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Failed to update role');
    }
  }

  // --- Diyahs ---
  static Future<List<Diyah>> getDiyahs() async {
    final response = await http.get(Uri.parse('$baseUrl/diyahs'), headers: _getHeaders());
    if (response.statusCode == 200) {
      List data = json.decode(response.body);
      return data.map((m) => Diyah.fromJson(m)).toList();
    }
    throw Exception('Failed to load diyahs');
  }

  static Future<Diyah> addDiyah(Diyah diyah) async {
    final response = await http.post(
      Uri.parse('$baseUrl/diyahs'),
      headers: _getHeaders(),
      body: json.encode(diyah.toJson()),
    );
    if (response.statusCode == 201) {
      return Diyah.fromJson(json.decode(response.body)['diyah']);
    }
    throw Exception('Failed to add diyah');
  }

  static Future<void> updateDiyah(Diyah diyah) async {
    final response = await http.put(
      Uri.parse('$baseUrl/diyahs/${diyah.id}'),
      headers: _getHeaders(),
      body: json.encode(diyah.toJson()),
    );
    if (response.statusCode != 200) throw Exception('Failed to update diyah');
  }

  static Future<void> deleteDiyah(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/diyahs/$id'), headers: _getHeaders());
    if (response.statusCode != 200) throw Exception('Failed to delete diyah');
  }

  static Future<Map<String, List<int>>> getDiyahPaymentStatus(int diyahId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/diyahs/$diyahId/payments'),
      headers: _getHeaders(),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return {
        'paid': List<int>.from(data['paid_member_ids']),
        'eligible': List<int>.from(data['eligible_member_ids']),
      };
    }
    throw Exception('Failed to load payment status');
  }

  static Future<void> updateDiyahPayments(int diyahId, List<int> paidMemberIds) async {
    final response = await http.post(
      Uri.parse('$baseUrl/diyahs/$diyahId/payments'),
      headers: _getHeaders(),
      body: json.encode({'paid_member_ids': paidMemberIds}),
    );
    if (response.statusCode != 200) throw Exception('Failed to update payments');
  }

  static Future<void> updateRemoteConfig(Map<String, String> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/settings/remote-config'),
      headers: _getHeaders(),
      body: json.encode(data),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update remote config: ${response.body}');
    }
  }
}
