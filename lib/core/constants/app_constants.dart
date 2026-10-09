/// ثوابت النظام المالي
class AppConstants {
  // مفاتيح الإعدادات في قاعدة البيانات
  static const String keyShopName = 'shop_name';
  static const String keyShopPhone = 'shop_phone';
  static const String keyShopAddress = 'shop_address';
  static const String keyShopTaxNumber = 'shop_tax_number';
  static const String keyCurrencySymbol = 'currency_symbol';
  static const String keyEnableBeep = 'enable_beep_sound';
  static const String keyAllowNegativeStock = 'allow_negative_stock';
  static const String keyTaxRate = 'default_tax_rate';

  // القيم الافتراضية
  static const String defaultShopName = 'المتجر المالي';
  static const String defaultCurrency = 'ر.س';
  static const double defaultTaxRate = 15.0;

  // طرق الدفع
  static const String paymentCash = 'نقد';
  static const String paymentCard = 'شبكة/بطاقة';
  static const String paymentCheck = 'شيك';
  static const String paymentCredit = 'آجل/ذمة';

  // أنواع الفواتير
  static const String invoiceTypeSale = 'sale';
  static const String invoiceTypePurchase = 'purchase';
  static const String invoiceTypeSaleReturn = 'sale_return';
  static const String invoiceTypePurchaseReturn = 'purchase_return';

  // حالات المنتجات
  static const String productStatusAvailable = 'متوفر';
  static const String productStatusFrozen = 'مجمد';
  static const String productStatusOutOfStock = 'غير متوفر';

  // أنواع حركات الصندوق
  static const String cashDeposit = 'إيداع';
  static const String cashWithdrawal = 'صرف';
}
