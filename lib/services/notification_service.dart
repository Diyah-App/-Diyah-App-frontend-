import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';
import 'auth_service.dart';
import '../models/member_model.dart';
import '../models/diyah_model.dart';
import '../screens/member_details_screen.dart';
import '../screens/diyah_details_screen.dart';
import '../widgets/custom_app_bar.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}

enum NotificationType { member, diyah, general }

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType? _type;
  NotificationType get type => _type ?? NotificationType.general;
  final int? entityId;
  bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    NotificationType? type,
    this.entityId,
    this.isRead = false,
  }) : _type = type ?? NotificationType.general;

  Map<String, dynamic> toPayload() {
    return {
      'id': id,
      'type': type.name,
      'entityId': entityId,
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'].toString(),
      title: 'إشعار من الإدارة', // Default title for server notifications
      message: json['message'] ?? '',
      timestamp: json['created_at'] != null ? DateTime.parse(json['created_at']).toLocal() : DateTime.now(),
      type: NotificationType.general,
      isRead: true, // Assuming fetched history is already read
    );
  }
}

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Stream for auto-refreshing screens
  final StreamController<void> _refreshController = StreamController<void>.broadcast();
  Stream<void> get onRefreshRequired => _refreshController.stream;

  void addRefreshRequest() {
    _refreshController.add(null);
  }

  final List<NotificationModel> _notifications = [];
  List<NotificationModel> get notifications => List.unmodifiable(_notifications);
  
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  int _page = 1;
  final int _limit = 30;
  bool hasMoreHistory = true;
  bool isLoadingHistory = false;

  Future<void> loadMoreHistory() async {
    if (isLoadingHistory || !hasMoreHistory) return;
    isLoadingHistory = true;
    notifyListeners();

    try {
      final response = await ApiService.getNotifications(page: _page, limit: _limit, userId: AuthService.currentUserId);
      final fetched = (response['data'] as List).map((json) => NotificationModel.fromJson(json)).toList();
      
      final existingIds = _notifications.map((n) => n.id).toSet();
      for (var n in fetched) {
        if (!existingIds.contains(n.id)) {
          _notifications.add(n);
        }
      }
      
      // Sort so newest are always first
      _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      hasMoreHistory = response['has_more'] ?? false;
      _page++;
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<void> refreshHistory() async {
    _page = 1;
    hasMoreHistory = true;
    _notifications.clear();
    await loadMoreHistory();
  }

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // To handle navigation from global context
  GlobalKey<NavigatorState>? globalNavigatorKey;

  Future<void> init({GlobalKey<NavigatorState>? navigatorKey}) async {
    globalNavigatorKey = navigatorKey;
    
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const linuxInit = LinuxInitializationSettings(defaultActionName: 'Open notification');
    
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      linux: linuxInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          _handleNotificationTap(details.payload!);
        }
      },
    );

    // --- Firebase Cloud Messaging Setup ---
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      try {
        String? token = await messaging.getToken(
          vapidKey: "BGTB3g4wKUXHis0wmQp0xNjOztPhKw5tQ_BvsO7Dt-8oIyKoZFQCIXXdvT-hVZMpIPVF270gjx0EAcnNZj8420c"
        );
        if (token != null) {
          await ApiService.updateFcmToken(token);
        }
      } catch (e) {
        debugPrint("Error getting FCM token: $e");
      }
      
      messaging.onTokenRefresh.listen((newToken) {
        ApiService.updateFcmToken(newToken);
      });
      
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          addNotification(
            title: message.notification!.title ?? 'إشعار جديد',
            message: message.notification!.body ?? '',
          );
          // Trigger the global auto-refresh stream so screens can update
          _refreshController.add(null);
        }
      });
    }
  }

  void addNotification({
    required String title, 
    required String message, 
    NotificationType type = NotificationType.general,
    int? entityId,
  }) {
    final notification = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      timestamp: DateTime.now(),
      type: type,
      entityId: entityId,
    );
    _notifications.insert(0, notification);
    
    _showLocalNotification(notification);
    
    notifyListeners();
  }

  Future<void> _showLocalNotification(NotificationModel notification) async {
    const androidDetails = AndroidNotificationDetails(
      'tribal_channel',
      'Tribal Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const linuxDetails = LinuxNotificationDetails();

    const plateformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      linux: linuxDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification.title,
      notification.message,
      plateformDetails,
      payload: '${notification.type.name}|${notification.entityId}',
    );
  }

  void _handleNotificationTap(String payload) {
    final parts = payload.split('|');
    if (parts.length < 2) return;
    
    final type = parts[0];
    final entityId = int.tryParse(parts[1]);
    
    if (entityId != null) {
      navigateToEntity(type, entityId);
    }
  }

  Future<void> navigateToEntity(String type, int entityId, [BuildContext? context]) async {
    final nav = context != null ? Navigator.of(context) : globalNavigatorKey?.currentState;
    if (nav == null) return;

    try {
      if (type == 'member') {
        final membersResponse = await ApiService.getMembers(limit: 0);
        final members = (membersResponse['data'] as List).cast<Member>();
        final member = members.firstWhere((m) => m.id == entityId);
        nav.push(MaterialPageRoute(builder: (_) => MemberDetailsScreen(member: member)));
      } else if (type == 'diyah') {
        final diyahsResponse = await ApiService.getDiyahs(limit: 0);
        final diyahs = (diyahsResponse['data'] as List).cast<Diyah>();
        final diyah = diyahs.firstWhere((d) => d.id == entityId);
        nav.push(MaterialPageRoute(builder: (_) => DiyahDetailsScreen(diyah: diyah)));
      }
    } catch (e) {
      debugPrint('Navigation error: $e');
    }
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index].isRead = true;
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (var n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }
}

class NotificationBadgeIcon extends StatelessWidget {
  const NotificationBadgeIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: NotificationService(),
      builder: (context, child) {
        final count = NotificationService().unreadCount;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const NotificationHistoryScreen()),
                );
              },
            ),
            if (count > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    count > 99 ? '99+' : count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Fetch initial history when opening screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().refreshHistory();
    });
    
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
        NotificationService().loadMoreHistory();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'سجل الإشعارات',
          extraActions: [
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'تحديد الكل كمقروء',
              onPressed: () => NotificationService().markAllAsRead(),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'مسح الكل',
              onPressed: () => NotificationService().clearAll(),
            ),
          ],
        ),
        body: AnimatedBuilder(
          animation: NotificationService(),
          builder: (context, child) {
            final notifications = NotificationService().notifications;
            final isLoading = NotificationService().isLoadingHistory;
            final hasMore = NotificationService().hasMoreHistory;
            
            if (notifications.isEmpty && isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (notifications.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('لا توجد إشعارات حالياً', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            return ListView.separated(
              controller: _scrollController,
              itemCount: notifications.length + (hasMore ? 1 : 0),
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == notifications.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                
                final notification = notifications[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: notification.isRead ? Colors.grey[200] : Colors.blue[50],
                    child: Icon(
                      notification.type == NotificationType.member ? Icons.person : 
                      notification.type == NotificationType.diyah ? Icons.history_edu : 
                      Icons.info_outline,
                      color: notification.isRead ? Colors.grey : Colors.blue,
                    ),
                  ),
                  title: Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notification.message),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(notification.timestamp),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  onTap: () {
                    NotificationService().markAsRead(notification.id);
                    if (notification.type != NotificationType.general && notification.entityId != null) {
                      NotificationService().navigateToEntity(notification.type.name, notification.entityId!, context);
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')} - ${dt.day}/${dt.month}/${dt.year}';
  }
}
