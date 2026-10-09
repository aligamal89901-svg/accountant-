import 'package:flutter/material.dart';

/// نظام الألوان والتصميم الهادئ والعصري للنظام المحاسبي المالي
class AppTheme {
  // ألوان رئيسية هادئة واحترافية (Slate Navy & Emerald Teal)
  static const Color primary = Color(0xFF1E3A5F); // أزرق كحلي هادئ واحترافي
  static const Color primaryLight = Color(0xFF2E5A88);
  static const Color primaryDark = Color(0xFF0F1E33);

  static const Color secondary = Color(0xFF0D9488); // تركواز / تيل مالي عصري
  static const Color secondaryLight = Color(0xFF14B8A6);

  static const Color background = Color(0xFFF8FAFC); // رمادي فاتح جداً مريح للعين
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF1F5F9);

  static const Color textPrimary = Color(0xFF0F172A); // كحلي مسود غامق للقراءة المريحة
  static const Color textSecondary = Color(0xFF475569); // رمادي متوسط
  static const Color textMuted = Color(0xFF94A3B8); // رمادي خفيف

  static const Color border = Color(0xFFE2E8F0); // حدود ناعمة
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color divider = Color(0xFFE2E8F0);

  // ألوان الحالة المالية
  static const Color success = Color(0xFF16A34A); // أخضر تحصيل / ربح / متوفر
  static const Color warning = Color(0xFFD97706); // برتقالي تنبيه / مخزون منخفض
  static const Color danger = Color(0xFFDC2626); // أحمر دين / متبقي / نفاد المخزون
  static const Color info = Color(0xFF2563EB); // أزرق معلومات
  static const Color neutral = Color(0xFF64748B); // رمادي محايد

  /// بطاقة ذات مظهر قياسي ناعم موحد
  static BoxDecoration cardDecoration({Color? color, Color? borderColor}) {
    return BoxDecoration(
      color: color ?? surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: borderColor ?? border, width: 1),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: null, // الخط الافتراضي للنظام عالي الجودة ويدعم العربية بسلاسة
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        onPrimary: Colors.white,
        secondary: secondary,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        error: danger,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: danger),
        ),
        hintStyle: const TextStyle(color: textMuted, fontSize: 13),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 48), // ارتفاع موحد للأزرار
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(0, 48), // ارتفاع موحد للأزرار
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

