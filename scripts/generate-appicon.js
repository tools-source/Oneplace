// Renders the OnePlace app icon at every size required by AppIcon.appiconset.
// Vector source -> crisp raster at each size (no upscaling), fully opaque PNGs.
const sharp = require('sharp');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const SVG = path.join(ROOT, 'assets', 'appicon.svg');
const OUT = path.join(ROOT, 'OnePlace', 'Resources', 'Assets.xcassets', 'AppIcon.appiconset');

// filename -> pixel size (matches Contents.json)
const targets = {
  'Icon-40.png': 40,
  'Icon-60.png': 60,
  'Icon-58.png': 58,
  'Icon-87.png': 87,
  'Icon-80.png': 80,
  'Icon-120 1.png': 120,
  'Icon-120.png': 120,
  'Icon-180.png': 180,
  'Icon-1024.png': 1024,
};

const BG = '#1E86D2'; // mid brand tone; only used to guarantee no transparency

async function run() {
  const svg = await require('fs').promises.readFile(SVG);
  for (const [name, size] of Object.entries(targets)) {
    await sharp(svg, { density: 384 })
      .resize(size, size, { fit: 'cover' })
      .flatten({ background: BG }) // App Store icons must be fully opaque (no alpha)
      .png()
      .toFile(path.join(OUT, name));
    console.log(`✓ ${name} (${size}x${size})`);
  }
  console.log('Done.');
}

run().catch((e) => { console.error(e); process.exit(1); });
