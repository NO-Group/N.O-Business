# Product Photos — How to add or replace images

This folder holds all product photos for the M-Tek Fire & Safety Ltd online shop.

## Quick workflow (what you asked for)

You said: *“products and prices for each category are in these four files, so picture will be uploaded for the products as the next step then you will add their names in the path.”*

That is now wired up:

1. **Upload a picture** to this folder (`assets/products/`).
   - You can name the file exactly like the product, e.g. `DCP 6kg Bajik I.jpg` or keep your camera name — both work.
   - Spaces, parentheses `(` `)`, and `&` are fine — the shop encodes them to `%20` automatically.
   - Recommended size: 800–1200px on the longest side, JPG or WEBP, < 300KB for fast loading. If the file is very large, compress it before uploading.

2. **Tell the catalogue where the picture lives** — open `products.js` at the project root and set the `image` field for that product:

```js
{
  id: "F016",
  name: "DCP 6kg Bajik I",
  category: "Fire",
  price: 30000,
  description: "6kg Dry Chemical Powder fire extinguisher (Bajik I).",
  image: "assets/products/DCP 6kg Bajik I.jpg",   // ← add / update this line
  featured: true
}
```

- The path **must** start with `assets/products/` (or just the filename — `shop.js` will prefix it for you).
- Alternatives also work: `img`, `photo`, `imageUrl` — but `image` is the convention.
- If you leave `image: ""` or omit it, the shop falls back to a keyword-matched placeholder (e.g. helmets → `MSA Helmet (Green).jpg`, extinguishers → `DCP_50kg_Fire_Extinguisher.jpg`). Nothing breaks while a photo is missing.

3. **Refresh `shop.html`** — the new photo appears in the catalogue grid, Top Picks carousel, cart drawer, and quick-view modal.

## Already in the folder (29 real photos)

`Auto Fire Ball.jpg`, `Beak Glass.jpg`, `Beware Of Dogs Mounted.jpg`, `Caution Cone (75cm).jpg`, `DCP_50kg_Fire_Extinguisher.jpg`, `MSA Helmet (Green).jpg`, `Muster Point Mounted.jpg`, `Overall.jpg`, `Pillar Hydrant.jpg`, `Rocklander Safety Boots.jpg`, `Zeta Smoke Detector.jpg`, `bulb camera.jpg`, `cctv equipments.jpg`, `continous flow hose reel.jpg`, `hose reel and box.jpg`, `hose reel.jpg`, `landing valve.jpg`, `metal dectector.jpg`, etc.

> ⚠️ `Fire Estinguisher Hanged.jpg` is currently a 2-byte placeholder (broken). The shop now **does not use it** — extinguishers automatically show `DCP_50kg_Fire_Extinguisher.jpg` until you replace the broken file with a real photo of that name, or point specific products to their own new photos.

## Naming tips

- Keep names human-readable. Example: `Box for 6kg Fire Extinguisher.jpg` is easier to audit than `IMG_20240101_123.jpg`, but both work.
- Avoid `\` and `#` or `?` in filenames — they break URLs. Use letters, numbers, spaces, `-`, `_`, `(`, `)`.
- If you have many products of one type (e.g. 50 DCP variants), you can reuse one photo for several products — just point multiple `image` fields to the same file, or let the fallback handle it until you have individual shots.

## Bulk update helper

A small helper script lives at `tools/update-image-paths.js` (created for you). It:
- scans `assets/products/`
- tries to fuzzy-match filenames to product names (case-insensitive, ignores spaces/dashes)
- prints a report of which products still use fallbacks and which filenames are unmatched

Run it with `node tools/update-image-paths.js` after uploading a batch.

## Four categories → one catalogue

Prices and products are organized in `products.js` by category blocks:

- `// FIRE` (127 items, id `F001`–`F127`)
- `// SAFETY` (65 items, id `S001`–`S065`)
- `// SECURITY` (11 items, id `Q001`–`Q011`)
- `// SOLAR` (26 items, id `L001`–`L026`)
- `// HOME AUTOMATION, ALARM & SURVEILLANCE` (12 items, id `H001`–`H012`)

If your “four files” are separate spreadsheets/CSVs per category, keep editing `products.js` in those blocks, or paste updated blocks here — the shop picks them up automatically with no other code changes.

Need the categories split into four separate files? Just say — the current `shop.js` also accepts `products-fire.js`, `products-safety.js`, etc., if you prefer that layout. For now a single file keeps deployment simple (one `<script src="products.js">` tag).

## After you upload

Once you drop the new pictures here, tell me the filenames (or just say “done”), and I’ll update `products.js` → `image: "assets/products/<your filename>"` for each product you indicate. If you want me to auto-match by product name, I can do that in one pass.
