const express = require('express');
const cors = require('cors');
require('dotenv').config();

const connectDB = require('./src/config/database');
const verifyToken = require('./src/middleware/authMiddleware');

const app = express();

// Kết nối MongoDB
connectDB();

// Middleware chung
app.use(cors());
app.use(express.json());

// API xác thực và tài khoản
app.use('/api/auth', require('./src/routes/authRoutes'));

// API công việc: yêu cầu đăng nhập bằng JWT
app.use(
  '/api/tasks',
  verifyToken,
  require('./src/routes/taskRoutes')
);

// API danh sách người dùng
app.use('/api/users', require('./src/routes/userRoutes'));

// API thống kê công việc
app.use('/statistics', require('./src/routes/statisticsRoutes'));

// Kiểm tra server
app.get('/', (req, res) => {
  res.send('Server dang hoat dong thanh cong!');
});

// Khởi động server
const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`Server dang chay tai port ${PORT}`);
});