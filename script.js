/* ==========================================================================
   M-TEK FIRE & SAFETY LTD — shared site behaviour
   (mobile nav, scroll spy, reveal animations, counters, lightbox, FAQ, etc.)
   ========================================================================== */

document.addEventListener("DOMContentLoaded", () => {
  /* ---------------------------------------------------------------
     1. Sticky header shadow on scroll
  --------------------------------------------------------------- */
  const header = document.querySelector(".site-header");
  const onHeaderScroll = () => {
    if (!header) return;
    header.classList.toggle("scrolled", window.scrollY > 10);
  };
  window.addEventListener("scroll", onHeaderScroll, { passive: true });
  onHeaderScroll();

  /* ---------------------------------------------------------------
     2. Mobile navigation
  --------------------------------------------------------------- */
  const menuToggle = document.querySelector(".menu-toggle");
  const mobileNav = document.querySelector(".mobile-nav");
  const backdrop = document.querySelector(".backdrop");
  const closeMobileNav = document.querySelector(".close-mobile-nav");

  if (menuToggle && mobileNav && backdrop) {
    const openNav = () => {
      mobileNav.classList.add("open");
      backdrop.classList.add("visible");
      document.body.classList.add("no-scroll");
    };
    const closeNav = () => {
      mobileNav.classList.remove("open");
      backdrop.classList.remove("visible");
      document.body.classList.remove("no-scroll");
    };
    menuToggle.addEventListener("click", openNav);
    if (closeMobileNav) closeMobileNav.addEventListener("click", closeNav);
    backdrop.addEventListener("click", closeNav);
    mobileNav.querySelectorAll("a").forEach((link) =>
      link.addEventListener("click", closeNav)
    );
  }

  /* ---------------------------------------------------------------
     3. Scroll spy — highlight active nav link (same page anchors)
  --------------------------------------------------------------- */
  const sections = document.querySelectorAll("main section[id], main div[id]");
  const navLinks = document.querySelectorAll(".main-nav .nav-link[href^='#'], .mobile-nav .nav-link[href^='#']");

  if (sections.length && navLinks.length) {
    const onSpyScroll = () => {
      let currentId = "";
      const pos = window.scrollY + 140;
      sections.forEach((section) => {
        if (pos >= section.offsetTop) currentId = section.id;
      });
      navLinks.forEach((link) => {
        const href = link.getAttribute("href");
        link.classList.toggle("active", href === `#${currentId}`);
      });
    };
    window.addEventListener("scroll", onSpyScroll, { passive: true });
    onSpyScroll();
  }

  /* ---------------------------------------------------------------
     4. Reveal-on-scroll animations
  --------------------------------------------------------------- */
  const revealEls = document.querySelectorAll(".reveal");
  if (revealEls.length) {
    if ("IntersectionObserver" in window) {
      const io = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry) => {
            if (entry.isIntersecting) {
              entry.target.classList.add("in-view");
              io.unobserve(entry.target);
            }
          });
        },
        { threshold: 0.12, rootMargin: "0px 0px -40px 0px" }
      );
      revealEls.forEach((el) => io.observe(el));
    } else {
      revealEls.forEach((el) => el.classList.add("in-view"));
    }
  }

  /* ---------------------------------------------------------------
     5. Animated counters
  --------------------------------------------------------------- */
  const counters = document.querySelectorAll("[data-count]");
  if (counters.length) {
    const animateCount = (el) => {
      const target = parseFloat(el.getAttribute("data-count"));
      const suffix = el.getAttribute("data-suffix") || "";
      const duration = 1600;
      const start = performance.now();
      const step = (now) => {
        const progress = Math.min((now - start) / duration, 1);
        const eased = 1 - Math.pow(1 - progress, 3);
        const value = Math.round(target * eased);
        el.textContent = value.toLocaleString("en-NG") + suffix;
        if (progress < 1) requestAnimationFrame(step);
        else el.textContent = target.toLocaleString("en-NG") + suffix;
      };
      requestAnimationFrame(step);
    };
    if ("IntersectionObserver" in window) {
      const cio = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry) => {
            if (entry.isIntersecting) {
              animateCount(entry.target);
              cio.unobserve(entry.target);
            }
          });
        },
        { threshold: 0.4 }
      );
      counters.forEach((el) => cio.observe(el));
    } else {
      counters.forEach((el) => animateCount(el));
    }
  }

  /* ---------------------------------------------------------------
     6. Back to top button
  --------------------------------------------------------------- */
  const toTop = document.querySelector(".back-to-top");
  if (toTop) {
    window.addEventListener("scroll", () => {
      toTop.classList.toggle("show", window.scrollY > 600);
    }, { passive: true });
    toTop.addEventListener("click", () => {
      if (typeof window.scrollTo === "function") {
        window.scrollTo({ top: 0, behavior: "smooth" });
      } else {
        window.scrollTo(0, 0);
      }
    });
  }

  /* ---------------------------------------------------------------
     7. Gallery filters + lightbox
  --------------------------------------------------------------- */
  const galleryItems = Array.from(document.querySelectorAll("[data-gallery-item]"));
  const galleryFilters = document.querySelector("[data-gallery-filters]");

  if (galleryItems.length) {
    if (galleryFilters) {
      galleryFilters.addEventListener("click", (e) => {
        const btn = e.target.closest("[data-filter]");
        if (!btn) return;
        galleryFilters
          .querySelectorAll("[data-filter]")
          .forEach((b) => b.classList.remove("chip-active"));
        btn.classList.add("chip-active");
        const filter = btn.getAttribute("data-filter");
        galleryItems.forEach((item) => {
          const cats = (item.getAttribute("data-categories") || "").split(" ");
          item.classList.toggle("hidden", !(filter === "all" || cats.includes(filter)));
        });
      });
    }

    // Lightbox
    const lightbox = document.querySelector(".lightbox");
    const lightboxImg = lightbox ? lightbox.querySelector("img") : null;
    const lightboxCat = lightbox ? lightbox.querySelector(".lightbox-cat") : null;
    const lightboxCap = lightbox ? lightbox.querySelector(".lightbox-cap") : null;
    let currentIndex = 0;

    const visibleItems = () => galleryItems.filter((i) => !i.classList.contains("hidden"));
    const openLightbox = (index) => {
      if (!lightbox) return;
      const items = visibleItems();
      currentIndex = index;
      const item = items[currentIndex];
      const img = item.querySelector("img");
      lightboxImg.src = img.src;
      lightboxImg.alt = img.alt;
      if (lightboxCat) lightboxCat.textContent = item.getAttribute("data-category") || "";
      if (lightboxCap) lightboxCap.textContent = item.getAttribute("data-caption") || img.alt || "";
      lightbox.classList.add("open");
      document.body.classList.add("no-scroll");
    };
    const closeLightbox = () => {
      if (!lightbox) return;
      lightbox.classList.remove("open");
      document.body.classList.remove("no-scroll");
    };
    const navLightbox = (dir) => {
      const items = visibleItems();
      currentIndex = (currentIndex + dir + items.length) % items.length;
      openLightbox(currentIndex);
    };

    galleryItems.forEach((item, idx) => {
      item.addEventListener("click", () => openLightbox(idx));
    });
    const lbClose = document.querySelector(".lightbox-close");
    if (lbClose) lbClose.addEventListener("click", closeLightbox);
    if (lightbox) lightbox.addEventListener("click", (e) => {
      if (e.target === lightbox) closeLightbox();
    });
    document.addEventListener("keydown", (e) => {
      if (!lightbox || !lightbox.classList.contains("open")) return;
      if (e.key === "Escape") closeLightbox();
      if (e.key === "ArrowRight") navLightbox(1);
      if (e.key === "ArrowLeft") navLightbox(-1);
    });
    const lbPrev = document.querySelector(".lightbox-prev");
    const lbNext = document.querySelector(".lightbox-next");
    if (lbPrev) lbPrev.addEventListener("click", (e) => { e.stopPropagation(); navLightbox(-1); });
    if (lbNext) lbNext.addEventListener("click", (e) => { e.stopPropagation(); navLightbox(1); });
  }

  /* ---------------------------------------------------------------
     8. FAQ accordion
  --------------------------------------------------------------- */
  const faqItems = document.querySelectorAll(".faq-item");
  if (faqItems.length) {
    faqItems.forEach((item) => {
      const q = item.querySelector(".faq-q");
      const a = item.querySelector(".faq-a");
      if (!q || !a) return;
      q.addEventListener("click", () => {
        const isOpen = item.classList.contains("open");
        faqItems.forEach((other) => {
          other.classList.remove("open");
          const otherA = other.querySelector(".faq-a");
          if (otherA) otherA.style.maxHeight = null;
        });
        if (!isOpen) {
          item.classList.add("open");
          a.style.maxHeight = a.scrollHeight + "px";
        }
      });
    });
  }

  /* ---------------------------------------------------------------
     9. Footer year
  --------------------------------------------------------------- */
  document.querySelectorAll("[data-year]").forEach((el) => {
    el.textContent = new Date().getFullYear();
  });

  /* ---------------------------------------------------------------
     10. Legal TOC scroll spy
  --------------------------------------------------------------- */
  const legalSections = document.querySelectorAll(".legal-section[id]");
  const legalTocLinks = document.querySelectorAll(".legal-toc-list a[href^='#']");
  if (legalSections.length && legalTocLinks.length) {
    const onLegalScroll = () => {
      let currentId = "";
      const pos = window.scrollY + 160;
      legalSections.forEach((section) => {
        if (pos >= section.offsetTop) currentId = section.id;
      });
      if (!currentId && legalSections[0]) {
        currentId = legalSections[0].id;
      }
      legalTocLinks.forEach((link) => {
        const href = link.getAttribute("href");
        link.classList.toggle("active", href === `#${currentId}`);
      });
    };
    window.addEventListener("scroll", onLegalScroll, { passive: true });
    onLegalScroll();
  }
});
