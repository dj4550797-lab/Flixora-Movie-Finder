const fs = require('fs');
const lines = fs.readFileSync('admin.html', 'utf8').split('\n');
console.log('Lines 1570-1615:\n' + lines.slice(1570, 1615).join('\n'));
console.log('\nLines 1970-2005:\n' + lines.slice(1970, 2005).join('\n'));

