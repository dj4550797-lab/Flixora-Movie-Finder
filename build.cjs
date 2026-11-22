// Flixora Production Build & Source Protection Script
// Minifies HTML, CSS, and JavaScript, strips internal comments, and prepares dist/ for deployment.

const fs = require('fs');
const path = require('path');

function minifyHtml(html) {
  // 1. Remove HTML comments (except conditional comments or doctype)
  let out = html.replace(/<!--[\s\S]*?-->/g, '');

  // 2. Minify inline CSS inside <style>
  out = out.replace(/<style\b[^>]*>([\s\S]*?)<\/style>/gi, (match, css) => {
    const minCss = css
      .replace(/\/\*[\s\S]*?\*\//g, '') // remove comments
      .replace(/\s+/g, ' ')             // collapse whitespace
      .replace(/\s*([\{\}\:\;\,])\s*/g, '$1')
      .replace(/;\}/g, '}')
      .trim();
    return `<style>${minCss}</style>`;
  });

  // 3. Minify inline JS inside <script> (excluding external src scripts)
  out = out.replace(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi, (match, attrs, js) => {
    if (attrs.includes('src=')) return match;
    let minJs = js
      .replace(/\/\*[\s\S]*?\*\//g, '')  // remove multiline comments
      .replace(/(^|[^:])\/\/[^\r\n]*/g, '$1') // remove single line comments
      .replace(/^\s*[\r\n]/gm, '');     // remove empty lines

    // Safe variable compacting
    minJs = minJs.replace(/\s{2,}/g, ' ');
    return `<script${attrs}>${minJs}</script>`;
  });

  return out;
}

function build() {
  console.log('--- FLIXORA PRODUCTION BUILD PIPELINE ---');
  const distDir = path.join(__dirname, 'dist');
  if (!fs.existsSync(distDir)) {
    fs.mkdirSync(distDir, { recursive: true });
  }

  // 1. Process index.html
  console.log('Processing index.html...');
  const indexRaw = fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8');
  const indexDist = minifyHtml(indexRaw);
  fs.writeFileSync(path.join(distDir, 'index.html'), indexDist, 'utf8');
  console.log(`  index.html: ${indexRaw.length} bytes -> ${indexDist.length} bytes (Saved ${Math.round((1 - indexDist.length / indexRaw.length) * 100)}%)`);

  // 2. Process admin.html
  console.log('Processing admin.html...');
  const adminRaw = fs.readFileSync(path.join(__dirname, 'admin.html'), 'utf8');
  const adminDist = minifyHtml(adminRaw);
  fs.writeFileSync(path.join(distDir, 'admin.html'), adminDist, 'utf8');
  console.log(`  admin.html: ${adminRaw.length} bytes -> ${adminDist.length} bytes (Saved ${Math.round((1 - adminDist.length / adminRaw.length) * 100)}%)`);

  // 3. Preserve uppercase Index.html backup if present
  const backupSrc = path.join(__dirname, 'Index.html.backup_preserved');
  if (fs.existsSync(backupSrc)) {
    console.log('Preserving Index.html backup in dist/ (uppercase reference)...');
    fs.copyFileSync(backupSrc, path.join(distDir, 'Index.html'));
  }

  console.log('Build completed successfully into dist/');
}

if (require.main === module) {
  build();
}

module.exports = { build, minifyHtml };

