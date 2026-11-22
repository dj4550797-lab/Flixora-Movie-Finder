const https = require('https');

const SUPABASE_URL = 'https://comxecntwlntgvjbvkjs.supabase.co';
const ANON_KEY = 'sb_publishable__5xCvJeJren5zsyR33SkJQ_fYwAZIbX';

async function fetchTable(tableName) {
  return new Promise((resolve) => {
    const url = new URL(`${SUPABASE_URL}/rest/v1/${tableName}?select=*&limit=1`);
    const options = {
      method: 'GET',
      headers: {
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${ANON_KEY}`
      }
    };
    const req = https.request(url, options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        resolve({ table: tableName, status: res.statusCode, data: data.substring(0, 100) });
      });
    });
    req.on('error', (err) => resolve({ table: tableName, status: 'ERROR', error: err.message }));
    req.end();
  });
}

async function auditSupabase() {
  const tables = [
    'movies',
    'site_settings',
    'audit_logs',
    'hero_slides',
    'content_overrides',
    'homepage_sections',
    'homepage_section_items',
    'intro_settings',
    'website_settings',
    'admin_settings',
    'analytics_events',
    'admin_activity_logs'
  ];

  console.log('Auditing Supabase Tables via Anon Key...');
  for (const t of tables) {
    const res = await fetchTable(t);
    console.log(`Table [${t}]: Status ${res.status} -> ${res.data}`);
  }
}

auditSupabase();

