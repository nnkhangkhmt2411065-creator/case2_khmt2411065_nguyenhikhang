
const express = require('express');
const router = express.Router();

const statistics = require('../controllers/statisticsController');
const verifyToken = require('../middleware/authMiddleware');

// E1: Thong ke cong viec theo trang thai
router.get('/tasks', statistics.getTaskStatistics);

// E2: Thong ke cong viec duoc giao
router.get('/assignments', verifyToken, statistics.getAssignmentStatistics);

// E3: Thong ke cong viec theo han
router.get('/deadlines', statistics.getDeadlineStatistics);

module.exports = router;
