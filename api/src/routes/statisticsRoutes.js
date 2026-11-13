const express = require('express');
const router = express.Router();
const statistics = require('../controllers/statisticsController');

router.get('/tasks', statistics.getTaskStatistics);
router.get('/assignments', statistics.getAssignmentStatistics);
router.get('/deadlines', statistics.getDeadlineStatistics);

module.exports = router;
