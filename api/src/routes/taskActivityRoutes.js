const express = require('express');
const router = express.Router();

const Task = require('../models/Task');
const TaskActivity = require('../models/TaskActivity');

// server.js đã xác thực đăng nhập cho đường dẫn /task-activities
router.get('/:taskId', async (req, res) => {
  try {
    const { taskId } = req.params;

    const task = await Task.findById(taskId);

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy công việc',
      });
    }

    const activities = await TaskActivity.find({ taskId })
      .sort({ createdAt: -1 })
      .limit(100);

    return res.json({
      success: true,
      activities,
    });
  } catch (error) {
    console.error('Lỗi tải lịch sử hoạt động:', error);

    return res.status(500).json({
      success: false,
      message: 'Không thể lấy lịch sử hoạt động',
      error: error.message,
    });
  }
});

module.exports = router;