import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      throw Exception('Vui lòng đăng nhập lại');
    }
    return token;
  }

  Future<void> _loadNotifications() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final token = await _getToken();
      final response = await ApiClient.get('/api/notifications', token: token);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = data['notifications'] as List<dynamic>? ?? [];
      if (!mounted) return;

      setState(() {
        _notifications = items
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  String? _taskId(dynamic value) {
    if (value is Map) return (value['_id'] ?? value['id'])?.toString();
    return value?.toString();
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '';
    final local = date.toLocal();
    return '${local.day}/${local.month}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openNotification(Map<String, dynamic> item) async {
    final notificationId = item['_id']?.toString();
    final taskId = _taskId(item['taskId']);

    if (notificationId != null) {
      try {
        final token = await _getToken();
        await ApiClient.patch(
          '/api/notifications/$notificationId/read',
          <String, dynamic>{},
          token: token,
        );
      } catch (_) {
        // Vẫn mở công việc nếu cập nhật trạng thái đã đọc thất bại.
      }
    }

    if (!mounted) return;
    if (taskId != null) {
      Navigator.pop(context, taskId);
    } else {
      await _loadNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loadNotifications,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadNotifications,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      )
          : _notifications.isEmpty
          ? const Center(child: Text('Chưa có thông báo'))
          : ListView.builder(
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final item = _notifications[index];
          final isRead = item['isRead'] == true;
          return Card(
            child: ListTile(
              leading: Icon(
                isRead
                    ? Icons.notifications_none
                    : Icons.notifications_active,
              ),
              title: Text(
                item['title']?.toString() ?? 'Thông báo',
              ),
              subtitle: Text(
                '${item['message']?.toString() ?? ''}\n'
                    '${_formatDate(item['createdAt'])}',
              ),
              isThreeLine: true,
              onTap: () => _openNotification(item),
            ),
          );
        },
      ),
    );
  }
}
