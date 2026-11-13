import 'package:flutter/material.dart';
import '../services/statistics_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late Future<List<Map<String, dynamic>>> _statistics;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _statistics = Future.wait([
        StatisticsService.getTaskStatistics(),
        StatisticsService.getAssignmentStatistics(),
        StatisticsService.getDeadlineStatistics(),
      ]);
    });
  }

  Widget _statCard(String title, Object? value, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        trailing: Text(
          '${value ?? 0}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _taskList(String title, dynamic tasks) {
    final items = tasks is List ? tasks : <dynamic>[];

    return Card(
      child: ExpansionTile(
        title: Text('$title (${items.length})'),
        children: items.isEmpty
            ? [
                const ListTile(
                  title: Text('Không có công việc'),
                ),
              ]
            : items.map<Widget>((task) {
                return ListTile(
                  title: Text('${task['title'] ?? 'Không có tên'}'),
                  subtitle: Text(
                    'Trạng thái: ${task['status'] ?? ''}\n'
                    'Hạn: ${task['dueDate'] ?? ''}',
                  ),
                );
              }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê công việc'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _statistics,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Không tải được thống kê:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  ElevatedButton(
                    onPressed: _refresh,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          final tasks = data[0];
          final assignments = data[1];
          final deadlines = data[2];

          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await _statistics;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'E1 - Thống kê trạng thái',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                _statCard('Tổng công việc', tasks['total'], Icons.list_alt),
                _statCard('Đang chờ', tasks['pending'], Icons.schedule),
                _statCard('Đang thực hiện', tasks['inProgress'], Icons.work),
                _statCard('Đã hoàn thành', tasks['completed'], Icons.check_circle),
                const SizedBox(height: 16),
                const Text(
                  'E2 - Thống kê giao việc',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                _statCard('Được giao', assignments['assigned'], Icons.person),
                _statCard(
                  'Đang phụ trách',
                  assignments['inProgress'],
                  Icons.assignment_ind,
                ),
                const SizedBox(height: 16),
                const Text(
                  'E3 - Thống kê thời hạn',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                _statCard(
                  'Sắp đến hạn (24 giờ)',
                  deadlines['upcomingCount'],
                  Icons.event,
                ),
                _statCard(
                  'Quá hạn',
                  deadlines['overdueCount'],
                  Icons.warning_amber,
                ),
                _taskList('Công việc sắp đến hạn', deadlines['upcoming']),
                _taskList('Công việc quá hạn', deadlines['overdue']),
              ],
            ),
          );
        },
      ),
    );
  }
}
