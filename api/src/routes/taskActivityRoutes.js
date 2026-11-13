const express = require('express');
const router = express.Router();
const Task = require('../models/Task');
const TaskActivity = require('../models/TaskActivity');
const verifyToken = require('../middleware/authMiddleware');

router.get('/:taskId', verifyToken, async (req, res) => {
  try {
    const task = await Task.findById(req.params.taskId);
    if (!task) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc'
      });
    }

    const activities = await TaskActivity.find({
      taskId: req.params.taskId
    })
      .sort({ createdAt: -1 })
      .limit(100);

    res.json({
      success: true,
      activities
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Không thể lấy lịch sử hoạt động'
    });
  }
});

module.exports = router;
