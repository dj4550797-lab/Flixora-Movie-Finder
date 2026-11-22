const fs = require('fs');

const idx = fs.readFileSync('index.html', 'utf8');

// Find where API is defined and used
const lines = idx.split('\n');
console.log('--- Lines mentioning API or themoviedb ---');
lines.forEach((line, i) => {
  if (line.includes('themoviedb') || line.includes('api.themoviedb') || /const API\s*=/.test(line)) {
    console.log(`Line ${i + 1}: ${line.trim().substring(0, 120)}`);
  }
});

// Check how fetch calls are made
console.log('\n--- Fetch calls to TMDB ---');
lines.forEach((line, i) => {
  if (line.includes('fetch(') && (line.includes('BASE') || line.includes('themoviedb') || line.includes('API'))) {
    console.log(`Line ${i + 1}: ${line.trim().substring(0, 140)}`);
  }
});

// Check ROWS or categories defined in index.html
console.log('\n--- ROWS or category definitions in index.html ---');
lines.forEach((line, i) => {
  if (/const\s+ROWS\s*=|let\s+ROWS\s*=|var\s+ROWS\s*=/.test(line) || /const\s+SECTIONS\s*=/.test(line) || line.includes('rowsContainer')) {
    console.log(`Line ${i + 1}: ${line.trim().substring(0, 140)}`);
  }
});
