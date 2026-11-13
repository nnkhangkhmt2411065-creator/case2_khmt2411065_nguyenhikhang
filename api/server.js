const express = require('express');
const cors = require('cors');
require('dotenv').config();
const connectDB = require('./src/config/database');
const app = express();
connectDB();

app.use(cors());
app.use(express.json());

app.use('/api/auth', require('./src/routes/authRoutes'));
app.use('/api/tasks', require('./src/routes/taskRoutes'));
app.get('/', (req, res) => {
    res.send('Server dang hoat dong thanh cong!');
});
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server đang chạy tại port ${PORT}`));