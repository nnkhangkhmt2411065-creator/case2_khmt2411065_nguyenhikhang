const express = require('express');
const cors = require('cors');
const connectDB = require('./config/database');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

connectDB();

app.use('/api/auth', require('./routes/authRoutes'));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));