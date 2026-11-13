
const express = require('express');
const router = express.Router();
const Task = require('../models/Task');
const TaskActivity = require('../models/TaskActivity');
const { updateTask } = require('../controllers/taskController');

// Lấy danh sách công việc
router.get('/', async (req, res) => {
  try {
    const tasks = await Task.find()
      .sort({ createdAt: -1 });
res.status(200).json({
      success: true,
      tasks
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Lỗi lấy danh sách công việc',
      error: error.message
    });
  }
});

// Thêm công việc mới
router.post('/', async (req, res) => {
  try {
    const {
      title,
      description,
      priority,
      status,
      dueDate,
      assignedTo
    } = req.body;

    if (typeof title !== 'string' || !title.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng nhập tên công việc'
      });
    }

    const task = await Task.create({
      title: title.trim(),
      description: description ?? '',
      priority: priority ?? 'medium',
      status: status ?? 'pending',
      ...(dueDate ? { dueDate } : {}),
      ...(assignedTo ? { assignedTo } : {})
    });

    await TaskActivity.create({
      taskId: task._id,
      action: 'created',
      description: 'Đã tạo công việc',
      changes: { title: task.title }
    });

    res.status(201).json({
      success: true,
      message: 'Thêm công việc thành công',
      task
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      message: 'Không thể thêm công việc',
      error: error.message
    });
  }
});

// Cập nhật công việc và gửi email thông báo
router.put('/:id', updateTask);

// Xóa công việc
router.delete('/:id', async (req, res) => {
  try {
    const task = await Task.findByIdAndDelete(req.params.id);

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy công việc'
      });
    }

    await TaskActivity.create({
      taskId: task._id,
      action: 'deleted',
      description: 'Đã xóa công việc',
      changes: { title: task.title }
    });

    res.status(200).json({
      success: true,
      message: 'Xóa công việc thành công'
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      message: 'Lỗi xóa công việc',
      error: error.message
    });
  }
});

module.exports = router;
