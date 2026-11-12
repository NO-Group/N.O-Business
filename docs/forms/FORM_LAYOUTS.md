# M-Tek Corporate Forms — Exact Layout Transcription

Source: owner's photos of the physical carbon-copy books (Aug 2026). These are the
authoritative layouts for the PDF painters (SPEC §12, Phase A). Items marked ⚠️ need
owner confirmation before final print styling.

---

## 1. PAYMENT RECEIPT — pre-printed serial `No: 2131` (landscape)

**Header (full width):**
- Logo (round, "M-TEK FIRE & SAFETY LIMITED", RC: 1082534) + wordmark **M-TEK FIRE & SAFETY LTD.**
- Services line: `*Sales *Supplies *Installations *Refilling *Maintenance *Training *Consultancy on`
- FIRE EQUIPMENT: FM 200, Fire Extinguishers, Fire Alarm Systems, Fire Hose Reels, Fire Hydrants, Water Sprinkler, Flame Fighting Hoses, Fire Tenders, Fire Proof Safes etc
- SAFETY EQUIPMENT: Chemical Masks, Carbon Cones, High Visibility Jackets, Breathing Apparatus, Safety Boots, Hand Gloves, Traffic Baton etc.
- SECURITY EQUIPMENT: Burglar Alarms, Metal Detectors, Bomb Detectors, Under Car Search Mirror, Motion Detectors, Security Personnel Kits etc
- SOLAR EQUIPMENT: Inverters, Solar Panels, Deep Cycle Batteries, Charge Controllers etc
- Right block (blue strip): **Kaduna I Office:** YY12 Kazure Road, by Lagos Street Round About, Kaduna. **Tel:** 08033489452, 08055922452 **E-mail:** mtekfiresafetyltd@gmail.com **Website:** www.mtekLtd.com.ng

**Identity block:**
- Red box: **IRN:** ________ + red banner **PAYMENT RECEIPT**
- Right: **No:** `2131` (pre-printed serial) · **Date:** ________

**Customer box (left, bordered):** Name ____ · Address ____ (3 lines) · Phone No. ____

**Body (two columns):**
- Left bordered box: **The Sum of** ____________ (3 ruled lines — amount in words)
- Right bordered box: **Being Payment for** ____________ (2 ruled lines)

**Payment method grid (2×2, bordered, each with a ruled line):**
| Cash ______ | Cheque ______ |
| Transfer ______ | POS ______ |

**Sign-off boxes:** `For: M-TEK FIRE & SAFETY LTD` ______ · `For: CUSTOMER'S/CLIENT` ______

**Disclaimer (exact, 2 lines):**
> No guarantee cover on tested goods and services. Purchased tested goods and services cannot be returned.
> We bear no liability on part paid and abandoned goods. This document is invalid without stamp and seal of this company.

---

## 2. MILS — MAINTENANCE INFORMATION LOG SHEET — pre-printed `MILS No: 925` (portrait, blue)

**Header:** logo (RC: 1082534) + services incl. `*Refilling *Maintenance *Training *Consultancy *Installation *Sales`
- **HEAD OFFICE:** YY12, Kazaure Road, By Lagos Street Round About, Kaduna. Tel: 08033489452
- **BRANCH OFFICE:** Plot 45, Sir Patrick Ibrahim Yakowa Way By Milton School, Kamazou Kaduna. 08170577595
- E-mail: mtekfiresafetyltd@gmail.com · Website: www.mtekLtd.com.ng

**Title (red banner):** MAINTENANCE INFORMATION LOG SHEET · **MILS No:** `925`

**Top field row:** Entry Date | Collection Date | Next Service Date | Invoice No | Receipt No | LPO NO.

**SECTION A — DESCRIPTION:** (weight grid)
| Description | Qty | Rate | Amount |
|---|---|---|---|
| 1kg | | | |
| 2kg | | | |
| 3kg | | | |
| 5kg | | | |
| 6kg | | | |
| 9kg | | | |
| 12kg | | | |
| 25kg | | | |
| 50kg | | | |
| 75kg | | | |

**SECTION B — REPLACEMENT:** (red heading) — component rows, each with 3 columns (qty/rate/amount):
Nipple · Horn · Hose · Manometre · Valve · Strap · Label · Lever · **Seal** · Powder · Pull Pin · Cartridge
✅ **Owner-confirmed.** 12 rows including "Seal" (blueprint's 11-item list updated to match the physical form).

**Customer block (left, ruled lines):** Customer's Name ____ · Address ____ · Phone Number ____ · Bill in words ____

**Summary boxes (right column, stacked):** VAT | Grand Total | Advance Payment | Balance Total

**Footer assent blocks:** Prepared by: ____ · APPROVED by: ____ · Customer's Assent: ____ · Collector's Assent: ____

**Caution (fine print — ✅ owner-confirmed wording, 2026-08-29):**
> Caution: Payment can only commence upon the payment of at least 50% value of the maintenance charges.
> No equipment is collected for repair before payment. Expired/Unserviceable old equipment should be
> exchanged with new ones after the expiration of the collection date. Goods left 3 months after will be
> considered as abandoned goods and the company shall bear no liability on any abandoned equipment.

---

## 3. SALES INVOICE — pre-printed `No: 4335` (portrait)

**Header:** same corporate header as receipt (Kaduna I Office block).

**Document-type checkbox cluster (2 rows):**
| **MILS No:** [ ] | **RECEIPT NO:** [ ] | **WAY BILL** [ ] |
| **PRO-FORMER** [ ] | **SERVICE INVOICE** [ ] | **SALES INVOICE** [ ] |

✅ "PRO-FORMER" kept exactly as printed (owner-confirmed).

**No:** `4335` · Fields: Name ____ · Address ____ · Phone No ____ · Date ____ · L.P.O. No ____

**Itemised ledger (blue header band):**
| S/NO | DESCRIPTION | QTY | RATE | AMOUNT# | K |
(~20 ruled rows — AMOUNT is split: naira (#/₦) + kobo (K) columns)

**Summary:** **7.5% VAT** ____ · **TOTAL** ____ · **Amount in words:** __________ ONLY

**Sign-off:** Prepared by: ____ · Approved by: ____ · Customer/Client ____

**Disclaimers (exact):**
> No guarantee cover on tested goods and services. We bear no liability on part paid and abandoned goods.
> This document is invalid without stamp and seal of this company.

---

## System implications (added to SPEC §12)

1. **Serials are pre-printed** on the books (`2131`, `925`, `4335`) → the app's serial counter
   service must be **seedable**: Admin sets each counter to the current book number so digital
   and paper serials continue in sequence without collision.
2. Weight classes fixed: **1, 2, 3, 5, 6, 9, 12, 25, 50, 75 kg** (10 classes).
3. MILS components fixed: **12** (incl. **Seal**).
4. Invoice amount column is **dual (₦ / K)** — kobo precision supported.
5. Receipt method grid: **Cash / Cheque / Transfer / POS** (matches PaymentMethod incl. cheque).
6. IRN, LPO No, MILS/Receipt cross-references become first-class stored fields (already in §12.2).

---

## OWNER DECISIONS (2026-08-29)

1. **Watermarks:** all three documents AND the app UI carry a faint brand watermark
   pattern (rotated "M-TEK FIRE & SAFETY LTD." + RC micro-text), echoing the security
   background of the physical books.
2. **Consistent headers:** every document uses the FULL dual-office header
   (Head Office YY12 Kazaure Road + Branch Office Plot 45 Sir P.I. Yakowa Way).
   The receipt's old compact "Kaduna I Office" block is retired.
