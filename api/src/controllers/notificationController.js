const Notification = require('../models/Notification');

function getCurrentUserId(req) {
  const id = req.user?.id || req.user?._id || req.user?.userId;
  return id ? String(id) : null;
}

// GET /api/notifications
exports.getNotifications = async (req, res) => {
  try {
    const userId = getCurrentUserId(req);

    console.log('[NOTIFICATIONS GET] userId:', userId);

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Vui lòng đăng nhập lại',
      });
    }

    const notifications = await Notification.find({ userId })
      .populate('taskId', 'title')
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();

    console.log('[NOTIFICATIONS GET] số lượng:', notifications.length);

    return res.status(200).json({
      success: true,
      notifications,
    });
  } catch (error) {
    console.error('Lỗi tải thông báo:', error);

    return res.status(500).json({
      success: false,
      message: 'Không thể tải thông báo',
      error: error.message,
    });
  }
};

// PATCH /api/notifications/:id/read
exports.markAsRead = async (req, res) => {
  try {
    const userId = getCurrentUserId(req);

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Vui lòng đăng nhập lại',
      });
    }

    const notification = await Notification.findOneAndUpdate(
      { _id: req.params.id, userId },
      {
        $set: {
          isRead: true,
          readAt: new Date(),
        },
      },
      { new: true }
    );

    if (!notification) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy thông báo',
      });
    }

    return res.status(200).json({
      success: true,
      notification,
    });
  } catch (error) {
    console.error('Lỗi cập nhật thông báo:', error);

    return res.status(500).json({
      success: false,
      message: 'Không thể cập nhật thông báo',
      error: error.message,
    });
  }
};