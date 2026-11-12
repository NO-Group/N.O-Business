#!/usr/bin/env node
/**
 * M-Tek - helper to audit product images
 * Scans assets/products/ and products.js, reports fallback vs explicit images
 * Run: node tools/update-image-paths.js
 * Optional: node tools/update-image-paths.js --apply
 *   (--apply auto-writes image paths where a filename clearly matches a product name)
 */
const fs = require('fs');
const path = require('path');
const ROOT = path.join(__dirname, '..');
const PRODUCTS_JS = path.join(ROOT, 'products.js');
const PRODUCTS_DIR = path.join(ROOT, 'assets', 'products');

function normalize(s) {
  return s.toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
}

function loadProducts() {
  const code = fs.readFileSync(PRODUCTS_JS, 'utf8');
  // crude parse: extract id, name, image, category
  const re = /\{\s+id:\s*"(?<id>[^"]+)",\s+name:\s*"(?<name>(?:\\.|[^"])*)",\s+category:\s*"(?<cat>[^"]+)",\s+price:\s*(?<price>\d+),\s+description:\s*"(?<desc>(?:\\.|[^"])*)",\s+image:\s*"(?<image>[^"]*)",\s+featured:\s*(?<feat>true|false)\s+\}/g;
  const products = [];
  let m;
  while ((m = re.exec(code))) {
    products.push(m.groups);
  }
  return products;
}

function scanImages() {
  if (!fs.existsSync(PRODUCTS_DIR)) return [];
  return fs.readdirSync(PRODUCTS_DIR).filter(f => /\.(jpe?g|png|webp|avif)$/i.test(f));
}

function main() {
  const products = loadProducts();
  const images = scanImages();
  console.log(`Products: ${products.length}`);
  console.log(`Images on disk: ${images.length}`);
  console.log(images.map(f => '  - ' + f + ` (${(fs.statSync(path.join(PRODUCTS_DIR,f)).size/1024).toFixed(1)}KB)`).join('\n'));
  console.log('\n--- Per-product image audit (first 30) ---');
  const apply = process.argv.includes('--apply');
  let updated = 0;
  let code = fs.readFileSync(PRODUCTS_JS, 'utf8');
  const normImages = images.map(f => ({ file: f, norm: normalize(path.parse(f).name) }));

  for (const p of products) {
    const normName = normalize(p.name);
    // Find best filename match: exact normalized name match, or filename contains product name, or vice versa
    let match = normImages.find(img => img.norm === normName);
    if (!match) match = normImages.find(img => img.norm.includes(normName) || normName.includes(img.norm));
    const isFallback = p.image === 'assets/products/DCP_50kg_Fire_Extinguisher.jpg' || p.image === 'assets/products/Rocklander Safety Boots.jpg';
    // Consider fallback vs explicit
  }

  // Detailed report per category
  const byCat = {};
  for (const p of products) byCat[p.cat] = (byCat[p.cat] || 0) + 1;
  console.log('\nPer-category counts:');
  for (const [cat, n] of Object.entries(byCat)) console.log(`  ${cat}: ${n}`);

  // List products still using generic placeholder that could have a better match
  console.log('\nProducts currently using generic fallback image (sample):');
  const generics = products.filter(p => {
    // generics are those where image equals CAT_IMG; we built them via resolve()
    // For now consider DCP_50kg as generic for many Fire items
    return p.image.includes('DCP_50kg') && !/DCP|CO2|Foam/i.test(p.name) === false;
  });
  // Instead just list those where image does not contain product name
  const unmatched = products.filter(p => {
    const fileBase = path.parse(p.image).name.toLowerCase();
    const nameNorm = p.name.toLowerCase();
    // if filename base not in name and name not in filename, consider generic
    return !fileBase.includes(nameNorm.split(' ')[0].toLowerCase()) && p.image.includes('DCP_50kg');
  });
  console.log(`  ${unmatched.length} products share the generic DCP image - they will improve when you upload specific photos.`);

  // Suggest matches for --apply
  if (apply) {
    let newCode = code;
    let changes = 0;
    for (const p of products) {
      const normName = normalize(p.name);
      const match = normImages.find(img => img.norm === normName);
      if (match) {
        const desired = `assets/products/${match.file}`;
        if (p.image !== desired) {
          const oldLine = `image: "${p.image}"`;
          const newLine = `image: "${desired}"`;
          // replace only the block for this id
          const blockRe = new RegExp(`(\\{\\s+id:\\s*"${p.id}"[^}]*?)image:\\s*"[^"]*"`, 's');
          if (blockRe.test(newCode)) {
            newCode = newCode.replace(blockRe, `$1image: "${desired}"`);
            changes++;
            console.log(`  APPLY ${p.id} ${p.name} -> ${desired}`);
          }
        }
      }
    }
    if (changes) {
      fs.writeFileSync(PRODUCTS_JS, newCode);
      console.log(`\nUpdated ${changes} products in products.js`);
    } else {
      console.log('\nNo exact filename matches to apply. Upload files named exactly like products (e.g. "DCP 6kg Bajik I.jpg") for auto-apply to work.');
    }
  } else {
    console.log('\nTip: upload files named like products, then run with --apply to auto-wire them.');
    console.log('Example: if you upload "DCP 6kg Bajik I.jpg", --apply will set F016/F036 image to that file where the name matches exactly.');
  }

  // Check for broken placeholder
  const broken = path.join(PRODUCTS_DIR, 'Fire Estinguisher Hanged.jpg');
  if (fs.existsSync(broken)) {
    const sz = fs.statSync(broken).size;
    if (sz < 100) {
      console.log(`\n⚠️  Warning: "Fire Estinguisher Hanged.jpg" is only ${sz} bytes (broken). The shop now avoids it, but you should replace it with a real photo.`);
    }
  }

  // Check imagePaths that don't exist
  const missing = products.filter(p => {
    const rel = p.image.replace(/^assets\/products\//, '');
    return !images.includes(rel) && !fs.existsSync(path.join(PRODUCTS_DIR, rel));
  });
  if (missing.length) {
    console.log(`\n⚠️  ${missing.length} products point to images not found on disk (they will fallback in browser):`);
    missing.slice(0, 10).forEach(p => console.log(`  ${p.id} -> ${p.image}`));
    if (missing.length > 10) console.log(`  ... and ${missing.length - 10} more`);
  } else {
    console.log('\nAll product image paths resolve to files on disk ✓ (fallback placeholders also present).');
  }
}

main();
