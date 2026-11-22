const fs = require('fs');
const lines = fs.readFileSync('index.html', 'utf8').split('\n');
console.log(lines.slice(1070, 1160).join('\n'));

