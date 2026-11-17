const Task = require('../models/Task');
const TaskActivity = require('../models/TaskActivity');
const { sendTaskUpdateEmail } = require('../services/emailService');

const hasField = (object, field) =>
  Object.prototype.hasOwnProperty.call(object, field);

const getId = (value) => {
  if (value == null) return null;

  if (typeof value === 'object' && value._id) {
    return value._id.toString();
  }

  return value.toString();
};

const getAssigneeIds = (task) => {
  const ids = Array.isArray(task.assigneeIds)
    ? task.assigneeIds.map(getId).filter(Boolean)
    : [];

  if (ids.length > 0) {
    return [...new Set(ids)];
  }

  // Dùng assignedTo cho các công việc cũ.
  const oldAssigneeId = getId(task.assignedTo);
  return oldAssigneeId ? [oldAssigneeId] : [];
};

// Cập nhật công việc và gửi email nếu có thay đổi.
exports.updateTask = async (req, res) => {
  try {
    const { id } = req.params;

    const oldTask = await Task.findById(id)
      .populate('assignedTo')
      .populate('assigneeIds')
      .populate('primaryAssigneeId');

    if (!oldTask) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc',
      });
    }

    const updates = {};

    for (const field of [
      'title',
      'description',
      'priority',
      'status',
      'dueDate',
    ]) {
      if (hasField(req.body, field)) {
        updates[field] = req.body[field];
      }
    }

    const oldAssigneeIds = getAssigneeIds(oldTask);

    // Giao công việc cho nhiều người.
    if (Array.isArray(req.body.assigneeIds)) {
      const assigneeIds = [
        ...new Set(req.body.assigneeIds.map(getId).filter(Boolean)),
      ];

      let primaryAssigneeId;

      if (hasField(req.body, 'primaryAssigneeId')) {
        primaryAssigneeId = getId(req.body.primaryAssigneeId);

        if (
          primaryAssigneeId &&
          !assigneeIds.includes(primaryAssigneeId)
        ) {
          return res.status(400).json({
            message:
              'Người phụ trách chính phải nằm trong danh sách người được giao',
          });
        }
      } else {
        const currentPrimaryId =
          getId(oldTask.primaryAssigneeId) ||
          getId(oldTask.assignedTo);

        primaryAssigneeId = assigneeIds.includes(currentPrimaryId)
          ? currentPrimaryId
          : assigneeIds[0] || null;
      }

      if (!primaryAssigneeId) {
        primaryAssigneeId = assigneeIds[0] || null;
      }

      updates.assigneeIds = assigneeIds;
      updates.primaryAssigneeId = primaryAssigneeId;

      // Giữ assignedTo để tương thích với giao diện cũ.
      updates.assignedTo = primaryAssigneeId;
    } else if (hasField(req.body, 'assignedTo')) {
      // Tương thích với giao diện hiện tại chỉ gửi một người.
      const assignedTo = getId(req.body.assignedTo);

      updates.assignedTo = assignedTo;
      updates.assigneeIds = assignedTo ? [assignedTo] : [];
      updates.primaryAssigneeId = assignedTo;
    } else if (hasField(req.body, 'primaryAssigneeId')) {
      const primaryAssigneeId = getId(req.body.primaryAssigneeId);

      if (
        primaryAssigneeId &&
        !oldAssigneeIds.includes(primaryAssigneeId)
      ) {
        return res.status(400).json({
          message:
            'Người phụ trách chính phải nằm trong danh sách người được giao',
        });
      }

      updates.primaryAssigneeId =
        primaryAssigneeId || oldAssigneeIds[0] || null;
      updates.assignedTo = updates.primaryAssigneeId;
    }

    if (Object.keys(updates).length === 0) {
      return res.status(400).json({
        message: 'Không có thông tin nào được gửi để cập nhật',
      });
    }

    const updatedTask = await Task.findByIdAndUpdate(id, updates, {
      new: true,
      runValidators: true,
    })
      .populate('assignedTo')
      .populate('assigneeIds')
      .populate('primaryAssigneeId');

    if (!updatedTask) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc',
      });
    }

    const newAssigneeIds = getAssigneeIds(updatedTask);
    const changes = [];

    const oldDueDate = oldTask.dueDate
      ? new Date(oldTask.dueDate).getTime()
      : null;
    const newDueDate = updatedTask.dueDate
      ? new Date(updatedTask.dueDate).getTime()
      : null;

    if (oldDueDate !== newDueDate) {
      changes.push(
        `Hạn hoàn thành mới: ${
          updatedTask.dueDate
            ? new Date(updatedTask.dueDate).toLocaleDateString('vi-VN')
            : 'Chưa thiết lập'
        }`
      );
    }

    if (oldTask.title !== updatedTask.title) {
      changes.push(`Tiêu đề mới: ${updatedTask.title}`);
    }

    if (oldTask.status !== updatedTask.status) {
      changes.push(`Trạng thái mới: ${updatedTask.status}`);
    }

    if (
      JSON.stringify([...oldAssigneeIds].sort()) !==
      JSON.stringify([...newAssigneeIds].sort())
    ) {
      changes.push('Danh sách người được giao đã thay đổi');
    }

    // Gửi email cho những người được giao.
    if (changes.length > 0) {
      const recipients = [
        ...(updatedTask.assigneeIds || []),
        updatedTask.assignedTo,
      ]
        .map((user) => user?.email)
        .filter(Boolean);

      for (const email of [...new Set(recipients)]) {
        await sendTaskUpdateEmail(email, updatedTask.title, changes);
      }
    }

    const getTrackedValue = (task, field) => {
      if (field === 'assigneeIds') {
        return getAssigneeIds(task).sort();
      }

      if (field === 'assignedTo' || field === 'primaryAssigneeId') {
        return getId(task[field]);
      }

      const value = task[field];

      if (value instanceof Date) {
        return value.toISOString();
      }

      return value ?? null;
    };

    const changedFields = {};
    const fieldsToTrack = [
      'title',
      'description',
      'priority',
      'status',
      'dueDate',
      'assignedTo',
      'assigneeIds',
      'primaryAssigneeId',
    ];

    for (const field of fieldsToTrack) {
      const before = getTrackedValue(oldTask, field);
      const after = getTrackedValue(updatedTask, field);

      if (JSON.stringify(before) !== JSON.stringify(after)) {
        changedFields[field] = { before, after };
      }
    }

    if (Object.keys(changedFields).length > 0) {
      await TaskActivity.create({
        taskId: updatedTask._id,
        userId: req.user?.id || null,
        action: 'updated',
        description: 'Đã cập nhật công việc',
        changes: changedFields,
      });
    }

    return res.status(200).json({
      message: 'Cập nhật công việc thành công',
      task: updatedTask,
    });
  } catch (error) {
    return res.status(500).json({
      message: 'Lỗi máy chủ',
      error: error.message,
    });
  }
};