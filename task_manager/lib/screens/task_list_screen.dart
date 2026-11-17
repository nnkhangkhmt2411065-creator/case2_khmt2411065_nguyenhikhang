import 'dart:convert';
import 'notification_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/statistics_screen.dart';
import '../services/api_client.dart';
import 'profile_screen.dart';
import 'task_activity_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;
  final Set<String> _updatingTaskIds = {};

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<String> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception('Vui lòng đăng nhập lại');
    }

    return token;
  }

  String? _getUserId(dynamic value) {
    if (value is Map) {
      return (value['_id'] ?? value['id'])?.toString();
    }
    return value?.toString();
  }

  String _getUserName(Map<String, dynamic> user) {
    final name = user['fullName']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
    return user['email']?.toString() ?? 'Người dùng';
  }

  // E2 - Lấy danh sách người dùng để giao việc.
  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception('Vui lòng đăng nhập lại');
    }

    final response = await ApiClient.get('/api/users', token: token);

    if (response.statusCode != 200) {
      throw Exception('Không thể tải người dùng: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final users = data['users'] as List<dynamic>? ?? [];

    return users
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  // Lấy danh sách công việc từ MongoDB.
  Future<void> _loadTasks() async {
    try {
      final token = await _getAuthToken();
      final response = await ApiClient.get('/api/tasks', token: token);

      if (response.statusCode != 200) {
        throw Exception('Không thể tải danh sách công việc');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tasks = data['tasks'] as List<dynamic>? ?? [];

      if (!mounted) return;

      setState(() {
        _tasks = tasks
            .map((task) => Map<String, dynamic>.from(task as Map))
            .toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Lỗi tải công việc: $error', isError: true);
    }
  }

  // Hiển thị thông báo.
  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // A3 - Đăng xuất và xóa thông tin đăng nhập đã lưu.
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

  // A4 - Mở màn hình thông tin cá nhân.
  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileScreen(),
      ),
    );
  }

  // Màu mức độ ưu tiên.
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

  // Hiển thị trạng thái.
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

  // Hiển thị mức độ ưu tiên.
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

  // Định dạng ngày.
  String _formatDate(dynamic date) {
    if (date == null || date.toString().isEmpty) {
      return 'Chưa thiết lập';
    }

    return date.toString().split('T').first;
  }

  // Thêm công việc mới.
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
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        selectedDate == null
                            ? 'Chọn hạn hoàn thành'
                            : _formatDate(
                          selectedDate!.toIso8601String(),
                        ),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                        final date = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );

                        if (date != null && dialogContext.mounted) {
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
                    final title = titleController.text.trim();

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
                      final token = await _getAuthToken();
                      final response = await ApiClient.post(
                        '/api/tasks',
                        {
                          'title': title,
                          'priority': priority,
                          'status': 'pending',
                          if (selectedDate != null)
                            'dueDate': _formatDate(
                              selectedDate!.toIso8601String(),
                            ),
                        },
                        token: token,
                      );

                      if (response.statusCode != 201) {
                        throw Exception(
                          'Không thể lưu công việc: ${response.body}',
                        );
                      }

                      if (!mounted || !dialogContext.mounted) {
                        return;
                      }

                      Navigator.pop(dialogContext);
                      _showMessage('Thêm công việc thành công!');
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
                  child: Text(isSaving ? 'Đang lưu...' : 'Lưu công việc'),
                ),
              ],
            );
          },
        );
      },
    );

    // Tránh giải phóng controller ngay khi dialog đang thực hiện hiệu ứng đóng.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    titleController.dispose();
  }

  // E2 - Chỉnh sửa công việc, chọn người được giao và thay đổi trạng thái.
  Future<void> _showEditTaskDialog(Map<String, dynamic> task) async {
    final titleController = TextEditingController(
      text: task['title']?.toString() ?? '',
    );

    List<Map<String, dynamic>> users;

    try {
      users = await _loadUsers();
    } catch (error) {
      titleController.dispose();

      if (mounted) {
        _showMessage(
          'Lỗi tải danh sách người dùng: $error',
          isError: true,
        );
      }
      return;
    }

    if (!mounted) {
      titleController.dispose();
      return;
    }

    String? getId(dynamic value) {
      if (value == null) return null;
      if (value is Map) return value['_id']?.toString();
      return value.toString();
    }

    final selectedUserIds = <String>{};
    final savedAssignees = task['assigneeIds'];

    if (savedAssignees is List) {
      for (final assignee in savedAssignees) {
        final userId = getId(assignee);
        if (userId != null && userId.isNotEmpty) {
          selectedUserIds.add(userId);
        }
      }
    }

    // Giữ người được giao của công việc cũ nếu chưa có assigneeIds.
    if (selectedUserIds.isEmpty) {
      final oldAssigneeId = getId(task['assignedTo']);
      if (oldAssigneeId != null && oldAssigneeId.isNotEmpty) {
        selectedUserIds.add(oldAssigneeId);
      }
    }

    String? selectedPrimaryUserId = getId(task['primaryAssigneeId']);

    if (!selectedUserIds.contains(selectedPrimaryUserId)) {
      final oldAssigneeId = getId(task['assignedTo']);
      selectedPrimaryUserId = selectedUserIds.contains(oldAssigneeId)
          ? oldAssigneeId
          : (selectedUserIds.isEmpty ? null : selectedUserIds.first);
    }

    String selectedStatus = task['status']?.toString() ?? 'pending';

    if (!['pending', 'in-progress', 'completed'].contains(selectedStatus)) {
      selectedStatus = 'pending';
    }

    String userLabel(String userId) {
      for (final user in users) {
        if (getId(user) == userId) {
          final name = user['fullName']?.toString().trim() ?? '';
          final email = user['email']?.toString() ?? '';

          if (name.isNotEmpty) return name;
          if (email.isNotEmpty) return email;
        }
      }
      return 'Người dùng';
    }

    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              scrollable: true,
              title: const Text('Chỉnh sửa công việc'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Tên công việc',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Chọn người được giao'),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: users.map((user) {
                      final userId = getId(user);

                      if (userId == null || userId.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          userLabel(userId),
                          overflow: TextOverflow.ellipsis,
                        ),
                        value: selectedUserIds.contains(userId),
                        onChanged: isSaving
                            ? null
                            : (checked) {
                          setDialogState(() {
                            if (checked == true) {
                              selectedUserIds.add(userId);
                              selectedPrimaryUserId ??= userId;
                            } else {
                              selectedUserIds.remove(userId);

                              if (selectedPrimaryUserId == userId) {
                                selectedPrimaryUserId =
                                selectedUserIds.isEmpty
                                    ? null
                                    : selectedUserIds.first;
                              }
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPrimaryUserId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Người phụ trách chính',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Chọn người phụ trách chính'),
                    items: selectedUserIds.map((userId) {
                      return DropdownMenuItem<String>(
                        value: userId,
                        child: Text(
                          userLabel(userId),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: isSaving || selectedUserIds.isEmpty
                        ? null
                        : (value) {
                      setDialogState(() {
                        selectedPrimaryUserId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Trạng thái',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('Chưa làm'),
                      ),
                      DropdownMenuItem(
                        value: 'in-progress',
                        child: Text('Đang làm'),
                      ),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('Hoàn thành'),
                      ),
                    ],
                    onChanged: isSaving
                        ? null
                        : (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedStatus = value;
                        });
                      }
                    },
                  ),
                ],
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

                    if (selectedUserIds.isNotEmpty &&
                        selectedPrimaryUserId == null) {
                      _showMessage(
                        'Vui lòng chọn người phụ trách chính',
                        isError: true,
                      );
                      return;
                    }

                    setDialogState(() {
                      isSaving = true;
                    });

                    try {
                      final prefs =
                      await SharedPreferences.getInstance();
                      final token = prefs.getString('token');

                      if (token == null || token.isEmpty) {
                        throw Exception('Vui lòng đăng nhập lại');
                      }

                      final response = await ApiClient.put(
                        '/api/tasks/${task['_id']}',
                        {
                          'title': title,
                          'assigneeIds': selectedUserIds.toList(),
                          'primaryAssigneeId': selectedPrimaryUserId,
                          'status': selectedStatus,
                        },
                        token: token,
                      );

                      if (response.statusCode != 200) {
                        throw Exception(response.body);
                      }

                      if (!mounted || !dialogContext.mounted) {
                        return;
                      }

                      Navigator.pop(dialogContext);
                      _showMessage('Cập nhật công việc thành công!');
                      await _loadTasks();
                    } catch (error) {
                      if (mounted) {
                        _showMessage(
                          'Lỗi cập nhật công việc: $error',
                          isError: true,
                        );
                      }

                      if (dialogContext.mounted) {
                        setDialogState(() {
                          isSaving = false;
                        });
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

  // Cập nhật trạng thái công việc và tải lại danh sách.
  Future<void> _changeTaskStatus(
      Map<String, dynamic> task,
      String newStatus,
      ) async {
    final id = task['_id']?.toString();

    if (id == null || id.isEmpty) {
      _showMessage('Không tìm thấy mã công việc', isError: true);
      return;
    }

    if (task['status'] == newStatus || _updatingTaskIds.contains(id)) {
      return;
    }

    setState(() {
      _updatingTaskIds.add(id);
    });

    try {
      final token = await _getAuthToken();
      final response = await ApiClient.put(
        '/api/tasks/$id',
        {'status': newStatus},
        token: token,
      );

      if (response.statusCode != 200) {
        throw Exception(response.body);
      }

      if (!mounted) return;

      _showMessage('Cập nhật trạng thái thành công!');
      await _loadTasks();
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Lỗi cập nhật trạng thái: $error',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingTaskIds.remove(id);
        });
      }
    }
  }

  // Xem chi tiết công việc và chỉ hiển thị thao tác theo quyền.
  Future<void> _showTaskDetails(int index) async {
    if (index < 0 || index >= _tasks.length) return;

    final task = _tasks[index];
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('userId');

    // Hỗ trợ các tên trường người tạo thường dùng trong dữ liệu task.
    final owner = task['userId'] ?? task['createdBy'] ?? task['ownerId'];
    final ownerId = _getUserId(owner);
    final isOwner = currentUserId != null &&
        ownerId != null &&
        currentUserId == ownerId;

    // API cần trả một trong các trường quyền này, giá trị viewer/editor.
    final permission = (task['permission'] ??
        task['sharePermission'] ??
        task['sharedPermission'] ??
        '')
        .toString()
        .toLowerCase();
    final canEdit = isOwner || permission == 'editor';

    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(task['title']?.toString() ?? ''),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trạng thái: '
                    '${_getStatusText(task['status']?.toString())}',
              ),
              const SizedBox(height: 10),
              Text(
                'Ưu tiên: '
                    '${_getPriorityText(task['priority']?.toString())}',
              ),
              const SizedBox(height: 10),
              Text('Hạn hoàn thành: ${_formatDate(task['dueDate'])}'),
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
            if (canEdit)
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _showEditTaskDialog(task);
                },
                icon: const Icon(Icons.edit),
                label: const Text('Chỉnh sửa'),
              ),
            if (isOwner)
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _showShareDialog(task);
                },
                icon: const Icon(Icons.share),
                label: const Text('Chia sẻ'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),
            if (isOwner)
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _deleteTask(task['_id']?.toString());
                },
                child: const Text(
                  'Xóa',
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        );
      },
    );
  }

  // Quản lý người được chia sẻ và quyền truy cập.
  Future<void> _showShareDialog(Map<String, dynamic> task) async {
    final taskId = task['_id']?.toString();
    if (taskId == null || taskId.isEmpty) {
      _showMessage('Không tìm thấy mã công việc', isError: true);
      return;
    }

    List<Map<String, dynamic>> users = [];
    List<Map<String, dynamic>> shares = [];

    try {
      final token = await _getAuthToken();
      users = await _loadUsers();

      final response = await ApiClient.get(
        '/api/tasks/$taskId/shares',
        token: token,
      );
      if (response.statusCode != 200) {
        throw Exception(response.body);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      shares = (data['shares'] as List<dynamic>? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (error) {
      _showMessage('Không thể tải danh sách chia sẻ: $error', isError: true);
      return;
    }

    if (!mounted) return;

    String? selectedUserId;
    String selectedPermission = 'viewer';
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> reloadShares() async {
              final token = await _getAuthToken();
              final response = await ApiClient.get(
                '/api/tasks/$taskId/shares',
                token: token,
              );
              if (response.statusCode != 200) {
                throw Exception(response.body);
              }
              final data = jsonDecode(response.body) as Map<String, dynamic>;
              setDialogState(() {
                shares = (data['shares'] as List<dynamic>? ?? [])
                    .map((item) => Map<String, dynamic>.from(item as Map))
                    .toList();
              });
            }

            Future<void> changeShare(String shareId, String action) async {
              try {
                final token = await _getAuthToken();
                final response = action == 'revoke'
                    ? await ApiClient.delete(
                  '/api/tasks/$taskId/shares/$shareId',
                  token: token,
                )
                    : await ApiClient.patch(
                  '/api/tasks/$taskId/shares/$shareId',
                  {'permission': action},
                  token: token,
                );

                if (response.statusCode != 200) {
                  throw Exception(response.body);
                }

                await reloadShares();
                if (mounted) {
                  _showMessage(
                    action == 'revoke'
                        ? 'Đã thu hồi quyền chia sẻ'
                        : 'Đã cập nhật quyền chia sẻ',
                  );
                }
              } catch (error) {
                if (mounted) {
                  _showMessage('Lỗi cập nhật chia sẻ: $error', isError: true);
                }
              }
            }

            return AlertDialog(
              scrollable: true,
              title: const Text('Chia sẻ công việc'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedUserId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Chọn người dùng',
                      border: OutlineInputBorder(),
                    ),
                    items: users.map((user) {
                      final userId = _getUserId(user);
                      if (userId == null || userId.isEmpty) return null;
                      return DropdownMenuItem<String>(
                        value: userId,
                        child: Text(
                          _getUserName(user),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).whereType<DropdownMenuItem<String>>().toList(),
                    onChanged: isSaving
                        ? null
                        : (value) => setDialogState(() {
                      selectedUserId = value;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPermission,
                    decoration: const InputDecoration(
                      labelText: 'Quyền truy cập',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'viewer',
                        child: Text('Chỉ xem (viewer)'),
                      ),
                      DropdownMenuItem(
                        value: 'editor',
                        child: Text('Được chỉnh sửa (editor)'),
                      ),
                    ],
                    onChanged: isSaving
                        ? null
                        : (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedPermission = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: isSaving || selectedUserId == null
                          ? null
                          : () async {
                        setDialogState(() {
                          isSaving = true;
                        });
                        try {
                          final token = await _getAuthToken();
                          final response = await ApiClient.post(
                            '/api/tasks/$taskId/shares',
                            {
                              'userId': selectedUserId,
                              'permission': selectedPermission,
                            },
                            token: token,
                          );
                          if (response.statusCode != 200 &&
                              response.statusCode != 201) {
                            throw Exception(response.body);
                          }
                          await reloadShares();
                          if (mounted) {
                            _showMessage('Chia sẻ công việc thành công');
                          }
                        } catch (error) {
                          if (mounted) {
                            _showMessage(
                              'Lỗi chia sẻ công việc: $error',
                              isError: true,
                            );
                          }
                        } finally {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              isSaving = false;
                            });
                          }
                        }
                      },
                      icon: const Icon(Icons.share),
                      label: Text(isSaving ? 'Đang lưu...' : 'Chia sẻ'),
                    ),
                  ),
                  const Divider(height: 24),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Người đang được chia sẻ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (shares.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Chưa chia sẻ công việc này với ai.'),
                    ),
                  ...shares.map((share) {
                    final recipient = share['userId'];
                    final shareId = share['_id']?.toString();
                    final recipientName = recipient is Map
                        ? _getUserName(Map<String, dynamic>.from(recipient))
                        : 'Người dùng';
                    final permission =
                        share['permission']?.toString() ?? 'viewer';

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        recipientName,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        permission == 'editor' ? 'Được chỉnh sửa' : 'Chỉ xem',
                      ),
                      trailing: shareId == null
                          ? null
                          : PopupMenuButton<String>(
                        tooltip: 'Quản lý quyền',
                        onSelected: (action) {
                          changeShare(shareId, action);
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'viewer',
                            child: Text('Đổi thành chỉ xem'),
                          ),
                          PopupMenuItem(
                            value: 'editor',
                            child: Text('Cho phép chỉnh sửa'),
                          ),
                          PopupMenuItem(
                            value: 'revoke',
                            child: Text('Thu hồi chia sẻ'),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Đóng'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Xóa công việc khỏi MongoDB.
  Future<void> _deleteTask(String? id) async {
    if (id == null || id.isEmpty) {
      _showMessage('Không tìm thấy mã công việc', isError: true);
      return;
    }

    try {
      final token = await _getAuthToken();
      final response = await ApiClient.delete(
        '/api/tasks/$id',
        token: token,
      );

      if (response.statusCode != 200) {
        throw Exception('Không thể xóa công việc');
      }

      _showMessage('Đã xóa công việc');
      await _loadTasks();
    } catch (error) {
      _showMessage('Lỗi xóa công việc: $error', isError: true);
    }
  }

  Future<void> _openNotifications() async {
    final taskId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationScreen(),
      ),
    );

    if (!mounted || taskId == null) return;

    await _loadTasks();

    final index = _tasks.indexWhere(
          (task) => task['_id']?.toString() == taskId,
    );

    if (index >= 0 && mounted) {
      _showTaskDetails(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách công việc'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Thông báo',
            onPressed: _openNotifications,
          ),
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
          style: TextStyle(fontSize: 18),
        ),
      )
          : ListView.builder(
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          final taskId = task['_id']?.toString();

          return Card(
            margin: const EdgeInsets.symmetric(
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
                  task['priority']?.toString(),
                ),
              ),
              title: Text(
                task['title']?.toString() ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Hạn hoàn thành: '
                    '${_formatDate(task['dueDate'])}',
              ),
              trailing: PopupMenuButton<String>(
                tooltip: 'Đổi trạng thái công việc',
                enabled: !_updatingTaskIds.contains(taskId),
                onSelected: (status) {
                  _changeTaskStatus(task, status);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'pending',
                    child: Text('Chưa làm'),
                  ),
                  PopupMenuItem(
                    value: 'in-progress',
                    child: Text('Đang làm'),
                  ),
                  PopupMenuItem(
                    value: 'completed',
                    child: Text('Hoàn thành'),
                  ),
                ],
                child: Chip(
                  label: Text(
                    _getStatusText(task['status']?.toString()),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        tooltip: 'Thêm công việc',
        child: const Icon(Icons.add),
      ),
    );
  }
}
