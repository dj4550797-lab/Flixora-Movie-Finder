const fs = require('fs');

const adm = fs.readFileSync('admin.html', 'utf8');
const lines = adm.split('\n');

console.log('=== ADMIN.HTML HEAD ===');
console.log(lines.slice(0, 35).join('\n'));

console.log('\n=== SUPER_ADMIN_UUID in admin.html ===');
lines.forEach((l, i) => {
  if (l.includes('SUPER_ADMIN_UUID') || l.includes('SUPER_ADMIN_EMAIL')) {
    console.log(`Line ${i + 1}: ${l.trim()}`);
  }
});

