import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:sapa_jonusa/api/api.dart' as Api;

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _storage = const FlutterSecureStorage();
  List _notifList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotificationList();
    // _markNotificationsAsRead() sengaja dihapus dari sini agar badge tidak hilang otomatis
  }

  Future<void> _fetchNotificationList() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      final res = await http.get(
        Uri.parse('${Api.baseUrl}/api/notifications/list'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _notifList = json.decode(res.body);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetch list: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markNotificationsAsRead() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      final res = await http.post(
        Uri.parse('${Api.baseUrl}/api/notifications/mark-read'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            for (var notif in _notifList) {
              notif['is_read'] = true;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Semua notifikasi ditandai dibaca')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error mark read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasUnread = _notifList.any((n) => n['is_read'] == false);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text(
          'Notifikasi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1565C0),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 1,
        actions: [
          if (hasUnread)
            IconButton(
              icon: const Icon(Icons.done_all_rounded),
              tooltip: 'Tandai semua dibaca',
              onPressed: _markNotificationsAsRead,
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _notifList.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                onRefresh: _fetchNotificationList,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder:
                      (context, index) => _buildNotifCard(_notifList[index]),
                ),
              ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_rounded,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada notifikasi baru',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNotifCard(dynamic notif) {
    IconData icon = Icons.info_rounded;
    Color color = Colors.grey;

    if (notif['type'] == 'chat') {
      icon = Icons.chat_rounded;
      color = const Color(0xFF1565C0);
    } else if (notif['type'] == 'presence') {
      icon = Icons.fingerprint_rounded;
      color = const Color(0xFF00897B);
    }

    bool isUnread = notif['is_read'] == false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            isUnread
                ? Border.all(color: color.withOpacity(0.5), width: 1.5)
                : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif['title'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF0D1B3E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notif['message'],
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A99B5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  notif['created_at'],
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (isUnread)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}
