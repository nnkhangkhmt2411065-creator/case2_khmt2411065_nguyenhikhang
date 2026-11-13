import 'task_activity_screen.dart';
import '../screens/statistics_screen.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_screen.dart';
import '../services/api_client.dart';

class TaskListScreen extends StatefulWidget {
const TaskListScreen({super.key});

@override
State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
List<Map<String, dynamic>> _tasks = [];
bool _isLoading = true;

@override
void initState() {
super.initState();
_loadTasks();
}

// Lấy danh sách công việc từ MongoDB
Future<void> _loadTasks() async {
try {
final response = await ApiClient.get('/tasks');

if (response.statusCode != 200) {
throw Exception('Không thể tải danh sách công việc');
}

final data = jsonDecode(response.body);
final tasks = data['tasks'] as List;

if (!mounted) return;

setState(() {
_tasks = tasks
    .map((task) => Map<String, dynamic>.from(task))
    .toList();
_isLoading = false;
});
} catch (error) {
if (!mounted) return;

setState(() {
_isLoading = false;
});

_showMessage(
'Lỗi tải công việc: $error',
isError: true,
);
}
}

// Hiển thị thông báo
void _showMessage(
String message, {
bool isError = false,
}) {
if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(message),
backgroundColor:
isError ? Colors.red : Colors.green,
),
);
}

// A3 - Đăng xuất và xóa thông tin đăng nhập đã lưu
Future<void> _handleLogout() async {
try {
final prefs = await SharedPreferences.getInstance();
await prefs.remove('token');
await prefs.remove('userId');
await prefs.remove('fullName');
await prefs.remove('email');

if (!mounted) return;
Navigator.pushNamedAndRemoveUntil(
context,
'/',
(route) => false,
);
} catch (error) {
_showMessage('Lỗi đăng xuất: $error', isError: true);
}
}

// A4 - Mở màn hình thông tin cá nhân
void _openProfile() {
Navigator.push(
context,
MaterialPageRoute(
builder: (context) => const ProfileScreen(),
),
);
}

// Màu mức độ ưu tiên
Color _getPriorityColor(String? priority) {
switch (priority) {
case 'high':
return Colors.red;
case 'medium':
return Colors.orange;
default:
return Colors.green;
}
}

// Hiển thị trạng thái
String _getStatusText(String? status) {
switch (status) {
case 'completed':
return 'Đã xong';
case 'in-progress':
return 'Đang làm';
default:
return 'Chưa làm';
}
}

// Hiển thị mức độ ưu tiên
String _getPriorityText(String? priority) {
switch (priority) {
case 'high':
return 'Cao';
case 'medium':
return 'Trung bình';
default:
return 'Thấp';
}
}

// Định dạng ngày
String _formatDate(dynamic date) {
if (date == null || date.toString().isEmpty) {
return 'Chưa thiết lập';
}

return date.toString().split('T').first;
}

// Thêm công việc mới
Future<void> _showAddTaskDialog() async {
final titleController = TextEditingController();

String priority = 'medium';
DateTime? selectedDate;
bool isSaving = false;

await showDialog<void>(
context: context,
builder: (dialogContext) {
return StatefulBuilder(
builder: (context, setDialogState) {
return AlertDialog(
title: const Text('Thêm công việc mới'),

content: SingleChildScrollView(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
TextField(
controller: titleController,
decoration: const InputDecoration(
labelText: 'Tên công việc',
border: OutlineInputBorder(),
prefixIcon: Icon(Icons.task),
),
),

const SizedBox(height: 16),

DropdownButtonFormField<String>(
initialValue: priority,
decoration: const InputDecoration(
labelText: 'Mức độ ưu tiên',
border: OutlineInputBorder(),
),
items: const [
DropdownMenuItem(
value: 'low',
child: Text('Thấp'),
),
DropdownMenuItem(
value: 'medium',
child: Text('Trung bình'),
),
DropdownMenuItem(
value: 'high',
child: Text('Cao'),
),
],
onChanged: isSaving
? null
    : (value) {
if (value != null) {
setDialogState(() {
priority = value;
});
}
},
),

const SizedBox(height: 16),

OutlinedButton.icon(
icon: const Icon(
Icons.calendar_today,
),
label: Text(
selectedDate == null
? 'Chọn hạn hoàn thành'
    : _formatDate(
selectedDate!
    .toIso8601String(),
),
),
onPressed: isSaving
? null
    : () async {
final date =
await showDatePicker(
context: dialogContext,
initialDate:
selectedDate ??
DateTime.now(),
firstDate: DateTime(2020),
lastDate: DateTime(2100),
);

if (date != null &&
dialogContext.mounted) {
setDialogState(() {
selectedDate = date;
});
}
},
),
],
),
),

actions: [
TextButton(
onPressed: isSaving
? null
    : () {
Navigator.pop(dialogContext);
},
child: const Text('Hủy'),
),

ElevatedButton(
onPressed: isSaving
? null
    : () async {
final title =
titleController.text.trim();

if (title.isEmpty) {
_showMessage(
'Vui lòng nhập tên công việc',
isError: true,
);
return;
}

setDialogState(() {
isSaving = true;
});

try {
final response =
await ApiClient.post(
'/tasks',
{
'title': title,
'priority': priority,
'status': 'pending',
if (selectedDate != null)
'dueDate': _formatDate(
selectedDate!
    .toIso8601String(),
),
},
);

if (response.statusCode != 201) {
throw Exception(
'Không thể lưu công việc: ${response.body}',
);
}

if (!mounted ||
!dialogContext.mounted) {
return;
}

Navigator.pop(dialogContext);

_showMessage(
'Thêm công việc thành công!',
);

await _loadTasks();
} catch (error) {
_showMessage(
'Lỗi thêm công việc: $error',
isError: true,
);

if (dialogContext.mounted) {
setDialogState(() {
isSaving = false;
});
}
}
},
child: Text(
isSaving
? 'Đang lưu...'
    : 'Lưu công việc',
),
),
],
);
},
);
},
);

