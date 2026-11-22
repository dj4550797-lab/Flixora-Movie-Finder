const fs = require('fs');
const lines = fs.readFileSync('migration.sql', 'utf8').split('\n');
console.log('Total lines:', lines.length);
console.log('First 60 lines:\n' + lines.slice(0, 60).join('\n'));

