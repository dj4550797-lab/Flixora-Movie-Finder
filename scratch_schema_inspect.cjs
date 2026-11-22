const https = require('https');

const SUPABASE_URL = 'https://comxecntwlntgvjbvkjs.supabase.co';
const ANON_KEY = 'sb_publishable__5xCvJeJren5zsyR33SkJQ_fYwAZIbX';

async function fetchOpenApi() {
  return new Promise((resolve) => {
    const url = new URL(`${SUPABASE_URL}/rest/v1/`);
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
        try {
          const json = JSON.parse(data);
          resolve(json);
        } catch(e) {
          resolve({ raw: data });
        }
      });
    });
    req.on('error', (err) => resolve({ error: err.message }));
    req.end();
  });
}

async function inspectSchema() {
  const schema = await fetchOpenApi();
  if (schema.definitions) {
    console.log('Available table definitions in OpenAPI:');
    Object.keys(schema.definitions).forEach(t => {
      console.log(`\nTable [${t}]:`);
      const props = schema.definitions[t].properties || {};
      Object.keys(props).forEach(p => {
        console.log(`  - ${p}: ${props[p].type} (format: ${props[p].format || 'none'})`);
      });
    });
  } else {
    console.log('OpenAPI response:', JSON.stringify(schema).substring(0, 300));
  }
}

inspectSchema();

