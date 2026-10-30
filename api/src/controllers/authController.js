const User = require('../models/User');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

// Đăng ký tài khoản
exports.register = async (req, res) => {
  try {
    const { fullName, email, password } = req.body;

    // Kiểm tra email trùng
    let user = await User.findOne({ email });
    if (user) return res.status(400).json({ message: 'Email đã tồn tại!' });

    // Băm mật khẩu
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    user = new User({ fullName, email, passwordHash });
    await user.save();

    res.status(201).json({ message: 'Đăng ký tài khoản thành công!' });
  } catch (err) {
    res.status(500).json({ message: 'Lỗi server', error: err.message });
  }
};

// Đăng nhập
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ email });
    if (!user) return res.status(400).json({ message: 'Email hoặc mật khẩu không đúng!' });

    const isMatch = await bcrypt.compare(password, user.passwordHash);
    if (!isMatch) return res.status(400).json({ message: 'Email hoặc mật khẩu không đúng!' });

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET || 'secretkey', { expiresIn: '7d' });

    res.json({
      token,
      user: { id: user._id, fullName: user.fullName, email: user.email }
    });
  } catch (err) {
    res.status(500).json({ message: 'Lỗi server', error: err.message });
  }
};