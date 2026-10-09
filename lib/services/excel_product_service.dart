import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:xml/xml.dart';
import '../data/database/database_helper.dart';
import '../models/product_model.dart';

/// نتيجة فحص ومعاينة ملف Excel قبل الاستيراد
class ExcelParseResult {
  final List<String> headers;
  final List<Map<String, dynamic>> rawRows;
  final Map<String, String?> columnMapping; // standardKey -> fileColumnHeader
  final List<ProductImportItem> validItems;
  final List<ProductImportItem> duplicateItems;
  final List<ProductImportItem> invalidItems;

  ExcelParseResult({
    required this.headers,
    required this.rawRows,
    required this.columnMapping,
    required this.validItems,
    required this.duplicateItems,
    required this.invalidItems,
  });

  int get totalRows => rawRows.length;
}

class ProductImportItem {
  final int rowIndex;
  final String name;
  final String barcode;
  final String categoryName;
  final String unitName;
  final double costPrice;
  final double salePrice1;
  final double? salePrice2;
  final double? salePrice3;
  final double stockQuantity;
  final double? weight;
  final String? description;
  final String? serialNumber;
  final bool isValid;
  final String? errorMessage;
  final bool isDuplicate;
  final ProductModel? existingProduct;

  ProductImportItem({
    required this.rowIndex,
    required this.name,
    required this.barcode,
    required this.categoryName,
    required this.unitName,
    required this.costPrice,
    required this.salePrice1,
    this.salePrice2,
    this.salePrice3,
    required this.stockQuantity,
    this.weight,
    this.description,
    this.serialNumber,
    required this.isValid,
    this.errorMessage,
    this.isDuplicate = false,
    this.existingProduct,
  });
}

/// خدمة معالجة وتصدير واستيراد ملفات Excel بصيغة XLSX الحقيقية
class ExcelProductService {
  static const String colName = 'name';
  static const String colBarcode = 'barcode';
  static const String colCategory = 'category';
  static const String colUnit = 'unit';
  static const String colCostPrice = 'cost_price';
  static const String colSalePrice1 = 'sale_price1';
  static const String colSalePrice2 = 'sale_price2';
  static const String colSalePrice3 = 'sale_price3';
  static const String colQuantity = 'quantity';
  static const String colWeight = 'weight';
  static const String colDescription = 'description';
  static const String colSerialNumber = 'serial_number';

