import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TaskActivityScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;

  const TaskActivityScreen({
    super.key,
    required this.taskId,
    required this.taskTitle,
  });

  @override
  State<TaskActivityScreen> createState() => _TaskActivityScreenState();
}

class _TaskActivityScreenState extends State<TaskActivityScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> activities = [];

  @override
  void initState() {
    super.initState();
    loadActivities();
  }

  Future<void> loadActivities() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await ApiClient.get(
        '/task-activities/${widget.taskId}',
        token: token,
      );

      if (response.statusCode != 200) {
        throw Exception('Không thể tải lịch sử hoạt động');
      }

      final data = jsonDecode(response.body);

      if (!mounted) return;

      setState(() {
        activities = data['activities'] as List;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = error.toString();
        isLoading = false;
      });
    }
  }

  String formatDate(dynamic value) {
    if (value == null) return '';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return '';
    final local = date.toLocal();
    return '${local.day}/${local.month}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử hoạt động'),
        actions: [
          IconButton(
            onPressed: loadActivities,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(errorMessage!),
                      ElevatedButton(
                        onPressed: loadActivities,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : activities.isEmpty
                  ? const Center(
                      child: Text('Chưa có lịch sử hoạt động'),
                    )
                  : ListView.builder(
                      itemCount: activities.length,
                      itemBuilder: (context, index) {
                        final activity = activities[index];
                        final action = activity['action'];

                        return Card(
                          margin: const EdgeInsets.all(8),
                          child: ListTile(
                            leading: Icon(
                              action == 'created'
                                  ? Icons.add_circle
                                  : action == 'deleted'
                                      ? Icons.delete
                                      : Icons.edit,
                            ),
                            title: Text(
                              activity['description']?.toString() ??
                                  'Hoạt động',
                            ),
                            subtitle: Text(
                              formatDate(activity['createdAt']),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
