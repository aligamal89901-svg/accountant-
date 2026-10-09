import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/unit_model.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../models/customer_model.dart';
import '../../models/supplier_model.dart';
import '../../models/cash_box_model.dart';
import '../../models/cash_transaction_model.dart';
import '../../models/invoice_model.dart';
import '../../models/invoice_item_model.dart';
import '../../core/constants/app_constants.dart';

/// الفئة المسؤولة عن إدارة قاعدة البيانات المحلية العلاقية (SQLite)
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('accountant_system.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final String path;
    if (kIsWeb) {
      path = filePath;
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filePath);
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: (db) async {
        if (!kIsWeb) {
          await db.execute('PRAGMA foreign_keys = ON;');
        }
      },
      onOpen: (db) async {
        await _migrateSchema(db);
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. جدول الوحدات (الوحدات الأساسية)
    await db.execute('''
      CREATE TABLE units (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 2. جدول التصنيفات
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 3. جدول المنتجات والمخزون
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT UNIQUE,
        name TEXT NOT NULL,
        category_id INTEGER,
        unit_id INTEGER,
        sale_price1 REAL NOT NULL,
        sale_price2 REAL,
        sale_price3 REAL,
        cost_price REAL NOT NULL DEFAULT 0,
        stock_quantity REAL NOT NULL DEFAULT 0,
        min_quantity REAL NOT NULL DEFAULT 5,
        tax_percent REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'متوفر',
        notes TEXT,
        created_at TEXT NOT NULL,
        weight REAL DEFAULT 0,
        description TEXT,
        image_path TEXT,
        serial_number TEXT,
        opening_stock REAL DEFAULT 0,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL,
        FOREIGN KEY (unit_id) REFERENCES units (id) ON DELETE SET NULL
      )
    ''');

    // 4. جدول العملاء
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        barcode TEXT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        city TEXT,
        tax_number TEXT,
        cr_number TEXT,
        default_price_tier INTEGER NOT NULL DEFAULT 1,
        credit_limit REAL,
        due_days INTEGER,
        notes TEXT,
        opening_balance REAL DEFAULT 0.0,
        opening_balance_date TEXT,
        opening_balance_notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // 5. جدول الموردين
    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        tax_number TEXT,
        cr_number TEXT,
        notes TEXT,
        opening_balance REAL DEFAULT 0.0,
        opening_balance_date TEXT,
        opening_balance_notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // 6. جدول الصناديق والخزائن
    await db.execute('''
      CREATE TABLE cash_boxes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        type TEXT NOT NULL DEFAULT 'نقد',
        balance REAL NOT NULL DEFAULT 0,
        is_default INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 7. جدول الفواتير (مبيعات / مشتريات)
    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT NOT NULL UNIQUE,
        type TEXT NOT NULL DEFAULT 'sale',
        customer_id INTEGER,
        supplier_id INTEGER,
        date TEXT NOT NULL,
        subtotal REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0,
        tax REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL,
        paid REAL NOT NULL,
        remaining REAL NOT NULL,
        payment_method TEXT NOT NULL,
        cash_box_id INTEGER,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'مكتملة',
        created_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE SET NULL,
        FOREIGN KEY (cash_box_id) REFERENCES cash_boxes (id) ON DELETE SET NULL
      )
    ''');

    // 8. جدول بنود الفواتير
    await db.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        unit_name TEXT,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        cost_price REAL NOT NULL DEFAULT 0,
        discount REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL,
        notes TEXT,
        FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT
      )
    ''');

    // 9. جدول حركات الصندوق (إيداع / صرف)
    await db.execute('''
      CREATE TABLE cash_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cash_box_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        description TEXT NOT NULL,
        related_account_type TEXT,
        related_id INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (cash_box_id) REFERENCES cash_boxes (id) ON DELETE RESTRICT
      )
    ''');

    // 10. جدول إعدادات النظام
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // فهارس لتحسين سرعة البحث
    await db.execute('CREATE INDEX idx_products_barcode ON products (barcode);');
    await db.execute('CREATE INDEX idx_products_name ON products (name);');
    await db.execute('CREATE INDEX idx_customers_name ON customers (name);');
    await db.execute('CREATE INDEX idx_invoices_number ON invoices (invoice_number);');
    await db.execute('CREATE INDEX idx_invoices_date ON invoices (date);');

    // البيانات التأسيسية الأولية للنظام (بدون بيانات وهمية، فقط ثوابت التشغيل)
    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    // 1. وحدات القياس الأساسية القابلة للتوسيع
    final defaultUnits = [
      'قطعة', 'كرتون', 'علبة', 'كيس', 'حبة', 'كيلو', 'غرام', 'درزن', 'طرد', 'لتر'
    ];
    for (final unit in defaultUnits) {
      await db.insert('units', {'name': unit, 'is_active': 1});
    }

    // 2. تصنيف عام افتراضي
    await db.insert('categories', {'name': 'عام', 'is_active': 1});

    // 3. عميل نقدي عام افتراضي
    await db.insert('customers', {
      'code': 'CUST-0001',
      'name': 'عميل نقدي',
      'default_price_tier': 1,
      'created_at': DateTime.now().toIso8601String(),
    });

    // 4. الصندوق الرئيسي الافتراضي
    await db.insert('cash_boxes', {
      'name': 'الصندوق الرئيسي',
      'type': 'نقد',
      'balance': 0.0,
      'is_default': 1,
      'is_active': 1,
    });

    // 5. الإعدادات الأولية
    await db.insert('app_settings', {'key': AppConstants.keyShopName, 'value': AppConstants.defaultShopName});
    await db.insert('app_settings', {'key': AppConstants.keyCurrencySymbol, 'value': AppConstants.defaultCurrency});
    await db.insert('app_settings', {'key': AppConstants.keyEnableBeep, 'value': '1'});
    await db.insert('app_settings', {'key': AppConstants.keyTaxRate, 'value': '15.0'});
  }

  /// ترقية مخطط قاعدة البيانات وإضافة الأعمدة الجديدة بأمان تام دون فقدان أي بيانات
  Future<void> _migrateSchema(Database db) async {
    try {
      // 1. ترقية جدول المنتجات (products)
      final productCols = await db.rawQuery("PRAGMA table_info(products)");
      final pNames = productCols.map((c) => c['name'] as String).toSet();
      if (!pNames.contains('weight')) {
        await db.execute('ALTER TABLE products ADD COLUMN weight REAL DEFAULT 0;');
      }
      if (!pNames.contains('description')) {
        await db.execute('ALTER TABLE products ADD COLUMN description TEXT;');
      }
      if (!pNames.contains('image_path')) {
        await db.execute('ALTER TABLE products ADD COLUMN image_path TEXT;');
      }
      if (!pNames.contains('serial_number')) {
        await db.execute('ALTER TABLE products ADD COLUMN serial_number TEXT;');
      }
      if (!pNames.contains('opening_stock')) {
        await db.execute('ALTER TABLE products ADD COLUMN opening_stock REAL DEFAULT 0;');
      }

      // 2. ترقية جدول العملاء (customers)
      final custCols = await db.rawQuery("PRAGMA table_info(customers)");
      final cNames = custCols.map((c) => c['name'] as String).toSet();
      if (!cNames.contains('opening_balance')) {
        await db.execute('ALTER TABLE customers ADD COLUMN opening_balance REAL DEFAULT 0.0;');
      }
      if (!cNames.contains('opening_balance_date')) {
        await db.execute('ALTER TABLE customers ADD COLUMN opening_balance_date TEXT;');
      }
      if (!cNames.contains('opening_balance_notes')) {
        await db.execute('ALTER TABLE customers ADD COLUMN opening_balance_notes TEXT;');
      }

      // 3. ترقية جدول الموردين (suppliers)
      final suppCols = await db.rawQuery("PRAGMA table_info(suppliers)");
      final sNames = suppCols.map((c) => c['name'] as String).toSet();
      if (!sNames.contains('opening_balance')) {
        await db.execute('ALTER TABLE suppliers ADD COLUMN opening_balance REAL DEFAULT 0.0;');
      }
      if (!sNames.contains('opening_balance_date')) {
        await db.execute('ALTER TABLE suppliers ADD COLUMN opening_balance_date TEXT;');
      }
      if (!sNames.contains('opening_balance_notes')) {
        await db.execute('ALTER TABLE suppliers ADD COLUMN opening_balance_notes TEXT;');
      }
    } catch (e) {
      debugPrint('Schema migration error: $e');
    }
  }

  // ==================== عمليات الوحدات والتصنيفات ====================
  Future<List<UnitModel>> getAllUnits() async {
    final db = await database;
    final res = await db.query('units', where: 'is_active = 1', orderBy: 'id ASC');
    return res.map((e) => UnitModel.fromMap(e)).toList();
  }

  Future<int> insertUnit(String name) async {
    final db = await database;
    return await db.insert('units', {'name': name, 'is_active': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<CategoryModel>> getAllCategories() async {
    final db = await database;
    final res = await db.query('categories', where: 'is_active = 1', orderBy: 'id ASC');
    return res.map((e) => CategoryModel.fromMap(e)).toList();
  }

  Future<int> insertCategory(String name) async {
    final db = await database;
    return await db.insert('categories', {'name': name, 'is_active': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<bool> categoryExists(String name) async {
    final db = await database;
    final res = await db.query(
      'categories',
      where: 'LOWER(TRIM(name)) = LOWER(TRIM(?)) AND is_active = 1',
      whereArgs: [name],
    );
    return res.isNotEmpty;
  }

  // ==================== عمليات المنتجات ====================
  Future<int> insertProduct(ProductModel product) async {
    final db = await database;
    return await db.insert('products', product.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateProduct(ProductModel product) async {
    final db = await database;
    return await db.update('products', product.toMap(), where: 'id = ?', whereArgs: [product.id]);
  }

  Future<int> updateProductPrices({
    required int productId,
    required double costPrice,
    required double salePrice1,
    double? salePrice2,
    double? salePrice3,
  }) async {
    final db = await database;
    return await db.update(
      'products',
      {
        'cost_price': costPrice,
        'sale_price1': salePrice1,
        'sale_price2': salePrice2,
        'sale_price3': salePrice3,
      },
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  Future<int> bulkUpdatePricesForProductIds({
    required List<int> productIds,
    double? percentageChange,
    double? fixedAmountChange,
    bool updateCost = false,
    bool updateSale1 = true,
    bool updateSale2 = true,
    bool updateSale3 = true,
  }) async {
    final db = await database;
    int count = 0;
    await db.transaction((txn) async {
      for (final id in productIds) {
        final res = await txn.query('products', where: 'id = ?', whereArgs: [id]);
        if (res.isNotEmpty) {
          final p = ProductModel.fromMap(res.first);
          double newCost = p.costPrice;
          double newSale1 = p.salePrice1;
          double? newSale2 = p.salePrice2;
          double? newSale3 = p.salePrice3;

          double applyChange(double current) {
            if (percentageChange != null) {
              return (current * (1 + percentageChange / 100.0)).clamp(0.0, 999999999.0);
            } else if (fixedAmountChange != null) {
              return (current + fixedAmountChange).clamp(0.0, 999999999.0);
            }
            return current;
          }

          if (updateCost) newCost = applyChange(newCost);
          if (updateSale1) newSale1 = applyChange(newSale1);
          if (updateSale2 && newSale2 != null) newSale2 = applyChange(newSale2);
          if (updateSale3 && newSale3 != null) newSale3 = applyChange(newSale3);

          await txn.update(
            'products',
            {
              'cost_price': newCost,
              'sale_price1': newSale1,
              'sale_price2': newSale2,
              'sale_price3': newSale3,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
          count++;
        }
      }
    });
    return count;
  }

  Future<int> deleteProductSafely(int id) async {
    final db = await database;
    // التحقق مما إذا كان المنتج مرتبطاً بأي فواتير قبل الحذف
    final invoiceCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM invoice_items WHERE product_id = ?', [id]),
    );
    if ((invoiceCount ?? 0) > 0) {
      // إذا كان له حركات سابقة، يتم تجميده فقط بدلاً من حذفه نهائياً لحماية السجلات المالية
      return await db.update('products', {'status': 'مجمد'}, where: 'id = ?', whereArgs: [id]);
    } else {
      return await db.delete('products', where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<List<ProductModel>> getProducts({String? query, int? categoryId, String? status}) async {
    final db = await database;
    String sql = '''
      SELECT p.*, c.name as category_name, u.name as unit_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN units u ON p.unit_id = u.id
      WHERE 1=1
    ''';
    List<dynamic> args = [];

    if (query != null && query.trim().isNotEmpty) {
      sql += ' AND (p.name LIKE ? OR p.barcode LIKE ?)';
      final q = '%${query.trim()}%';
      args.addAll([q, q]);
    }

    if (categoryId != null) {
      sql += ' AND p.category_id = ?';
      args.add(categoryId);
    }

    if (status != null && status.isNotEmpty) {
      sql += ' AND p.status = ?';
      args.add(status);
    }

    sql += ' ORDER BY p.id DESC';
    final res = await db.rawQuery(sql, args);
    return res.map((e) => ProductModel.fromMap(e)).toList();
  }

  Future<ProductModel?> getProductByBarcode(String barcode) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT p.*, c.name as category_name, u.name as unit_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN units u ON p.unit_id = u.id
      WHERE p.barcode = ?
      LIMIT 1
    ''', [barcode]);

    if (res.isNotEmpty) {
      return ProductModel.fromMap(res.first);
    }
    return null;
  }

  Future<ProductModel?> getProductById(int id) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT p.*, c.name as category_name, u.name as unit_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN units u ON p.unit_id = u.id
      WHERE p.id = ?
      LIMIT 1
    ''', [id]);

    if (res.isNotEmpty) {
      return ProductModel.fromMap(res.first);
    }
    return null;
  }

  // ==================== عمليات العملاء ====================
  Future<int> insertCustomer(CustomerModel customer) async {
    final db = await database;
    return await db.insert('customers', customer.toMap());
  }

  Future<int> updateCustomer(CustomerModel customer) async {
    final db = await database;
    return await db.update('customers', customer.toMap(), where: 'id = ?', whereArgs: [customer.id]);
  }

  Future<List<CustomerModel>> getCustomers({String? query}) async {
    final db = await database;
    String sql = '''
      SELECT c.*,
        (
          COALESCE(c.opening_balance, 0.0)
          + COALESCE((
              SELECT SUM(remaining) FROM invoices WHERE customer_id = c.id AND status = 'مكتملة' AND type = 'sale'
            ), 0.0)
          - COALESCE((
              SELECT SUM(amount) FROM cash_transactions 
              WHERE related_account_type = 'customer' AND related_id = c.id AND type = 'إيداع'
            ), 0.0)
        ) as calculated_balance
      FROM customers c
      WHERE 1=1
    ''';
    List<dynamic> args = [];

    if (query != null && query.trim().isNotEmpty) {
      sql += ' AND (c.name LIKE ? OR c.phone LIKE ? OR c.code LIKE ?)';
      final q = '%${query.trim()}%';
      args.addAll([q, q, q]);
    }

    sql += ' ORDER BY c.id ASC';
    final res = await db.rawQuery(sql, args);
    return res.map((e) {
      final bal = (e['calculated_balance'] as num?)?.toDouble() ?? 0.0;
      return CustomerModel.fromMap(e, balance: bal);
    }).toList();
  }

  Future<int> setCustomerOpeningBalance({
    required int customerId,
    required double amount,
    required String date,
    String? notes,
  }) async {
    final db = await database;
    return await db.update(
      'customers',
      {
        'opening_balance': amount,
        'opening_balance_date': date,
        'opening_balance_notes': notes,
      },
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }

  Future<List<Map<String, dynamic>>> auditCustomerBalances() async {
    final customers = await getCustomers();
    final db = await database;
    List<Map<String, dynamic>> audits = [];

    for (final c in customers) {
      final invoices = await db.query(
        'invoices',
        where: "customer_id = ? AND type = 'sale' AND status = 'مكتملة'",
        whereArgs: [c.id],
      );
      final double totalInvoicesRemaining = invoices.fold(0.0, (sum, row) => sum + ((row['remaining'] as num?)?.toDouble() ?? 0.0));

      final receipts = await db.query(
        'cash_transactions',
        where: "related_account_type = 'customer' AND related_id = ? AND type = 'إيداع'",
        whereArgs: [c.id],
      );
      final double totalDirectPayments = receipts.fold(0.0, (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0.0));

      final double expectedBalance = c.openingBalance + totalInvoicesRemaining - totalDirectPayments;
      final double diff = (c.currentBalance - expectedBalance).abs();

      audits.add({
        'customer': c,
        'openingBalance': c.openingBalance,
        'totalInvoicesCount': invoices.length,
        'totalInvoicesRemaining': totalInvoicesRemaining,
        'totalDirectPayments': totalDirectPayments,
        'currentBalance': c.currentBalance,
        'expectedBalance': expectedBalance,
        'isMatched': diff < 0.01,
        'difference': diff,
      });
    }

    return audits;
  }

  Future<String> generateNextCustomerCode() async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM customers')) ?? 0;
    return 'CUST-${(count + 1).toString().padLeft(4, '0')}';
  }

  // ==================== عمليات الموردين ====================
  Future<int> insertSupplier(SupplierModel supplier) async {
    final db = await database;
    return await db.insert('suppliers', supplier.toMap());
  }

  Future<int> updateSupplier(SupplierModel supplier) async {
    final db = await database;
    return await db.update('suppliers', supplier.toMap(), where: 'id = ?', whereArgs: [supplier.id]);
  }

  Future<List<SupplierModel>> getSuppliers({String? query}) async {
    final db = await database;
    String sql = '''
      SELECT s.*,
        (
          COALESCE(s.opening_balance, 0.0)
          + COALESCE((
              SELECT SUM(remaining) FROM invoices WHERE supplier_id = s.id AND status = 'مكتملة' AND type = 'purchase'
            ), 0.0)
          - COALESCE((
              SELECT SUM(amount) FROM cash_transactions 
              WHERE related_account_type = 'supplier' AND related_id = s.id AND type = 'صرف'
            ), 0.0)
        ) as calculated_balance
      FROM suppliers s
      WHERE 1=1
    ''';
    List<dynamic> args = [];

    if (query != null && query.trim().isNotEmpty) {
      sql += ' AND (s.name LIKE ? OR s.phone LIKE ? OR s.code LIKE ?)';
      final q = '%${query.trim()}%';
      args.addAll([q, q, q]);
    }

    sql += ' ORDER BY s.id ASC';
    final res = await db.rawQuery(sql, args);
    return res.map((e) {
      final bal = (e['calculated_balance'] as num?)?.toDouble() ?? 0.0;
      return SupplierModel.fromMap(e, balance: bal);
    }).toList();
  }

  Future<int> setSupplierOpeningBalance({
    required int supplierId,
    required double amount,
    required String date,
    String? notes,
  }) async {
    final db = await database;
    return await db.update(
      'suppliers',
      {
        'opening_balance': amount,
        'opening_balance_date': date,
        'opening_balance_notes': notes,
      },
      where: 'id = ?',
      whereArgs: [supplierId],
    );
  }

  Future<List<Map<String, dynamic>>> auditSupplierBalances() async {
    final suppliers = await getSuppliers();
    final db = await database;
    List<Map<String, dynamic>> audits = [];

    for (final s in suppliers) {
      final invoices = await db.query(
        'invoices',
        where: "supplier_id = ? AND type = 'purchase' AND status = 'مكتملة'",
        whereArgs: [s.id],
      );
      final double totalInvoicesRemaining = invoices.fold(0.0, (sum, row) => sum + ((row['remaining'] as num?)?.toDouble() ?? 0.0));

      final payments = await db.query(
        'cash_transactions',
        where: "related_account_type = 'supplier' AND related_id = ? AND type = 'صرف'",
        whereArgs: [s.id],
      );
      final double totalDirectPayments = payments.fold(0.0, (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0.0));

      final double expectedBalance = s.openingBalance + totalInvoicesRemaining - totalDirectPayments;
      final double diff = (s.currentBalance - expectedBalance).abs();

      audits.add({
        'supplier': s,
        'openingBalance': s.openingBalance,
        'totalInvoicesCount': invoices.length,
        'totalInvoicesRemaining': totalInvoicesRemaining,
        'totalDirectPayments': totalDirectPayments,
        'currentBalance': s.currentBalance,
        'expectedBalance': expectedBalance,
        'isMatched': diff < 0.01,
        'difference': diff,
      });
    }

    return audits;
  }

  Future<String> generateNextSupplierCode() async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM suppliers')) ?? 0;
    return 'SUP-${(count + 1).toString().padLeft(4, '0')}';
  }

  // ==================== عمليات الصناديق ====================
  Future<List<CashBoxModel>> getCashBoxes() async {
    final db = await database;
    final res = await db.query('cash_boxes', where: 'is_active = 1', orderBy: 'is_default DESC, id ASC');
    return res.map((e) => CashBoxModel.fromMap(e)).toList();
  }

  Future<int> insertCashBox(CashBoxModel cashBox) async {
    final db = await database;
    return await db.insert('cash_boxes', cashBox.toMap());
  }

  Future<CashBoxModel?> getDefaultCashBox() async {
    final db = await database;
    final res = await db.query('cash_boxes', where: 'is_default = 1', limit: 1);
    if (res.isNotEmpty) return CashBoxModel.fromMap(res.first);
    final fallback = await db.query('cash_boxes', limit: 1);
    if (fallback.isNotEmpty) return CashBoxModel.fromMap(fallback.first);
    return null;
  }

  Future<int> recordCashTransaction({
    required int cashBoxId,
    required String type,
    required double amount,
    required String description,
    String? relatedAccountType,
    int? relatedId,
  }) async {
    final db = await database;
    return await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      // 1. تسجيل الحركة
      final transId = await txn.insert('cash_transactions', {
        'cash_box_id': cashBoxId,
        'type': type,
        'amount': amount,
        'date': now,
        'description': description,
        'related_account_type': relatedAccountType,
        'related_id': relatedId,
        'created_at': now,
      });

      // 2. تحديث رصيد الصندوق فورياً وبدقة
      final delta = type == 'إيداع' ? amount : -amount;
      await txn.rawUpdate(
        'UPDATE cash_boxes SET balance = balance + ? WHERE id = ?',
        [delta, cashBoxId],
      );

      return transId;
    });
  }
  Future<int> createCashTransaction(CashTransactionModel transaction) async {
    return await recordCashTransaction(
      cashBoxId: transaction.cashBoxId,
      type: transaction.type,
      amount: transaction.amount,
      description: transaction.description,
      relatedAccountType: transaction.relatedAccountType,
      relatedId: transaction.relatedId,
    );
  }


  Future<List<CashTransactionModel>> getCashTransactions({int? cashBoxId, int limit = 50}) async {
    final db = await database;
    String sql = '''
      SELECT ct.*, cb.name as cash_box_name
      FROM cash_transactions ct
      JOIN cash_boxes cb ON ct.cash_box_id = cb.id
    ''';
    List<dynamic> args = [];
    if (cashBoxId != null) {
      sql += ' WHERE ct.cash_box_id = ?';
      args.add(cashBoxId);
    }
    sql += ' ORDER BY ct.id DESC LIMIT ?';
    args.add(limit);

    final res = await db.rawQuery(sql, args);
    return res.map((e) => CashTransactionModel.fromMap(e)).toList();
  }

  // ==================== عمليات الفواتير والبيع الكامل ====================
  Future<String> generateNextInvoiceNumber(String type) async {
    final db = await database;
    final prefix = type == 'sale' ? 'INV' : 'PUR';
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM invoices WHERE type = ?', [type]),
    ) ?? 0;
    final year = DateTime.now().year;
    return '$prefix-$year-${(count + 1).toString().padLeft(5, '0')}';
  }

  /// إنشاء الفاتورة بعملية ذرية (Atomic Transaction):
  /// - حفظ الفاتورة
  /// - حفظ البنود
  /// - خصم الكميات من المخزون
  /// - إضافة المبلغ المدفوع للصندوق إن وجد
  Future<int> createInvoiceTransaction(InvoiceModel invoice, List<InvoiceItemModel> items) async {
    final db = await database;
    return await db.transaction((txn) async {
      // 1. إدراج الفاتورة
      final invoiceId = await txn.insert('invoices', invoice.toMap());

      // 2. إدراج البنود وخصم المخزون
      for (final item in items) {
        final itemMap = item.toMap();
        itemMap['invoice_id'] = invoiceId;
        await txn.insert('invoice_items', itemMap);

        if (invoice.type == 'sale') {
          // خصم المخزون في المبيعات
          await txn.rawUpdate(
            'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
            [item.quantity, item.productId],
          );
        } else if (invoice.type == 'purchase') {
          // زيادة المخزون وتحديث سعر التكلفة/الشراء في المشتريات
          if (item.unitPrice > 0) {
            await txn.rawUpdate(
              'UPDATE products SET stock_quantity = stock_quantity + ?, cost_price = ? WHERE id = ?',
              [item.quantity, item.unitPrice, item.productId],
            );
          } else {
            await txn.rawUpdate(
              'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
              [item.quantity, item.productId],
            );
          }
        }
      }

      // 3. إذا كان هناك مبلغ مدفوع، يتم ربطه بالصندوق فورياً
      if (invoice.paid > 0 && invoice.cashBoxId != null) {
        final now = DateTime.now().toIso8601String();
        final transType = invoice.type == 'sale' ? 'إيداع' : 'صرف';
        await txn.insert('cash_transactions', {
          'cash_box_id': invoice.cashBoxId,
          'type': transType,
          'amount': invoice.paid,
          'date': invoice.date,
          'description': 'دفعة فاتورة ${invoice.type == 'sale' ? 'مبيعات' : 'مشتريات'} رقم ${invoice.invoiceNumber}',
          'related_account_type': 'فاتورة',
          'related_id': invoiceId,
          'created_at': now,
        });

        final delta = invoice.type == 'sale' ? invoice.paid : -invoice.paid;
        await txn.rawUpdate(
          'UPDATE cash_boxes SET balance = balance + ? WHERE id = ?',
          [delta, invoice.cashBoxId],
        );
      }

      return invoiceId;
    });
  }

  Future<List<InvoiceModel>> getInvoices({String? type, String? query, int limit = 50}) async {
    final db = await database;
    String sql = '''
      SELECT i.*,
        c.name as customer_name,
        s.name as supplier_name
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      LEFT JOIN suppliers s ON i.supplier_id = s.id
      WHERE 1=1
    ''';
    List<dynamic> args = [];

    if (type != null) {
      sql += ' AND i.type = ?';
      args.add(type);
    }

    if (query != null && query.trim().isNotEmpty) {
      sql += ' AND (i.invoice_number LIKE ? OR c.name LIKE ?)';
      final q = '%${query.trim()}%';
      args.addAll([q, q]);
    }

    sql += ' ORDER BY i.id DESC LIMIT ?';
    args.add(limit);

    final res = await db.rawQuery(sql, args);
    return res.map((e) => InvoiceModel.fromMap(e)).toList();
  }

  Future<List<InvoiceItemModel>> getInvoiceItems(int invoiceId) async {
    final db = await database;
    final res = await db.query('invoice_items', where: 'invoice_id = ?', whereArgs: [invoiceId]);
    return res.map((e) => InvoiceItemModel.fromMap(e)).toList();
  }

  Future<InvoiceModel?> getInvoiceById(int id) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT i.*,
        c.name as customer_name,
        s.name as supplier_name
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      LEFT JOIN suppliers s ON i.supplier_id = s.id
      WHERE i.id = ?
      LIMIT 1
    ''', [id]);
    if (res.isNotEmpty) {
      return InvoiceModel.fromMap(res.first);
    }
    return null;
  }

  Future<List<InvoiceModel>> getCustomerInvoices(int customerId) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT i.*, c.name as customer_name
      FROM invoices i
      JOIN customers c ON i.customer_id = c.id
      WHERE i.customer_id = ?
      ORDER BY i.id DESC
    ''', [customerId]);
    return res.map((e) => InvoiceModel.fromMap(e)).toList();
  }

  /// تسجيل سداد دفعة من العميل (تحصيل نقدي/بنكي):
  /// - تسجيل حركة إيداع في الصندوق
  /// - خصم الدفعة من الفواتير الآجلة غير المسددة للعميل بنظام FIFO
  Future<void> recordCustomerPayment({
    required int customerId,
    required double amount,
    required int cashBoxId,
    String? notes,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();

      // 1. جلب اسم العميل
      final custRes = await txn.query('customers', columns: ['name'], where: 'id = ?', whereArgs: [customerId]);
      final customerName = custRes.isNotEmpty ? custRes.first['name'] as String : 'العميل';

      // 2. تسجيل حركة الصندوق (إيداع)
      await txn.insert('cash_transactions', {
        'cash_box_id': cashBoxId,
        'type': 'إيداع',
        'amount': amount,
        'date': now,
        'description': 'تحصيل دفعة من العميل: $customerName ${notes != null ? "($notes)" : ""}',
        'related_account_type': 'عميل',
        'related_id': customerId,
        'created_at': now,
      });

      // 3. زيادة رصيد الصندوق
      await txn.rawUpdate(
        'UPDATE cash_boxes SET balance = balance + ? WHERE id = ?',
        [amount, cashBoxId],
      );

      // 4. تسوية الفواتير الآجلة للعميل بنظام الأقدمية (FIFO)
      double remainingToPay = amount;
      final unpaidInvoices = await txn.query(
        'invoices',
        where: 'customer_id = ? AND remaining > 0 AND status = "مكتملة"',
        orderBy: 'id ASC',
      );

      for (final inv in unpaidInvoices) {
        if (remainingToPay <= 0) break;
        final invId = inv['id'] as int;
        final invRemaining = (inv['remaining'] as num).toDouble();
        final invPaid = (inv['paid'] as num).toDouble();

        if (remainingToPay >= invRemaining) {
          await txn.update(
            'invoices',
            {'paid': invPaid + invRemaining, 'remaining': 0.0},
            where: 'id = ?',
            whereArgs: [invId],
          );
          remainingToPay -= invRemaining;
        } else {
          await txn.update(
            'invoices',
            {'paid': invPaid + remainingToPay, 'remaining': invRemaining - remainingToPay},
            where: 'id = ?',
            whereArgs: [invId],
          );
          remainingToPay = 0;
        }
      }
    });
  }

  /// تسجيل سداد دفعة لمورد (سند صرف):
  /// - تسجيل حركة صرف من الصندوق
  /// - خصم المبلغ من فواتير المشتريات الآجلة للمورد
  Future<void> recordSupplierPayment({
    required int supplierId,
    required double amount,
    required int cashBoxId,
    String? notes,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();

      // 1. جلب اسم المورد
      final supRes = await txn.query('suppliers', columns: ['name'], where: 'id = ?', whereArgs: [supplierId]);
      final supplierName = supRes.isNotEmpty ? supRes.first['name'] as String : 'المورد';

      // 2. تسجيل حركة الصندوق (صرف)
      await txn.insert('cash_transactions', {
        'cash_box_id': cashBoxId,
        'type': 'صرف',
        'amount': amount,
        'date': now,
        'description': 'سداد دفعة للمورد: $supplierName ${notes != null ? "($notes)" : ""}',
        'related_account_type': 'مورد',
        'related_id': supplierId,
        'created_at': now,
      });

      // 3. خصم من رصيد الصندوق
      await txn.rawUpdate(
        'UPDATE cash_boxes SET balance = balance - ? WHERE id = ?',
        [amount, cashBoxId],
      );

      // 4. تسوية فواتير المشتريات الآجلة للمورد
      double remainingToPay = amount;
      final unpaidPurchases = await txn.query(
        'invoices',
        where: 'supplier_id = ? AND remaining > 0 AND type = "purchase" AND status = "مكتملة"',
        orderBy: 'id ASC',
      );

      for (final inv in unpaidPurchases) {
        if (remainingToPay <= 0) break;
        final invId = inv['id'] as int;
        final invRemaining = (inv['remaining'] as num).toDouble();
        final invPaid = (inv['paid'] as num).toDouble();

        if (remainingToPay >= invRemaining) {
          await txn.update(
            'invoices',
            {'paid': invPaid + invRemaining, 'remaining': 0.0},
            where: 'id = ?',
            whereArgs: [invId],
          );
          remainingToPay -= invRemaining;
        } else {
          await txn.update(
            'invoices',
            {'paid': invPaid + remainingToPay, 'remaining': invRemaining - remainingToPay},
            where: 'id = ?',
            whereArgs: [invId],
          );
          remainingToPay = 0;
        }
      }
    });
  }

  /// التعديل الجماعي للأسعار حسب التصنيف والنوع (البند 13 من الوثيقة)
  /// [priceType]: 'sale_price1', 'sale_price2', 'sale_price3', 'cost_price'
  /// [isPercentage]: true للنسبة المئوية، false للقيمة الثابتة
  /// [isIncrease]: true للزيادة، false للنقصان
  Future<int> bulkUpdatePrices({
    int? categoryId,
    required String priceColumn,
    required double changeValue,
    required bool isPercentage,
    required bool isIncrease,
  }) async {
    final db = await database;
    String sql = 'UPDATE products SET ';
    final factor = isIncrease ? '+' : '-';

    if (isPercentage) {
      final multiplier = isIncrease ? (1.0 + (changeValue / 100.0)) : (1.0 - (changeValue / 100.0));
      sql += '$priceColumn = ROUND($priceColumn * $multiplier, 2)';
    } else {
      sql += '$priceColumn = MAX(0, $priceColumn $factor $changeValue)';
    }

    List<dynamic> args = [];
    if (categoryId != null) {
      sql += ' WHERE category_id = ?';
      args.add(categoryId);
    }

    return await db.rawUpdate(sql, args);
  }

  // ==================== عمليات الإعدادات ====================
  Future<String?> getSetting(String key) async {
    final db = await database;
    final res = await db.query('app_settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (res.isNotEmpty) {
      return res.first['value'] as String;
    }
    return null;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ==================== إحصائيات سريعة للرئيسية والتقارير ====================
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    final db = await database;

    final totalSalesToday = Sqflite.firstIntValue(await db.rawQuery('''
      SELECT COALESCE(SUM(total), 0) FROM invoices
      WHERE type = 'sale' AND status = 'مكتملة' AND date(created_at) = date('now')
    ''')) ?? 0;

    final totalCustomersDebt = Sqflite.firstIntValue(await db.rawQuery('''
      SELECT COALESCE(SUM(remaining), 0) FROM invoices
      WHERE type = 'sale' AND status = 'مكتملة' AND remaining > 0
    ''')) ?? 0;

    final totalProductsCount = Sqflite.firstIntValue(
      await db.rawQuery("SELECT COUNT(*) FROM products WHERE status = 'متوفر'"),
    ) ?? 0;

    final totalCashBalance = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COALESCE(SUM(balance), 0) FROM cash_boxes WHERE is_active = 1'),
    ) ?? 0;

    return {
      'totalSalesToday': totalSalesToday.toDouble(),
      'totalCustomersDebt': totalCustomersDebt.toDouble(),
      'totalProductsCount': totalProductsCount,
      'totalCashBalance': totalCashBalance.toDouble(),
    };
  }

  /// تقرير ملخص مالي وأرباح وتقييم المخزون (البند 14 من المواصفات)
  Future<Map<String, dynamic>> getFinancialReportSummary() async {
    final db = await database;

    final salesRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(total), 0) as total_sales,
        COALESCE(SUM(paid), 0) as total_paid,
        COALESCE(SUM(remaining), 0) as total_remaining,
        COALESCE(SUM(discount), 0) as total_discount,
        COUNT(*) as total_invoices
      FROM invoices 
      WHERE type = 'sale' AND status = 'مكتملة'
    ''');

    final purchasesRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(total), 0) as total_purchases,
        COALESCE(SUM(paid), 0) as total_purchases_paid,
        COALESCE(SUM(remaining), 0) as total_purchases_remaining,
        COUNT(*) as total_purchase_invoices
      FROM invoices 
      WHERE type = 'purchase' AND status = 'مكتملة'
    ''');

    final costRes = await db.rawQuery('''
      SELECT COALESCE(SUM(ii.quantity * ii.cost_price), 0) as total_cost
      FROM invoice_items ii
      JOIN invoices i ON ii.invoice_id = i.id
      WHERE i.type = 'sale' AND i.status = 'مكتملة'
    ''');

    final invRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(stock_quantity * cost_price), 0) as inventory_cost_value,
        COALESCE(SUM(stock_quantity * sale_price1), 0) as inventory_sale_value
      FROM products
      WHERE status = 'متوفر'
    ''');

    final totalSales = (salesRes.first['total_sales'] as num?)?.toDouble() ?? 0.0;
    final totalCost = (costRes.first['total_cost'] as num?)?.toDouble() ?? 0.0;
    final totalProfit = totalSales - totalCost;

    return {
      'totalSales': totalSales,
      'totalCost': totalCost,
      'totalProfit': totalProfit,
      'totalPaid': (salesRes.first['total_paid'] as num?)?.toDouble() ?? 0.0,
      'totalRemaining': (salesRes.first['total_remaining'] as num?)?.toDouble() ?? 0.0,
      'totalDiscount': (salesRes.first['total_discount'] as num?)?.toDouble() ?? 0.0,
      'totalInvoices': (salesRes.first['total_invoices'] as num?)?.toInt() ?? 0,
      'totalPurchases': (purchasesRes.first['total_purchases'] as num?)?.toDouble() ?? 0.0,
      'totalPurchasesPaid': (purchasesRes.first['total_purchases_paid'] as num?)?.toDouble() ?? 0.0,
      'totalPurchasesRemaining': (purchasesRes.first['total_purchases_remaining'] as num?)?.toDouble() ?? 0.0,
      'totalPurchaseInvoices': (purchasesRes.first['total_purchase_invoices'] as num?)?.toInt() ?? 0,
      'inventoryCostValue': (invRes.first['inventory_cost_value'] as num?)?.toDouble() ?? 0.0,
      'inventorySaleValue': (invRes.first['inventory_sale_value'] as num?)?.toDouble() ?? 0.0,
    };
  }

  // ==================== عمليات النسخ الاحتياطي والاسترجاع المحلي (البند 16) ====================
  Future<String> createLocalBackup([String? customDestinationDir]) async {
    if (kIsWeb) {
      throw UnsupportedError('النسخ الاحتياطي للملفات متاح في تطبيق الهاتف؛ بيانات الويب تُحفظ تلقائياً في المتصفح');
    }
    final db = await database;
    await db.rawQuery('PRAGMA wal_checkpoint(FULL);');

    final dbPath = await getDatabasesPath();
    final sourceFile = File(join(dbPath, 'accountant_system.db'));

    final destDir = customDestinationDir ?? join(dbPath, 'backups');
    final directory = Directory(destDir);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final targetPath = join(destDir, 'accountant_backup_$timestamp.db');
    await sourceFile.copy(targetPath);
    return targetPath;
  }

  Future<List<String>> listLocalBackups([String? customDestinationDir]) async {
    if (kIsWeb) return [];
    final dbPath = await getDatabasesPath();
    final destDir = customDestinationDir ?? join(dbPath, 'backups');
    final directory = Directory(destDir);
    if (!await directory.exists()) return [];
    final files = directory.listSync().whereType<File>().where((f) => f.path.endsWith('.db')).toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files.map((f) => f.path).toList();
  }

  /// إلغاء الفاتورة بشكل محاسبي سليم ومعالجة المخزون والصندوق (المرتجعات والتصحيح)
  Future<bool> cancelInvoiceTransaction(int invoiceId, {String? reason}) async {
    final db = await database;
    return await db.transaction((txn) async {
      // 1. التحقق من وجود الفاتورة وحالتها
      final invRes = await txn.query('invoices', where: 'id = ?', whereArgs: [invoiceId], limit: 1);
      if (invRes.isEmpty) return false;
      final invoice = invRes.first;
      if (invoice['status'] == 'ملغاة') return false;

      final type = invoice['type'] as String;
      final invNumber = invoice['invoice_number'] as String;
      final paid = (invoice['paid'] as num).toDouble();
      final cashBoxId = invoice['cash_box_id'] as int?;
      final now = DateTime.now().toIso8601String();

      // 2. جلب بنود الفاتورة وعكس تأثيرها على المخزون
      final items = await txn.query('invoice_items', where: 'invoice_id = ?', whereArgs: [invoiceId]);
      for (final item in items) {
        final prodId = item['product_id'] as int;
        final qty = (item['quantity'] as num).toDouble();

        if (type == 'sale') {
          // إعادة الكمية للمخزون
          await txn.rawUpdate(
            'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
            [qty, prodId],
          );
        } else if (type == 'purchase') {
          // إنقاص الكمية من المخزون
          await txn.rawUpdate(
            'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
            [qty, prodId],
          );
        }
      }

      // 3. عكس الحركة المالية على الصندوق إن كان هناك مبلغ مسدد
      if (paid > 0 && cashBoxId != null) {
        if (type == 'sale') {
          // صرف من الصندوق (استرجاع نقدي للعميل)
          await txn.insert('cash_transactions', {
            'cash_box_id': cashBoxId,
            'type': 'صرف',
            'amount': paid,
            'date': now,
            'description': 'استرداد نقدي لإلغاء فاتورة مبيعات $invNumber ${reason != null ? "($reason)" : ""}',
            'related_account_type': 'إلغاء فاتورة',
            'related_id': invoiceId,
            'created_at': now,
          });
          await txn.rawUpdate(
            'UPDATE cash_boxes SET balance = balance - ? WHERE id = ?',
            [paid, cashBoxId],
          );
        } else if (type == 'purchase') {
          // إيداع في الصندوق (استرداد نقدي من المورد)
          await txn.insert('cash_transactions', {
            'cash_box_id': cashBoxId,
            'type': 'إيداع',
            'amount': paid,
            'date': now,
            'description': 'استرداد نقدي لإلغاء فاتورة مشتريات $invNumber ${reason != null ? "($reason)" : ""}',
            'related_account_type': 'إلغاء فاتورة',
            'related_id': invoiceId,
            'created_at': now,
          });
          await txn.rawUpdate(
            'UPDATE cash_boxes SET balance = balance + ? WHERE id = ?',
            [paid, cashBoxId],
          );
        }
      }

      // 4. تعديل حالة الفاتورة وتصفير المتبقي حتى لا تظهر في ذمم العميل أو المورد
      final currentNotes = invoice['notes'] as String? ?? '';
      final cancelNote = '[ملغاة: ${reason ?? "بدون سبب"}]';
      await txn.update(
        'invoices',
        {
          'status': 'ملغاة',
          'remaining': 0.0,
          'notes': currentNotes.isEmpty ? cancelNote : '$currentNotes $cancelNote',
        },
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      return true;
    });
  }

  /// التحويل المالي الآمن بين الصناديق والخزائن
  Future<bool> transferBetweenCashBoxes({
    required int fromBoxId,
    required int toBoxId,
    required double amount,
    String? notes,
  }) async {
    if (fromBoxId == toBoxId || amount <= 0) return false;
    final db = await database;

    return await db.transaction((txn) async {
      final fromRes = await txn.query('cash_boxes', where: 'id = ?', whereArgs: [fromBoxId], limit: 1);
      final toRes = await txn.query('cash_boxes', where: 'id = ?', whereArgs: [toBoxId], limit: 1);
      if (fromRes.isEmpty || toRes.isEmpty) return false;

      final fromBalance = (fromRes.first['balance'] as num).toDouble();
      if (fromBalance < amount) return false; // منع تحويل رصيد غير متاح

      final fromName = fromRes.first['name'] as String;
      final toName = toRes.first['name'] as String;
      final now = DateTime.now().toIso8601String();

      // حركة صرف من الصندوق المصدر
      await txn.insert('cash_transactions', {
        'cash_box_id': fromBoxId,
        'type': 'صرف',
        'amount': amount,
        'date': now,
        'description': 'تحويل صادر إلى: $toName ${notes != null ? "($notes)" : ""}',
        'related_account_type': 'تحويل بين صناديق',
        'related_id': toBoxId,
        'created_at': now,
      });
      await txn.rawUpdate(
        'UPDATE cash_boxes SET balance = balance - ? WHERE id = ?',
        [amount, fromBoxId],
      );

      // حركة إيداع في الصندوق المستلم
      await txn.insert('cash_transactions', {
        'cash_box_id': toBoxId,
        'type': 'إيداع',
        'amount': amount,
        'date': now,
        'description': 'تحويل وارد من: $fromName ${notes != null ? "($notes)" : ""}',
        'related_account_type': 'تحويل بين صناديق',
        'related_id': fromBoxId,
        'created_at': now,
      });
      await txn.rawUpdate(
        'UPDATE cash_boxes SET balance = balance + ? WHERE id = ?',
        [amount, toBoxId],
      );

      return true;
    });
  }

  /// كشف حساب العميل التراكمي (Ledger Statement)
  Future<List<Map<String, dynamic>>> getCustomerAccountStatement(int customerId) async {
    final db = await database;
    // جلب جميع فواتير العميل
    final invoices = await db.query(
      'invoices',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'date ASC',
    );

    // جلب جميع سندات القبض والدفعات المسجلة للعميل
    final payments = await db.query(
      'cash_transactions',
      where: 'related_account_type = "عميل" AND related_id = ?',
      whereArgs: [customerId],
      orderBy: 'date ASC',
    );

    List<Map<String, dynamic>> statement = [];

    for (final inv in invoices) {
      statement.add({
        'date': inv['date'],
        'type': inv['status'] == 'ملغاة' ? 'فاتورة ملغاة' : 'فاتورة مبيعات',
        'ref': inv['invoice_number'],
        'debit': inv['status'] == 'ملغاة' ? 0.0 : (inv['total'] as num).toDouble(), // مدين (المبلغ المستحق)
        'credit': inv['status'] == 'ملغاة' ? 0.0 : (inv['paid'] as num).toDouble(), // دائن (المدفوع فورياً)
        'notes': inv['notes'],
      });
    }

    for (final p in payments) {
      statement.add({
        'date': p['date'],
        'type': 'سند قبض',
        'ref': 'REC-${p['id']}',
        'debit': 0.0,
        'credit': (p['amount'] as num).toDouble(), // دائن (تحصيل دفعة)
        'notes': p['description'],
      });
    }

    // ترتيب كشف الحساب زمنياً وحساب الرصيد التراكمي
    statement.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    double runningBalance = 0.0;
    for (var entry in statement) {
      final debit = entry['debit'] as double;
      final credit = entry['credit'] as double;
      runningBalance += (debit - credit);
      entry['balance'] = runningBalance;
    }

    return statement;
  }

  /// كشف حساب المورد التراكمي (Supplier Statement)
  Future<List<Map<String, dynamic>>> getSupplierAccountStatement(int supplierId) async {
    final db = await database;
    final purchases = await db.query(
      'invoices',
      where: 'supplier_id = ? AND type = "purchase"',
      whereArgs: [supplierId],
      orderBy: 'date ASC',
    );

    final payments = await db.query(
      'cash_transactions',
      where: 'related_account_type = "مورد" AND related_id = ?',
      whereArgs: [supplierId],
      orderBy: 'date ASC',
    );

    List<Map<String, dynamic>> statement = [];

    for (final inv in purchases) {
      statement.add({
        'date': inv['date'],
        'type': inv['status'] == 'ملغاة' ? 'فاتورة شراء ملغاة' : 'فاتورة مشتريات',
        'ref': inv['invoice_number'],
        'debit': inv['status'] == 'ملغاة' ? 0.0 : (inv['paid'] as num).toDouble(), // مدين (المدفوع للمورد)
        'credit': inv['status'] == 'ملغاة' ? 0.0 : (inv['total'] as num).toDouble(), // دائن (المستحق للمورد)
        'notes': inv['notes'],
      });
    }

    for (final p in payments) {
      statement.add({
        'date': p['date'],
        'type': 'سند صرف',
        'ref': 'PAY-${p['id']}',
        'debit': (p['amount'] as num).toDouble(), // مدين (سداد دفعة للمورد)
        'credit': 0.0,
        'notes': p['description'],
      });
    }

    statement.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    double runningBalance = 0.0;
    for (var entry in statement) {
      final debit = entry['debit'] as double;
      final credit = entry['credit'] as double;
      runningBalance += (credit - debit); // مستحق للمورد
      entry['balance'] = runningBalance;
    }

    return statement;
  }

  /// استرجاع آمن مع التحقق الصارم من سلامة وهيكلية النسخة الاحتياطية قبل الاستعادة
  Future<bool> restoreLocalBackup(String backupPath) async {
    if (kIsWeb) return false;
    final backupFile = File(backupPath);
    if (!await backupFile.exists() || backupFile.lengthSync() == 0) return false;

    // 1. فحص النسخة في وضع القراءة فقط
    try {
      final testDb = await openReadOnlyDatabase(backupPath);
      final integrityRes = await testDb.rawQuery('PRAGMA integrity_check;');
      final integrityOk = integrityRes.isNotEmpty && integrityRes.first.values.first == 'ok';
      if (!integrityOk) {
        await testDb.close();
        return false;
      }

      // التحقق من وجود الجداول المحاسبية الأساسية
      final tablesRes = await testDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('products', 'invoices', 'customers', 'suppliers', 'cash_boxes');"
      );
      await testDb.close();
      if (tablesRes.length < 5) {
        return false;
      }
    } catch (_) {
      return false;
    }

    // 2. إغلاق القاعدة الحالية واستبدالها بالنسخة المفحوصة
    final dbPath = await getDatabasesPath();
    final targetPath = join(dbPath, 'accountant_system.db');

    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }

    await backupFile.copy(targetPath);
    _database = await _initDB('accountant_system.db');
    return true;
  }

  /// تصدير نسخة احتياطية كاملة وشاملة لكافة جداول وعلاقات النظام بصيغة JSON مهيكلة
  Future<Map<String, dynamic>> exportFullBackupJson() async {
    final db = await database;
    final categories = await db.query('categories');
    final units = await db.query('units');
    final products = await db.query('products');
    final customers = await db.query('customers');
    final suppliers = await db.query('suppliers');
    final invoices = await db.query('invoices');
    final invoiceItems = await db.query('invoice_items');
    final cashBoxes = await db.query('cash_boxes');
    final cashTransactions = await db.query('cash_transactions');
    final settings = await db.query('app_settings');

    return {
      'system': 'AccountingApp',
      'schema_version': 1,
      'created_at': DateTime.now().toIso8601String(),
      'tables': {
        'categories': categories,
        'units': units,
        'products': products,
        'customers': customers,
        'suppliers': suppliers,
        'invoices': invoices,
        'invoice_items': invoiceItems,
        'cash_boxes': cashBoxes,
        'cash_transactions': cashTransactions,
        'app_settings': settings,
      },
      'stats': {
        'products_count': products.length,
        'customers_count': customers.length,
        'suppliers_count': suppliers.length,
        'invoices_count': invoices.length,
      }
    };
  }

  /// استرداد ذري وشامل للنسخة الاحتياطية الأصلية للنظام مع فحص التوافق وسلامة المعرفات
  Future<Map<String, int>> importFullBackupJson(Map<String, dynamic> data) async {
    if (data['system'] != 'AccountingApp' || !data.containsKey('tables')) {
      throw const FormatException('الملف المحدد ليس نسخة احتياطية صالحة لهذا النظام.');
    }

    final tables = data['tables'] as Map<String, dynamic>;
    final db = await database;
    final Map<String, int> counts = {};

    await db.transaction((txn) async {
      // 1. تفريغ الجداول الحالية بترتيب يراعي المفاتيح الأجنبية
      await txn.delete('invoice_items');
      await txn.delete('invoices');
      await txn.delete('cash_transactions');
      await txn.delete('products');
      await txn.delete('customers');
      await txn.delete('suppliers');
      await txn.delete('cash_boxes');
      await txn.delete('categories');
      await txn.delete('units');
      await txn.delete('app_settings');

      // 2. إدراج الجداول بالترتيب الصحيح مع الحفاظ على المعرفات
      Future<int> insertTable(String tableName) async {
        final rows = (tables[tableName] as List<dynamic>?) ?? [];
        int count = 0;
        for (final row in rows) {
          final map = Map<String, dynamic>.from(row as Map);
          await txn.insert(tableName, map, conflictAlgorithm: ConflictAlgorithm.replace);
          count++;
        }
        return count;
      }

      counts['units'] = await insertTable('units');
      counts['categories'] = await insertTable('categories');
      counts['cash_boxes'] = await insertTable('cash_boxes');
      counts['suppliers'] = await insertTable('suppliers');
      counts['customers'] = await insertTable('customers');
      counts['products'] = await insertTable('products');
      counts['invoices'] = await insertTable('invoices');
      counts['invoice_items'] = await insertTable('invoice_items');
      counts['cash_transactions'] = await insertTable('cash_transactions');
      counts['app_settings'] = await insertTable('app_settings');
    });

    return counts;
  }
}
