const fs = require('fs');
const lines = fs.readFileSync('index.html', 'utf8').split('\n');
console.log(lines.slice(1135, 1360).join('\n'));

