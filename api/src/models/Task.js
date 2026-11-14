const mongoose = require('mongoose');

const taskSchema = new mongoose.Schema(
  {
    // Tên công việc
    title: {
      type: String,
      required: true,
      trim: true,
    },

    // Mô tả công việc
    description: {
      type: String,
      default: '',
    },

    // Mức độ ưu tiên
    priority: {
      type: String,
      enum: ['low', 'medium', 'high'],
      default: 'medium',
    },

    // Trạng thái công việc
    status: {
      type: String,
      enum: ['pending', 'in-progress', 'completed'],
      default: 'pending',
    },

    // Hạn hoàn thành
    dueDate: {
      type: Date,
    },

    // Người tạo công việc
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },

    // Giữ lại để tương thích với code cũ
    assignedTo: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },

    // Danh sách người được giao
    assigneeIds: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
      },
    ],

    // Người phụ trách chính
    primaryAssigneeId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model('Task', taskSchema);