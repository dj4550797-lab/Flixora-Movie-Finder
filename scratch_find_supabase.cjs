const fs = require('fs');

const idx = fs.readFileSync('index.html', 'utf8');

// Find FlixoraSupabase definition
const match = idx.indexOf('const FlixoraSupabase');
if (match !== -1) {
  console.log(idx.substring(match, match + 2000));
} else {
  console.log('FlixoraSupabase not found');
}
