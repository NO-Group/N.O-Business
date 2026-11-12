// M-Tek Fire & Safety Ltd — product catalogue
// Data only: prices are indicative in Naira (₦). To update the catalogue,
// edit this file — no other code changes are required.
//
// Each product has: id, name, category, price (₦), description, featured, image
//   - price: 0 or omit for "Price on request"
//   - featured: true shows in Shop "Top Picks" carousel
//   - image: optional path to product photo in assets/products/
//            Example: image: "assets/products/DCP 6kg Bajik I.jpg"
//            When image is "" or omitted, shop.js auto-picks a sensible
//            placeholder based on product name/category. Once you upload
//            a new photo to assets/products/, just set image to that path
//            — use forward slashes, keep spaces/parentheses as-is.
//            Supported aliases: image, img, photo, imageUrl
//   - categories: "Fire" | "Safety" | "Security" | "Solar" | "Home Automation, Alarm & Surveillance"
//   - To add a new product, copy a block and fill all fields.
//   - Filenames with spaces or ( ) are handled automatically (encoded to %20).

const MTEK_PRODUCTS = [
    // FIRE 
        {
        id: "F001",
        name: "BOX FOR BREECHING INLET",
        category: "Fire",
        price: 185000,
        description: "BOX FOR BREECHING INLET \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: true
    },
        {
        id: "F002",
        name: "BOX FOR 6KG FIRE EXTINGUISHER",
        category: "Fire",
        price: 55000,
        description: "BOX FOR 6KG FIRE EXTINGUISHER \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: true
    },
        {
        id: "F003",
        name: "BOX FOR 9KG FIRE EXTINGUISHER",
        category: "Fire",
        price: 65000,
        description: "BOX FOR 9KG FIRE EXTINGUISHER \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F004",
        name: "BOX FOR FLAME FIGHTING HOSE ( BAJIK)",
        category: "Fire",
        price: 95000,
        description: "BOX FOR FLAME FIGHTING HOSE ( BAJIK) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F005",
        name: "BOX FOR FLAME FIGHTING HOSE (STANGOZ)",
        category: "Fire",
        price: 92000,
        description: "BOX FOR FLAME FIGHTING HOSE (STANGOZ) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F006",
        name: "BOX FOR FLAME FIGHTING HOSE (BRYK)",
        category: "Fire",
        price: 95000,
        description: "BOX FOR FLAME FIGHTING HOSE (BRYK) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F007",
        name: "BOX FOR FLAME FIGHTING HOSE (DOUBLE BAJIK)",
        category: "Fire",
        price: 100000,
        description: "BOX FOR FLAME FIGHTING HOSE (DOUBLE BAJIK) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F008",
        name: "BREATHING APPARATUS",
        category: "Fire",
        price: 350000,
        description: "BREATHING APPARATUS \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Auto Fire Ball.jpg",
        featured: false
    },
        {
        id: "F009",
        name: "CO2 2KG ANGUS",
        category: "Fire",
        price: 32000,
        description: "CO2 2KG ANGUS \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/CO2 5kg Fire Extinguisher.webp",
        featured: false
    },
        {
        id: "F010",
        name: "CO2 3KG BRYK I",
        category: "Fire",
        price: 40000,
        description: "CO2 3KG BRYK I \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/CO2 5kg Fire Extinguisher.webp",
        featured: false
    },
        {
        id: "F011",
        name: "CO2 3KG (BAJIK)",
        category: "Fire",
        price: 38000,
        description: "CO2 3KG (BAJIK) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/CO2 5kg Fire Extinguisher.webp",
        featured: false
    },
        {
        id: "F012",
        name: "CO2 3KG (BIZLAND I)",
        category: "Fire",
        price: 38000,
        description: "CO2 3KG (BIZLAND I) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/CO2 5kg Fire Extinguisher.webp",
        featured: true
    },
        {
        id: "F013",
        name: "CO2 3KG (STANGOZ I)",
        category: "Fire",
        price: 39500,
        description: "CO2 3KG (STANGOZ I) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/CO2 5kg Fire Extinguisher.webp",
        featured: false
    },
        {
        id: "F014",
        name: "CO2 3KG CO2 II (ANGUS)",
        category: "Fire",
        price: 35000,
        description: "CO2 3KG CO2 II (ANGUS) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/CO2 5kg Fire Extinguisher.webp",
        featured: false
    },
        {
        id: "F015",
        name: "CO2 5KG (ESTINTORE)",
        category: "Fire",
        price: 45000,
        description: "CO2 5KG (ESTINTORE) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/CO2 5kg Fire Extinguisher.webp",
        featured: false
    },
        {
        id: "F016",
        name: "CO2 5KG (CAPITAL TELL)",
        category: "Fire",
        price: 45000,
        description: "CO2 5KG (CAPITAL TELL) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/CO2 5kg Fire Extinguisher.webp",
        featured: false
    },
        {
        id: "F017",
        name: "CO2 5KG (FLAME POINT)",
        category: "Fire",
        price: 40000,
        description: "CO2 5KG (FLAME POINT) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/CO2 5kg Fire Extinguisher.webp",
        featured: false
    },
        {
        id: "F018",
        name: "CO2 5KG (BIZLAND I)",
        category: "Fire",
        price: 45000,
        description: "CO2 5KG (BIZLAND I) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/CO2 5kg Fire Extinguisher.webp",
        featured: false
    },
        {
        id: "F019",
        name: "CO2 5KG I ANGUS",
        category: "Fire",
        price: 40000,
        description: "CO2 5KG I ANGUS \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/CO2 5kg Fire Extinguisher.webp",
        featured: false
    },
        {
        id: "F020",
        name: "CO2 5KG ( BRYK)",
        category: "Fire",
        price: 52000,
        description: "CO2 5KG ( BRYK) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/CO2 5kg Fire Extinguisher.webp",
        featured: false
    },
        {
        id: "F021",
        name: "CO2 5KG BAJIK I",
        category: "Fire",
        price: 50000,
        description: "CO2 5KG BAJIK I \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/CO2 5kg Fire Extinguisher.webp",
        featured: false
    },
        {
        id: "F022",
        name: "CO2 5KG BAJIK II",
        category: "Fire",
        price: 45000,
        description: "CO2 5KG BAJIK II \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/CO2 5kg Fire Extinguisher.webp",
        featured: false
    },
        {
        id: "F023",
        name: "CO2 5KG(ANGUS II)",
        category: "Fire",
        price: 46500,
        description: "CO2 5KG(ANGUS II) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/CO2 5kg Fire Extinguisher.webp",
        featured: false
    },
        {
        id: "F024",
        name: "CO2 9KG BAJIK I",
        category: "Fire",
        price: 135000,
        description: "CO2 9KG BAJIK I \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/CO2 5kg Fire Extinguisher.webp",
        featured: true
    },
        {
        id: "F025",
        name: "CO2 9KG (ANGUS II)",
        category: "Fire",
        price: 180000,
        description: "CO2 9KG (ANGUS II) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/CO2 5kg Fire Extinguisher.webp",
        featured: false
    },
        {
        id: "F026",
        name: "CO2 25 KG (FLAMESENSE)",
        category: "Fire",
        price: 180000,
        description: "CO2 25 KG (FLAMESENSE) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/CO2 5kg Fire Extinguisher.webp",
        featured: false
    },
        {
        id: "F027",
        name: "CO2 50KG",
        category: "Fire",
        price: 250000,
        description: "CO2 50KG \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/CO2 5kg Fire Extinguisher.webp",
        featured: false
    },
        {
        id: "F028",
        name: "COUPLINE [3\"X 2\" -OUTSIDE THREAD]",
        category: "Fire",
        price: 18000,
        description: "COUPLINE [3\"X 2\" -OUTSIDE THREAD] \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F029",
        name: "COUPLINE [3\"X 2 1/2\"- INSIDE THREAD ]",
        category: "Fire",
        price: 18000,
        description: "COUPLINE [3\"X 2 1/2\"- INSIDE THREAD ] \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F030",
        name: "COUPLINE [3\"X 2 1/2\"- OUTSIDE THREAD ]",
        category: "Fire",
        price: 18000,
        description: "COUPLINE [3\"X 2 1/2\"- OUTSIDE THREAD ] \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F031",
        name: "DCP 1KG VISA",
        category: "Fire",
        price: 7000,
        description: "DCP 1KG VISA \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F032",
        name: "DCP 1KG PJV",
        category: "Fire",
        price: 7000,
        description: "DCP 1KG PJV \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F033",
        name: "DCP 1KG (ANL GOLD) /KBI GOLD",
        category: "Fire",
        price: 8000,
        description: "DCP 1KG (ANL GOLD) /KBI GOLD \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F034",
        name: "DCP 1KG ECL MULTIPURPOSE",
        category: "Fire",
        price: 5000,
        description: "DCP 1KG ECL MULTIPURPOSE \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F035",
        name: "DCP 1KG BAJIK",
        category: "Fire",
        price: 11500,
        description: "DCP 1KG BAJIK \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F036",
        name: "DCP 2KG (ECL GOLD/GOLD STAR)",
        category: "Fire",
        price: 16000,
        description: "DCP 2KG (ECL GOLD/GOLD STAR) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: true
    },
        {
        id: "F037",
        name: "DCP 2KG (BAJIK)",
        category: "Fire",
        price: 20500,
        description: "DCP 2KG (BAJIK) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F038",
        name: "DCP 3KG (BAJIK)",
        category: "Fire",
        price: 24000,
        description: "DCP 3KG (BAJIK) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F039",
        name: "DCP 6KG (BIZLAND)",
        category: "Fire",
        price: 35000,
        description: "DCP 6KG (BIZLAND) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F040",
        name: "DCP 6KG MBCI II",
        category: "Fire",
        price: 23000,
        description: "DCP 6KG MBCI II \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F041",
        name: "DCP 6KG ASI II",
        category: "Fire",
        price: 23000,
        description: "DCP 6KG ASI II \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F042",
        name: "DCP 6KG BAJIK II",
        category: "Fire",
        price: 26000,
        description: "DCP 6KG BAJIK II \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F043",
        name: "DCP 6KG AUTOMATIC FIRE EXTINGUISHER (BAJIK)",
        category: "Fire",
        price: 60000,
        description: "DCP 6KG AUTOMATIC FIRE EXTINGUISHER (BAJIK) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F044",
        name: "DCP 6KG (ANAF GROUP I)",
        category: "Fire",
        price: 30000,
        description: "DCP 6KG (ANAF GROUP I) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F045",
        name: "DCP 6KG (BRYK I)",
        category: "Fire",
        price: 26000,
        description: "DCP 6KG (BRYK I) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F046",
        name: "DCP 6KG (FIRE-KILLER I)",
        category: "Fire",
        price: 26500,
        description: "DCP 6KG (FIRE-KILLER I) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F047",
        name: "DCP 6KG ANGUS I ORIGINAL",
        category: "Fire",
        price: 50000,
        description: "DCP 6KG ANGUS I ORIGINAL \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F048",
        name: "DCP 6KG BAJIK I",
        category: "Fire",
        price: 30000,
        description: "DCP 6KG BAJIK I \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: true
    },
        {
        id: "F049",
        name: "DCP 6KG DCP I KEENSTOP",
        category: "Fire",
        price: 23000,
        description: "DCP 6KG DCP I KEENSTOP \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F050",
        name: "DCP 6KG MOUNEX II",
        category: "Fire",
        price: 27000,
        description: "DCP 6KG MOUNEX II \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F051",
        name: "DCP 6KG PJV II",
        category: "Fire",
        price: 28000,
        description: "DCP 6KG PJV II \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F052",
        name: "DCP 6KG (UMENIC II)",
        category: "Fire",
        price: 25000,
        description: "DCP 6KG (UMENIC II) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F053",
        name: "DCP 6KG ANGUS II",
        category: "Fire",
        price: 26000,
        description: "DCP 6KG ANGUS II \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F054",
        name: "DCP 6KG EXTINTORE II",
        category: "Fire",
        price: 27000,
        description: "DCP 6KG EXTINTORE II \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F055",
        name: "DCP 6KG FLAME-SENSE II",
        category: "Fire",
        price: 30000,
        description: "DCP 6KG FLAME-SENSE II \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F056",
        name: "DCP 6KG GLORIA II",
        category: "Fire",
        price: 38500,
        description: "DCP 6KG GLORIA II \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F057",
        name: "DCP 9KG KEENSTOP I",
        category: "Fire",
        price: 40000,
        description: "DCP 9KG KEENSTOP I \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F058",
        name: "DCP 9KG KABGOLD I",
        category: "Fire",
        price: 36000,
        description: "DCP 9KG KABGOLD I \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F059",
        name: "DCP 9KG EXTINTORE",
        category: "Fire",
        price: 38000,
        description: "DCP 9KG EXTINTORE \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F060",
        name: "DCP 9KG FIRE FIGHTER/UNIQUE/EVER SAFE",
        category: "Fire",
        price: 40000,
        description: "DCP 9KG FIRE FIGHTER/UNIQUE/EVER SAFE \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: true
    },
        {
        id: "F061",
        name: "DCP 9KG ANGUS I",
        category: "Fire",
        price: 50000,
        description: "DCP 9KG ANGUS I \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F062",
        name: "DCP 9KG BAJIK I",
        category: "Fire",
        price: 38000,
        description: "DCP 9KG BAJIK I \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F063",
        name: "DCP 9KG BIZLAND I",
        category: "Fire",
        price: 37500,
        description: "DCP 9KG BIZLAND I \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F064",
        name: "DCP 9KG FESCO I",
        category: "Fire",
        price: 38000,
        description: "DCP 9KG FESCO I \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F065",
        name: "DCP 9KG (BRYK) I",
        category: "Fire",
        price: 39500,
        description: "DCP 9KG (BRYK) I \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F066",
        name: "DCP 9KG (FIRE KILLER) I",
        category: "Fire",
        price: 38500,
        description: "DCP 9KG (FIRE KILLER) I \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F067",
        name: "DCP 9KG (ANGUS) II",
        category: "Fire",
        price: 36000,
        description: "DCP 9KG (ANGUS) II \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F068",
        name: "DCP 9KG (SRI) II",
        category: "Fire",
        price: 45000,
        description: "DCP 9KG (SRI) II \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F069",
        name: "DCP 9KG BAJIK II",
        category: "Fire",
        price: 40000,
        description: "DCP 9KG BAJIK II \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F070",
        name: "DCP 9KG FLAMESENCE II",
        category: "Fire",
        price: 36500,
        description: "DCP 9KG FLAMESENCE II \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F071",
        name: "DCP 12 KG M-TEK PRODUCT",
        category: "Fire",
        price: 40000,
        description: "DCP 12 KG M-TEK PRODUCT \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F072",
        name: "DCP 25KG FLAMESENSE",
        category: "Fire",
        price: 155000,
        description: "DCP 25KG FLAMESENSE \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: true
    },
        {
        id: "F073",
        name: "DCP 25KG (BAJIK) I",
        category: "Fire",
        price: 250000,
        description: "DCP 25KG (BAJIK) I \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F074",
        name: "DCP 25KG (ANGUS) II",
        category: "Fire",
        price: 150000,
        description: "DCP 25KG (ANGUS) II \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F075",
        name: "DCP 50KG ANGUS",
        category: "Fire",
        price: 250000,
        description: "DCP 50KG ANGUS \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F076",
        name: "DCP 50KG POZTAN",
        category: "Fire",
        price: 240000,
        description: "DCP 50KG POZTAN \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F077",
        name: "DCP 50KG FLAME SENSE",
        category: "Fire",
        price: 200000,
        description: "DCP 50KG FLAME SENSE \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F078",
        name: "DCP 50KG FIRE KILLER I",
        category: "Fire",
        price: 350000,
        description: "DCP 50KG FIRE KILLER I \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F079",
        name: "DCP 50KG (BAJIK) I",
        category: "Fire",
        price: 250000,
        description: "DCP 50KG (BAJIK) I \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F080",
        name: "DCP 50KG (BAJIK) I",
        category: "Fire",
        price: 200000,
        description: "DCP 50KG (BAJIK) I \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F081",
        name: "DCP (DRY CHEMICAL POWDER) KG",
        category: "Fire",
        price: 1500,
        description: "DCP (DRY CHEMICAL POWDER) KG \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F082",
        name: "FIRE STOP 1KG",
        category: "Fire",
        price: 7000,
        description: "FIRE STOP 1KG \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F083",
        name: "FIRE BALL AFO/ELIDE",
        category: "Fire",
        price: 20000,
        description: "FIRE BALL AFO/ELIDE \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Auto Fire Ball.jpg",
        featured: false
    },
        {
        id: "F084",
        name: "FIRE BLANKET (1.2 X 1.8) PLASTIC CONTAINER",
        category: "Fire",
        price: 20000,
        description: "FIRE BLANKET (1.2 X 1.8) PLASTIC CONTAINER \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: true
    },
        {
        id: "F085",
        name: "FIRE BLANKET (1X1) PLASTIC CONTAINER",
        category: "Fire",
        price: 10000,
        description: "FIRE BLANKET (1X1) PLASTIC CONTAINER \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F086",
        name: "FIRE BLANKET (1.0 X1.0) LEATHER CONTAINER",
        category: "Fire",
        price: 10000,
        description: "FIRE BLANKET (1.0 X1.0) LEATHER CONTAINER \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F087",
        name: "FIRE BLANKET (1.2X1.2) LEATHER CONTAINER",
        category: "Fire",
        price: 15000,
        description: "FIRE BLANKET (1.2X1.2) LEATHER CONTAINER \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F088",
        name: "FIRE BLANKET (1.2X1.2) PLASTIC CONTAINER",
        category: "Fire",
        price: 15000,
        description: "FIRE BLANKET (1.2X1.2) PLASTIC CONTAINER \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F089",
        name: "FIRE BLANKET (1.8 X1.8) PLASTIC CONTAINER",
        category: "Fire",
        price: 25000,
        description: "FIRE BLANKET (1.8 X1.8) PLASTIC CONTAINER \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F090",
        name: "FIRE BLANKET CHUBB (3FT X3FT)",
        category: "Fire",
        price: 25000,
        description: "FIRE BLANKET CHUBB (3FT X3FT) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F091",
        name: "FIRE BUCKET (BIG)",
        category: "Fire",
        price: 5500,
        description: "FIRE BUCKET (BIG) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F092",
        name: "FIRE BUCKET (SMALL)",
        category: "Fire",
        price: 5000,
        description: "FIRE BUCKET (SMALL) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F093",
        name: "FIRE EXTINGUISHER LABELS( DCP6&9+Co2 5&9)",
        category: "Fire",
        price: 200,
        description: "FIRE EXTINGUISHER LABELS( DCP6&9+Co2 5&9) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/CO2 5kg Fire Extinguisher.webp",
        featured: false
    },
        {
        id: "F094",
        name: "FIRE HOSE REEL [BRYK]",
        category: "Fire",
        price: 195000,
        description: "FIRE HOSE REEL [BRYK] \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/hose reel.jpg",
        featured: false
    },
        {
        id: "F095",
        name: "FIRE HOSE REEL (BAJIK)",
        category: "Fire",
        price: 185000,
        description: "FIRE HOSE REEL (BAJIK) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/hose reel.jpg",
        featured: false
    },
        {
        id: "F096",
        name: "FIRE HOSE REEL [NAFFCO]",
        category: "Fire",
        price: 350000,
        description: "FIRE HOSE REEL [NAFFCO] \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/hose reel.jpg",
        featured: true
    },
        {
        id: "F097",
        name: "FIRE HOSE REEL [STANGOZ]",
        category: "Fire",
        price: 180000,
        description: "FIRE HOSE REEL [STANGOZ] \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/hose reel.jpg",
        featured: false
    },
        {
        id: "F098",
        name: "FIRE HOSE REEL (CARBINET SFPS)",
        category: "Fire",
        price: 340000,
        description: "FIRE HOSE REEL (CARBINET SFPS) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/hose reel.jpg",
        featured: false
    },
        {
        id: "F099",
        name: "FIRE HOSE REEL AND BOX (FIRE KILLER)",
        category: "Fire",
        price: 345000,
        description: "FIRE HOSE REEL AND BOX (FIRE KILLER) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Fire Hose Reel Cabinet.jpg",
        featured: false
    },
        {
        id: "F100",
        name: "FIRE HOSE REEL AND BOX (STANGOZ)",
        category: "Fire",
        price: 365000,
        description: "FIRE HOSE REEL AND BOX (STANGOZ) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Fire Hose Reel Cabinet.jpg",
        featured: false
    },
        {
        id: "F101",
        name: "FIRE HOSE REEL AND BOX (CAPITAL TELL)",
        category: "Fire",
        price: 350000,
        description: "FIRE HOSE REEL AND BOX (CAPITAL TELL) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Fire Hose Reel Cabinet.jpg",
        featured: false
    },
        {
        id: "F102",
        name: "FIRE HOSE REEL AND BOX [BAJIK]",
        category: "Fire",
        price: 350000,
        description: "FIRE HOSE REEL AND BOX [BAJIK] \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Fire Hose Reel Cabinet.jpg",
        featured: false
    },
        {
        id: "F103",
        name: "FIRE HOSE REEL AND BOX [ANGUS]",
        category: "Fire",
        price: 400000,
        description: "FIRE HOSE REEL AND BOX [ANGUS] \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Fire Hose Reel Cabinet.jpg",
        featured: false
    },
        {
        id: "F104",
        name: "FIREMAN SUIT (BULLDOZER)",
        category: "Fire",
        price: 450000,
        description: "FIREMAN SUIT (BULLDOZER) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Overall.jpg",
        featured: false
    },
        {
        id: "F105",
        name: "FIRE TUNIC (BAJIK)",
        category: "Fire",
        price: 200000,
        description: "FIRE TUNIC (BAJIK) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F106",
        name: "FLAME FIGHTING HOSE ADAPTOR 3''X2'' MALE/FEMALE)",
        category: "Fire",
        price: 15000,
        description: "FLAME FIGHTING HOSE ADAPTOR 3''X2'' MALE/FEMALE) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F107",
        name: "FOAM 6LITRE II ANGUS",
        category: "Fire",
        price: 30000,
        description: "FOAM 6LITRE II ANGUS \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Foam 9L Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F108",
        name: "FOAM 6LITRES (MIXED BRANDS)",
        category: "Fire",
        price: 35000,
        description: "FOAM 6LITRES (MIXED BRANDS) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Foam 9L Fire Extinguisher.jpg",
        featured: true
    },
        {
        id: "F109",
        name: "FOAM 9 LITRES I ORIGINAL ANGUS",
        category: "Fire",
        price: 55000,
        description: "FOAM 9 LITRES I ORIGINAL ANGUS \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Foam 9L Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F110",
        name: "HAND CONTROL NOZZLE (METAL)",
        category: "Fire",
        price: 40000,
        description: "HAND CONTROL NOZZLE (METAL) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F111",
        name: "HAND CONTROL NOZZLE (METAL/PLASTIC)",
        category: "Fire",
        price: 27500,
        description: "HAND CONTROL NOZZLE (METAL/PLASTIC) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F112",
        name: "HANGER (U SHAPE WITH GOLDEN COLOUR)",
        category: "Fire",
        price: 1500,
        description: "HANGER (U SHAPE WITH GOLDEN COLOUR) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F113",
        name: "HANGER (L SHAPE BLACK FABRICATED )",
        category: "Fire",
        price: 1000,
        description: "HANGER (L SHAPE BLACK FABRICATED ) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F114",
        name: "HANGER (L SHAPE/SILVER/CYLINDRICAL TIP)",
        category: "Fire",
        price: 1500,
        description: "HANGER (L SHAPE/SILVER/CYLINDRICAL TIP) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F115",
        name: "HANGER (ROUND HEAD RED)",
        category: "Fire",
        price: 2000,
        description: "HANGER (ROUND HEAD RED) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F116",
        name: "HANGER (SIDE TYPE SILVER)",
        category: "Fire",
        price: 1000,
        description: "HANGER (SIDE TYPE SILVER) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F117",
        name: "HORN (2/3KG CO2 ) SHORT HORN",
        category: "Fire",
        price: 4000,
        description: "HORN (2/3KG CO2 ) SHORT HORN \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/CO2 5kg Fire Extinguisher.webp",
        featured: false
    },
        {
        id: "F118",
        name: "HORN (5KG CO2 CHINA)",
        category: "Fire",
        price: 6500,
        description: "HORN (5KG CO2 CHINA) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/CO2 5kg Fire Extinguisher.webp",
        featured: false
    },
        {
        id: "F119",
        name: "HOSE (5KG CO2 LONDON USE)",
        category: "Fire",
        price: 4500,
        description: "HOSE (5KG CO2 LONDON USE) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/CO2 5kg Fire Extinguisher.webp",
        featured: false
    },
        {
        id: "F120",
        name: "HOSE (6/9KG DCP HOSE)",
        category: "Fire",
        price: 3500,
        description: "HOSE (6/9KG DCP HOSE) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: true
    },
        {
        id: "F121",
        name: "HOSE (CANVAS WITH COMPLETE ADAPTORS)",
        category: "Fire",
        price: 70000,
        description: "HOSE (CANVAS WITH COMPLETE ADAPTORS) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F122",
        name: "HOSE (DURALINE WITH COMPLETE ADAPTORS) 1.5/30/10BAR",
        category: "Fire",
        price: 90000,
        description: "HOSE (DURALINE WITH COMPLETE ADAPTORS) 1.5/30/10BAR \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F123",
        name: "HOSE (DURALINE WITH COMPLETE ADAPTORS) 2.5 /30M/13BAR",
        category: "Fire",
        price: 169000,
        description: "HOSE (DURALINE WITH COMPLETE ADAPTORS) 2.5 /30M/13BAR \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F124",
        name: "HOSE (DURALINE WITH COMPLETE ADAPTORS) 2.5/30M/10BAR",
        category: "Fire",
        price: 105000,
        description: "HOSE (DURALINE WITH COMPLETE ADAPTORS) 2.5/30M/10BAR \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F125",
        name: "HOSE 50KG DCP",
        category: "Fire",
        price: 25000,
        description: "HOSE 50KG DCP \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F126",
        name: "HYDRANT (PILLAR/PEDESTRAIN)",
        category: "Fire",
        price: 400000,
        description: "HYDRANT (PILLAR/PEDESTRAIN) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Pillar Hydrant.jpg",
        featured: false
    },
        {
        id: "F127",
        name: "HYDRANT (UNDERGROUND AVR190809900)",
        category: "Fire",
        price: 0,
        description: "HYDRANT (UNDERGROUND AVR190809900) \u2014 Fire equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/one way pillar hydrant.jpg",
        featured: false
    },
        {
        id: "F128",
        name: "HYDRANT KEY & BAR(ALUMINIUM COLOUR) PAIR",
        category: "Fire",
        price: 0,
        description: "HYDRANT KEY & BAR(ALUMINIUM COLOUR) PAIR \u2014 Fire equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F129",
        name: "HYDRANT STAND PIPE (ALUMINIUM COLOUR)",
        category: "Fire",
        price: 0,
        description: "HYDRANT STAND PIPE (ALUMINIUM COLOUR) \u2014 Fire equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F130",
        name: "LANDING VALVE",
        category: "Fire",
        price: 95000,
        description: "LANDING VALVE \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/landing valve.jpg",
        featured: false
    },
        {
        id: "F131",
        name: "MAINTENANCE TAG (MULTIPLE COLOUR)",
        category: "Fire",
        price: 100,
        description: "MAINTENANCE TAG (MULTIPLE COLOUR) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F132",
        name: "MANOMETRE (PRESSURE GAUGE)",
        category: "Fire",
        price: 1500,
        description: "MANOMETRE (PRESSURE GAUGE) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: true
    },
        {
        id: "F133",
        name: "NIPPLE 1KG/2KG DCP",
        category: "Fire",
        price: 500,
        description: "NIPPLE 1KG/2KG DCP \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F134",
        name: "SAFETY PIN",
        category: "Fire",
        price: 200,
        description: "SAFETY PIN \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F135",
        name: "STRAP (FIRE EXTINGUISHER)",
        category: "Fire",
        price: 1000,
        description: "STRAP (FIRE EXTINGUISHER) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F136",
        name: "SPRAY JET (TRIPLE PURPOSE BRANCH)",
        category: "Fire",
        price: 70000,
        description: "SPRAY JET (TRIPLE PURPOSE BRANCH) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "F137",
        name: "SPACEMAN (AUTOMATIC FIRE EXSTINGUISHER)",
        category: "Fire",
        price: 85000,
        description: "SPACEMAN (AUTOMATIC FIRE EXSTINGUISHER) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Auto Fire Ball.jpg",
        featured: false
    },
        {
        id: "F138",
        name: "VALVE CO2 FOR: (2,3 & 5KG)",
        category: "Fire",
        price: 9000,
        description: "VALVE CO2 FOR: (2,3 & 5KG) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/CO2 5kg Fire Extinguisher.webp",
        featured: false
    },
        {
        id: "F139",
        name: "VALVE DCP 25KG/50KG",
        category: "Fire",
        price: 25000,
        description: "VALVE DCP 25KG/50KG \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F140",
        name: "VALVE DCP 25KG/50KG STEERING",
        category: "Fire",
        price: 15000,
        description: "VALVE DCP 25KG/50KG STEERING \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F141",
        name: "VALVE DCP (9KG/6KG)",
        category: "Fire",
        price: 5000,
        description: "VALVE DCP (9KG/6KG) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F142",
        name: "WATER 9LITRE I ANGUS (UK WATER H2O)",
        category: "Fire",
        price: 50000,
        description: "WATER 9LITRE I ANGUS (UK WATER H2O) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "F143",
        name: "WATER SPRINKLER HEADS 3/4",
        category: "Fire",
        price: 6000,
        description: "WATER SPRINKLER HEADS 3/4 \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/sprinkler head.jpg",
        featured: false
    },
        {
        id: "F144",
        name: "WATER SPRINKLER HEADS",
        category: "Fire",
        price: 4000,
        description: "WATER SPRINKLER HEADS \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/sprinkler head.jpg",
        featured: true
    },
        {
        id: "F145",
        name: "WATER SPRINKLER HEADS (CASING)",
        category: "Fire",
        price: 1500,
        description: "WATER SPRINKLER HEADS (CASING) \u2014 Fire equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/sprinkler head.jpg",
        featured: false
    },

    // SAFETY 
        {
        id: "S001",
        name: "AVIATION SOLAR POWERED BEACON",
        category: "Safety",
        price: 20000,
        description: "AVIATION SOLAR POWERED BEACON \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/solar bulb.jpg",
        featured: true
    },
        {
        id: "S002",
        name: "BAOFENG EARPIECE",
        category: "Safety",
        price: 3000,
        description: "BAOFENG EARPIECE \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/ear muffs.jpg",
        featured: true
    },
        {
        id: "S003",
        name: "BODY HARNESS",
        category: "Safety",
        price: 50000,
        description: "BODY HARNESS \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Overall.jpg",
        featured: false
    },
        {
        id: "S004",
        name: "CAUTION CONE (50CM)SINGLE RELECTOR NECK",
        category: "Safety",
        price: 18000,
        description: "CAUTION CONE (50CM)SINGLE RELECTOR NECK \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Muster Point Sign.jpg",
        featured: false
    },
        {
        id: "S005",
        name: "CAUTION CONE (75CM)",
        category: "Safety",
        price: 16000,
        description: "CAUTION CONE (75CM) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Muster Point Sign.jpg",
        featured: false
    },
        {
        id: "S006",
        name: "CAUTION TRIANGLE (RED PACK)",
        category: "Safety",
        price: 6000,
        description: "CAUTION TRIANGLE (RED PACK) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Muster Point Sign.jpg",
        featured: false
    },
        {
        id: "S007",
        name: "CAUTION TRIANGLE 2 In 1 (BULE PACK)",
        category: "Safety",
        price: 5000,
        description: "CAUTION TRIANGLE 2 In 1 (BULE PACK) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Muster Point Sign.jpg",
        featured: false
    },
        {
        id: "S008",
        name: "COMPLETE OVERALL",
        category: "Safety",
        price: 23000,
        description: "COMPLETE OVERALL \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Overall.jpg",
        featured: false
    },
        {
        id: "S009",
        name: "EARTH CLAMP (MUREX SAFFIRE \\500A)",
        category: "Safety",
        price: 28000,
        description: "EARTH CLAMP (MUREX SAFFIRE \\500A) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Rocklander Safety Boots.jpg",
        featured: false
    },
        {
        id: "S010",
        name: "EMERGENCY/EXIT LIGHT(WITHUOT SIGNAGE)",
        category: "Safety",
        price: 10000,
        description: "EMERGENCY/EXIT LIGHT(WITHUOT SIGNAGE) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Muster Point Sign.jpg",
        featured: false
    },
        {
        id: "S011",
        name: "EXIT SIGN (SCHRACK [LUMINOUS TYPE])",
        category: "Safety",
        price: 20000,
        description: "EXIT SIGN (SCHRACK [LUMINOUS TYPE]) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Rocklander Safety Boots.jpg",
        featured: false
    },
        {
        id: "S012",
        name: "FIRST AID BOX (BIG)",
        category: "Safety",
        price: 40000,
        description: "FIRST AID BOX (BIG) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/First Aid Box.jpg",
        featured: true
    },
        {
        id: "S013",
        name: "FIRST AID BOX (SMALL)",
        category: "Safety",
        price: 32000,
        description: "FIRST AID BOX (SMALL) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/First Aid Box.jpg",
        featured: false
    },
        {
        id: "S014",
        name: "FIRSTAID BOX (MEDIUM)",
        category: "Safety",
        price: 38000,
        description: "FIRSTAID BOX (MEDIUM) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Rocklander Safety Boots.jpg",
        featured: false
    },
        {
        id: "S015",
        name: "HANDGLOVES (FABRICKS) IN PAIRS.",
        category: "Safety",
        price: 1000,
        description: "HANDGLOVES (FABRICKS) IN PAIRS. \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Rocklander Safety Boots.jpg",
        featured: false
    },
        {
        id: "S016",
        name: "HANDGLOVES (SHORT MIXED COLOUR)",
        category: "Safety",
        price: 3500,
        description: "HANDGLOVES (SHORT MIXED COLOUR) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Rocklander Safety Boots.jpg",
        featured: false
    },
        {
        id: "S017",
        name: "HELMET (TOOLSMASTERS)",
        category: "Safety",
        price: 3000,
        description: "HELMET (TOOLSMASTERS) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/MSA Helmet (Green).jpg",
        featured: false
    },
        {
        id: "S018",
        name: "HELMET(GOLDEN GULF)",
        category: "Safety",
        price: 5000,
        description: "HELMET(GOLDEN GULF) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/MSA Helmet (Green).jpg",
        featured: false
    },
        {
        id: "S019",
        name: "HELMET(MSA) GREEN DARK, WHITE & BLULE",
        category: "Safety",
        price: 5000,
        description: "HELMET(MSA) GREEN DARK, WHITE & BLULE \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/MSA Helmet (Green).jpg",
        featured: false
    },
        {
        id: "S020",
        name: "METAL DETECTOR ( COVERED HANDLE)",
        category: "Safety",
        price: 20000,
        description: "METAL DETECTOR ( COVERED HANDLE) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/metal dectector.jpg",
        featured: false
    },
        {
        id: "S021",
        name: "METAL DETECTOR ( GROOVED HANDLE)",
        category: "Safety",
        price: 3500,
        description: "METAL DETECTOR ( GROOVED HANDLE) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/metal dectector.jpg",
        featured: false
    },
        {
        id: "S022",
        name: "MUSTER POINT (NON - LUMINOUS) M-TEK",
        category: "Safety",
        price: 1500,
        description: "MUSTER POINT (NON - LUMINOUS) M-TEK \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Muster Point Sign.jpg",
        featured: false
    },
        {
        id: "S023",
        name: "MUSTER POINT (PLASTIC) M-TEK",
        category: "Safety",
        price: 6000,
        description: "MUSTER POINT (PLASTIC) M-TEK \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Muster Point Sign.jpg",
        featured: false
    },
        {
        id: "S024",
        name: "NO SMOKING ( M-TEK) PLASTIC (NON-LUMINOUS)",
        category: "Safety",
        price: 6000,
        description: "NO SMOKING ( M-TEK) PLASTIC (NON-LUMINOUS) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Muster Point Sign.jpg",
        featured: true
    },
        {
        id: "S025",
        name: "NOSE MASK ( FILTER MASK)",
        category: "Safety",
        price: 500,
        description: "NOSE MASK ( FILTER MASK) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/MSA Helmet (Green).jpg",
        featured: false
    },
        {
        id: "S026",
        name: "NOSE MASK (303[NP303])",
        category: "Safety",
        price: 2500,
        description: "NOSE MASK (303[NP303]) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/MSA Helmet (Green).jpg",
        featured: false
    },
        {
        id: "S027",
        name: "NOSE MASK (3M/6003)",
        category: "Safety",
        price: 1000,
        description: "NOSE MASK (3M/6003) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/MSA Helmet (Green).jpg",
        featured: false
    },
        {
        id: "S028",
        name: "NOSE MASK 303 CATRIDGE",
        category: "Safety",
        price: 2500,
        description: "NOSE MASK 303 CATRIDGE \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/MSA Helmet (Green).jpg",
        featured: false
    },
        {
        id: "S029",
        name: "ORDINARY RAIN BOOT (BLACK) short",
        category: "Safety",
        price: 10000,
        description: "ORDINARY RAIN BOOT (BLACK) short \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Rocklander Safety Boots.jpg",
        featured: false
    },
        {
        id: "S030",
        name: "ORDINARY RAIN BOOT (BLACK) Long",
        category: "Safety",
        price: 12000,
        description: "ORDINARY RAIN BOOT (BLACK) Long \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Rocklander Safety Boots.jpg",
        featured: false
    },
        {
        id: "S031",
        name: "PEPPER SPRAY (PS 007/PROSECURE/BODYGUARD)",
        category: "Safety",
        price: 3500,
        description: "PEPPER SPRAY (PS 007/PROSECURE/BODYGUARD) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Rocklander Safety Boots.jpg",
        featured: false
    },
        {
        id: "S032",
        name: "RAIN COAT GOWN",
        category: "Safety",
        price: 12500,
        description: "RAIN COAT GOWN \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Rocklander Safety Boots.jpg",
        featured: false
    },
        {
        id: "S033",
        name: "RAIN COAT UP/DOWN",
        category: "Safety",
        price: 13000,
        description: "RAIN COAT UP/DOWN \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Rocklander Safety Boots.jpg",
        featured: false
    },
        {
        id: "S034",
        name: "REFLECTIVE JACKET (BLACK NECK 2) GREEN",
        category: "Safety",
        price: 3500,
        description: "REFLECTIVE JACKET (BLACK NECK 2) GREEN \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/reflective jacket green.jpg",
        featured: false
    },
        {
        id: "S035",
        name: "REFLECTIVE JACKET (BLACK NECK 1) ORANGE /GREEN",
        category: "Safety",
        price: 3500,
        description: "REFLECTIVE JACKET (BLACK NECK 1) ORANGE /GREEN \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/reflective jacket green.jpg",
        featured: false
    },
        {
        id: "S036",
        name: "REFLECTIVE JACKET (NORMAL) ORANGE /GREEN",
        category: "Safety",
        price: 3500,
        description: "REFLECTIVE JACKET (NORMAL) ORANGE /GREEN \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/reflective jacket green.jpg",
        featured: true
    },
        {
        id: "S037",
        name: "SAFETY BOOT(ARMSTRONG)",
        category: "Safety",
        price: 25000,
        description: "SAFETY BOOT(ARMSTRONG) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Rocklander Safety Boots.jpg",
        featured: false
    },
        {
        id: "S038",
        name: "SAFETY BOOT(ROCK LANDER)",
        category: "Safety",
        price: 22000,
        description: "SAFETY BOOT(ROCK LANDER) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Rocklander Safety Boots.jpg",
        featured: false
    },
        {
        id: "S039",
        name: "SAFTETY BODY HARNESS BELT",
        category: "Safety",
        price: 10000,
        description: "SAFTETY BODY HARNESS BELT \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Overall.jpg",
        featured: false
    },
        {
        id: "S040",
        name: "SAFTETY RAIN BOOT (YELLOW)",
        category: "Safety",
        price: 15000,
        description: "SAFTETY RAIN BOOT (YELLOW) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Rocklander Safety Boots.jpg",
        featured: false
    },
        {
        id: "S041",
        name: "SECURITY BELT (BIG SIZE)",
        category: "Safety",
        price: 6000,
        description: "SECURITY BELT (BIG SIZE) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Overall.jpg",
        featured: false
    },
        {
        id: "S042",
        name: "SECURITY PERSONNEL [ANKLET] PAIRS",
        category: "Safety",
        price: 5000,
        description: "SECURITY PERSONNEL [ANKLET] PAIRS \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Rocklander Safety Boots.jpg",
        featured: false
    },
        {
        id: "S043",
        name: "SECURITY BOOT (LEATHER /FABRICK)",
        category: "Safety",
        price: 15000,
        description: "SECURITY BOOT (LEATHER /FABRICK) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Rocklander Safety Boots.jpg",
        featured: false
    },
        {
        id: "S044",
        name: "SECURITY BOOT (LEATHER ONLY)",
        category: "Safety",
        price: 10000,
        description: "SECURITY BOOT (LEATHER ONLY) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Rocklander Safety Boots.jpg",
        featured: false
    },
        {
        id: "S045",
        name: "SECURITY PERSONNEL [BERET]",
        category: "Safety",
        price: 0,
        description: "SECURITY PERSONNEL [BERET] \u2014 Safety equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/Rocklander Safety Boots.jpg",
        featured: false
    },
        {
        id: "S046",
        name: "SECURITY PERSONNEL [LYNYARD]",
        category: "Safety",
        price: 0,
        description: "SECURITY PERSONNEL [LYNYARD] \u2014 Safety equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/Rocklander Safety Boots.jpg",
        featured: false
    },
        {
        id: "S047",
        name: "SECURITY PERSONNEL BELT (SMALL SIZE)",
        category: "Safety",
        price: 0,
        description: "SECURITY PERSONNEL BELT (SMALL SIZE) \u2014 Safety equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/Overall.jpg",
        featured: false
    },
        {
        id: "S048",
        name: "SINAGE BEWARE OF DOG (MOUNTED) [12 BY 12]",
        category: "Safety",
        price: 4000,
        description: "SINAGE BEWARE OF DOG (MOUNTED) [12 BY 12] \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Muster Point Sign.jpg",
        featured: true
    },
        {
        id: "S049",
        name: "SINAGE CAUTION (MOUNTED) 10 BY 12",
        category: "Safety",
        price: 7000,
        description: "SINAGE CAUTION (MOUNTED) 10 BY 12 \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Muster Point Sign.jpg",
        featured: false
    },
        {
        id: "S050",
        name: "SINAGE CCTV (MOUNTED) 10 BY 12",
        category: "Safety",
        price: 7000,
        description: "SINAGE CCTV (MOUNTED) 10 BY 12 \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Muster Point Sign.jpg",
        featured: false
    },
        {
        id: "S051",
        name: "SINAGE DANGER ELECTRIC SHOCK ... (MOUNTED) [6 BY 12]",
        category: "Safety",
        price: 4000,
        description: "SINAGE DANGER ELECTRIC SHOCK ... (MOUNTED) [6 BY 12] \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Muster Point Sign.jpg",
        featured: false
    },
        {
        id: "S052",
        name: "SINAGE FIRE BLANKET POINT (MOUNTED) [6 BY 12]",
        category: "Safety",
        price: 4000,
        description: "SINAGE FIRE BLANKET POINT (MOUNTED) [6 BY 12] \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "S053",
        name: "SINAGE FIRE EXIT (MOUNTED) [6 BY 12]",
        category: "Safety",
        price: 4000,
        description: "SINAGE FIRE EXIT (MOUNTED) [6 BY 12] \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Muster Point Sign.jpg",
        featured: false
    },
        {
        id: "S054",
        name: "SINAGE FIRE EXTINGUISHER POINT (MOUNTED) [6 BY 12]",
        category: "Safety",
        price: 4000,
        description: "SINAGE FIRE EXTINGUISHER POINT (MOUNTED) [6 BY 12] \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP 6kg Fire Extinguisher.jpg",
        featured: false
    },
        {
        id: "S055",
        name: "SINAGE MUSTER POINT (MOUNTED) 12BY12",
        category: "Safety",
        price: 7000,
        description: "SINAGE MUSTER POINT (MOUNTED) 12BY12 \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Muster Point Sign.jpg",
        featured: false
    },
        {
        id: "S056",
        name: "SINAGE FILLING STATION CAUTION(MOUNTED)",
        category: "Safety",
        price: 6000,
        description: "SINAGE FILLING STATION CAUTION(MOUNTED) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Muster Point Sign.jpg",
        featured: false
    },
        {
        id: "S057",
        name: "SINAGE RESTRICTED AREA (MOUNTED) 6 BY 12",
        category: "Safety",
        price: 4000,
        description: "SINAGE RESTRICTED AREA (MOUNTED) 6 BY 12 \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Muster Point Sign.jpg",
        featured: false
    },
        {
        id: "S058",
        name: "SINAGE SOUND ALARM (MOUNTED) 6 BY 12",
        category: "Safety",
        price: 4000,
        description: "SINAGE SOUND ALARM (MOUNTED) 6 BY 12 \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Muster Point Sign.jpg",
        featured: false
    },
        {
        id: "S059",
        name: "SINAGE VEHICLES PARKED AT OWNERS RISK (MOUNTED) [12 BY 12]",
        category: "Safety",
        price: 7000,
        description: "SINAGE VEHICLES PARKED AT OWNERS RISK (MOUNTED) [12 BY 12] \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Muster Point Sign.jpg",
        featured: false
    },
        {
        id: "S060",
        name: "SINAGE VEHICLES PARKED AT OWNERS RISK (MOUNTED) [6 BY 12]",
        category: "Safety",
        price: 4000,
        description: "SINAGE VEHICLES PARKED AT OWNERS RISK (MOUNTED) [6 BY 12] \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Muster Point Sign.jpg",
        featured: true
    },
        {
        id: "S061",
        name: "SINAGE WORKSHOP NO ENTRANCE (MOUNTED) 6 BY 12",
        category: "Safety",
        price: 4000,
        description: "SINAGE WORKSHOP NO ENTRANCE (MOUNTED) 6 BY 12 \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Muster Point Sign.jpg",
        featured: false
    },
        {
        id: "S062",
        name: "UNDERCAR MIRROR SEARCH",
        category: "Safety",
        price: 60000,
        description: "UNDERCAR MIRROR SEARCH \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Rocklander Safety Boots.jpg",
        featured: false
    },
        {
        id: "S063",
        name: "VEHICULAR ''C'' CAUTION",
        category: "Safety",
        price: 3000,
        description: "VEHICULAR ''C'' CAUTION \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Muster Point Sign.jpg",
        featured: false
    },
        {
        id: "S064",
        name: "WARNING TAPE ( CAUTION TAPE)",
        category: "Safety",
        price: 10000,
        description: "WARNING TAPE ( CAUTION TAPE) \u2014 Safety equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Muster Point Sign.jpg",
        featured: false
    },

// SECURITY
        {
        id: "Q001",
        name: "Handheld Metal Detector",
        category: "Security",
        price: 20000,
        description: "Hand held safety.",
        image: "assets/products/metal dectector.jpg",
        featured: true
    },
        {
        id: "Q002",
        name: "Walk-Through Metal Detector Gate",
        category: "Security",
        price: 680000,
        description: "Full-height walk-through detector gate for high-traffic entry points.",
        image: "assets/products/metal dectector.jpg",
        featured: true
    },
        {
        id: "Q003",
        name: "Under Vehicle Inspection Mirror",
        category: "Security",
        price: 42000,
        description: "Inspection mirror with torch for under-vehicle checks.",
        image: "assets/products/cctv equipments.jpg",
        featured: false
    },
        {
        id: "Q004",
        name: "Security Torch \u2013 Rechargeable",
        category: "Security",
        price: 15000,
        description: "Heavy-duty rechargeable torch for guards and patrols.",
        image: "assets/products/cctv equipments.jpg",
        featured: false
    },
        {
        id: "Q005",
        name: "Expandable Baton \u2013 Rubber Grip",
        category: "Security",
        price: 11500,
        description: "Expandable baton for security personnel and patrol teams.",
        image: "assets/products/cctv equipments.jpg",
        featured: false
    },
        {
        id: "Q006",
        name: "Traffic Baton \u2013 LED",
        category: "Security",
        price: 8500,
        description: "Illuminated baton for traffic control and emergency scenes.",
        image: "assets/products/cctv equipments.jpg",
        featured: false
    },
        {
        id: "Q007",
        name: "Door Contact Sensor \u2013 Magnetic",
        category: "Security",
        price: 6500,
        description: "Magnetic contact sensor for doors and windows.",
        image: "assets/products/cctv equipments.jpg",
        featured: false
    },
        {
        id: "Q008",
        name: "Vibration/Shock Sensor",
        category: "Security",
        price: 7200,
        description: "Sensor to detect forced entry attempts on doors, windows or safes.",
        image: "assets/products/cctv equipments.jpg",
        featured: false
    },
        {
        id: "Q009",
        name: "Panic Button \u2013 Wired",
        category: "Security",
        price: 8000,
        description: "Emergency panic button for offices, banks and receptions.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "Q010",
        name: "Siren \u2013 30W External",
        category: "Security",
        price: 16500,
        description: "Loud external siren for security alarm systems.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "Q011",
        name: "Standalone PIR Motion Sensor Alarm",
        category: "Security",
        price: 21000,
        description: "Standalone PIR motion sensor with alarm.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },

    // SOLAR
        {
        id: "L001",
        name: "1,000WATTS(SATCHET INVERTER)(SOLAR POWER INVERTER)",
        category: "Solar",
        price: 0,
        description: "1,000WATTS(SATCHET INVERTER)(SOLAR POWER INVERTER) \u2014 Solar equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/Solar Inverter 3kVA.jpg",
        featured: true
    },
        {
        id: "L002",
        name: "1.0 KVA INVERTER (FAMI -CARE)",
        category: "Solar",
        price: 0,
        description: "1.0 KVA INVERTER (FAMI -CARE) \u2014 Solar equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/Solar Inverter 3kVA.jpg",
        featured: true
    },
        {
        id: "L003",
        name: "1.5KVA/24VOLTS/PSW",
        category: "Solar",
        price: 0,
        description: "1.5KVA/24VOLTS/PSW \u2014 Solar equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/solar bulb.jpg",
        featured: false
    },
        {
        id: "L004",
        name: "100AHS DCB SUNTEST",
        category: "Solar",
        price: 0,
        description: "100AHS DCB SUNTEST \u2014 Solar equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/solar bulb.jpg",
        featured: false
    },
        {
        id: "L005",
        name: "150AHS DCB SUNTEST",
        category: "Solar",
        price: 0,
        description: "150AHS DCB SUNTEST \u2014 Solar equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/solar bulb.jpg",
        featured: false
    },
        {
        id: "L006",
        name: "150AHS DCB TOPLIGHT",
        category: "Solar",
        price: 0,
        description: "150AHS DCB TOPLIGHT \u2014 Solar equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/solar bulb.jpg",
        featured: false
    },
        {
        id: "L007",
        name: "20AHS CHARGE CONTROLLER",
        category: "Solar",
        price: 10,
        description: "20AHS CHARGE CONTROLLER \u2014 Solar equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Solar Inverter 3kVA.jpg",
        featured: false
    },
        {
        id: "L008",
        name: "2200WATTS/12VOLTS/MODIFIED",
        category: "Solar",
        price: 220000,
        description: "2200WATTS/12VOLTS/MODIFIED \u2014 Solar equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/solar bulb.jpg",
        featured: false
    },
        {
        id: "L009",
        name: "3.5KVA/24VOLTS/PSW",
        category: "Solar",
        price: 0,
        description: "3.5KVA/24VOLTS/PSW \u2014 Solar equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/solar bulb.jpg",
        featured: false
    },
        {
        id: "L010",
        name: "3000WATTS/ 24VOLTS/ MODIFIED",
        category: "Solar",
        price: 300000,
        description: "3000WATTS/ 24VOLTS/ MODIFIED \u2014 Solar equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/solar bulb.jpg",
        featured: false
    },
        {
        id: "L011",
        name: "30AHS CHARGE CONTROLLER",
        category: "Solar",
        price: 20000,
        description: "30AHS CHARGE CONTROLLER \u2014 Solar equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Solar Inverter 3kVA.jpg",
        featured: false
    },
        {
        id: "L012",
        name: "30WATTS LED SOLAR LIGHT",
        category: "Solar",
        price: 25000,
        description: "30WATTS LED SOLAR LIGHT \u2014 Solar equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/solar bulb.jpg",
        featured: true
    },
        {
        id: "L013",
        name: "36WATTS LED SOLAR LIGHT",
        category: "Solar",
        price: 30000,
        description: "36WATTS LED SOLAR LIGHT \u2014 Solar equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/solar bulb.jpg",
        featured: false
    },
        {
        id: "L014",
        name: "3WATTS DC BULB [PLASTIC]",
        category: "Solar",
        price: 1500,
        description: "3WATTS DC BULB [PLASTIC] \u2014 Solar equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/solar bulb.jpg",
        featured: false
    },
        {
        id: "L015",
        name: "3WATTS DC BULB [METAL]",
        category: "Solar",
        price: 1800,
        description: "3WATTS DC BULB [METAL] \u2014 Solar equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/solar bulb.jpg",
        featured: false
    },
        {
        id: "L016",
        name: "40AHS CHARGE CONTROLLER",
        category: "Solar",
        price: 30000,
        description: "40AHS CHARGE CONTROLLER \u2014 Solar equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Solar Inverter 3kVA.jpg",
        featured: false
    },
        {
        id: "L017",
        name: "500WATTS SOLAR INVERTER (12VDC TO AC 220)",
        category: "Solar",
        price: 25000,
        description: "500WATTS SOLAR INVERTER (12VDC TO AC 220) \u2014 Solar equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Solar Inverter 3kVA.jpg",
        featured: false
    },
        {
        id: "L018",
        name: "5WATTS DC BULB",
        category: "Solar",
        price: 2000,
        description: "5WATTS DC BULB \u2014 Solar equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/solar bulb.jpg",
        featured: false
    },
        {
        id: "L019",
        name: "7WATTS DC BULB",
        category: "Solar",
        price: 2500,
        description: "7WATTS DC BULB \u2014 Solar equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/solar bulb.jpg",
        featured: false
    },
        {
        id: "L020",
        name: "SOLAR POWER PACK",
        category: "Solar",
        price: 50000,
        description: "SOLAR POWER PACK \u2014 Solar equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/solar bulb.jpg",
        featured: false
    },
        {
        id: "L021",
        name: "SOLAR FAN",
        category: "Solar",
        price: 0,
        description: "SOLAR FAN \u2014 Solar equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/solar bulb.jpg",
        featured: false
    },
        {
        id: "L022",
        name: "SOLAR PANEL 100WATTS MONO",
        category: "Solar",
        price: 0,
        description: "SOLAR PANEL 100WATTS MONO \u2014 Solar equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/Solar Panel 200W.jpg",
        featured: false
    },
        {
        id: "L023",
        name: "SOLAR PANEL 200WATTS MONO",
        category: "Solar",
        price: 0,
        description: "SOLAR PANEL 200WATTS MONO \u2014 Solar equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/Solar Panel 200W.jpg",
        featured: false
    },
        {
        id: "L024",
        name: "220AHS AFRIIPOWER TABULARBATTERY",
        category: "Solar",
        price: 280000,
        description: "220AHS AFRIIPOWER TABULARBATTERY \u2014 Solar equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Solar Battery 200Ah.jpg",
        featured: true
    },
        {
        id: "L025",
        name: "2KVA INVERTER",
        category: "Solar",
        price: 250000,
        description: "2KVA INVERTER \u2014 Solar equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Solar Inverter 3kVA.jpg",
        featured: false
    },
        {
        id: "L026",
        name: "200AH MONO PANEL",
        category: "Solar",
        price: 50000,
        description: "200AH MONO PANEL \u2014 Solar equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Solar Panel 200W.jpg",
        featured: false
    },
    
    //HOME AUTOMATION, ALARM & SURVEILANCE
        {
        id: "H001",
        name: "BAOFENG TWO WAY RADIO BF-7775",
        category: "Home Automation, Alarm & Surveillance",
        price: 18000,
        description: "BAOFENG TWO WAY RADIO BF-7775 \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Baofeng Radio.jpg",
        featured: true
    },
        {
        id: "H002",
        name: "BAOFENG TWO WAY RADIO BF-888",
        category: "Home Automation, Alarm & Surveillance",
        price: 19000,
        description: "BAOFENG TWO WAY RADIO BF-888 \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Baofeng Radio.jpg",
        featured: true
    },
        {
        id: "H003",
        name: "BATTERY (12VOLTS/7.2AH)PANASONIC/EVERGOOD/TIRELESS",
        category: "Home Automation, Alarm & Surveillance",
        price: 18000,
        description: "BATTERY (12VOLTS/7.2AH)PANASONIC/EVERGOOD/TIRELESS \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Solar Battery 200Ah.jpg",
        featured: false
    },
        {
        id: "H004",
        name: "BATTERY (9VOLTS/6F22M[HI-WATTS)",
        category: "Home Automation, Alarm & Surveillance",
        price: 1000,
        description: "BATTERY (9VOLTS/6F22M[HI-WATTS) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Solar Battery 200Ah.jpg",
        featured: false
    },
        {
        id: "H005",
        name: "BATTERY for BAOFENG RADIO",
        category: "Home Automation, Alarm & Surveillance",
        price: 5000,
        description: "BATTERY for BAOFENG RADIO \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Solar Battery 200Ah.jpg",
        featured: false
    },
        {
        id: "H006",
        name: "BELL (24 VDC CHLORIDE UK)",
        category: "Home Automation, Alarm & Surveillance",
        price: 15000,
        description: "BELL (24 VDC CHLORIDE UK) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H007",
        name: "BELL (24 VDC JORDY B4:H104DY)",
        category: "Home Automation, Alarm & Surveillance",
        price: 12000,
        description: "BELL (24 VDC JORDY B4:H104DY) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H008",
        name: "BELL (24 VDC ZETA 6\")",
        category: "Home Automation, Alarm & Surveillance",
        price: 10000,
        description: "BELL (24 VDC ZETA 6\") \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H009",
        name: "CABLE (FIRE ALARM/1.5MM x2/100M/100% COPPER KUBIX)",
        category: "Home Automation, Alarm & Surveillance",
        price: 120000,
        description: "CABLE (FIRE ALARM/1.5MM x2/100M/100% COPPER KUBIX) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H010",
        name: "CABLE (FIRE ALARM\\1.5MMx2\\100M (ACCESS KING)",
        category: "Home Automation, Alarm & Surveillance",
        price: 56000,
        description: "CABLE (FIRE ALARM\\1.5MMx2\\100M (ACCESS KING) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H011",
        name: "CABLE (FIRE ALARM\\1.5MMx2\\100M\\KUBIX(NON COPPER",
        category: "Home Automation, Alarm & Surveillance",
        price: 56000,
        description: "CABLE (FIRE ALARM\\1.5MMx2\\100M\\KUBIX(NON COPPER \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H012",
        name: "CABLE (HDMI CABLE) 2m",
        category: "Home Automation, Alarm & Surveillance",
        price: 3000,
        description: "CABLE (HDMI CABLE) 2m \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: true
    },
        {
        id: "H013",
        name: "CABLE (TELEPHONE \\2P\\300 YARDS\\ACCESS KING)",
        category: "Home Automation, Alarm & Surveillance",
        price: 36000,
        description: "CABLE (TELEPHONE \\2P\\300 YARDS\\ACCESS KING) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H014",
        name: "CABLE (TELEPHONE\\2P\\100M KUBIX)",
        category: "Home Automation, Alarm & Surveillance",
        price: 16000,
        description: "CABLE (TELEPHONE\\2P\\100M KUBIX) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H015",
        name: "CABLE (TELEPHONE\\2P\\200 YARDS\\ACCESS KING)",
        category: "Home Automation, Alarm & Surveillance",
        price: 30000,
        description: "CABLE (TELEPHONE\\2P\\200 YARDS\\ACCESS KING) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H016",
        name: "CABLE (VGA CABLE)",
        category: "Home Automation, Alarm & Surveillance",
        price: 5000,
        description: "CABLE (VGA CABLE) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H017",
        name: "CABLE TELEPHONE 2P/200 YARDS /ACCESS KING",
        category: "Home Automation, Alarm & Surveillance",
        price: 32000,
        description: "CABLE TELEPHONE 2P/200 YARDS /ACCESS KING \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H018",
        name: "CALL POINT (KIDI FIRE BOX)",
        category: "Home Automation, Alarm & Surveillance",
        price: 10500,
        description: "CALL POINT (KIDI FIRE BOX) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Beak Glass.jpg",
        featured: false
    },
        {
        id: "H019",
        name: "CALL POINT (ZETA RESETTABLE)",
        category: "Home Automation, Alarm & Surveillance",
        price: 18000,
        description: "CALL POINT (ZETA RESETTABLE) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Beak Glass.jpg",
        featured: false
    },
        {
        id: "H020",
        name: "CALL POINT CHLORIDE UK (CP-387)",
        category: "Home Automation, Alarm & Surveillance",
        price: 8500,
        description: "CALL POINT CHLORIDE UK (CP-387) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Beak Glass.jpg",
        featured: false
    },
        {
        id: "H021",
        name: "CAMERA (BATTERY CAM IP V380)",
        category: "Home Automation, Alarm & Surveillance",
        price: 36000,
        description: "CAMERA (BATTERY CAM IP V380) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Solar Battery 200Ah.jpg",
        featured: true
    },
        {
        id: "H022",
        name: "CAMERA (BULB CAM IPC-V380-E27)",
        category: "Home Automation, Alarm & Surveillance",
        price: 30000,
        description: "CAMERA (BULB CAM IPC-V380-E27) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/bulb camera.jpg",
        featured: false
    },
        {
        id: "H023",
        name: "CAMERA (INDOOR 2.0MP/WP-AH5536TC WINPOSSEE)",
        category: "Home Automation, Alarm & Surveillance",
        price: 21000,
        description: "CAMERA (INDOOR 2.0MP/WP-AH5536TC WINPOSSEE) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/bulb camera.jpg",
        featured: false
    },
        {
        id: "H024",
        name: "CAMERA (INDOOR CAMERA V380 World Vision)",
        category: "Home Automation, Alarm & Surveillance",
        price: 50000,
        description: "CAMERA (INDOOR CAMERA V380 World Vision) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/bulb camera.jpg",
        featured: true
    },
        {
        id: "H025",
        name: "CAMERA (INDOOR SEARCH/420TVL/SH-HLD)",
        category: "Home Automation, Alarm & Surveillance",
        price: 15000,
        description: "CAMERA (INDOOR SEARCH/420TVL/SH-HLD) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/bulb camera.jpg",
        featured: false
    },
        {
        id: "H026",
        name: "CAMERA (INDOOR SOON: 6MM/3.6MM/220B)",
        category: "Home Automation, Alarm & Surveillance",
        price: 20000,
        description: "CAMERA (INDOOR SOON: 6MM/3.6MM/220B) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/bulb camera.jpg",
        featured: false
    },
        {
        id: "H027",
        name: "CAMERA (INDOOR SOON:3.6MM/OO3G)",
        category: "Home Automation, Alarm & Surveillance",
        price: 18000,
        description: "CAMERA (INDOOR SOON:3.6MM/OO3G) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/bulb camera.jpg",
        featured: false
    },
        {
        id: "H028",
        name: "CAMERA (INDOOR VR CAM)",
        category: "Home Automation, Alarm & Surveillance",
        price: 30000,
        description: "CAMERA (INDOOR VR CAM) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/bulb camera.jpg",
        featured: false
    },
        {
        id: "H029",
        name: "CAMERA INDOOR WINPOSSEE : WP- AH5624 VMH\\1.3MP",
        category: "Home Automation, Alarm & Surveillance",
        price: 21500,
        description: "CAMERA INDOOR WINPOSSEE : WP- AH5624 VMH\\1.3MP \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/bulb camera.jpg",
        featured: false
    },
        {
        id: "H030",
        name: "CAMERA INDOOR WINPOSSEE :WP-AH5006TC\\2.0MP",
        category: "Home Automation, Alarm & Surveillance",
        price: 22000,
        description: "CAMERA INDOOR WINPOSSEE :WP-AH5006TC\\2.0MP \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/bulb camera.jpg",
        featured: false
    },
        {
        id: "H031",
        name: "CAMERA INDOOR WINPOSSEE 4MP F5024VK4",
        category: "Home Automation, Alarm & Surveillance",
        price: 35200,
        description: "CAMERA INDOOR WINPOSSEE 4MP F5024VK4 \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/bulb camera.jpg",
        featured: false
    },
        {
        id: "H032",
        name: "CAMERA OUTDOOR SOON \\3.6MM\\K702",
        category: "Home Automation, Alarm & Surveillance",
        price: 0,
        description: "CAMERA OUTDOOR SOON \\3.6MM\\K702 \u2014 Home Automation, Alarm & Surveillance equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/Outdoor CCTV Camera.jpg",
        featured: false
    },
        {
        id: "H033",
        name: "CAMERA OUTDOOR SOON \\6MM\\007B",
        category: "Home Automation, Alarm & Surveillance",
        price: 0,
        description: "CAMERA OUTDOOR SOON \\6MM\\007B \u2014 Home Automation, Alarm & Surveillance equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/Outdoor CCTV Camera.jpg",
        featured: false
    },
        {
        id: "H034",
        name: "CAMERA OUTDOOR WINPOSSEE : WP 6036TC- U\\2.0 MP",
        category: "Home Automation, Alarm & Surveillance",
        price: 22500,
        description: "CAMERA OUTDOOR WINPOSSEE : WP 6036TC- U\\2.0 MP \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Outdoor CCTV Camera.jpg",
        featured: false
    },
        {
        id: "H035",
        name: "CAMERA OUTDOOR WINPOSSEE \\0.2MP\\WP-6136 TS-A ( IP CAM)",
        category: "Home Automation, Alarm & Surveillance",
        price: 38000,
        description: "CAMERA OUTDOOR WINPOSSEE \\0.2MP\\WP-6136 TS-A ( IP CAM) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Outdoor CCTV Camera.jpg",
        featured: false
    },
        {
        id: "H036",
        name: "CAMERA OUTDOOR WINPOSSEE \\1.8MP\\AH6036 MH-S",
        category: "Home Automation, Alarm & Surveillance",
        price: 0,
        description: "CAMERA OUTDOOR WINPOSSEE \\1.8MP\\AH6036 MH-S \u2014 Home Automation, Alarm & Surveillance equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/Outdoor CCTV Camera.jpg",
        featured: true
    },
        {
        id: "H037",
        name: "CAMERA OUTDOOR WINPOSSEE \\2.0MP\\WP- AH6024 TC",
        category: "Home Automation, Alarm & Surveillance",
        price: 22000,
        description: "CAMERA OUTDOOR WINPOSSEE \\2.0MP\\WP- AH6024 TC \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Outdoor CCTV Camera.jpg",
        featured: false
    },
        {
        id: "H038",
        name: "CAMERA OUTDOOR WINPOSSEE \\4MP \\WP-F6024K4",
        category: "Home Automation, Alarm & Surveillance",
        price: 35200,
        description: "CAMERA OUTDOOR WINPOSSEE \\4MP \\WP-F6024K4 \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Outdoor CCTV Camera.jpg",
        featured: false
    },
        {
        id: "H039",
        name: "CAMERA OUTDOOR WINPOSSEE\\1.3MP\\WP-6036MC-S (IP CAM)",
        category: "Home Automation, Alarm & Surveillance",
        price: 38000,
        description: "CAMERA OUTDOOR WINPOSSEE\\1.3MP\\WP-6036MC-S (IP CAM) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Outdoor CCTV Camera.jpg",
        featured: true
    },
        {
        id: "H040",
        name: "CAMERA POWER ADAPTOR (WINPOSSEE)",
        category: "Home Automation, Alarm & Surveillance",
        price: 0,
        description: "CAMERA POWER ADAPTOR (WINPOSSEE) \u2014 Home Automation, Alarm & Surveillance equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/bulb camera.jpg",
        featured: false
    },
        {
        id: "H041",
        name: "CAMERA SOLAR PTZ",
        category: "Home Automation, Alarm & Surveillance",
        price: 150000,
        description: "CAMERA SOLAR PTZ \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/bulb camera.jpg",
        featured: false
    },
        {
        id: "H042",
        name: "CAMERA WI-FI SMART CAMERA",
        category: "Home Automation, Alarm & Surveillance",
        price: 25000,
        description: "CAMERA WI-FI SMART CAMERA \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/bulb camera.jpg",
        featured: false
    },
        {
        id: "H043",
        name: "DVR EIGHT CHANNELS (WINPOSSEE)",
        category: "Home Automation, Alarm & Surveillance",
        price: 73600,
        description: "DVR EIGHT CHANNELS (WINPOSSEE) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DVR 8 Channel.jpg",
        featured: false
    },
        {
        id: "H044",
        name: "DVR FOUR CHANNELS (CHLORIDE UK)",
        category: "Home Automation, Alarm & Surveillance",
        price: 50000,
        description: "DVR FOUR CHANNELS (CHLORIDE UK) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DVR 8 Channel.jpg",
        featured: false
    },
        {
        id: "H045",
        name: "DVR FOUR CHANNELS (NON - BRANDED)",
        category: "Home Automation, Alarm & Surveillance",
        price: 55000,
        description: "DVR FOUR CHANNELS (NON - BRANDED) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DVR 8 Channel.jpg",
        featured: false
    },
        {
        id: "H046",
        name: "DVR FOUR CHANNELS WINPOSSEE",
        category: "Home Automation, Alarm & Surveillance",
        price: 70000,
        description: "DVR FOUR CHANNELS WINPOSSEE \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DVR 8 Channel.jpg",
        featured: false
    },
        {
        id: "H047",
        name: "DVR SIXTEEN CHANNEL (WINPOSSEE)",
        category: "Home Automation, Alarm & Surveillance",
        price: 0,
        description: "DVR SIXTEEN CHANNEL (WINPOSSEE) \u2014 Home Automation, Alarm & Surveillance equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/DVR 8 Channel.jpg",
        featured: false
    },
        {
        id: "H048",
        name: "DVR SIXTEEN CHANNEL (CHLORIDE UK)",
        category: "Home Automation, Alarm & Surveillance",
        price: 0,
        description: "DVR SIXTEEN CHANNEL (CHLORIDE UK) \u2014 Home Automation, Alarm & Surveillance equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/DVR 8 Channel.jpg",
        featured: true
    },
        {
        id: "H049",
        name: "DVR SIXTEEN CHANNEL (CODY -XUN)",
        category: "Home Automation, Alarm & Surveillance",
        price: 115000,
        description: "DVR SIXTEEN CHANNEL (CODY -XUN) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DVR 8 Channel.jpg",
        featured: false
    },
        {
        id: "H050",
        name: "DVR SIXTEEN CHANNEL (WINPOSSEE) 5MP",
        category: "Home Automation, Alarm & Surveillance",
        price: 0,
        description: "DVR SIXTEEN CHANNEL (WINPOSSEE) 5MP \u2014 Home Automation, Alarm & Surveillance equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/DVR 8 Channel.jpg",
        featured: false
    },
        {
        id: "H051",
        name: "EMERGENCY/EXIT LIGHT (WITHOUT SIGNAGE)",
        category: "Home Automation, Alarm & Surveillance",
        price: 25000,
        description: "EMERGENCY/EXIT LIGHT (WITHOUT SIGNAGE) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Muster Point Sign.jpg",
        featured: false
    },
        {
        id: "H052",
        name: "FIRE ALARM (CHLORIDE UK SOUNDER/STROBE - CP 313-SF)",
        category: "Home Automation, Alarm & Surveillance",
        price: 26000,
        description: "FIRE ALARM (CHLORIDE UK SOUNDER/STROBE - CP 313-SF) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H053",
        name: "FIRE ALARM SOUNDER FLASHER (CHLORIDE uk} MODEL:CP 408-CS/F)",
        category: "Home Automation, Alarm & Surveillance",
        price: 25000,
        description: "FIRE ALARM SOUNDER FLASHER (CHLORIDE uk} MODEL:CP 408-CS/F) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H054",
        name: "FLASHER (12 VOLTS)",
        category: "Home Automation, Alarm & Surveillance",
        price: 6500,
        description: "FLASHER (12 VOLTS) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H055",
        name: "FLASHER (24 VOLTS)",
        category: "Home Automation, Alarm & Surveillance",
        price: 6000,
        description: "FLASHER (24 VOLTS) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H056",
        name: "HARD DRIVE ( 1TB)",
        category: "Home Automation, Alarm & Surveillance",
        price: 45000,
        description: "HARD DRIVE ( 1TB) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DVR 8 Channel.jpg",
        featured: false
    },
        {
        id: "H057",
        name: "HEAT DETECTOR (CHLORIDE UK/AH-751-2)",
        category: "Home Automation, Alarm & Surveillance",
        price: 0,
        description: "HEAT DETECTOR (CHLORIDE UK/AH-751-2) \u2014 Home Automation, Alarm & Surveillance equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H058",
        name: "INDUSTRIAL SAFETY BELT(SAFETY HARNESS BELT)",
        category: "Home Automation, Alarm & Surveillance",
        price: 0,
        description: "INDUSTRIAL SAFETY BELT(SAFETY HARNESS BELT) \u2014 Home Automation, Alarm & Surveillance equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/Overall.jpg",
        featured: false
    },
        {
        id: "H059",
        name: "INFRARED (PIR-9822 PASSIVE INFRARED INTRUSION DETECTOR",
        category: "Home Automation, Alarm & Surveillance",
        price: 20000,
        description: "INFRARED (PIR-9822 PASSIVE INFRARED INTRUSION DETECTOR \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H060",
        name: "MAGNETIC DOOR CONTACT ( 2 FOR A PAIR)",
        category: "Home Automation, Alarm & Surveillance",
        price: 7500,
        description: "MAGNETIC DOOR CONTACT ( 2 FOR A PAIR) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: true
    },
        {
        id: "H061",
        name: "MANUAL CALL POINT (INFINITY PLUS) IP -04 Resetable",
        category: "Home Automation, Alarm & Surveillance",
        price: 12000,
        description: "MANUAL CALL POINT (INFINITY PLUS) IP -04 Resetable \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Beak Glass.jpg",
        featured: false
    },
        {
        id: "H062",
        name: "NVR EIGHT CHANNELS (WINPOSSEE/POE)",
        category: "Home Automation, Alarm & Surveillance",
        price: 96000,
        description: "NVR EIGHT CHANNELS (WINPOSSEE/POE) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DVR 8 Channel.jpg",
        featured: false
    },
        {
        id: "H063",
        name: "PANEL ( VICA UK 6 ZONE [FAP])",
        category: "Home Automation, Alarm & Surveillance",
        price: 200000,
        description: "PANEL ( VICA UK 6 ZONE [FAP]) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Solar Panel 200W.jpg",
        featured: false
    },
        {
        id: "H064",
        name: "PANEL (1 ZONE FAP CHLORIDE UK)",
        category: "Home Automation, Alarm & Surveillance",
        price: 120000,
        description: "PANEL (1 ZONE FAP CHLORIDE UK) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Solar Panel 200W.jpg",
        featured: false
    },
        {
        id: "H065",
        name: "PANEL (2 ZONE FAP CHLORIDE UK)",
        category: "Home Automation, Alarm & Surveillance",
        price: 125000,
        description: "PANEL (2 ZONE FAP CHLORIDE UK) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Solar Panel 200W.jpg",
        featured: false
    },
        {
        id: "H066",
        name: "PANEL (2 ZONE FAP ZETA)",
        category: "Home Automation, Alarm & Surveillance",
        price: 0,
        description: "PANEL (2 ZONE FAP ZETA) \u2014 Home Automation, Alarm & Surveillance equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/Solar Panel 200W.jpg",
        featured: false
    },
        {
        id: "H067",
        name: "PANEL (CHLORIDE OPTICAL UK 4 ZONE [FAP])",
        category: "Home Automation, Alarm & Surveillance",
        price: 0,
        description: "PANEL (CHLORIDE OPTICAL UK 4 ZONE [FAP]) \u2014 Home Automation, Alarm & Surveillance equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/Solar Panel 200W.jpg",
        featured: false
    },
        {
        id: "H068",
        name: "PANEL (C-TECH-FF380-2) 2 ZONE FAP",
        category: "Home Automation, Alarm & Surveillance",
        price: 95000,
        description: "PANEL (C-TECH-FF380-2) 2 ZONE FAP \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Solar Panel 200W.jpg",
        featured: false
    },
        {
        id: "H069",
        name: "PANEL (MAXLOGIC 2 ZONE FIRE ALARM PANEL [FAP])",
        category: "Home Automation, Alarm & Surveillance",
        price: 0,
        description: "PANEL (MAXLOGIC 2 ZONE FIRE ALARM PANEL [FAP]) \u2014 Home Automation, Alarm & Surveillance equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/Solar Panel 200W.jpg",
        featured: false
    },
        {
        id: "H070",
        name: "PANEL (TEXECOM/VARITAS 8 BUGLAR ALARM PANEL)",
        category: "Home Automation, Alarm & Surveillance",
        price: 0,
        description: "PANEL (TEXECOM/VARITAS 8 BUGLAR ALARM PANEL) \u2014 Home Automation, Alarm & Surveillance equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/Solar Panel 200W.jpg",
        featured: false
    },
        {
        id: "H071",
        name: "PANEL (VICA UK 1 ZONE [FAP])",
        category: "Home Automation, Alarm & Surveillance",
        price: 0,
        description: "PANEL (VICA UK 1 ZONE [FAP]) \u2014 Home Automation, Alarm & Surveillance equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/Solar Panel 200W.jpg",
        featured: false
    },
        {
        id: "H072",
        name: "PANEL (VICA UK 2 ZONE [FAP])",
        category: "Home Automation, Alarm & Surveillance",
        price: 95000,
        description: "PANEL (VICA UK 2 ZONE [FAP]) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Solar Panel 200W.jpg",
        featured: true
    },
        {
        id: "H073",
        name: "PANEL (VICA UK 4 ZONE [FAP])",
        category: "Home Automation, Alarm & Surveillance",
        price: 145000,
        description: "PANEL (VICA UK 4 ZONE [FAP]) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Solar Panel 200W.jpg",
        featured: false
    },
        {
        id: "H074",
        name: "PANIC BUTTON",
        category: "Home Automation, Alarm & Surveillance",
        price: 5000,
        description: "PANIC BUTTON \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H075",
        name: "PSU EIGHT CHANNELS",
        category: "Home Automation, Alarm & Surveillance",
        price: 26000,
        description: "PSU EIGHT CHANNELS \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H076",
        name: "PSU EIGHTEEN CHANNEL (20A /30A)",
        category: "Home Automation, Alarm & Surveillance",
        price: 32000,
        description: "PSU EIGHTEEN CHANNEL (20A /30A) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H077",
        name: "PSU FOUR CHANNELS",
        category: "Home Automation, Alarm & Surveillance",
        price: 21000,
        description: "PSU FOUR CHANNELS \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H078",
        name: "SIREN (MINI MOTOR SIREN MS 190)",
        category: "Home Automation, Alarm & Surveillance",
        price: 0,
        description: "SIREN (MINI MOTOR SIREN MS 190) \u2014 Home Automation, Alarm & Surveillance equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H079",
        name: "SIREN (MOTOR SIREN (MS- 290 12VDC)",
        category: "Home Automation, Alarm & Surveillance",
        price: 30000,
        description: "SIREN (MOTOR SIREN (MS- 290 12VDC) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H080",
        name: "SIREN (MOTOR SIREN MS -290 220VAC/240VAC)",
        category: "Home Automation, Alarm & Surveillance",
        price: 0,
        description: "SIREN (MOTOR SIREN MS -290 220VAC/240VAC) \u2014 Home Automation, Alarm & Surveillance equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H081",
        name: "SIREN (MOTOR SIREN: MS 290 24VDC)",
        category: "Home Automation, Alarm & Surveillance",
        price: 25000,
        description: "SIREN (MOTOR SIREN: MS 290 24VDC) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H082",
        name: "SIREN KIDI",
        category: "Home Automation, Alarm & Surveillance",
        price: 15000,
        description: "SIREN KIDI \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H083",
        name: "SIREN (ONE TONE SIREN HORN)",
        category: "Home Automation, Alarm & Surveillance",
        price: 15000,
        description: "SIREN (ONE TONE SIREN HORN) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "H084",
        name: "SIREN (ZETA CYLINDRICAL SHAPE)",
        category: "Home Automation, Alarm & Surveillance",
        price: 25000,
        description: "SIREN (ZETA CYLINDRICAL SHAPE) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: true
    },
        {
        id: "H085",
        name: "SIREN (ZETA SQUARE SHAPE)",
        category: "Home Automation, Alarm & Surveillance",
        price: 20000,
        description: "SIREN (ZETA SQUARE SHAPE) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H086",
        name: "SIREN HORN SPEAKER",
        category: "Home Automation, Alarm & Surveillance",
        price: 0,
        description: "SIREN HORN SPEAKER \u2014 Home Automation, Alarm & Surveillance equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/DCP_50kg_Fire_Extinguisher.jpg",
        featured: false
    },
        {
        id: "H087",
        name: "SIREN INFINITY PLUS 24V/IR -065",
        category: "Home Automation, Alarm & Surveillance",
        price: 30000,
        description: "SIREN INFINITY PLUS 24V/IR -065 \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H088",
        name: "SIREN TWO (2) TONES 12V/30WATTS",
        category: "Home Automation, Alarm & Surveillance",
        price: 20000,
        description: "SIREN TWO (2) TONES 12V/30WATTS \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H089",
        name: "SIREN TWO TONES 24V/DC 30WATTS",
        category: "Home Automation, Alarm & Surveillance",
        price: 22000,
        description: "SIREN TWO TONES 24V/DC 30WATTS \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H090",
        name: "SIREN ZETA (CYLINDRICAL SHAPE)",
        category: "Home Automation, Alarm & Surveillance",
        price: 28000,
        description: "SIREN ZETA (CYLINDRICAL SHAPE) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H091",
        name: "SIX TONE SIREN (ES 200 ELECTRONIC SIREN)",
        category: "Home Automation, Alarm & Surveillance",
        price: 25000,
        description: "SIX TONE SIREN (ES 200 ELECTRONIC SIREN) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H092",
        name: "SMOKE ALARM (STAND ALONE [CEMAT/LX98B])",
        category: "Home Automation, Alarm & Surveillance",
        price: 12000,
        description: "SMOKE ALARM (STAND ALONE [CEMAT/LX98B]) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H093",
        name: "SMOKE ALARM (CSD-218 CHLORIDE UK)",
        category: "Home Automation, Alarm & Surveillance",
        price: 13000,
        description: "SMOKE ALARM (CSD-218 CHLORIDE UK) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H094",
        name: "SMOKE ALARM (FSD-418 CHLORIDE UK)",
        category: "Home Automation, Alarm & Surveillance",
        price: 11000,
        description: "SMOKE ALARM (FSD-418 CHLORIDE UK) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H095",
        name: "SMOKE ALARM (STAND ALONE [CONFIDENCE UK/AH/8ND500])",
        category: "Home Automation, Alarm & Surveillance",
        price: 6000,
        description: "SMOKE ALARM (STAND ALONE [CONFIDENCE UK/AH/8ND500]) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H096",
        name: "SMOKE ALARM (STAND ALONE [GENERAL PURPOSE])",
        category: "Home Automation, Alarm & Surveillance",
        price: 6000,
        description: "SMOKE ALARM (STAND ALONE [GENERAL PURPOSE]) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: true
    },
        {
        id: "H097",
        name: "SMOKE ALARM (STAND ALONE [JABO/JB-8O3])",
        category: "Home Automation, Alarm & Surveillance",
        price: 0,
        description: "SMOKE ALARM (STAND ALONE [JABO/JB-8O3]) \u2014 Home Automation, Alarm & Surveillance equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H098",
        name: "SMOKE ALARM (STAND ALONE [SUPER PROTECH/85DB])",
        category: "Home Automation, Alarm & Surveillance",
        price: 0,
        description: "SMOKE ALARM (STAND ALONE [SUPER PROTECH/85DB]) \u2014 Home Automation, Alarm & Surveillance equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H099",
        name: "SMOKE ALARM (VICA UK) STAND ALONE",
        category: "Home Automation, Alarm & Surveillance",
        price: 0,
        description: "SMOKE ALARM (VICA UK) STAND ALONE \u2014 Home Automation, Alarm & Surveillance equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H100",
        name: "SMOKE ALARM CHLORIDE UK (CSD-218)",
        category: "Home Automation, Alarm & Surveillance",
        price: 9000,
        description: "SMOKE ALARM CHLORIDE UK (CSD-218) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H101",
        name: "SMOKE ALARM(STAND ALONE[COMOT])",
        category: "Home Automation, Alarm & Surveillance",
        price: 0,
        description: "SMOKE ALARM(STAND ALONE[COMOT]) \u2014 Home Automation, Alarm & Surveillance equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H102",
        name: "SMOKE DETECTOR (NUMENS/SNC300-52)",
        category: "Home Automation, Alarm & Surveillance",
        price: 0,
        description: "SMOKE DETECTOR (NUMENS/SNC300-52) \u2014 Home Automation, Alarm & Surveillance equipment. Price on request. Contact M-Tek for current price and availability.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H103",
        name: "SMOKE DETECTOR ( GENT NON-ADDRESSABLE)",
        category: "Home Automation, Alarm & Surveillance",
        price: 20000,
        description: "SMOKE DETECTOR ( GENT NON-ADDRESSABLE) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H104",
        name: "SMOKE DETECTOR (CHLORIDE UK [AH-388-2])",
        category: "Home Automation, Alarm & Surveillance",
        price: 15000,
        description: "SMOKE DETECTOR (CHLORIDE UK [AH-388-2]) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H105",
        name: "SMOKE DETECTOR (ZETA P/ PART NO:80-022)",
        category: "Home Automation, Alarm & Surveillance",
        price: 18000,
        description: "SMOKE DETECTOR (ZETA P/ PART NO:80-022) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H106",
        name: "SMOKE DETECTOR (ZETA/ PART NO: 80-200)",
        category: "Home Automation, Alarm & Surveillance",
        price: 20000,
        description: "SMOKE DETECTOR (ZETA/ PART NO: 80-200) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H107",
        name: "SMOKE DETECTOR CHLORIDE MODEL: CSD-588-2",
        category: "Home Automation, Alarm & Surveillance",
        price: 10000,
        description: "SMOKE DETECTOR CHLORIDE MODEL: CSD-588-2 \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H108",
        name: "SOUND LIGHT (FIRE SIREN ALARM)",
        category: "Home Automation, Alarm & Surveillance",
        price: 40000,
        description: "SOUND LIGHT (FIRE SIREN ALARM) \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: true
    },
        {
        id: "H109",
        name: "SOUNDER BEACON (CHLORIDE UK) [AH-318-SF]",
        category: "Home Automation, Alarm & Surveillance",
        price: 30000,
        description: "SOUNDER BEACON (CHLORIDE UK) [AH-318-SF] \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/solar bulb.jpg",
        featured: false
    },
        {
        id: "H110",
        name: "SOUNDER BEACON (WR -06BS VICA UK ) 24VDC",
        category: "Home Automation, Alarm & Surveillance",
        price: 30000,
        description: "SOUNDER BEACON (WR -06BS VICA UK ) 24VDC \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/solar bulb.jpg",
        featured: false
    },
        {
        id: "H111",
        name: "TABLE PHONE (HUAWEI)F316",
        category: "Home Automation, Alarm & Surveillance",
        price: 18000,
        description: "TABLE PHONE (HUAWEI)F316 \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
        {
        id: "H112",
        name: "VIDEO BALLON",
        category: "Home Automation, Alarm & Surveillance",
        price: 4000,
        description: "VIDEO BALLON \u2014 Home Automation, Alarm & Surveillance equipment from M-Tek Fire & Safety Ltd.",
        image: "assets/products/Zeta Smoke Detector.jpg",
        featured: false
    },
];

// Expose for environments that read it via window (defensive; bare identifier works too)
if (typeof window !== "undefined") {
  window.MTEK_PRODUCTS = MTEK_PRODUCTS;
}