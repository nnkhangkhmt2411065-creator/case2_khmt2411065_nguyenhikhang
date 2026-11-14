const express = require('express');
const router = express.Router();
const User = require('../models/User');
const verifyToken = require('../middleware/authMiddleware');

router.get('/', verifyToken, async (req, res) => {
  try {
    const users = await User.find()
      .select('_id fullName email')
      .sort({ fullName: 1 });

    res.status(200).json({
      success: true,
      users
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Khong the lay danh sach nguoi dung'
    });
  }
});

module.exports = router;
