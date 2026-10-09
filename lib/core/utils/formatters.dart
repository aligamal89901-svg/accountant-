import 'package:intl/intl.dart';

/// أدوات التنسيق والتفقيط المالي باللغة العربية
class Formatters {
  static final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en');
  static final NumberFormat _integerFormat = NumberFormat('#,##0', 'en');
  /// تنسيق المبالغ المالية مع الفاصلة العشرية
  static String formatCurrency(double amount, [String currency = 'ر.س']) {
    return '${_currencyFormat.format(amount)} $currency';
  }

  /// تنسيق الأرقام والكميات
  static String formatNumber(num number) {
    if (number is int || number == number.roundToDouble()) {
      return _integerFormat.format(number.toInt());
    }
    return _currencyFormat.format(number);
  }

  /// تنسيق التاريخ
  static String formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  /// تنسيق التاريخ والوقت
  static String formatDateTime(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final hour = date.hour;
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final min = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'م' : 'ص';
    return '$y/$m/$d ${h.toString().padLeft(2, '0')}:$min $period';
  }

  /// التفقيط باللغة العربية (تحويل الرقم إلى كلمات)
  /// مثال: 690 -> "ستمائة وتسعون ريالاً لا غير"
  static String tafqeet(double amount, [String currency = 'ريال']) {
    if (amount == 0) return 'صفر $currency لا غير';
    if (amount < 0) return 'سالب ${tafqeet(-amount, currency)}';

    final int integerPart = amount.floor();
    final int decimalPart = ((amount - integerPart) * 100).round();

    String result = _convertIntegerToArabicWords(integerPart);
    result = '$result $currency';

    if (decimalPart > 0) {
      result += ' و${_convertIntegerToArabicWords(decimalPart)} هللة';
    }

    return '$result لا غير';
  }

  static String _convertIntegerToArabicWords(int number) {
    if (number == 0) return 'صفر';

    final List<String> ones = [
      '', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة',
      'عشرة', 'أحد عشر', 'اثنا عشر', 'ثلاثة عشر', 'أربعة عشر', 'خمسة عشر', 'ستة عشر',
      'سبعة عشر', 'ثمانية عشر', 'تسعة عشر'
    ];

    final List<String> tens = [
      '', '', 'عشرون', 'ثلاثون', 'أربعون', 'خمسون', 'ستون', 'سبعون', 'ثمانون', 'تسعون'
    ];

    final List<String> hundreds = [
      '', 'مائة', 'مائتان', 'ثلاثمائة', 'أربعمائة', 'خمسمائة', 'ستمائة', 'سبعمائة', 'ثمانمائة', 'تسعمائة'
    ];

    String convertLessThanThousand(int n) {
      String str = '';
      final int h = n ~/ 100;
      final int remainder = n % 100;

      if (h > 0) {
        str += hundreds[h];
      }

      if (remainder > 0) {
        if (str.isNotEmpty) str += ' و';
        if (remainder < 20) {
          str += ones[remainder];
        } else {
          final int t = remainder ~/ 10;
          final int o = remainder % 10;
          if (o > 0) {
            str += '${ones[o]} و${tens[t]}';
          } else {
            str += tens[t];
          }
        }
      }

      return str;
    }

    if (number < 1000) {
      return convertLessThanThousand(number);
    }

    final int billions = number ~/ 1000000000;
    int rem = number % 1000000000;
    final int millions = rem ~/ 1000000;
    rem = rem % 1000000;
    final int thousands = rem ~/ 1000;
    final int rest = rem % 1000;

    List<String> parts = [];

    if (billions > 0) {
      if (billions == 1) {
        parts.add('مليار');
      } else if (billions == 2) {
        parts.add('ملياران');
      } else {
        parts.add('${convertLessThanThousand(billions)} مليار');
      }
    }

    if (millions > 0) {
      if (millions == 1) {
        parts.add('مليون');
      } else if (millions == 2) {
        parts.add('مليونان');
      } else if (millions >= 3 && millions <= 10) {
        parts.add('${convertLessThanThousand(millions)} ملايين');
      } else {
        parts.add('${convertLessThanThousand(millions)} مليون');
      }
    }

    if (thousands > 0) {
      if (thousands == 1) {
        parts.add('ألف');
      } else if (thousands == 2) {
        parts.add('ألفان');
      } else if (thousands >= 3 && thousands <= 10) {
        parts.add('${convertLessThanThousand(thousands)} آلاف');
      } else {
        parts.add('${convertLessThanThousand(thousands)} ألف');
      }
    }

    if (rest > 0) {
      parts.add(convertLessThanThousand(rest));
    }

    return parts.join(' و');
  }
}
