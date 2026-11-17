require('dotenv').config();

const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const readline = require('node:readline/promises');
const { stdin, stdout } = require('node:process');

const connectDB = require('./src/config/database');
const User = require('./src/models/User');

async function main() {
  const rl = readline.createInterface({ input: stdin, output: stdout });

  const email = (await rl.question('Nhap email tai khoan cu: ')).trim();
  const newPassword = await rl.question('Nhap mat khau moi: ');

  rl.close();

  if (!email || !newPassword) {
    throw new Error('Email va mat khau moi khong duoc de trong.');
  }

  await connectDB();

  const user = await User.findOne({ email });

  if (!user) {
    throw new Error('Khong tim thay tai khoan voi email nay.');
  }

  user.passwordHash = await bcrypt.hash(newPassword, 10);
  await user.save();

  console.log('Da dat lai mat khau. Tai khoan va cong viec van duoc giu nguyen.');
}

main()
  .catch((error) => {
    console.error('Khong dat lai duoc mat khau:', error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });