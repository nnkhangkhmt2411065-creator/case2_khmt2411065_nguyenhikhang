
const express = require('express');
const router = express.Router();

// Controller đăng ký và đăng nhập
const {
  register,
  login
} = require('../controllers/authController');

// Controller thông tin cá nhân
const {
  getProfile,
  updateProfile
} = require('../controllers/profileController');

// Controller đổi mật khẩu
const {
  changePassword
} = require('../controllers/changePasswordController');

// Middleware xác thực JWT
const verifyToken = require('../middleware/authMiddleware');

// A1 - Đăng ký tài khoản
router.post('/register', register);

// A2 - Đăng nhập tài khoản
router.post('/login', login);

// A4.1 - Xem thông tin cá nhân
router.get('/profile', verifyToken, getProfile);

// A4.2 - Cập nhật thông tin cá nhân
router.put('/profile', verifyToken, updateProfile);

// A5 - Đổi mật khẩu
router.put('/change-password', verifyToken, changePassword);

module.exports = router;
