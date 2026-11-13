const express = require('express');
const cors = require('cors');
require('dotenv').config();
const connectDB = require('./src/config/database');

const app = express();
connectDB();

app.use(cors());
app.use(express.json());

app.use('/api/auth', require('./src/routes/authRoutes'));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server đang chạy tại port ${PORT}`));