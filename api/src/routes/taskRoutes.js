const express = require('express');
const router = express.Router();

const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const TaskActivity = require('../models/TaskActivity');
const User = require('../models/User');
const { updateTask } = require('../controllers/taskController');

function getCurrentUserId(req) {
  return req.user?.id || req.user?._id || req.user?.userId || null;
}

function isTaskOwner(task, userId) {
  const ownerId = task.createdBy?._id || task.createdBy;
  return ownerId && String(ownerId) === String(userId);
}

// Lấy danh sách công việc
router.get('/', async (req, res) => {
  try {
    const tasks = await Task.find().sort({ createdAt: -1 });

    return res.status(200).json({
      success: true,
      tasks,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi lấy danh sách công việc',
      error: error.message,
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
      assignedTo,
      assigneeIds,
      primaryAssigneeId,
    } = req.body;

    const userId = getCurrentUserId(req);

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Không xác định được người dùng đang đăng nhập',
      });
    }

    if (typeof title !== 'string' || !title.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng nhập tên công việc',
      });
    }

    const task = await Task.create({
      createdBy: userId,
      title: title.trim(),
      description: description ?? '',
      priority: priority ?? 'medium',
      status: status ?? 'pending',
      ...(dueDate ? { dueDate } : {}),
      ...(assignedTo ? { assignedTo } : {}),
      ...(Array.isArray(assigneeIds) ? { assigneeIds } : {}),
      ...(primaryAssigneeId ? { primaryAssigneeId } : {}),
    });

    await TaskActivity.create({
      taskId: task._id,
      userId,
      action: 'created',
      description: 'Đã tạo công việc',
      changes: { title: task.title },
    });

    return res.status(201).json({
      success: true,
      message: 'Thêm công việc thành công',
      task,
    });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: 'Không thể thêm công việc',
      error: error.message,
    });
  }
});

// Xem danh sách người được chia sẻ
router.get('/:id/shares', async (req, res) => {
  try {
    const userId = getCurrentUserId(req);
    const task = await Task.findById(req.params.id);

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy công việc',
      });
    }

    if (!isTaskOwner(task, userId)) {
      return res.status(403).json({
        success: false,
        message: 'Chỉ người tạo công việc mới được quản lý chia sẻ',
      });
    }

    const shares = await TaskShare.find({ taskId: task._id })
      .populate('userId', 'fullName email')
      .populate('sharedBy', 'fullName email')
      .sort({ createdAt: -1 });

    return res.status(200).json({
      success: true,
      shares,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi lấy danh sách chia sẻ',
      error: error.message,
    });
  }
});

// Chia sẻ công việc cho một người
router.post('/:id/shares', async (req, res) => {
  try {
    const userId = getCurrentUserId(req);
    const { userId: recipientId, permission = 'viewer' } = req.body;

    const task = await Task.findById(req.params.id);

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy công việc',
      });
    }

    if (!isTaskOwner(task, userId)) {
      return res.status(403).json({
        success: false,
        message: 'Chỉ người tạo công việc mới được chia sẻ',
      });
    }

    if (!recipientId) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng chọn người cần chia sẻ',
      });
    }

    if (!['viewer', 'editor'].includes(permission)) {
      return res.status(400).json({
        success: false,
        message: 'Quyền chỉ có thể là viewer hoặc editor',
      });
    }

    const recipient = await User.findById(recipientId);

    if (!recipient) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy người dùng được chia sẻ',
      });
    }

    if (String(recipientId) === String(userId)) {
      return res.status(400).json({
        success: false,
        message: 'Bạn không thể chia sẻ công việc cho chính mình',
      });
    }

    let share = await TaskShare.findOne({
      taskId: task._id,
      userId: recipientId,
    });

    const isNewShare = !share;

    if (share) {
      share.permission = permission;
      share.sharedBy = userId;
      await share.save();
    } else {
      share = await TaskShare.create({
        taskId: task._id,
        userId: recipientId,
        permission,
        sharedBy: userId,
      });
    }

    await TaskActivity.create({
      taskId: task._id,
      userId,
      action: 'shared',
      description: `Đã chia sẻ công việc với ${recipient.email}`,
      changes: {
        userId: recipientId,
        permission,
      },
    });

    await share.populate('userId', 'fullName email');

    return res.status(isNewShare ? 201 : 200).json({
      success: true,
      message: isNewShare
        ? 'Chia sẻ công việc thành công'
        : 'Đã cập nhật quyền chia sẻ',
      share,
    });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: 'Không thể chia sẻ công việc',
      error: error.message,
    });
  }
});

// Đổi quyền viewer/editor
router.patch('/:id/shares/:shareId', async (req, res) => {
  try {
    const userId = getCurrentUserId(req);
    const { permission } = req.body;

    const task = await Task.findById(req.params.id);

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy công việc',
      });
    }

    if (!isTaskOwner(task, userId)) {
      return res.status(403).json({
        success: false,
        message: 'Chỉ người tạo công việc mới được đổi quyền',
      });
    }

    if (!['viewer', 'editor'].includes(permission)) {
      return res.status(400).json({
        success: false,
        message: 'Quyền chỉ có thể là viewer hoặc editor',
      });
    }

    const share = await TaskShare.findOneAndUpdate(
      {
        _id: req.params.shareId,
        taskId: task._id,
      },
      { permission },
      { new: true, runValidators: true }
    ).populate('userId', 'fullName email');

    if (!share) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy quyền chia sẻ',
      });
    }

    await TaskActivity.create({
      taskId: task._id,
      userId,
      action: 'share_permission_updated',
      description: 'Đã cập nhật quyền chia sẻ',
      changes: { permission },
    });

    return res.status(200).json({
      success: true,
      message: 'Cập nhật quyền chia sẻ thành công',
      share,
    });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: 'Không thể cập nhật quyền chia sẻ',
      error: error.message,
    });
  }
});

// Thu hồi quyền chia sẻ
router.delete('/:id/shares/:shareId', async (req, res) => {
  try {
    const userId = getCurrentUserId(req);
    const task = await Task.findById(req.params.id);

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy công việc',
      });
    }

    if (!isTaskOwner(task, userId)) {
      return res.status(403).json({
        success: false,
        message: 'Chỉ người tạo công việc mới được thu hồi quyền',
      });
    }

    const share = await TaskShare.findOneAndDelete({
      _id: req.params.shareId,
      taskId: task._id,
    });

    if (!share) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy quyền chia sẻ',
      });
    }

    await TaskActivity.create({
      taskId: task._id,
      userId,
      action: 'share_revoked',
      description: 'Đã thu hồi quyền chia sẻ',
      changes: { userId: share.userId },
    });

    return res.status(200).json({
      success: true,
      message: 'Đã thu hồi quyền chia sẻ',
    });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: 'Không thể thu hồi quyền chia sẻ',
      error: error.message,
    });
  }
});

// Cập nhật công việc
router.put('/:id', updateTask);

// Xóa công việc
router.delete('/:id', async (req, res) => {
  try {
    const task = await Task.findByIdAndDelete(req.params.id);

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy công việc',
      });
    }

    await TaskShare.deleteMany({ taskId: task._id });

    await TaskActivity.create({
      taskId: task._id,
      userId: getCurrentUserId(req),
      action: 'deleted',
      description: 'Đã xóa công việc',
      changes: { title: task.title },
    });

    return res.status(200).json({
      success: true,
      message: 'Xóa công việc thành công',
    });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: 'Lỗi xóa công việc',
      error: error.message,
    });
  }
});

module.exports = router;