const fs = require('fs');

const mig = fs.readFileSync('migration.sql', 'utf8');
console.log('Migration length:', mig.length, 'bytes');

// Show table creation statements
const tableMatches = mig.match(/CREATE TABLE[^\;]+\;/gi) || [];
console.log('CREATE TABLE statements count:', tableMatches.length);
tableMatches.forEach((s, i) => {
  const firstLine = s.trim().split('\n')[0];
  console.log(`[${i + 1}] ${firstLine}`);
});

// Show RLS policies
const policyMatches = mig.match(/CREATE POLICY[^\;]+\;/gi) || [];
console.log('\nCREATE POLICY statements count:', policyMatches.length);
policyMatches.forEach((s, i) => {
  const firstLine = s.trim().split('\n')[0];
  console.log(`[${i + 1}] ${firstLine}`);
});
