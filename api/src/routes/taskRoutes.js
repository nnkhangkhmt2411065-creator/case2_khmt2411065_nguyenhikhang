const express = require('express');
const router = express.Router();

const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const TaskActivity = require('../models/TaskActivity');
const Notification = require('../models/Notification');
const User = require('../models/User');
const { updateTask } = require('../controllers/taskController');
const { sendTaskSharedEmail } = require('../services/emailService');

function getCurrentUserId(req) {
  const id = req.user?.id || req.user?._id || req.user?.userId;
  return id ? String(id) : null;
}

function getId(value) {
  if (value == null) return null;

  if (typeof value === 'object' && value._id != null) {
    return String(value._id);
  }

  return String(value);
}

function isTaskOwner(task, userId) {
  return getId(task.createdBy) === String(userId);
}

function isTaskAssignee(task, userId) {
  const assigneeIds = Array.isArray(task.assigneeIds)
    ? task.assigneeIds
    : [];

  return [
    task.assignedTo,
    task.primaryAssigneeId,
    ...assigneeIds,
  ].some((assignee) => getId(assignee) === String(userId));
}

async function requireTaskEditor(req, res, next) {
  try {
    const userId = getCurrentUserId(req);

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Không xác định được người dùng đang đăng nhập',
      });
    }

    const task = await Task.findById(req.params.id);

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy công việc',
      });
    }

    if (isTaskOwner(task, userId) || isTaskAssignee(task, userId)) {
      return next();
    }

    const share = await TaskShare.findOne({
      taskId: task._id,
      userId,
    }).select('permission');

    if (share?.permission === 'editor') {
      return next();
    }

    return res.status(403).json({
      success: false,
      message: 'Bạn không có quyền chỉnh sửa công việc này',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi kiểm tra quyền chỉnh sửa',
      error: error.message,
    });
  }
}

async function requireTaskOwner(req, res, next) {
  try {
    const userId = getCurrentUserId(req);

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Không xác định được người dùng đang đăng nhập',
      });
    }

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
        message: 'Chỉ người tạo công việc mới được xóa',
      });
    }

    return next();
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi kiểm tra quyền xóa',
      error: error.message,
    });
  }
}

// Lấy các công việc người dùng có quyền truy cập
router.get('/', async (req, res) => {
  try {
    const userId = getCurrentUserId(req);

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Không xác định được người dùng đang đăng nhập',
      });
    }

    const shares = await TaskShare.find({ userId })
      .select('taskId permission')
      .lean();

    const sharedTaskIds = shares.map((share) => share.taskId);

    const tasks = await Task.find({
      $or: [
        { createdBy: userId },
        { assignedTo: userId },
        { assigneeIds: userId },
        { primaryAssigneeId: userId },
        { _id: { $in: sharedTaskIds } },
      ],
    })
      .sort({ createdAt: -1 })
      .lean();

    const permissionByTaskId = new Map(
      shares.map((share) => [
        String(share.taskId),
        String(share.permission || 'viewer').toLowerCase(),
      ])
    );

    const tasksWithPermission = tasks.map((task) => {
      const taskId = String(task._id);
      const isOwner = getId(task.createdBy) === userId;
      const isAssignee = isTaskAssignee(task, userId);

      let permission = permissionByTaskId.get(taskId) || 'viewer';

      if (isOwner) {
        permission = 'owner';
      } else if (isAssignee) {
        permission = 'editor';
      }

      return {
        ...task,
        permission,
      };
    });

    console.log(
      'Quyền task:',
      tasksWithPermission.map((task) => ({
        title: task.title,
        permission: task.permission,
      }))
    );

    return res.status(200).json({
      success: true,
      tasks: tasksWithPermission,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi lấy danh sách công việc',
      error: error.message,
    });
  }
});

// Thêm công việc
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

// Xem người được chia sẻ
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

    return res.status(200).json({ success: true, shares });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi lấy danh sách chia sẻ',
      error: error.message,
    });
  }
});

// Chia sẻ công việc
router.post('/:id/shares', async (req, res) => {
  try {
    console.log('[SHARE ROUTE HIT]', req.originalUrl);
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
      changes: { userId: recipientId, permission },
    });

    await share.populate('userId', 'fullName email');

    // Tạo thông báo mỗi khi chia sẻ hoặc cập nhật quyền chia sẻ.
    const notification = await Notification.create({
      userId: recipientId,
      taskId: task._id,
      type: 'task_shared',
      title: 'Bạn được chia sẻ một công việc',
      message: `Công việc "${task.title}" đã được chia sẻ với bạn. Quyền: ${
        permission === 'editor' ? 'được chỉnh sửa' : 'chỉ xem'
      }.`,
    });
    console.log(
      '[NOTIFICATION] Đã tạo thông báo cho user:',
      String(notification.userId)
    );

    let emailSent = null;
    if (isNewShare) {
      emailSent = await sendTaskSharedEmail(
        recipient.email,
        task.title,
        permission
      );
    }

    return res.status(isNewShare ? 201 : 200).json({
      success: true,
      message: isNewShare
        ? emailSent
          ? 'Đã chia sẻ công việc và gửi email thành công'
          : 'Đã chia sẻ công việc nhưng gửi email thất bại'
        : 'Đã cập nhật quyền chia sẻ',
      emailSent,
      share,
    });
  } catch (error) {
    console.error('Lỗi chia sẻ công việc:', error);

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
      { _id: req.params.shareId, taskId: task._id },
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
router.put('/:id', requireTaskEditor, updateTask);

// Xóa công việc: chỉ chủ sở hữu
router.delete('/:id', requireTaskOwner, async (req, res) => {
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