// Tránh giải phóng controller ngay khi dialog
// đang thực hiện hiệu ứng đóng.
await Future<void>.delayed(
const Duration(milliseconds: 300),
);
titleController.dispose();
}

Future<void> _showEditTaskDialog(Map<String, dynamic> task) async {
  final titleController = TextEditingController(
    text: task['title']?.toString() ?? '',
  );
  bool isSaving = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Chỉnh sửa công việc'),
            content: TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Tên công việc',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) {
                          _showMessage(
                            'Vui lòng nhập tên công việc',
                            isError: true,
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);

                        try {
                          final response = await ApiClient.put(
                            '/tasks/${task['_id']}',
                            {'title': title},
                          );

                          if (response.statusCode != 200) {
                            throw Exception(response.body);
                          }

                          if (!mounted || !dialogContext.mounted) return;

                          Navigator.pop(dialogContext);
                          _showMessage('Cập nhật công việc thành công!');
                          await _loadTasks();
                        } catch (error) {
                          _showMessage(
                            'Lỗi cập nhật công việc: $error',
                            isError: true,
                          );
                          if (dialogContext.mounted) {
                            setDialogState(() => isSaving = false);
                          }
                        }
                      },
                child: Text(isSaving ? 'Đang lưu...' : 'Lưu'),
              ),
            ],
          );
        },
      );
    },
  );

  await Future<void>.delayed(const Duration(milliseconds: 300));
  titleController.dispose();
}
// Xem chi tiết công việc
void _showTaskDetails(int index) {
final task = _tasks[index];

showDialog<void>(
context: context,
builder: (dialogContext) {
return AlertDialog(
title: Text(
task['title']?.toString() ?? '',
),
content: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'Trạng thái: ${_getStatusText(task['status']?.toString())}',
),

const SizedBox(height: 10),

Text(
'Ưu tiên: ${_getPriorityText(task['priority']?.toString())}',
),

const SizedBox(height: 10),

Text(
'Hạn hoàn thành: ${_formatDate(task['dueDate'])}',
),
],
),
actions: [
TextButton.icon(
  onPressed: () {
    Navigator.pop(dialogContext);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskActivityScreen(
          taskId: task['_id'].toString(),
          taskTitle: task['title'].toString(),
        ),
      ),
    );
  },
  icon: const Icon(Icons.history),
  label: const Text('Lịch sử'),
),
TextButton.icon(
  onPressed: () {
    Navigator.pop(dialogContext);
    _showEditTaskDialog(task);
  },
  icon: const Icon(Icons.edit),
  label: const Text('Chỉnh sửa'),
),
TextButton(
onPressed: () {
Navigator.pop(dialogContext);
},
child: const Text('Đóng'),
),

TextButton(
onPressed: () {
Navigator.pop(dialogContext);

_deleteTask(
task['_id']?.toString(),
);
},
child: const Text(
'Xóa',
style: TextStyle(
color: Colors.red,
),
),
),
],
);
},
);
}

// Xóa công việc khỏi MongoDB
Future<void> _deleteTask(String? id) async {
if (id == null || id.isEmpty) {
_showMessage(
'Không tìm thấy mã công việc',
isError: true,
);
return;
}

try {
final response =
await ApiClient.delete('/tasks/$id');

if (response.statusCode != 200) {
throw Exception(
'Không thể xóa công việc',
);
}

_showMessage('Đã xóa công việc');

await _loadTasks();
} catch (error) {
_showMessage(
'Lỗi xóa công việc: $error',
isError: true,
);
}
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text(
'Danh sách công việc',
),
actions: [
IconButton(
  icon: const Icon(Icons.bar_chart),
  tooltip: 'Thống kê',
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const StatisticsScreen(),
      ),
    );
  },
),
IconButton(
icon: const Icon(Icons.refresh),
tooltip: 'Tải lại',
onPressed: _loadTasks,
),

IconButton(
icon: const Icon(Icons.person_outline),
tooltip: 'Thông tin cá nhân',
onPressed: _openProfile,
),
IconButton(
icon: const Icon(Icons.logout),
tooltip: 'Đăng xuất',
onPressed: _handleLogout,
),
],
),

body: _isLoading
? const Center(
child: CircularProgressIndicator(),
)
    : _tasks.isEmpty
? const Center(
child: Text(
'Chưa có công việc nào',
style: TextStyle(
fontSize: 18,
),
),
)
    : ListView.builder(
itemCount: _tasks.length,
itemBuilder: (context, index) {
final task = _tasks[index];

return Card(
margin:
const EdgeInsets.symmetric(
horizontal: 12,
vertical: 6,
),
child: ListTile(
onTap: () {
_showTaskDetails(index);
},

leading: Icon(
Icons.task_alt,
color: _getPriorityColor(
task['priority']
    ?.toString(),
),
),

title: Text(
task['title']
    ?.toString() ??
'',
style: const TextStyle(
fontWeight:
FontWeight.bold,
),
),

subtitle: Text(
'Hạn hoàn thành: ${_formatDate(task['dueDate'])}',
),

trailing: Chip(
label: Text(
_getStatusText(
task['status']
    ?.toString(),
),
),
),
),
);
},
),

floatingActionButton:
FloatingActionButton(
onPressed: _showAddTaskDialog,
tooltip: 'Thêm công việc',
child: const Icon(Icons.add),
),
);
}
}
