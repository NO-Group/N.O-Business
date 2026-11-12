/// M-Tek corporate branding — EXACT text from the physical forms
/// (docs/forms/FORM_LAYOUTS.md). Used by every PDF header block.
abstract final class MtekBranding {
  static const companyName = 'M-TEK FIRE & SAFETY LTD.';
  static const rcNumber = 'RC: 1082534';

  static const servicesLine =
      '*Sales *Supplies *Installations *Refilling *Maintenance *Training *Consultancy';

  static const fireEquipment =
      'FIRE EQUIPMENT: FM 200, Fire Extinguishers, Fire Alarm Systems, Fire Hose Reels, '
      'Fire Hydrants, Water Sprinkler, Flame Fighting Hoses, Fire Tenders, Fire Proof Safes etc';
  static const safetyEquipment =
      'SAFETY EQUIPMENT: Chemical Masks, Carbon Cones, High Visibility Jackets, '
      'Breathing Apparatus, Safety Boots, Hand Gloves, Traffic Baton etc.';
  static const securityEquipment =
      'SECURITY EQUIPMENT: Burglar Alarms, Metal Detectors, Bomb Detectors, Under Car '
      'Search Mirror, Motion Detectors, Security Personnel Kits etc';
  static const solarEquipment =
      'SOLAR EQUIPMENT: Inverters, Solar Panels, Deep Cycle Batteries, Charge Controllers etc';

  static const headOffice =
      'HEAD OFFICE: YY12, Kazaure Road, By Lagos Street Round About, Kaduna.';
  static const ceoPhone = '+2348033498452';
  static const headOfficeTel = 'Tel: +2348033498452';
  static const email = 'mtekfiresafetyltd@gmail.com';
  static const website = 'www.mtekLtd.com.ng';

  /// Single-office contact block used on every generated document.
  static const officeBlock =
      'HEAD OFFICE: YY12, Kazaure Road, By Lagos Street Round About, Kaduna. '
      'Tel: +2348033498452\n'
      'E-mail: mtekfiresafetyltd@gmail.com\n'
      'Website: www.mtekLtd.com.ng';


  static const receiptDisclaimer =
      'No guarantee cover on tested goods and services. Purchased tested goods and '
      'services cannot be returned.\nWe bear no liability on part paid and abandoned '
      'goods. This document is invalid without stamp and seal of this company.';

  static const invoiceDisclaimer =
      'No guarantee cover on tested goods and services. We bear no liability on part '
      'paid and abandoned goods. This document is invalid without stamp and seal of this company.';

  /// MILS fine print (transcribed from photo — owner to confirm wording).
  static const milsCaution =
      'Caution: Payment can only commence upon the payment of at least 50% value of the '
      'maintenance charges. No equipment is collected for repair before payment. '
      'Expired/Unserviceable old equipment should be exchanged with new ones after the '
      'expiration of the collection date. Goods left 3 months after will be considered '
      'as abandoned goods and the company shall bear no liability on any abandoned equipment.';
}
