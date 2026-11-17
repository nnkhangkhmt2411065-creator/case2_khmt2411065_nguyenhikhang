const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

// Gửi email khi thông tin công việc thay đổi
const sendTaskUpdateEmail = async (userEmail, taskTitle, changes) => {
  try {
    const safeTitle = escapeHtml(taskTitle);
    const changeList = Array.isArray(changes) ? changes : [];

    await transporter.sendMail({
      from: process.env.EMAIL_USER,
      to: userEmail,
      subject: `[Thông báo] Công việc "${taskTitle}" đã được cập nhật`,
      html: `
        <h3>Công việc của bạn có thay đổi mới!</h3>
        <p><strong>Tên công việc:</strong> ${safeTitle}</p>
        <p><strong>Chi tiết thay đổi:</strong></p>
        <ul>
          ${changeList.map((change) => `<li>${escapeHtml(change)}</li>`).join('')}
        </ul>
      `,
    });

    console.log('Đã gửi email cập nhật tới:', userEmail);
    return true;
  } catch (error) {
    console.error('Lỗi gửi email cập nhật:', error.message);
    return false;
  }
};

// Gửi email khi được mời xem hoặc chỉnh sửa công việc
const sendTaskSharedEmail = async (userEmail, taskTitle, permission) => {
  try {
    const safeTitle = escapeHtml(taskTitle);
    const permissionText =
      permission === 'editor' ? 'có thể chỉnh sửa' : 'chỉ có thể xem';

    await transporter.sendMail({
      from: process.env.EMAIL_USER,
      to: userEmail,
      subject: `[Mời chia sẻ] Bạn được chia sẻ công việc "${taskTitle}"`,
      html: `
        <h3>Bạn vừa được mời tham gia một công việc</h3>
        <p><strong>Tên công việc:</strong> ${safeTitle}</p>
        <p><strong>Quyền truy cập:</strong> ${permissionText}</p>
        <p>Đăng nhập vào Task Manager để xem công việc này.</p>
      `,
    });

    console.log('Đã gửi email chia sẻ tới:', userEmail);
    return true;
  } catch (error) {
    console.error('Lỗi gửi email chia sẻ:', error.message);
    return false;
  }
};

module.exports = {
  sendTaskUpdateEmail,
  sendTaskSharedEmail,
};