const fs = require('fs');

const idx = fs.readFileSync('index.html', 'utf8');
const adm = fs.readFileSync('admin.html', 'utf8');

console.log('=== FILE SIZES ===');
console.log('index.html:', idx.length, 'bytes, lines:', idx.split('\n').length);
console.log('admin.html:', adm.length, 'bytes, lines:', adm.split('\n').length);

// Scan for TMDB API key pattern (usually 32 hex chars)
const tmdbKeyRegex = /\b[a-f0-9]{32}\b/gi;
const idxHexMatches = idx.match(tmdbKeyRegex) || [];
console.log('\n=== INDEX.HTML 32-HEX MATCHES (potential TMDB keys) ===');
console.log('Count:', idxHexMatches.length);
idxHexMatches.forEach(m => {
  // Check context
  const idxPos = idx.indexOf(m);
  const snippet = idx.substring(Math.max(0, idxPos - 40), Math.min(idx.length, idxPos + 60)).replace(/\r?\n/g, ' ');
  const masked = m.substring(0, 4) + '...' + m.substring(m.length - 4);
  console.log('Match snippet:', snippet.replace(m, masked));
});

// Scan for Supabase keys
const sbKeyRegex = /sb_publishable_[a-zA-Z0-9_\-]+|eyJ[a-zA-Z0-9_\-\.]{50,}/g;
console.log('\n=== SUPABASE KEY SCAN ===');
const sbIdx = idx.match(sbKeyRegex) || [];
console.log('index.html Supabase key matches:', sbIdx.map(k => k.substring(0, 15) + '... (' + k.length + ' chars)'));
const sbAdm = adm.match(sbKeyRegex) || [];
console.log('admin.html Supabase key matches:', sbAdm.map(k => k.substring(0, 15) + '... (' + k.length + ' chars)'));

// Scan for TMDB fetch / urls
const tmdbUrls = idx.match(/https?:\/\/[^\s"'`]+themoviedb[^\s"'`]+/g) || [];
console.log('\n=== TMDB URL SAMPLES ===');
console.log('Count:', tmdbUrls.length);
console.log('Unique patterns:');
const uniqueUrls = [...new Set(tmdbUrls.map(u => u.split('?')[0]))];
uniqueUrls.forEach(u => console.log(' ', u));

// Scan for all homepage section keys / carousels in index.html
const sectionMatches = idx.match(/id=["']([a-zA-Z0-9_\-]+)["']/g) || [];
console.log('\n=== ID SCAN (Sample sections) ===');
const sampleSecs = sectionMatches.filter(s => s.toLowerCase().includes('section') || s.toLowerCase().includes('row') || s.toLowerCase().includes('grid') || s.toLowerCase().includes('carousel') || s.toLowerCase().includes('movie') || s.toLowerCase().includes('anime') || s.toLowerCase().includes('trending'));
console.log('Sample section IDs:', sampleSecs.slice(0, 20));