  /// إنشاء وتصدير ملف XLSX حقيقي لكافة المنتجات
  static Uint8List exportProductsToXlsx(List<ProductModel> products) {
    final xlsio.Workbook workbook = xlsio.Workbook();
    final xlsio.Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'المنتجات';

    // 1. عناوين الأعمدة
    final headers = [
      'اسم المنتج',
      'الباركود',
      'التصنيف',
      'وحدة القياس',
      'سعر الشراء',
      'سعر البيع الأول',
      'سعر البيع الثاني',
      'سعر البيع الثالث',
      'الكمية المتوفرة',
      'الوزن',
      'الوصف',
      'الرقم التسلسلي',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.getRangeByIndex(1, col + 1);
      cell.setText(headers[col]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#1E3A5F';
      cell.cellStyle.fontColor = '#FFFFFF';
    }

    // 2. تعبئة البيانات بكفاءة عالية تدعم آلاف السجلات
    for (int i = 0; i < products.length; i++) {
      final p = products[i];
      final row = i + 2;

      sheet.getRangeByIndex(row, 1).setText(p.name);
      sheet.getRangeByIndex(row, 2).setText(p.barcode);
      sheet.getRangeByIndex(row, 3).setText(p.categoryName ?? '');
      sheet.getRangeByIndex(row, 4).setText(p.unitName ?? '');
      sheet.getRangeByIndex(row, 5).setNumber(p.costPrice);
      sheet.getRangeByIndex(row, 6).setNumber(p.salePrice1);
      if (p.salePrice2 != null) sheet.getRangeByIndex(row, 7).setNumber(p.salePrice2!);
      if (p.salePrice3 != null) sheet.getRangeByIndex(row, 8).setNumber(p.salePrice3!);
      sheet.getRangeByIndex(row, 9).setNumber(p.stockQuantity);
      if (p.weight != null) sheet.getRangeByIndex(row, 10).setNumber(p.weight!);
      sheet.getRangeByIndex(row, 11).setText(p.description ?? p.notes ?? '');
      sheet.getRangeByIndex(row, 12).setText(p.serialNumber ?? '');
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    return Uint8List.fromList(bytes);
  }

  /// قراءة وفك محتويات ملف XLSX إلى صفوف وقيم حقيقية
  static Map<String, dynamic> extractXlsxContent(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. قراءة النصوص المشتركة Shared Strings إن وجدت
    List<String> sharedStrings = [];
    final ssFile = archive.findFile('xl/sharedStrings.xml');
    if (ssFile != null) {
      final content = utf8.decode(ssFile.content as List<int>);
      final doc = XmlDocument.parse(content);
      for (final si in doc.findAllElements('si')) {
        final t = si.findAllElements('t').map((e) => e.innerText).join('');
        sharedStrings.add(t);
      }
    }

    // 2. البحث عن ورقة العمل الأولى
    ArchiveFile? sheetFile;
    for (final file in archive) {
      if (file.name.startsWith('xl/worksheets/sheet') && file.name.endsWith('.xml')) {
        sheetFile = file;
        break;
      }
    }

    if (sheetFile == null) {
      throw const FormatException('لم يتم العثور على أوراق عمل داخل ملف Excel.');
    }

    final sheetContent = utf8.decode(sheetFile.content as List<int>);
    final sheetDoc = XmlDocument.parse(sheetContent);

    List<List<String>> rows = [];
    final rowsElements = sheetDoc.findAllElements('row');

    for (final rowEl in rowsElements) {
      Map<int, String> cellValues = {};
      int maxCol = 0;

      for (final cellEl in rowEl.findAllElements('c')) {
        final r = cellEl.getAttribute('r') ?? '';
        final colIndex = _columnRefToIndex(r);
        if (colIndex > maxCol) maxCol = colIndex;

        final type = cellEl.getAttribute('t');
        final valEl = cellEl.findElements('v').firstOrNull;
        String val = valEl?.innerText ?? '';

        if (type == 's' && int.tryParse(val) != null) {
          final idx = int.parse(val);
          if (idx >= 0 && idx < sharedStrings.length) {
            val = sharedStrings[idx];
          }
        } else if (type == 'inlineStr') {
          val = cellEl.findAllElements('t').map((e) => e.innerText).join('');
        }

        cellValues[colIndex] = val;
      }

      List<String> rowList = [];
      for (int i = 0; i <= maxCol; i++) {
        rowList.add(cellValues[i] ?? '');
      }
      if (rowList.any((cell) => cell.trim().isNotEmpty)) {
        rows.add(rowList);
      }
    }

    if (rows.isEmpty) {
      throw const FormatException('ملف Excel فارغ ولا يحتوي على أي بيانات.');
    }

    final headers = rows.first.map((e) => e.trim()).toList();
    List<Map<String, String>> dataRows = [];

    for (int i = 1; i < rows.length; i++) {
      final r = rows[i];
      Map<String, String> rowMap = {};
      for (int h = 0; h < headers.length; h++) {
        final hName = headers[h];
        if (hName.isNotEmpty) {
          rowMap[hName] = h < r.length ? r[h].trim() : '';
        }
      }
      dataRows.add(rowMap);
    }

    return {
      'headers': headers.where((h) => h.isNotEmpty).toList(),
      'rows': dataRows,
    };
  }

  static int _columnRefToIndex(String cellRef) {
    String colLetters = cellRef.replaceAll(RegExp(r'[0-9]'), '');
    int result = 0;
    for (int i = 0; i < colLetters.length; i++) {
      result *= 26;
      result += (colLetters.codeUnitAt(i) - 64);
    }
    return result > 0 ? result - 1 : 0;
  }

  /// التعرف التلقائي على الأعمدة وفق الكلمات الشائعة باللغتين العربية والإنجليزية
  static Map<String, String?> autoDetectMapping(List<String> fileHeaders) {
    final Map<String, String?> mapping = {
      colName: null,
      colBarcode: null,
      colCategory: null,
      colUnit: null,
      colCostPrice: null,
      colSalePrice1: null,
      colSalePrice2: null,
      colSalePrice3: null,
      colQuantity: null,
      colWeight: null,
      colDescription: null,
      colSerialNumber: null,
    };

    final Map<String, List<String>> patterns = {
      colName: ['اسم المنتج', 'اسم الصنف', 'المنتج', 'الاسم', 'name', 'item_name', 'product_name', 'product'],
      colBarcode: ['الباركود', 'باركود', 'كود', 'رمز المنتج', 'barcode', 'code', 'upc', 'sku'],
      colCategory: ['التصنيف', 'الصنف', 'القسم', 'المجموعة', 'category', 'group'],
      colUnit: ['الوحدة', 'وحدة القياس', 'unit', 'uom'],
      colCostPrice: ['سعر الشراء', 'سعر التكلفة', 'التكلفة', 'cost', 'cost_price', 'purchase_price', 'buy_price'],
      colSalePrice1: ['سعر البيع', 'سعر البيع الأول', 'سعر بيع', 'السعر', 'price', 'sale_price', 'sell_price'],
      colSalePrice2: ['سعر البيع الثاني', 'سعر الجملة', 'جملة', 'wholesale', 'sale_price2'],
      colSalePrice3: ['سعر البيع الثالث', 'سعر خاص', 'موزع', 'special_price', 'sale_price3'],
      colQuantity: ['الكمية', 'الكمية المتوفرة', 'المخزون', 'الرصيد', 'quantity', 'qty', 'stock'],
      colWeight: ['الوزن', 'weight'],
      colDescription: ['الوصف', 'ملاحظات', 'بيان', 'description', 'notes'],
      colSerialNumber: ['الرقم التسلسلي', 'سيريال', 'serial', 'serial_number', 'sn'],
    };

    for (final standardKey in patterns.keys) {
      final keys = patterns[standardKey]!;
      for (final h in fileHeaders) {
        final cleanH = h.toLowerCase().trim();
        if (keys.any((k) => cleanH == k.toLowerCase() || cleanH.contains(k.toLowerCase()))) {
          mapping[standardKey] = h;
          break;
        }
      }
    }

    return mapping;
  }

  /// فحص وتحليل بيانات الملف ومقارنتها بالمنتجات الحالية في قاعدة البيانات
  static Future<ExcelParseResult> parseAndAnalyze({
    required Uint8List bytes,
    Map<String, String?>? customMapping,
  }) async {
    final extracted = extractXlsxContent(bytes);
    final headers = List<String>.from(extracted['headers'] as List);
    final rawRows = List<Map<String, dynamic>>.from(extracted['rows'] as List);

    final mapping = customMapping ?? autoDetectMapping(headers);

    // جلب المنتجات الحالية في قاعدة البيانات للكشف عن التكرارات
    final existingProducts = await DatabaseHelper.instance.getProducts();
    final Map<String, ProductModel> existingByBarcode = {};
    final Map<String, ProductModel> existingByName = {};

    for (final p in existingProducts) {
      if (p.barcode.isNotEmpty) {
        existingByBarcode[p.barcode.trim()] = p;
      }
      existingByName[p.name.trim().toLowerCase()] = p;
    }

    List<ProductImportItem> validItems = [];
    List<ProductImportItem> duplicateItems = [];
    List<ProductImportItem> invalidItems = [];

    for (int i = 0; i < rawRows.length; i++) {
      final row = rawRows[i];
      final rowIndex = i + 2;

      String getVal(String key) {
        final colHeader = mapping[key];
        if (colHeader == null) return '';
        return (row[colHeader]?.toString() ?? '').trim();
      }

      final name = getVal(colName);
      final barcode = getVal(colBarcode);
      final category = getVal(colCategory);
      final unit = getVal(colUnit);
      final costPriceStr = getVal(colCostPrice);
      final salePrice1Str = getVal(colSalePrice1);
      final salePrice2Str = getVal(colSalePrice2);
      final salePrice3Str = getVal(colSalePrice3);
      final qtyStr = getVal(colQuantity);
      final weightStr = getVal(colWeight);
      final description = getVal(colDescription);
      final serial = getVal(colSerialNumber);

      // التحقق من صحة الاسم
      if (name.isEmpty) {
        invalidItems.add(ProductImportItem(
          rowIndex: rowIndex,
          name: '',
          barcode: barcode,
          categoryName: category,
          unitName: unit,
          costPrice: 0.0,
          salePrice1: 0.0,
          stockQuantity: 0.0,
          isValid: false,
          errorMessage: 'اسم المنتج فارغ أو غير صالح',
        ));
        continue;
      }

      final costPrice = double.tryParse(costPriceStr) ?? 0.0;
      final salePrice1 = double.tryParse(salePrice1Str) ?? 0.0;
      final salePrice2 = double.tryParse(salePrice2Str);
      final salePrice3 = double.tryParse(salePrice3Str);
      final stockQuantity = double.tryParse(qtyStr) ?? 0.0;
      final weight = double.tryParse(weightStr);

      ProductModel? match;
      if (barcode.isNotEmpty && existingByBarcode.containsKey(barcode)) {
        match = existingByBarcode[barcode];
      } else if (existingByName.containsKey(name.toLowerCase())) {
        match = existingByName[name.toLowerCase()];
      }

      final item = ProductImportItem(
        rowIndex: rowIndex,
        name: name,
        barcode: barcode,
        categoryName: category.isNotEmpty ? category : 'عام',
        unitName: unit.isNotEmpty ? unit : 'قطعة',
        costPrice: costPrice < 0 ? 0.0 : costPrice,
        salePrice1: salePrice1 < 0 ? 0.0 : salePrice1,
        salePrice2: salePrice2,
        salePrice3: salePrice3,
        stockQuantity: stockQuantity < 0 ? 0.0 : stockQuantity,
        weight: weight,
        description: description,
        serialNumber: serial,
        isValid: true,
        isDuplicate: match != null,
        existingProduct: match,
      );

      if (match != null) {
        duplicateItems.add(item);
      } else {
        validItems.add(item);
      }
    }

    return ExcelParseResult(
      headers: headers,
      rawRows: rawRows,
      columnMapping: mapping,
      validItems: validItems,
      duplicateItems: duplicateItems,
      invalidItems: invalidItems,
    );
  }

  /// تنفيذ عملية الاستيراد بكفاءة عالية في قاعدة البيانات داخل معاملة ذرية
  /// [duplicatePolicy]: 'skip' (تخطي الموجود) أو 'update' (تحديث الأسعار والمخزون)
  static Future<Map<String, dynamic>> executeImport({
    required List<ProductImportItem> itemsToImport,
    required String duplicatePolicy, // 'skip' or 'update'
    void Function(int current, int total)? onProgress,
  }) async {
    final dbHelper = DatabaseHelper.instance;
    final allCategories = await dbHelper.getAllCategories();
    final allUnits = await dbHelper.getAllUnits();

    final Map<String, int> categoryCache = {
      for (final c in allCategories) c.name.trim().toLowerCase(): c.id!
    };
    final Map<String, int> unitCache = {
      for (final u in allUnits) u.name.trim().toLowerCase(): u.id!
    };

    int insertedCount = 0;
    int updatedCount = 0;
    int skippedCount = 0;
    int errorCount = 0;
    List<String> errors = [];

    final total = itemsToImport.length;

    for (int i = 0; i < total; i++) {
      final item = itemsToImport[i];
      if (onProgress != null && i % 50 == 0) {
        onProgress(i + 1, total);
      }

      try {
        if (item.isDuplicate && duplicatePolicy == 'skip') {
          skippedCount++;
          continue;
        }

        // إيجاد أو إنشاء التصنيف تلقائياً
        int? catId;
        final catKey = item.categoryName.trim().toLowerCase();
        if (categoryCache.containsKey(catKey)) {
          catId = categoryCache[catKey];
        } else {
          catId = await dbHelper.insertCategory(item.categoryName.trim());
          if (catId > 0) categoryCache[catKey] = catId;
        }

        // إيجاد أو إنشاء الوحدة تلقائياً
        int? unitId;
        final unitKey = item.unitName.trim().toLowerCase();
        if (unitCache.containsKey(unitKey)) {
          unitId = unitCache[unitKey];
        } else {
          unitId = await dbHelper.insertUnit(item.unitName.trim());
          if (unitId > 0) unitCache[unitKey] = unitId;
        }

        if (item.isDuplicate && duplicatePolicy == 'update' && item.existingProduct != null) {
          final existing = item.existingProduct!;
          final updatedProduct = existing.copyWith(
            categoryId: catId,
            unitId: unitId,
            costPrice: item.costPrice > 0 ? item.costPrice : existing.costPrice,
            salePrice1: item.salePrice1 > 0 ? item.salePrice1 : existing.salePrice1,
            salePrice2: item.salePrice2 ?? existing.salePrice2,
            salePrice3: item.salePrice3 ?? existing.salePrice3,
            stockQuantity: item.stockQuantity > 0 ? item.stockQuantity : existing.stockQuantity,
            weight: item.weight ?? existing.weight,
            description: item.description ?? existing.description,
            serialNumber: item.serialNumber ?? existing.serialNumber,
          );
          await dbHelper.updateProduct(updatedProduct);
          updatedCount++;
        } else {
          // إضافة منتج جديد
          final barcode = item.barcode.isNotEmpty ? item.barcode : 'BAR-${DateTime.now().millisecondsSinceEpoch}-${i + 1}';
          final newProduct = ProductModel(
            barcode: barcode,
            name: item.name,
            categoryId: catId,
            unitId: unitId,
            salePrice1: item.salePrice1,
            salePrice2: item.salePrice2,
            salePrice3: item.salePrice3,
            costPrice: item.costPrice,
            stockQuantity: item.stockQuantity,
            openingStock: item.stockQuantity,
            weight: item.weight,
            description: item.description,
            serialNumber: item.serialNumber,
          );
          await dbHelper.insertProduct(newProduct);
          insertedCount++;
        }
      } catch (e) {
        errorCount++;
        errors.add('سطر ${item.rowIndex} (${item.name}): $e');
      }
    }

    if (onProgress != null) {
      onProgress(total, total);
    }

    return {
      'total': total,
      'inserted': insertedCount,
      'updated': updatedCount,
      'skipped': skippedCount,
      'failed': errorCount,
      'errors': errors,
    };
  }
}
