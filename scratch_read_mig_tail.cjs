const fs = require('fs');
const lines = fs.readFileSync('migration.sql', 'utf8').split('\n');
console.log('Lines 240 to 392:\n' + lines.slice(240).join('\n'));

