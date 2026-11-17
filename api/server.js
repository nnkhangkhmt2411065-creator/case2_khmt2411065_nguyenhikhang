const express = require('express');
const cors = require('cors');
require('dotenv').config();

const connectDB = require('./src/config/database');
const verifyToken = require('./src/middleware/authMiddleware');

const app = express();

connectDB();

app.use(cors());
app.use(express.json());

app.use((req, res, next) => {
  console.log(`[API] ${req.method} ${req.originalUrl}`);
  next();
});

app.use('/api/auth', require('./src/routes/authRoutes'));

app.use(
  '/api/tasks',
  verifyToken,
  require('./src/routes/taskRoutes')
);

app.use(
  '/task-activities',
  verifyToken,
  require('./src/routes/taskActivityRoutes')
);

app.use(
  '/api/notifications',
  verifyToken,
  require('./src/routes/notificationRoutes')
);

app.use('/api/users', require('./src/routes/userRoutes'));
app.use('/statistics', require('./src/routes/statisticsRoutes'));

app.get('/', (req, res) => {
  res.send('Server đang hoạt động thành công!');
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`Server đang chạy tại port ${PORT}`);
});