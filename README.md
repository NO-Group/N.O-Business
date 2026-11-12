# M-Tek Fire & Safety Ltd — Official Website

Multi-page static website for **M-Tek Fire & Safety Ltd** (Kaduna, Nigeria) — certified fire safety,
security and solar equipment supplier since 2012 (RC: 1082534).

## Pages

| Page           | File            | Purpose                                              |
| -------------- | --------------- | ---------------------------------------------------- |
| Home           | `index.html`    | Hero, about preview, categories, services, gallery, testimonials |
| About          | `about.html`    | Company story, mission/vision/values, timeline, stats |
| Products       | `products.html` | Category overview with deep links into the shop      |
| Services       | `services.html` | Full service lines, process steps, industries served |
| Gallery        | `gallery.html`  | Filterable photo gallery with lightbox               |
| Shop           | `shop.html`     | Product catalogue, cart, quick-view modal, checkout  |
| Contact        | `contact.html`  | Offices, form (WhatsApp/email), map, FAQ             |
| Terms          | `terms.html`    | Terms & Conditions of Use and Sale (legal framework) |
| Privacy        | `privacy.html`  | Privacy Policy & Cookie / Local Storage Statement    |

## Tech

- Plain HTML + CSS + vanilla JS — no build step, no dependencies.
- `styles.css` — full design system (Sora + Poppins fonts, brand tokens).
- `script.js` — shared behaviour (mobile nav, reveal animations, counters, lightbox, FAQ).
- `products.js` — **product catalogue data** (edit this file to update prices/products; the
  shop and pages pick it up automatically). Prices are indicative Naira values.
- `shop.js` — shop & cart logic (filters, search, sort, quick-view, WhatsApp/email checkout).

## Assets

- `logo.png` — original full-size logo (kept as master).
- `assets/img/logo-256.png` — optimised logo used in the header/footer (74 KB).
- `assets/img/favicon-32.png` / `favicon-64.png` — site favicons.
- `assets/img/` — hero & section photography.
- `assets/products/` — real product photos, auto-matched to catalogue items by `shop.js`.

## Updating the product catalogue

1. Open `products.js`.
2. Each product has: `id`, `name`, `category`, `price` (₦), `description`, `featured`.
   - Set `price: 0` (or omit) for “Price on request”.
   - `featured: true` shows the item in the Shop “Top Picks” carousel.
3. Product photos live in `assets/products/`. `shop.js` maps product names to the closest
   real photo automatically; add new photos to that folder and tweak the `imageRules` list
   in `shop.js` if you want a specific match.

## Deploying

This is a static site — upload the whole folder to any static host (GitHub Pages, Netlify,
Vercel, cPanel) or keep using the existing GitHub Pages workflow.

## Inventory & Business App (in development)

See [`docs/SPEC.md`](docs/SPEC.md) for the agreed spec of the **M-Tek Inventory app** —
one Flutter codebase in [`app/`](app/) targeting Android, Windows and a PWA served at
`/app`. Backend: Supabase + MongoDB (`backend/`, credentials in gitignored `.env`).
`seed/` holds the owner-editable product import file. `preview/` is a runnable
design preview of the app's screens, including authenticated document workflows. Target PWA URL:
`https://mtekfiresafetyltd.github.io/m-tek_fire_safety_ltd.org/` (company
GitHub Pages — the app opens at the bare URL, website under `/site/`;
activation steps in `docs/SPEC.md` §11).
