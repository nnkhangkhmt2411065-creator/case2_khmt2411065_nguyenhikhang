
const User = require('../models/User');
const bcrypt = require('bcryptjs');

// A5 - Đổi mật khẩu
const changePassword = async (req, res) => {
  try {
    const { oldPassword, newPassword, confirmPassword } = req.body;

    // Kiểm tra dữ liệu đầu vào
    if (
      typeof oldPassword !== 'string' ||
      typeof newPassword !== 'string' ||
      typeof confirmPassword !== 'string' ||
      !oldPassword ||
      !newPassword ||
      !confirmPassword
    ) {
      return res.status(400).json({
        message: 'Vui lòng nhập đầy đủ thông tin mật khẩu'
      });
    }

    // Kiểm tra xác nhận mật khẩu
    if (newPassword !== confirmPassword) {
      return res.status(400).json({
        message: 'Xác nhận mật khẩu mới không khớp'
      });
    }

    // Kiểm tra độ dài mật khẩu
    if (newPassword.length < 8) {
      return res.status(400).json({
        message: 'Mật khẩu mới phải có ít nhất 8 ký tự'
      });
    }

    // Tìm tài khoản đang đăng nhập
    const user = await User.findById(req.user.id);

    if (!user) {
      return res.status(404).json({
        message: 'Không tìm thấy tài khoản'
      });
    }

    // Kiểm tra mật khẩu cũ
    const isMatch = await bcrypt.compare(
      oldPassword,
      user.passwordHash
    );

    if (!isMatch) {
      return res.status(400).json({
        message: 'Mật khẩu cũ không chính xác'
      });
    }

    // Không cho dùng lại mật khẩu cũ
    if (oldPassword === newPassword) {
      return res.status(400).json({
        message: 'Mật khẩu mới phải khác mật khẩu cũ'
      });
    }

    // Mã hóa mật khẩu mới
    const hashedPassword = await bcrypt.hash(newPassword, 10);

    // Lưu mật khẩu mới vào MongoDB
    user.passwordHash = hashedPassword;
    await user.save();

    return res.status(200).json({
      message: 'Đổi mật khẩu thành công'
    });

  } catch (error) {
    return res.status(500).json({
      message: 'Lỗi đổi mật khẩu',
      error: error.message
    });
  }
};

module.exports = { changePassword };
