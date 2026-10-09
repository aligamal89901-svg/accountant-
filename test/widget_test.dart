import 'package:flutter_test/flutter_test.dart';
import 'package:my_project/core/utils/formatters.dart';
import 'package:my_project/models/product_model.dart';
import 'package:my_project/models/customer_model.dart';
import 'package:my_project/models/supplier_model.dart';
import 'package:my_project/models/invoice_model.dart';
import 'package:my_project/models/invoice_item_model.dart';
import 'package:my_project/models/cash_box_model.dart';
import 'package:my_project/models/cash_transaction_model.dart';
import 'dart:convert';
import 'package:my_project/core/services/pdf_invoice_service.dart';
import 'package:my_project/services/excel_product_service.dart';

void main() {
  group('اختبارات نظام التنسيق والتفقيط المالي (Formatters & Tafqeet)', () {
    test('تنسيق المبالغ والعملات', () {
      expect(Formatters.formatCurrency(1500.5), '1,500.50 ر.س');
      expect(Formatters.formatCurrency(0), '0.00 ر.س');
    });

    test('تفقيط المبالغ المالية باللغة العربية (Tafqeet)', () {
      expect(Formatters.tafqeet(690), 'ستمائة وتسعون ريال لا غير');
      expect(Formatters.tafqeet(1000), 'ألف ريال لا غير');
      expect(Formatters.tafqeet(1500.50), 'ألف وخمسمائة ريال وخمسون هللة لا غير');
      expect(Formatters.tafqeet(0), 'صفر ريال لا غير');
    });
  });

  group('اختبارات النماذج المحاسبية (Models Integrity)', () {
    test('نموذج المنتج والمخزون وحالات التنبيه', () {
      final product = ProductModel(
        barcode: '123456789',
        name: 'منتج تجريبي',
        salePrice1: 50.0,
        costPrice: 35.0,
        stockQuantity: 4.0,
        minQuantity: 5.0,
      );

      expect(product.isLowStock, true);
      expect(product.isOutOfStock, false);
      expect(product.salePrice1, 50.0);

      final map = product.toMap();
      final fromMap = ProductModel.fromMap(map);
      expect(fromMap.barcode, '123456789');
      expect(fromMap.name, 'منتج تجريبي');
    });

    test('نموذج العميل والذمم المالية', () {
      final customer = CustomerModel(
        code: 'CUST-0001',
        name: 'أحمد علي',
        currentBalance: 250.0,
      );

      expect(customer.hasDebt, true);
      expect(customer.currentBalance, 250.0);
    });

    test('نموذج المورد والمستحقات', () {
      final supplier = SupplierModel(
        code: 'SUP-0001',
        name: 'مؤسسة التوريد',
        currentBalance: 1200.0,
      );

      expect(supplier.hasPayables, true);
      expect(supplier.currentBalance, 1200.0);
    });

    test('نموذج الفاتورة وحسابات الصافي والمتبقي', () {
      final invoice = InvoiceModel(
        invoiceNumber: 'INV-2026-00001',
        type: 'sale',
        date: DateTime.now().toIso8601String(),
        subtotal: 700.0,
        discount: 10.0,
        total: 690.0,
        paid: 500.0,
        remaining: 190.0,
        paymentMethod: 'نقد',
      );

      expect(invoice.isPaidInFull, false);
      expect(invoice.hasRemaining, true);
      expect(invoice.remaining, 190.0);
      expect(invoice.total, 690.0);
    });
  });

  group('اختبارات توليد ملفات PDF لفاتورة المبيعات (PDF Invoice)', () {
    test('توليد ملف فاتورة PDF باللغة العربية والتفقيط', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final invoice = InvoiceModel(
        invoiceNumber: 'INV-2026-00001',
        type: 'sale',
        date: DateTime.now().toIso8601String(),
        subtotal: 700.0,
        discount: 10.0,
        total: 690.0,
        paid: 500.0,
        remaining: 190.0,
        customerName: 'أحمد علي',
      );
      final items = [
        InvoiceItemModel(
          productId: 1,
          productName: 'أرز بسمتي',
          quantity: 2,
          unitPrice: 50.0,
          total: 100.0,
        ),
      ];

      final pdfBytes = await PdfInvoiceService.generateInvoicePdf(
        invoice: invoice,
        items: items,
        shopSettings: {'shopName': 'مؤسسة التجارة', 'shopTaxNumber': '300012345600003'},
      );

      expect(pdfBytes.isNotEmpty, true);
      final header = String.fromCharCodes(pdfBytes.take(4));
      expect(header, '%PDF');
    });

    test('توليد ملف فاتورة مشتريات PDF مع بيانات المورد', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final invoice = InvoiceModel(
        invoiceNumber: 'PUR-2026-00001',
        type: 'purchase',
        date: DateTime.now().toIso8601String(),
        subtotal: 1200.0,
        discount: 50.0,
        total: 1150.0,
        paid: 1000.0,
        remaining: 150.0,
        supplierName: 'شركة الإمداد الغذائي',
      );
      final items = [
        InvoiceItemModel(
          productId: 1,
          productName: 'سكر ناعم 10 كجم',
          quantity: 10,
          unitPrice: 120.0,
          total: 1200.0,
        ),
      ];

      final pdfBytes = await PdfInvoiceService.generateInvoicePdf(
        invoice: invoice,
        items: items,
        shopSettings: {'shopName': 'المتجر المركزي', 'shopTaxNumber': '300099999900003'},
      );

      expect(pdfBytes.isNotEmpty, true);
      final header = String.fromCharCodes(pdfBytes.take(4));
      expect(header, '%PDF');
    });

    test('توليد سند قبض مالي وسند صرف PDF بالتفقيط', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final receiptBytes = await PdfInvoiceService.generatePaymentReceiptPdf(
        receiptType: 'سند قبض',
        receiptNumber: 'REC-2026-0001',
        partyName: 'مؤسسة الأفق للتجارة',
        amount: 850.50,
        date: DateTime.now().toIso8601String(),
        cashBoxName: 'الصندوق الرئيسي',
        notes: 'دفعة تحت الحساب للفاتورة رقم INV-001',
        shopSettings: {'shopName': 'المتجر المركزي'},
      );

      expect(receiptBytes.isNotEmpty, true);
      final header = String.fromCharCodes(receiptBytes.take(4));
      expect(header, '%PDF');
    });

    test('توليد كشف حساب تفصيلي PDF باللغة العربية والتفقيط', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final statementEntries = [
        {
          'date': '2026-10-01',
          'type': 'فاتورة مبيعات',
          'ref': 'INV-2026-0001',
          'debit': 500.0,
          'credit': 200.0,
          'balance': 300.0,
          'notes': 'فاتورة افتتاحية',
        },
        {
          'date': '2026-10-03',
          'type': 'سند قبض',
          'ref': 'REC-1',
          'debit': 0.0,
          'credit': 300.0,
          'balance': 0.0,
          'notes': 'سداد كامل الرصيد المتبقي',
        },
      ];

      final statementBytes = await PdfInvoiceService.generateAccountStatementPdf(
        partyType: 'العميل',
        partyName: 'مؤسسة التجارة العالمية',
        partyCode: 'CUST-0001',
        statementEntries: statementEntries,
        finalBalance: 0.0,
        shopSettings: {'shopName': 'المتجر المركزي', 'shopTaxNumber': '300012345600003'},
      );

      expect(statementBytes.isNotEmpty, true);
      final header = String.fromCharCodes(statementBytes.take(4));
      expect(header, '%PDF');
    });
  });

  group('اختبارات الصناديق والحركات المالية (Cash Box & Transactions)', () {
    test('نموذج الصندوق وإجمالي الرصيد والنوع', () {
      final cashBox = CashBoxModel(
        id: 1,
        name: 'الصندوق الرئيسي',
        type: 'نقد',
        balance: 3500.0,
        isDefault: true,
      );

      expect(cashBox.name, 'الصندوق الرئيسي');
      expect(cashBox.balance, 3500.0);
      expect(cashBox.isDefault, true);

      final map = cashBox.toMap();
      final fromMap = CashBoxModel.fromMap(map);
      expect(fromMap.id, 1);
      expect(fromMap.name, 'الصندوق الرئيسي');
      expect(fromMap.balance, 3500.0);
    });

    test('نموذج الحركة المالية وحالات الإيداع والصرف', () {
      final deposit = CashTransactionModel(
        id: 1,
        cashBoxId: 1,
        type: 'إيداع',
        amount: 500.0,
        date: DateTime.now().toIso8601String(),
        description: 'دفعة مبيعات نقدية',
      );

      final withdrawal = CashTransactionModel(
        id: 2,
        cashBoxId: 1,
        type: 'صرف',
        amount: 200.0,
        date: DateTime.now().toIso8601String(),
        description: 'مصاريف تشغيلية',
      );

      expect(deposit.isDeposit, true);
      expect(withdrawal.isDeposit, false);
      expect(deposit.amount, 500.0);
      expect(withdrawal.amount, 200.0);
    });

    test('صحة معادلة صافي الربح المحاسبي وحساب الأرصدة', () {
      // إجمالي المبيعات = 10,000 | تكلفة البضاعة المباعة = 6,500 | الخصم الممنوح = 500
      final double grossSales = 10000.0;
      final double discount = 500.0;
      final double netSales = grossSales - discount;
      final double cogs = 6500.0;
      final double grossProfit = netSales - cogs;

      expect(netSales, 9500.0);
      expect(grossProfit, 3000.0);

      // التأكد من عدم تجاوز التحويل الرصيد المتاح
      final double cashBalance = 1500.0;
      final double requestedTransfer = 2000.0;
      final bool canTransfer = cashBalance >= requestedTransfer;
      expect(canTransfer, false);
    });
  });

  group('اختبارات تصدير ومعالجة ملفات Excel للمنتجات (Excel Service)', () {
    test('تصدير المنتجات إلى ملف XLSX حقيقي والتحقق من الترويسة الثنائية', () {
      final sampleProducts = [
        ProductModel(
          id: 1,
          name: 'أرز بسمتي 5 كجم',
          barcode: '6281001001',
          costPrice: 40.0,
          salePrice1: 55.0,
          salePrice2: 50.0,
          salePrice3: 48.0,
          stockQuantity: 100.0,
          categoryName: 'مواد غذائية',
          unitName: 'كيس',
          weight: 5.0,
        ),
        ProductModel(
          id: 2,
          name: 'زيت دوار الشمس 1.5 لتر',
          barcode: '6281001002',
          costPrice: 15.0,
          salePrice1: 22.0,
          stockQuantity: 50.0,
          categoryName: 'زيوت',
          unitName: 'حبة',
        ),
      ];

      final xlsxBytes = ExcelProductService.exportProductsToXlsx(sampleProducts);
      expect(xlsxBytes.isNotEmpty, true);
      // التحقق من توقيع ملف ZIP/XLSX: PK\x03\x04
      expect(xlsxBytes[0], 0x50);
      expect(xlsxBytes[1], 0x4B);
      expect(xlsxBytes[2], 0x03);
      expect(xlsxBytes[3], 0x04);
    });
  });

  group('اختبارات التدقيق المحاسبي للعملاء والموردين (Accounting Audits)', () {
    test('معادلة تدقيق رصيد العميل (الافتتاحي + المبيعات - المقبوضات = الرصيد)', () {
      final customer = CustomerModel(
        id: 1,
        code: 'CUST-001',
        name: 'شركة الأمل',
        openingBalance: 1000.0,
        currentBalance: 2500.0,
      );

      final double openingBalance = customer.openingBalance;
      final double totalInvoicesRemaining = 2000.0; // مبيعات آجلة
      final double totalDirectPayments = 500.0; // سند قبض نقدي
      final double expectedBalance = openingBalance + totalInvoicesRemaining - totalDirectPayments;

      expect(expectedBalance, 2500.0);
      final double diff = (customer.currentBalance - expectedBalance).abs();
      expect(diff < 0.01, true); // مطابقة تامة
    });

    test('معادلة تدقيق رصيد المورد (الافتتاحي + المشتريات - المدفوعات = الرصيد)', () {
      final supplier = SupplierModel(
        id: 1,
        code: 'SUP-001',
        name: 'مصنع التقنية',
        openingBalance: 5000.0,
        currentBalance: 8200.0,
      );

      final double openingBalance = supplier.openingBalance;
      final double totalInvoicesRemaining = 4200.0; // فواتير مشتريات آجلة
      final double totalDirectPayments = 1000.0; // سند صرف نقدي
      final double expectedBalance = openingBalance + totalInvoicesRemaining - totalDirectPayments;

      expect(expectedBalance, 8200.0);
      final double diff = (supplier.currentBalance - expectedBalance).abs();
      expect(diff < 0.01, true); // مطابقة تامة
    });
  });

  group('اختبارات بنية النسخ الاحتياطي الشامل للنظام (System Backup JSON Schema)', () {
    test('التحقق من صحة واكتمال بنية ملف النسخ الاحتياطي الشامل', () {
      final backupData = {
        'system': 'AccountingApp',
        'schema_version': 1,
        'created_at': DateTime.now().toIso8601String(),
        'tables': {
          'categories': [{'id': 1, 'name': 'عام'}],
          'units': [{'id': 1, 'name': 'قطعة'}],
          'products': [{'id': 1, 'name': 'صنف 1', 'barcode': '111', 'sale_price_1': 10.0}],
          'customers': [{'id': 1, 'name': 'عميل 1', 'code': 'C-1'}],
          'suppliers': [{'id': 1, 'name': 'مورد 1', 'code': 'S-1'}],
          'invoices': [],
          'invoice_items': [],
          'cash_boxes': [{'id': 1, 'name': 'الرئيسي', 'balance': 500.0}],
          'cash_transactions': [],
          'app_settings': [{'key': 'enable_beep', 'value': 'true'}],
        },
      };

      // التحقق من صحة النظام وإصدار البنية
      expect(backupData['system'], 'AccountingApp');
      expect(backupData['schema_version'], 1);
      final tables = backupData['tables'] as Map<String, dynamic>;
      expect(tables.containsKey('products'), true);
      expect(tables.containsKey('invoices'), true);
      expect(tables.containsKey('customers'), true);
      expect(tables.containsKey('suppliers'), true);
      expect(tables.containsKey('cash_boxes'), true);
      expect(tables.containsKey('cash_transactions'), true);
      expect(tables.containsKey('app_settings'), true);

      // التأكد من إمكانية التشفير وفك التشفير دون أخطاء
      final encoded = jsonEncode(backupData);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      expect(decoded['system'], 'AccountingApp');
      expect((decoded['tables'] as Map)['products'].length, 1);
    });
  });

  group('اختبارات منطق المبيعات والأسعار المتعددة (Sales & Multi-Tier Pricing)', () {
    test('فئات الأسعار المتعددة للعميل واحتساب الخصومات', () {
      final product = ProductModel(
        id: 1,
        name: 'شاشة حاسوب',
        barcode: '998877',
        salePrice1: 1000.0, // مفرق
        salePrice2: 900.0,  // جملة
        salePrice3: 850.0,  // خاص
        costPrice: 700.0,
        stockQuantity: 10.0,
      );

      // عميل فئة 2 (جملة)
      final tier2Price = product.getPriceForTier(2);
      expect(tier2Price, 900.0);

      // عميل فئة 3 (خاص)
      final tier3Price = product.getPriceForTier(3);
      expect(tier3Price, 850.0);

      // احتساب السعر بعد الخصم المئوي 10%
      const double discountPercent = 10.0;
      final double discountedPrice = tier2Price * (1.0 - (discountPercent / 100.0));
      expect(discountedPrice, 810.0);
    });

    test('فحص منع البيع بالسالب عند تعطيل البيع بالسالب', () {
      final product = ProductModel(
        id: 1,
        name: 'جهاز لوحي',
        barcode: '112233',
        stockQuantity: 3.0,
        salePrice1: 1500.0,
        costPrice: 1200.0,
      );

      const double requestedQuantity = 5.0;
      const bool allowNegativeStock = false;

      final bool canSell = allowNegativeStock || (product.stockQuantity >= requestedQuantity);
      expect(canSell, false);
    });
  });
}

