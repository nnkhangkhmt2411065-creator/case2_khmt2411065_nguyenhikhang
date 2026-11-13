
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
import 'change_password_screen.dart';
import 'login_screen_part_a.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // A4.1 - Lấy thông tin cá nhân từ MongoDB
  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Bạn chưa đăng nhập');
      }

      final response = await ApiClient.get(
        '/auth/profile',
        token: token,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(
          data['message']?.toString() ??
              'Không thể tải thông tin cá nhân',
        );
      }

      final user = data['user'];

      if (user is! Map) {
        throw Exception('Dữ liệu người dùng không hợp lệ');
      }

      if (!mounted) return;

      setState(() {
        _fullNameController.text =
            user['fullName']?.toString() ?? '';
        _emailController.text =
            user['email']?.toString() ?? '';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // A4.2 - Cập nhật thông tin cá nhân
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Bạn chưa đăng nhập');
      }

      final response = await ApiClient.put(
        '/auth/profile',
        {
          'fullName': _fullNameController.text.trim(),
          'email': _emailController.text.trim(),
        },
        token: token,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(
          data['message']?.toString() ??
              'Không thể cập nhật thông tin',
        );
      }

      final user = data['user'];

      if (user is! Map) {
        throw Exception('Dữ liệu người dùng không hợp lệ');
      }

      final fullName = user['fullName']?.toString() ?? '';
      final email = user['email']?.toString() ?? '';

      await prefs.setString('fullName', fullName);
      await prefs.setString('email', email);

      if (!mounted) return;

      setState(() {
        _fullNameController.text = fullName;
        _emailController.text = email;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật thông tin thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi cập nhật: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // A5 - Mở màn hình đổi mật khẩu
  Future<void> _openChangePassword() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChangePasswordScreen(),
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreenPartA(),
      ),
      (route) => false,
    );
  }
  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin cá nhân'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Tải lại thông tin',
            onPressed: _isLoading ? null : _loadProfile,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : _errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 55,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProfile,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      )
          : Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 450,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.stretch,
                children: [
                  const CircleAvatar(
                    radius: 48,
                    child: Icon(
                      Icons.person,
                      size: 55,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'HỒ SƠ CÁ NHÂN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Họ tên
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'Vui lòng nhập họ tên';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType:
                    TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';

                      if (email.isEmpty) {
                        return 'Vui lòng nhập email';
                      }

                      if (!RegExp(
                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                      ).hasMatch(email)) {
                        return 'Email không hợp lệ';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 25),

                  // A4 - Lưu thay đổi
                  ElevatedButton.icon(
                    onPressed:
                    _isSaving ? null : _updateProfile,
                    icon: const Icon(Icons.save),
                    label: Text(
                      _isSaving
                          ? 'Đang lưu...'
                          : 'Lưu thay đổi',
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize:
                      const Size.fromHeight(50),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // A5 - Đổi mật khẩu
                  OutlinedButton.icon(
                    onPressed: _isSaving
                        ? null
                        : _openChangePassword,
                    icon: const Icon(Icons.lock_reset),
                    label: const Text('Đổi mật khẩu'),
                    style: OutlinedButton.styleFrom(
                      minimumSize:
                      const Size.fromHeight(50),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
