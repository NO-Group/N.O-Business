/* ==========================================================================
   M-TEK FIRE & SAFETY LTD — Shop & cart
   Product data lives in products.js (edit that file to update the catalogue).
   ========================================================================== */

document.addEventListener("DOMContentLoaded", () => {
  // products.js declares `const MTEK_PRODUCTS` (a global lexical binding).
  // Read it defensively — it is exposed both as a bare identifier and on window.
  let products = [];
  try {
    if (typeof window !== "undefined" && Array.isArray(window.MTEK_PRODUCTS)) {
      products = window.MTEK_PRODUCTS;
    } else if (typeof MTEK_PRODUCTS !== "undefined") {
      products = MTEK_PRODUCTS;
    }
  } catch (e) {
    products = [];
  }

  /* ---------------------------------------------------------------
     1. Product photography — per-product `image` + smart fallback
        WORKFLOW FOR NEW PICTURES:
        1) Upload the photo to assets/products/  (e.g. "DCP 6kg Bajik I.jpg")
        2) In products.js set the product's `image` to that path:
           image: "assets/products/DCP 6kg Bajik I.jpg"
        3) shop.js will use `product.image` verbatim (encoded). If `image`
           is empty/null, the keyword fallback below keeps a sensible
           placeholder so nothing breaks.
        NOTE: Fire Estinguisher Hanged.jpg on disk is currently a 2-byte
        placeholder (broken). Extinguishers therefore fall back to
        DCP_50kg_Fire_Extinguisher.jpg until the real photo is replaced.
  --------------------------------------------------------------- */
  // Use encodeURI so filenames with spaces / parentheses work in the browser.
  const IMG = (file) => encodeURI("assets/products/" + file);
  const CAT_IMG = {
    Fire: IMG("DCP_50kg_Fire_Extinguisher.jpg"),
    Safety: IMG("Rocklander Safety Boots.jpg"),
    Security: IMG("cctv equipments.jpg"),
    Solar: IMG("solar bulb.jpg"),
    "Home Automation, Alarm & Surveillance": IMG("Zeta Smoke Detector.jpg"),
  };
  // Generic product placeholder when nothing else matches
  const PLACEHOLDER = CAT_IMG.Fire;

  const imageRules = [
    // Fire — specific extinguisher types first (more specific than generic)
    [/foam\s*9/i, IMG("Foam 9L Fire Extinguisher.jpg")],
    [/foam/i, IMG("Foam 9L Fire Extinguisher.jpg")],
    [/co2\s*2kg/i, IMG("CO2 5kg Fire Extinguisher.webp")],
    [/co2/i, IMG("CO2 5kg Fire Extinguisher.webp")],
    [/dcp\s*1kg/i, IMG("DCP 6kg Fire Extinguisher.jpg")],
    [/dcp/i, IMG("DCP 6kg Fire Extinguisher.jpg")],
    [/hose reel and box|hose reel cabinet|fire hose reel and box|hose reel cabinet/i, IMG("Fire Hose Reel Cabinet.jpg")],
    [/hose reel|fire hose reel/i, IMG("hose reel.jpg")],
    [/continous flow|continuous flow/i, IMG("continous flow hose reel.jpg")],
    [/hydrant \(pillar|pillar\/pedestrian|pillar hydrant/i, IMG("Pillar Hydrant.jpg")],
    [/hydrant \(underground|one way pillar/i, IMG("one way pillar hydrant.jpg")],
    [/landing valve/i, IMG("landing valve.jpg")],
    [/breathing apparatus|respiratory|dust mask|spaceman/i, IMG("Auto Fire Ball.jpg")],
    [/fire blanket/i, IMG("DCP_50kg_Fire_Extinguisher.jpg")],
    [/sprinkler/i, IMG("sprinkler head.jpg")],
    [/fire bucket/i, IMG("DCP_50kg_Fire_Extinguisher.jpg")],
    [/hanger|valve|coupline|nozzle|horn|strap|pin|nipple/i, IMG("DCP_50kg_Fire_Extinguisher.jpg")],
    [/extinguisher|bajik|angus|bryk|stangoz|extintore|bizland|flamesense|flame point|keenstop|poztan|fire killer|capital tell|chubb|visa|pansion|fire stop/i, IMG("DCP 6kg Fire Extinguisher.jpg")],
    // Safety — first aid and signage get dedicated images
    [/first aid box/i, IMG("First Aid Box.jpg")],
    [/muster point|sinage|signage|beware.*dog|caution|danger|fire exit|fire action|wet floor|no smoking/i, IMG("Muster Point Sign.jpg")],
    [/helmet/i, IMG("MSA Helmet (Green).jpg")],
    [/boots|rain boot/i, IMG("Rocklander Safety Boots.jpg")],
    [/vest|jacket|reflective/i, IMG("reflective jacket green.jpg")],
    [/ear muffs|ear defenders|earpiece|ear plug/i, IMG("ear muffs.jpg")],
    [/overall|fireman suit|fire tunic|harness|belt/i, IMG("Overall.jpg")],
    [/metal detector/i, IMG("metal dectector.jpg")],
    [/gloves/i, IMG("Rocklander Safety Boots.jpg")],
    [/goggles|mask/i, IMG("MSA Helmet (Green).jpg")],
    [/cone|barrier|tape/i, IMG("Caution Cone (75cm).jpg")],
    // Solar — specific assets we just sourced
    [/inverter/i, IMG("Solar Inverter 3kVA.jpg")],
    [/panel/i, IMG("Solar Panel 200W.jpg")],
    [/battery|220ah|200ah/i, IMG("Solar Battery 200Ah.jpg")],
    [/charge controller/i, IMG("Solar Inverter 3kVA.jpg")],
    [/solar light|solar lamp|solar bulb|dc bulb|solar fan|solar power pack|beacon/i, IMG("solar bulb.jpg")],
    // Surveillance / Home Automation
    [/baofeng|two way radio/i, IMG("Baofeng Radio.jpg")],
    [/dvr|nvr|hard drive/i, IMG("DVR 8 Channel.jpg")],
    [/camera.*outdoor|cctv.*outdoor/i, IMG("Outdoor CCTV Camera.jpg")],
    [/camera|cctv/i, IMG("bulb camera.jpg")],
    [/panel.*fap|fire alarm panel/i, IMG("Fire Alarm Panel.jpg")],
    [/bell|siren|flasher|strobe|sounder|beacon/i, IMG("Zeta Smoke Detector.jpg")],
    [/call point|break glass/i, IMG("Beak Glass.jpg")],
    [/cable/i, IMG("Zeta Smoke Detector.jpg")],
    [/smoke detector|smoke alarm|heat detector|pir|infrared|magnetic.*contact|panic button|psu/i, IMG("Zeta Smoke Detector.jpg")],
    [/fire ball/i, IMG("Auto Fire Ball.jpg")],
  ];

  function resolveImage(product) {
    // 1) Explicit per-product image wins — this is where your uploads plug in.
    //    Accepts: product.image, product.img, product.photo, product.imageUrl
    const explicit = product.image || product.img || product.photo || product.imageUrl;
    if (explicit && typeof explicit === "string" && explicit.trim()) {
      const trimmed = explicit.trim();
      // Already a full path or URL? Return as-is (encoded).
      if (/^(https?:)?\/\//.test(trimmed) || trimmed.startsWith("data:")) return trimmed;
      if (trimmed.startsWith("assets/")) return encodeURI(trimmed);
      // Bare filename — assume it lives in assets/products/
      return IMG(trimmed);
    }
    // 2) Keyword fallback keeps existing catalogue working without extra config
    const name = (product.name || "") + " " + (product.category || "");
    for (const [re, path] of imageRules) {
      if (re.test(name)) return path;
    }
    return CAT_IMG[product.category] || PLACEHOLDER;
  }

  // Expose for debugging / tooling
  if (typeof window !== "undefined") {
    window.MTEK_IMG = { IMG, CAT_IMG, PLACEHOLDER, resolveImage };
  }

  /* ---------------------------------------------------------------
     2. Elements
  --------------------------------------------------------------- */
  const productGrid = document.getElementById("productGrid");
  const topPicksTrack = document.querySelector(".top-picks-track");
  const categoryFilters = document.getElementById("categoryFilters");
  const searchInput = document.getElementById("productSearch");
  const sortSelect = document.getElementById("sortSelect");
  const resultsCount = document.getElementById("resultsCount");

  const cartDrawer = document.querySelector(".cart-drawer");
  const cartBackdrop = document.querySelector(".cart-drawer-backdrop");
  const openCartButtons = document.querySelectorAll(".open-cart, .cart-toggle");
  const closeCartButton = document.querySelector(".cart-close");
  const cartItemsContainer = document.querySelector(".cart-items");
  const cartTotalEl = document.getElementById("cartTotal");
  const cartCountEls = document.querySelectorAll(".cart-count");

  const checkoutWhatsAppBtn = document.getElementById("checkoutWhatsApp");
  const checkoutEmailBtn = document.getElementById("checkoutEmail");
  const customerNameInput = document.getElementById("customerName");
  const customerPhoneInput = document.getElementById("customerPhone");
  const customerAddressInput = document.getElementById("customerAddress");
  const customerNoteInput = document.getElementById("customerNote");
  const clearCartBtn = document.getElementById("clearCart");

  const topPicksPrev = document.querySelector(".top-picks-prev");
  const topPicksNext = document.querySelector(".top-picks-next");

  const modalBackdrop = document.querySelector(".modal-backdrop");
  const productModal = document.querySelector(".product-modal");
  const modalClose = document.querySelector(".modal-close");
  const modalBody = document.getElementById("modalBody");

  /* ---------------------------------------------------------------
     3. State
  --------------------------------------------------------------- */
  const urlParams = new URLSearchParams(window.location.search);
  let currentCategory = urlParams.get("category") || "All";
  if (!["All", "Fire", "Safety", "Security", "Solar", "Home Automation, Alarm & Surveillance"].includes(currentCategory)) {
    currentCategory = "All";
  }
  let searchQuery = "";
  let sortMode = "featured";
  let cart = loadCart();
  let modalQty = 1;
  let activeModalProduct = null;

  const whatsappNumber = "2348033498452";
  const orderEmail = "mtekfiresafetyltd@gmail.com";

  /* ---------------------------------------------------------------
     4. Helpers
  --------------------------------------------------------------- */
  function formatNaira(amount) {
    if (amount === null || amount === undefined || isNaN(amount) || amount <= 0) return "Price on request";
    return "₦" + amount.toLocaleString("en-NG");
  }

  function saveCart() {
    localStorage.setItem("mtekCart", JSON.stringify(cart));
  }

  function loadCart() {
    try {
      const stored = localStorage.getItem("mtekCart");
      return stored ? JSON.parse(stored) : [];
    } catch {
      return [];
    }
  }

  function toast(message) {
    let el = document.querySelector(".toast");
    if (!el) {
      el = document.createElement("div");
      el.className = "toast";
      el.innerHTML =
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 6L9 17l-5-5" stroke-linecap="round" stroke-linejoin="round"/></svg><span></span>';
      document.body.appendChild(el);
    }
    el.querySelector("span").textContent = message;
    el.classList.add("show");
    clearTimeout(el._t);
    el._t = setTimeout(() => el.classList.remove("show"), 2600);
  }

  function categoryCounts() {
    const counts = { All: products.length };
    products.forEach((p) => {
      counts[p.category] = (counts[p.category] || 0) + 1;
    });
    return counts;
  }

  function getFilteredProducts() {
    let list = products.filter((p) => {
      const matchCategory = currentCategory === "All" || p.category === currentCategory;
      const matchSearch =
        !searchQuery ||
        p.name.toLowerCase().includes(searchQuery) ||
        (p.description || "").toLowerCase().includes(searchQuery);
      return matchCategory && matchSearch;
    });

    switch (sortMode) {
      case "price-asc":
        list = list.slice().sort((a, b) => (a.price || 0) - (b.price || 0));
        break;
      case "price-desc":
        list = list.slice().sort((a, b) => (b.price || 0) - (a.price || 0));
        break;
      case "name":
        list = list.slice().sort((a, b) => a.name.localeCompare(b.name));
        break;
      default:
        list = list.slice().sort((a, b) => Number(b.featured || 0) - Number(a.featured || 0));
    }
    return list;
  }

  function productCardHTML(p) {
    return `
      <article class="product-card reveal in-view" data-id="${p.id}">
        <div class="product-card-media">
          ${p.featured ? '<span class="product-card-badge">Featured</span>' : ""}
          <img src="${resolveImage(p)}" alt="${p.name}" loading="lazy" onerror="this.onerror=null;this.src=CAT_IMG[p.category]||PLACEHOLDER">
        </div>
        <div class="product-card-body">
          <span class="product-card-category">${p.category}</span>
          <h3 class="product-card-title">${p.name}</h3>
          <div class="product-card-price">${formatNaira(p.price)}</div>
          <p class="product-card-desc">${p.description || ""}</p>
          <div class="product-card-footer">
            <button class="btn btn-primary add-to-cart" data-id="${p.id}">
              Add to Cart
            </button>
            <button class="btn-icon quick-view" data-id="${p.id}" title="Quick view" aria-label="Quick view">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7-11-7-11-7z"/><circle cx="12" cy="12" r="3"/></svg>
            </button>
          </div>
        </div>
      </article>
    `;
  }

  /* ---------------------------------------------------------------
     5. Rendering
  --------------------------------------------------------------- */
  function renderCategoryChips() {
    if (!categoryFilters) return;
    const counts = categoryCounts();
    const cats = [
      ["All", "All"],
      ["Fire", "Fire"],
      ["Safety", "Safety"],
      ["Security", "Security"],
      ["Solar", "Solar"],
      ["Home Automation, Alarm & Surveillance", "Home Automation, Alarm &amp; Surveillance"],
    ];
    categoryFilters.innerHTML = cats
      .map(
        ([value, label]) => `
        <button type="button" class="chip ${currentCategory === value ? "chip-active" : ""}" data-category="${value}">
          ${label}<span class="chip-count">${counts[value] || 0}</span>
        </button>`
      )
      .join("");
  }

  function renderProducts() {
    if (!productGrid) return;
    const list = getFilteredProducts();

    if (resultsCount) {
      resultsCount.textContent = `${list.length} product${list.length === 1 ? "" : "s"}${
        currentCategory !== "All" ? " in " + currentCategory : ""
      }`;
    }

    if (!list.length) {
      productGrid.innerHTML = `
        <div class="no-results">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.35-4.35" stroke-linecap="round"/><path d="M8 11h6M11 8v6" stroke-linecap="round"/></svg>
          <h3>No products found</h3>
          <p>Try a different search term or category.</p>
        </div>`;
      return;
    }

    productGrid.innerHTML = list.map(productCardHTML).join("");
  }

  function renderTopPicks() {
    if (!topPicksTrack) return;
    const topPicks = products.filter((p) => p.featured).slice(0, 12);
    topPicksTrack.innerHTML = topPicks
      .map(
        (p) => `
        <article class="top-pick-card" data-id="${p.id}">
          <img src="${resolveImage(p)}" alt="${p.name}" loading="lazy" onerror="this.onerror=null;this.src=CAT_IMG[p.category]||PLACEHOLDER">
          <div class="top-pick-body">
            <h3 class="top-pick-title">${p.name}</h3>
            <div class="top-pick-price">${formatNaira(p.price)}</div>
            <p>${p.description || ""}</p>
            <button class="btn btn-primary btn-sm add-to-cart" data-id="${p.id}">Add to Cart</button>
          </div>
        </article>`
      )
      .join("");
  }

  function renderCart() {
    if (!cartItemsContainer || !cartTotalEl) return;

    if (!cart.length) {
      cartItemsContainer.innerHTML = `
        <div class="cart-empty">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="9" cy="21" r="1.5"/><circle cx="19" cy="21" r="1.5"/><path d="M2.5 3h2l2.4 12.2a1.5 1.5 0 001.5 1.3h8.9a1.5 1.5 0 001.5-1.2L21 7H6" stroke-linecap="round" stroke-linejoin="round"/></svg>
          <p>Your cart is empty.<br>Browse the catalogue and add items to get started.</p>
          <a href="#catalog" class="btn btn-primary btn-sm mt-2">Browse Products</a>
        </div>`;
      cartTotalEl.textContent = "₦0";
      cartCountEls.forEach((el) => (el.textContent = "0"));
      return;
    }

    let total = 0;
    const html = cart
      .map((item) => {
        const lineTotal = (item.price || 0) * item.qty;
        total += lineTotal;
        return `
          <div class="cart-item" data-id="${item.id}">
            <img src="${item.image}" alt="${item.name}" onerror="this.onerror=null;this.src=PLACEHOLDER">
            <div class="cart-item-details">
              <p class="cart-item-title">${item.name}</p>
              <p class="cart-item-meta">${formatNaira(item.price)} × ${item.qty}</p>
            </div>
            <div class="cart-item-actions">
              <div class="cart-qty-controls">
                <button class="cart-qty-btn cart-qty-dec" type="button" aria-label="Decrease quantity">−</button>
                <span class="cart-qty-value">${item.qty}</span>
                <button class="cart-qty-btn cart-qty-inc" type="button" aria-label="Increase quantity">+</button>
              </div>
              <button class="cart-remove-btn" type="button">Remove</button>
            </div>
          </div>`;
      })
      .join("");

    cartItemsContainer.innerHTML = html;
    cartTotalEl.textContent = formatNaira(total);
    const count = cart.reduce((sum, i) => sum + i.qty, 0);
    cartCountEls.forEach((el) => {
      const prev = parseInt(el.textContent, 10) || 0;
      el.textContent = String(count);
      if (count > prev && el.classList.contains("cart-count-badge")) {
        el.classList.remove("pop");
        void el.offsetWidth;
        el.classList.add("pop");
      }
    });
  }

  /* ---------------------------------------------------------------
     6. Product modal
  --------------------------------------------------------------- */
  function openModal(productId) {
    const p = products.find((x) => x.id === productId);
    if (!p || !modalBody || !productModal || !modalBackdrop) return;
    activeModalProduct = p;
    modalQty = 1;
    modalBody.innerHTML = `
      <div class="modal-media">
        <img src="${resolveImage(p)}" alt="${p.name}" onerror="this.onerror=null;this.src=CAT_IMG[p.category]||PLACEHOLDER">
      </div>
      <div class="modal-info">
        <span class="product-card-category">${p.category}</span>
        <h2>${p.name}</h2>
        <div class="modal-price">${formatNaira(p.price)}</div>
        <p class="modal-desc">${p.description || "Please contact us for full specifications and the best price for this item."}</p>
        <div class="modal-meta">
          <div><span>Product code</span><strong>${p.id}</strong></div>
          <div><span>Availability</span><strong>In stock — confirm by phone</strong></div>
          <div><span>Delivery</span><strong>Nationwide (Nigeria)</strong></div>
        </div>
        <div class="qty-row">
          <label for="modalQty">Quantity</label>
          <div class="qty-controls">
            <button type="button" data-qty="-1" aria-label="Decrease quantity">−</button>
            <span class="qty-value">1</span>
            <button type="button" data-qty="1" aria-label="Increase quantity">+</button>
          </div>
        </div>
        <div class="modal-actions">
          <button class="btn btn-primary" id="modalAddCart">Add to Cart</button>
          <a class="btn btn-whatsapp" id="modalWhatsApp" target="_blank" rel="noopener noreferrer">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M17.5 14.4c-.3-.15-1.76-.87-2.03-.97-.27-.1-.47-.15-.67.15-.2.3-.77.97-.94 1.17-.17.2-.35.22-.65.07-.3-.15-1.26-.46-2.4-1.48-.89-.79-1.49-1.77-1.66-2.07-.17-.3-.02-.46.13-.61.14-.13.3-.35.45-.52.15-.17.2-.3.3-.5.1-.2.05-.37-.02-.52-.08-.15-.67-1.62-.92-2.22-.24-.58-.49-.5-.67-.51h-.57c-.2 0-.52.07-.8.37-.27.3-1.04 1.02-1.04 2.5 0 1.47 1.07 2.9 1.22 3.1.15.2 2.1 3.2 5.1 4.49.71.31 1.27.49 1.7.63.72.23 1.37.2 1.88.12.58-.09 1.76-.72 2.01-1.41.25-.7.25-1.29.17-1.41-.07-.13-.27-.2-.57-.35zM12.05 21.79h-.01a9.87 9.87 0 01-5.03-1.38l-.36-.21-3.74.98 1-3.65-.24-.37a9.85 9.85 0 01-1.51-5.26c0-5.45 4.44-9.88 9.9-9.88a9.83 9.83 0 019.88 9.89c0 5.45-4.44 9.87-9.89 9.87zm8.42-18.3A11.82 11.82 0 0012.05 0C5.5 0 .16 5.33.16 11.89c0 2.1.55 4.14 1.59 5.95L.06 24l6.3-1.65a11.9 11.9 0 005.68 1.45h.01c6.55 0 11.89-5.34 11.89-11.89 0-3.18-1.24-6.16-3.47-8.42z"/></svg>
            Order on WhatsApp
          </a>
        </div>
      </div>`;

    productModal.classList.add("open");
    modalBackdrop.classList.add("visible");
    document.body.classList.add("no-scroll");

    const qtyValue = modalBody.querySelector(".qty-value");
    modalBody.querySelectorAll("[data-qty]").forEach((btn) => {
      btn.addEventListener("click", () => {
        modalQty = Math.max(1, modalQty + Number(btn.getAttribute("data-qty")));
        qtyValue.textContent = modalQty;
      });
    });
    modalBody.querySelector("#modalAddCart").addEventListener("click", () => {
      for (let i = 0; i < modalQty; i++) addToCart(p.id, true);
      toast("Added to cart — " + p.name);
    });
    const wa = modalBody.querySelector("#modalWhatsApp");
    const msg = `Hello M-Tek Fire & Safety! I'm interested in: ${p.name} (${p.id})${p.price ? " at " + formatNaira(p.price) : ""} — quantity ${modalQty}. Please share availability and delivery options.`;
    wa.href = `https://wa.me/${whatsappNumber}?text=${encodeURIComponent(msg)}`;
  }

  function closeModal() {
    if (!productModal || !modalBackdrop) return;
    productModal.classList.remove("open");
    modalBackdrop.classList.remove("visible");
    document.body.classList.remove("no-scroll");
  }

  /* ---------------------------------------------------------------
     7. Cart operations
  --------------------------------------------------------------- */
  function addToCart(productId, silent) {
    const product = products.find((p) => p.id === productId);
    if (!product) return;
    const existing = cart.find((item) => item.id === productId);
    if (existing) {
      existing.qty += 1;
    } else {
      cart.push({
        id: product.id,
        name: product.name,
        price: product.price,
        image: resolveImage(product),
        qty: 1,
      });
    }
    saveCart();
    renderCart();
    if (!silent) {
      toast("Added to cart — " + product.name);
      openCart();
    }
  }

  function updateCartQty(productId, delta) {
    const item = cart.find((i) => i.id === productId);
    if (!item) return;
    item.qty += delta;
    if (item.qty <= 0) cart = cart.filter((i) => i.id !== productId);
    saveCart();
    renderCart();
  }

  function removeCartItem(productId) {
    cart = cart.filter((i) => i.id !== productId);
    saveCart();
    renderCart();
  }

  /* ---------------------------------------------------------------
     8. Events — filters, search, sort
  --------------------------------------------------------------- */
  if (categoryFilters) {
    categoryFilters.addEventListener("click", (e) => {
      const btn = e.target.closest(".chip");
      if (!btn) return;
      currentCategory = btn.getAttribute("data-category");
      categoryFilters.querySelectorAll(".chip").forEach((c) => c.classList.remove("chip-active"));
      btn.classList.add("chip-active");
      renderProducts();
      if (history.replaceState) {
        const url = new URL(window.location);
        if (currentCategory === "All") url.searchParams.delete("category");
        else url.searchParams.set("category", currentCategory);
        history.replaceState(null, "", url);
      }
    });
  }

  if (searchInput) {
    searchInput.addEventListener("input", () => {
      searchQuery = searchInput.value.trim().toLowerCase();
      renderProducts();
    });
  }

  if (sortSelect) {
    sortSelect.addEventListener("change", () => {
      sortMode = sortSelect.value;
      renderProducts();
    });
  }

  /* ---------------------------------------------------------------
     9. Events — add to cart / quick view (delegated)
  --------------------------------------------------------------- */
  if (productGrid) {
    productGrid.addEventListener("click", (e) => {
      const addBtn = e.target.closest(".add-to-cart");
      if (addBtn) return addToCart(addBtn.getAttribute("data-id"));
      const viewBtn = e.target.closest(".quick-view");
      if (viewBtn) return openModal(viewBtn.getAttribute("data-id"));
      const card = e.target.closest(".product-card");
      if (card && e.target.closest(".product-card-media")) openModal(card.getAttribute("data-id"));
    });
  }

  if (topPicksTrack) {
    topPicksTrack.addEventListener("click", (e) => {
      const btn = e.target.closest(".add-to-cart");
      if (!btn) return;
      addToCart(btn.getAttribute("data-id"));
    });
  }

  /* ---------------------------------------------------------------
     10. Cart drawer open/close
  --------------------------------------------------------------- */
  function openCart() {
    if (!cartDrawer || !cartBackdrop) return;
    cartDrawer.classList.add("open");
    cartBackdrop.classList.add("visible");
    document.body.classList.add("no-scroll");
  }

  function closeCart() {
    if (!cartDrawer || !cartBackdrop) return;
    cartDrawer.classList.remove("open");
    cartBackdrop.classList.remove("visible");
    document.body.classList.remove("no-scroll");
  }

  if (openCartButtons.length && cartDrawer && cartBackdrop) {
    openCartButtons.forEach((btn) =>
      btn.addEventListener("click", (e) => {
        e.preventDefault();
        openCart();
      })
    );
    cartBackdrop.addEventListener("click", closeCart);
  }
  if (closeCartButton) closeCartButton.addEventListener("click", closeCart);

  if (cartItemsContainer) {
    cartItemsContainer.addEventListener("click", (e) => {
      const itemEl = e.target.closest(".cart-item");
      if (!itemEl) return;
      const id = itemEl.getAttribute("data-id");
      if (e.target.classList.contains("cart-qty-inc")) updateCartQty(id, 1);
      else if (e.target.classList.contains("cart-qty-dec")) updateCartQty(id, -1);
      else if (e.target.classList.contains("cart-remove-btn")) removeCartItem(id);
    });
  }

  /* ---------------------------------------------------------------
     11. Modal events
  --------------------------------------------------------------- */
  if (modalClose) modalClose.addEventListener("click", closeModal);
  if (modalBackdrop) modalBackdrop.addEventListener("click", closeModal);
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
      closeModal();
      closeCart();
    }
  });

  /* ---------------------------------------------------------------
     12. Top picks carousel
  --------------------------------------------------------------- */
  if (topPicksTrack && topPicksPrev && topPicksNext) {
    const step = () => topPicksTrack.querySelector(".top-pick-card")?.offsetWidth + 22 || 320;
    topPicksPrev.addEventListener("click", () => topPicksTrack.scrollBy({ left: -step(), behavior: "smooth" }));
    topPicksNext.addEventListener("click", () => topPicksTrack.scrollBy({ left: step(), behavior: "smooth" }));
  }

  /* ---------------------------------------------------------------
     13. Checkout (WhatsApp & Email) + clear cart
  --------------------------------------------------------------- */
  function buildOrderSummary() {
    if (!cart.length) return "";
    let text = "M-Tek Fire & Safety Ltd — Online Order\n\n";
    text += "ITEMS:\n";
    cart.forEach((item, index) => {
      const lineTotal = (item.price || 0) * item.qty;
      text += `${index + 1}. ${item.name} (x${item.qty}) — ${formatNaira(item.price)} each, ${formatNaira(lineTotal)} total\n`;
    });
    const total = cart.reduce((sum, i) => sum + (i.price || 0) * i.qty, 0);
    text += `\nSubtotal: ${formatNaira(total)}\n`;
    text += "Note: prices are indicative; final confirmation follows our review.\n\n";
    text += "CUSTOMER DETAILS:\n";
    text += `Name: ${customerNameInput.value.trim()}\n`;
    text += `Phone: ${customerPhoneInput.value.trim()}\n`;
    text += `Address: ${customerAddressInput.value.trim()}\n`;
    const note = customerNoteInput.value.trim();
    if (note) text += `Note: ${note}\n`;
    return text;
  }

  function validateCustomerForm() {
    if (!cart.length) {
      toast("Your cart is empty — add at least one product first.");
      return false;
    }
    if (!customerNameInput.value.trim()) {
      customerNameInput.focus();
      toast("Please enter your name.");
      return false;
    }
    if (!customerPhoneInput.value.trim()) {
      customerPhoneInput.focus();
      toast("Please enter your phone number.");
      return false;
    }
    if (!customerAddressInput.value.trim()) {
      customerAddressInput.focus();
      toast("Please enter your delivery address.");
      return false;
    }
    return true;
  }

  if (checkoutWhatsAppBtn) {
    checkoutWhatsAppBtn.addEventListener("click", () => {
      if (!validateCustomerForm()) return;
      const url = `https://wa.me/${whatsappNumber}?text=${encodeURIComponent(buildOrderSummary())}`;
      window.open(url, "_blank");
    });
  }

  if (checkoutEmailBtn) {
    checkoutEmailBtn.addEventListener("click", () => {
      if (!validateCustomerForm()) return;
      const subject = encodeURIComponent("New Order – M-Tek Online Shop");
      const body = encodeURIComponent(buildOrderSummary());
      window.location.href = `mailto:${orderEmail}?subject=${subject}&body=${body}`;
    });
  }

  if (clearCartBtn) {
    clearCartBtn.addEventListener("click", () => {
      if (!cart.length) {
        toast("Your cart is already empty.");
        return;
      }
      if (confirm("Clear all items from your cart?")) {
        cart = [];
        saveCart();
        renderCart();
        toast("Cart cleared.");
      }
    });
  }

  /* ---------------------------------------------------------------
     14. Initial render
  --------------------------------------------------------------- */
  renderCategoryChips();
  renderTopPicks();
  renderProducts();
  renderCart();
  if (sortSelect) sortSelect.value = sortMode;

  // Scroll to catalog when deep-linked with a category
  if (urlParams.get("category") && document.getElementById("catalog")) {
    setTimeout(() => {
      const el = document.getElementById("catalog");
      if (el && typeof el.scrollIntoView === "function") {
        el.scrollIntoView({ behavior: "smooth" });
      }
    }, 120);
  }
});
