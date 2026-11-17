const express = require('express');
const cors = require('cors');
require('dotenv').config();

const connectDB = require('./config/database');
const verifyToken = require('./middleware/authMiddleware');

const app = express();

// Kết nối MongoDB
connectDB();

// Middleware chung
app.use(cors());
app.use(express.json());

app.use((req, res, next) => {
  console.log(`[API] ${req.method} ${req.originalUrl}`);
  next();
});

// API xác thực và tài khoản
app.use('/api/auth', require('./routes/authRoutes'));

// API công việc
app.use(
  '/api/tasks',
  verifyToken,
  require('./routes/taskRoutes')
);

// API lịch sử hoạt động
app.use(
  '/task-activities',
  verifyToken,
  require('./routes/taskActivityRoutes')
);

// API thông báo
app.use(
  '/api/notifications',
  verifyToken,
  require('./routes/notificationRoutes')
);

// API người dùng
app.use('/api/users', require('./routes/userRoutes'));

// API thống kê
app.use('/statistics', require('./routes/statisticsRoutes'));

// Kiểm tra server
app.get('/', (req, res) => {
  res.send('Server đang hoạt động thành công!');
});

// Khởi động server
const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`Server đang chạy tại port ${PORT}`);
});
