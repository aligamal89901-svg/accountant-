import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/database_helper.dart';
import '../../models/product_model.dart';
import '../../models/customer_model.dart';
import '../../models/invoice_model.dart';
import '../../models/invoice_item_model.dart';
import '../../models/cash_box_model.dart';
import 'invoice_receipt_dialog.dart';

/// شاشة المبيعات ونقطة البيع الرئيسية (POS)
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ProductModel> _searchResults = [];
  final List<InvoiceItemModel> _cartItems = [];
  List<CustomerModel> _customers = [];
  CustomerModel? _selectedCustomer;
  List<CashBoxModel> _cashBoxes = [];
  CashBoxModel? _selectedCashBox;
  bool _isBeepEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final customers = await DatabaseHelper.instance.getCustomers();
    final cashBoxes = await DatabaseHelper.instance.getCashBoxes();
    final beepSetting = await DatabaseHelper.instance.getSetting('enable_beep');
    if (mounted) {
      setState(() {
        _customers = customers;
        if (customers.isNotEmpty) {
          _selectedCustomer = customers.first; // عميل نقدي افتراضياً
        }
        _cashBoxes = cashBoxes;
        if (cashBoxes.isNotEmpty) {
          _selectedCashBox = cashBoxes.first;
        }
        if (beepSetting != null) {
          _isBeepEnabled = beepSetting == 'true';
        }
      });
    }
  }

  void _playBeep() {
    if (_isBeepEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  Future<void> _toggleBeepSound() async {
    final newVal = !_isBeepEnabled;
    setState(() => _isBeepEnabled = newVal);
    await DatabaseHelper.instance.setSetting('enable_beep', newVal ? 'true' : 'false');
    if (newVal) _playBeep();
  }

  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    // البحث بالباركود المباشر أولاً
    final exactBarcode = await DatabaseHelper.instance.getProductByBarcode(query.trim());
    if (exactBarcode != null) {
      _addProductToCart(exactBarcode);
      _searchController.clear();
      setState(() {
        _searchResults = [];
      });
      return;
    }

    final products = await DatabaseHelper.instance.getProducts(query: query.trim(), status: 'متوفر');
    if (mounted) {
      setState(() {
        _searchResults = products;
      });
    }
  }

  void _addProductToCart(ProductModel product) {
    if (product.isFrozen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا المنتج مجمد ولا يمكن بيعه حالياً')),
      );
      return;
    }

    _playBeep();

    final existingIndex = _cartItems.indexWhere((item) => item.productId == product.id);
    setState(() {
      if (existingIndex >= 0) {
        final item = _cartItems[existingIndex];
        _cartItems[existingIndex] = item.copyWith(quantity: item.quantity + 1);
      } else {
        // تحديد سعر البيع بناء على فئة العميل الافتراضية
        double selectedPrice = product.salePrice1;
        if (_selectedCustomer?.defaultPriceTier == 2 && product.salePrice2 != null && product.salePrice2! > 0) {
          selectedPrice = product.salePrice2!;
        } else if (_selectedCustomer?.defaultPriceTier == 3 && product.salePrice3 != null && product.salePrice3! > 0) {
          selectedPrice = product.salePrice3!;
        }

        _cartItems.add(InvoiceItemModel(
          productId: product.id!,
          productName: product.name,
          unitName: product.unitName,
          quantity: 1.0,
          unitPrice: selectedPrice,
          costPrice: product.costPrice,
        ));
      }
    });
  }

  double get _subtotal => _cartItems.fold(0.0, (sum, i) => sum + i.total);

  void _increaseQuantity(int index) {
    _playBeep();
    setState(() {
      final item = _cartItems[index];
      _cartItems[index] = item.copyWith(quantity: item.quantity + 1);
    });
  }

  void _decreaseQuantity(int index) {
    setState(() {
      final item = _cartItems[index];
      if (item.quantity > 1) {
        _cartItems[index] = item.copyWith(quantity: item.quantity - 1);
      } else {
        _cartItems.removeAt(index);
      }
    });
  }

  void _showQuickQtyEditDialog(int index) {
    final item = _cartItems[index];
    final ctrl = TextEditingController(text: Formatters.formatNumber(item.quantity));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل كمية: ${item.productName}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'الكمية المطلوبة',
            prefixIcon: Icon(Icons.pin_outlined),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final newQty = double.tryParse(ctrl.text.trim());
              if (newQty != null && newQty > 0) {
                setState(() {
                  _cartItems[index] = item.copyWith(quantity: newQty);
                });
                _playBeep();
                Navigator.pop(ctx);
              }
            },
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }

  Future<void> _showItemDetailDialog(int index) async {
    final item = _cartItems[index];
    final product = await DatabaseHelper.instance.getProductById(item.productId);
    final units = await DatabaseHelper.instance.getAllUnits();
    final allowNegativeSetting = await DatabaseHelper.instance.getSetting(AppConstants.keyAllowNegativeStock) ?? 'true';
    final allowNegative = allowNegativeSetting == 'true';

    if (!mounted) return;

    final qtyController = TextEditingController(text: Formatters.formatNumber(item.quantity));
    final priceController = TextEditingController(text: item.unitPrice.toString());
    final discountController = TextEditingController(text: item.discount.toString());
    final notesController = TextEditingController(text: item.notes ?? '');
    String? selectedUnit = item.unitName;
    bool isDiscountPercent = false;
    final double currentStock = product?.stockQuantity ?? 0.0;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDetailState) {
          final qtyVal = double.tryParse(qtyController.text.trim()) ?? 0.0;
          final priceVal = double.tryParse(priceController.text.trim()) ?? 0.0;
          final discInput = double.tryParse(discountController.text.trim()) ?? 0.0;

          double actualDiscount = discInput;
          if (isDiscountPercent) {
            actualDiscount = (qtyVal * priceVal) * (discInput / 100.0);
          }
          final lineTotal = ((qtyVal * priceVal) - actualDiscount) > 0 ? ((qtyVal * priceVal) - actualDiscount) : 0.0;

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.edit_note_rounded, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تعديل بند: ${item.productName}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // شريط معلومات المخزون والباركود
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: currentStock > 0 ? AppTheme.primary.withValues(alpha: 0.08) : AppTheme.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                currentStock > 0 ? Icons.inventory_2_outlined : Icons.warning_amber_rounded,
                                size: 16,
                                color: currentStock > 0 ? AppTheme.primary : AppTheme.danger,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'المخزون المتاح: ${Formatters.formatNumber(currentStock)} ${product?.unitName ?? ""}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: currentStock > 0 ? AppTheme.primary : AppTheme.danger,
                                ),
                              ),
                            ],
                          ),
                          if (product?.barcode != null && product!.barcode.isNotEmpty)
                            Text(
                              'الباركود: ${product.barcode}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // اختيار فئة السعر السريعة (سعر 1، 2، 3)
                    const Text('فئات الأسعار المسجلة للمنتج:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                              side: BorderSide(
                                color: (priceVal == (product?.salePrice1 ?? 0)) ? AppTheme.primary : AppTheme.border,
                                width: (priceVal == (product?.salePrice1 ?? 0)) ? 2 : 1,
                              ),
                            ),
                            onPressed: () {
                              setDetailState(() {
                                priceController.text = (product?.salePrice1 ?? 0.0).toString();
                              });
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('سعر 1 (أساسي)', style: TextStyle(fontSize: 10)),
                                Text('${product?.salePrice1 ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                              side: BorderSide(
                                color: (product?.salePrice2 != null && priceVal == product!.salePrice2!) ? AppTheme.primary : AppTheme.border,
                                width: (product?.salePrice2 != null && priceVal == product!.salePrice2!) ? 2 : 1,
                              ),
                            ),
                            onPressed: (product?.salePrice2 != null && product!.salePrice2! > 0)
                                ? () {
                                    setDetailState(() {
                                      priceController.text = product.salePrice2.toString();
                                    });
                                  }
                                : null,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('سعر 2 (جملة)', style: TextStyle(fontSize: 10)),
                                Text(product?.salePrice2 != null && product!.salePrice2! > 0 ? '${product.salePrice2}' : '-',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                              side: BorderSide(
                                color: (product?.salePrice3 != null && priceVal == product!.salePrice3!) ? AppTheme.primary : AppTheme.border,
                                width: (product?.salePrice3 != null && priceVal == product!.salePrice3!) ? 2 : 1,
                              ),
                            ),
                            onPressed: (product?.salePrice3 != null && product!.salePrice3! > 0)
                                ? () {
                                    setDetailState(() {
                                      priceController.text = product.salePrice3.toString();
                                    });
                                  }
                                : null,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('سعر 3 (خاص)', style: TextStyle(fontSize: 10)),
                                Text(product?.salePrice3 != null && product!.salePrice3! > 0 ? '${product.salePrice3}' : '-',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // تعديل السعر والكمية
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'سعر الوحدة *', suffixText: 'ر.س'),
                            onChanged: (_) => setDetailState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: qtyController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'الكمية *', prefixIcon: Icon(Icons.numbers)),
                            onChanged: (_) => setDetailState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // وحدة القياس والخصم
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: selectedUnit,
                            decoration: const InputDecoration(labelText: 'وحدة البيع'),
                            items: [
                              DropdownMenuItem(value: item.unitName, child: Text(item.unitName ?? 'الوحدة الافتراضية')),
                              ...units.map((u) => DropdownMenuItem(value: u.name, child: Text(u.name))),
                            ],
                            onChanged: (v) => setDetailState(() => selectedUnit = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: discountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: isDiscountPercent ? 'خصم (%)' : 'خصم (مبلغ)',
                              suffixIcon: IconButton(
                                icon: Icon(isDiscountPercent ? Icons.percent : Icons.attach_money, size: 18),
                                tooltip: isDiscountPercent ? 'تغيير إلى خصم بمبلغ' : 'تغيير إلى نسبة مئوية',
                                onPressed: () {
                                  setDetailState(() => isDiscountPercent = !isDiscountPercent);
                                },
                              ),
                            ),
                            onChanged: (_) => setDetailState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // الرقم التسلسلي أو ملاحظة البند
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'الرقم التسلسلي / ملاحظات البند (اختياري)',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // بطاقة الإجمالي المحسوب
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('إجمالي هذا البند:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            Formatters.formatCurrency(lineTotal),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () {
                  final newQty = double.tryParse(qtyController.text.trim()) ?? item.quantity;
                  final newPrice = double.tryParse(priceController.text.trim()) ?? item.unitPrice;
                  final discInputVal = double.tryParse(discountController.text.trim()) ?? 0.0;
                  double calculatedDiscount = discInputVal;
                  if (isDiscountPercent) {
                    calculatedDiscount = (newQty * newPrice) * (discInputVal / 100.0);
                  }

                  if (newQty <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('الكمية يجب أن تكون أكبر من صفر'), backgroundColor: AppTheme.warning),
                    );
                    return;
                  }

                  if (!allowNegative && newQty > currentStock) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('الكمية المطلوبة ($newQty) تتجاوز المخزون المتاح ($currentStock)، والبيع بالسالب غير مسموح.'),
                        backgroundColor: AppTheme.danger,
                      ),
                    );
                    return;
                  }

                  setState(() {
                    _cartItems[index] = item.copyWith(
                      quantity: newQty,
                      unitPrice: newPrice,
                      discount: calculatedDiscount,
                      unitName: selectedUnit,
                      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                    );
                  });
                  _playBeep();
                  Navigator.pop(ctx);
                },
                child: const Text('تطبيق التعديلات'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBarcodeScanModal() {
    final barcodeInputController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('مسح وإدخال الباركود', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل الباركود يدويًا، أو استخدم قارئ الباركود، أو اختر صورة لتحليلها:',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: barcodeInputController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'رمز الباركود',
                hintText: 'امسح بجهاز الباركود أو اكتب الرمز...',
                prefixIcon: Icon(Icons.qr_code_scanner),
              ),
              onSubmitted: (val) async {
                final code = val.trim();
                if (code.isNotEmpty) {
                  Navigator.pop(ctx);
                  await _handleScannedBarcode(code);
                }
              },
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
              icon: const Icon(Icons.image_search_outlined),
              label: const Text('اختيار صورة لفحص الباركود'),
              onPressed: () async {
                try {
                  final files = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['jpg', 'png', 'jpeg'],
                  );
                  if (files.isNotEmpty) {
                    final file = files.first;
                    final potentialBarcode = file.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
                    barcodeInputController.text = potentialBarcode;
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('تم اختيار الصورة: ${file.name}')),
                      );
                    }
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('تعذر فتح الصورة: $e'), backgroundColor: AppTheme.danger),
                    );
                  }
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final code = barcodeInputController.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(ctx);
                await _handleScannedBarcode(code);
              }
            },
            child: const Text('إضافة الصنف'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleScannedBarcode(String barcode) async {
    final product = await DatabaseHelper.instance.getProductByBarcode(barcode);
    if (product != null) {
      _addProductToCart(product);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تمت إضافة: ${product.name} إلى السلة'),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('لم يتم العثور على منتج بالباركود: $barcode'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
    }
  }

  void _showCheckoutDialog() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('السلة فارغة، يرجى إضافة منتجات أولاً')),
      );
      return;
    }

    final totalAmount = _subtotal;
    final paidController = TextEditingController(text: totalAmount.toStringAsFixed(2));
    final discountController = TextEditingController(text: '0.0');
    final notesController = TextEditingController();
    String paymentMethod = AppConstants.paymentCash;
    CustomerModel? currentCustomer = _selectedCustomer;
    CashBoxModel? currentCashBox = _selectedCashBox;

    final nextInvoiceNumber = await DatabaseHelper.instance.generateNextInvoiceNumber('sale');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (ctx, setCheckoutState) {
            final discountVal = double.tryParse(discountController.text.trim()) ?? 0.0;
            final netTotal = (totalAmount - discountVal) > 0 ? (totalAmount - discountVal) : 0.0;
            final paidVal = double.tryParse(paidController.text.trim()) ?? 0.0;
            final remainingVal = (netTotal - paidVal) > 0 ? (netTotal - paidVal) : 0.0;

          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('إتمام الفاتورة (حاسب)', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(nextInvoiceNumber, style: const TextStyle(fontSize: 13, color: AppTheme.primary)),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // اختيار العميل مع إمكانية إضافة عميل سريع
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<CustomerModel?>(
                            initialValue: currentCustomer,
                            decoration: const InputDecoration(labelText: 'العميل *'),
                            items: _customers.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                            onChanged: (v) => setCheckoutState(() => currentCustomer = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.person_add_alt, color: AppTheme.primary),
                          tooltip: 'إضافة عميل سريع',
                          onPressed: () async {
                            final nameCtrl = TextEditingController();
                            final phoneCtrl = TextEditingController();
                            final newCode = await DatabaseHelper.instance.generateNextCustomerCode();
                            if (!ctx.mounted) return;
                            final created = await showDialog<CustomerModel>(
                              context: ctx,
                              builder: (subCtx) => AlertDialog(
                                title: const Text('إضافة عميل سريع'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم *')),
                                    const SizedBox(height: 10),
                                    TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'الهاتف')),
                                  ],
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(subCtx), child: const Text('إلغاء')),
                                  ElevatedButton(
                                    onPressed: () async {
                                      if (nameCtrl.text.trim().isEmpty) return;
                                      final newCust = CustomerModel(
                                        code: newCode,
                                        name: nameCtrl.text.trim(),
                                        phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                                      );
                                      await DatabaseHelper.instance.insertCustomer(newCust);
                                      if (subCtx.mounted) {
                                        Navigator.pop(subCtx, newCust);
                                      }
                                    },
                                    child: const Text('إضافة'),
                                  ),
                                ],
                              ),
                            );

                            if (created != null) {
                              await _loadInitialData();
                              setCheckoutState(() {
                                currentCustomer = _customers.firstWhere((c) => c.code == created.code, orElse: () => created);
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // طريقة الدفع والصندوق
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: paymentMethod,
                            decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                            items: const [
                              DropdownMenuItem(value: AppConstants.paymentCash, child: Text(AppConstants.paymentCash)),
                              DropdownMenuItem(value: AppConstants.paymentCard, child: Text(AppConstants.paymentCard)),
                              DropdownMenuItem(value: AppConstants.paymentCheck, child: Text(AppConstants.paymentCheck)),
                              DropdownMenuItem(value: AppConstants.paymentCredit, child: Text(AppConstants.paymentCredit)),
                            ],
                            onChanged: (v) {
                              setCheckoutState(() {
                                paymentMethod = v!;
                                if (paymentMethod == AppConstants.paymentCredit) {
                                  paidController.text = '0.0';
                                } else {
                                  paidController.text = netTotal.toStringAsFixed(2);
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<CashBoxModel?>(
                            initialValue: currentCashBox,
                            decoration: const InputDecoration(labelText: 'الصندوق'),
                            items: _cashBoxes
                                .map((b) => DropdownMenuItem(value: b, child: Text(b.name)))
                                .toList(),
                            onChanged: (v) => setCheckoutState(() => currentCashBox = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // المبالغ المالية والخصم
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: discountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'الخصم الكلي'),
                            onChanged: (_) => setCheckoutState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: paidController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'المبلغ المدفوع *'),
                            onChanged: (_) => setCheckoutState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ملخص الفاتورة والتفقيط
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('صافي الفاتورة:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(Formatters.formatCurrency(netTotal),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('المتبقي (آجل):', style: TextStyle(color: AppTheme.danger)),
                              Text(Formatters.formatCurrency(remainingVal),
                                  style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(height: 16),
                          Text(
                            Formatters.tafqeet(netTotal),
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'ملاحظة الفاتورة (اختياري)'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                icon: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(isSubmitting ? 'جارٍ الحفظ...' : 'حساب وإتمام البيع'),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (netTotal < 0 || paidVal < 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('القيم المالية غير منطقية')),
                          );
                          return;
                        }

                        setCheckoutState(() => isSubmitting = true);

                        final invoice = InvoiceModel(
                          invoiceNumber: nextInvoiceNumber,
                          type: 'sale',
                          customerId: currentCustomer?.id,
                          date: DateTime.now().toIso8601String(),
                          subtotal: totalAmount,
                          discount: discountVal,
                          total: netTotal,
                          paid: paidVal,
                          remaining: remainingVal,
                          paymentMethod: paymentMethod,
                          cashBoxId: currentCashBox?.id,
                          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                        );

                        final savedItems = List<InvoiceItemModel>.from(_cartItems);
                        final invoiceWithCustomer = invoice.copyWith(
                          customerName: currentCustomer?.name,
                        );

                        try {
                          await DatabaseHelper.instance.createInvoiceTransaction(invoice, _cartItems);

                          if (ctx.mounted) Navigator.pop(ctx);

                          // مسح محتويات الفاتورة فقط بعد نجاح الحفظ بالكامل
                          setState(() {
                            _cartItems.clear();
                          });

                          _playBeep();

                          if (mounted) {
                            InvoiceReceiptDialog.show(context, invoiceWithCustomer, savedItems);
                          }
                        } catch (e) {
                          setCheckoutState(() => isSubmitting = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('فشل حفظ الفاتورة: $e'), backgroundColor: AppTheme.danger),
                            );
                          }
                        }
                      },
              ),
            ],
          );
        },
      );
    },
  );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 750;

          if (isWide) {
            return Row(
              children: [
                // الجانب الأيمن: البحث عن المنتجات والكتالوج
                Expanded(
                  flex: 5,
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        _buildSearchBar(),
                        const Divider(height: 1),
                        Expanded(
                          child: _searchResults.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.search_rounded, size: 56, color: Colors.grey.shade300),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'ابحث بالاسم أو امسح الباركود لإضافة الأصناف',
                                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _searchResults.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                                  itemBuilder: (ctx, i) {
                                    final p = _searchResults[i];
                                    return _buildProductSearchResultTile(p);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                const VerticalDivider(width: 1, thickness: 1),

                // الجانب الأيسر: سلة الفاتورة وملخص الحساب
                Expanded(
                  flex: 6,
                  child: Container(
                    color: AppTheme.background,
                    child: Column(
                      children: [
                        _buildCartHeader(),
                        Expanded(child: _buildCartItemsList()),
                        _buildCheckoutBottomBar(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          } else {
            // تخطيط الهاتف الذكي المتجاوب عمودياً
            return Container(
              color: AppTheme.background,
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    child: _buildSearchBar(),
                  ),
                  if (_searchResults.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      color: Colors.white,
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final p = _searchResults[i];
                          return _buildProductSearchResultTile(p);
                        },
                      ),
                    ),
                  const Divider(height: 1),
                  _buildCartHeader(),
                  Expanded(child: _buildCartItemsList()),
                  _buildCheckoutBottomBar(),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'امسح الباركود أو ابحث باسم المنتج...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchProducts('');
                        },
                      )
                    : null,
              ),
              onChanged: _searchProducts,
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  _searchProducts(v.trim());
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'مسح الباركود (قارئ / يدوي / صورة)',
            onPressed: _showBarcodeScanModal,
          ),
          const SizedBox(width: 4),
          IconButton.outlined(
            icon: Icon(
              _isBeepEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: _isBeepEnabled ? AppTheme.primary : Colors.grey,
            ),
            tooltip: _isBeepEnabled ? 'صوت التأكيد مفعّل (Beep ON)' : 'صوت التأكيد معطل (Beep OFF)',
            onPressed: _toggleBeepSound,
          ),
        ],
      ),
    );
  }

  Widget _buildProductSearchResultTile(ProductModel p) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      child: ListTile(
        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          'الباركود: ${p.barcode} | المخزون: ${Formatters.formatNumber(p.stockQuantity)}',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Formatters.formatCurrency(p.salePrice1),
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 14),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                _addProductToCart(p);
                _searchController.clear();
                setState(() => _searchResults = []);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: const Text('إضافة', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_cart_outlined, size: 20, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'سلة الفاتورة (${_cartItems.length} صنف)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          if (_cartItems.isNotEmpty)
            TextButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('تأكيد مسح السلة'),
                    content: const Text('هل تريد إفراغ جميع بنود الفاتورة الحالية؟'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                        child: const Text('إفراغ السلة'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  setState(() => _cartItems.clear());
                }
              },
              icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: AppTheme.danger),
              label: const Text('مسح السلة', style: TextStyle(color: AppTheme.danger, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildCartItemsList() {
    if (_cartItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'سلة الفاتورة فارغة حالياً',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            const Text(
              'امسح الباركود أو ابحث عن المنتجات لإضافتها للسلة',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _cartItems.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, index) {
        final item = _cartItems[index];

        return Container(
          decoration: AppTheme.cardDecoration(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // تفاصيل الصنف
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${Formatters.formatCurrency(item.unitPrice)}${item.discount > 0 ? " (خصم: ${Formatters.formatCurrency(item.discount)})" : ""}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // أزرار التحكم بالكمية (+ / -)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _decreaseQuantity(index),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Icon(Icons.remove, size: 18, color: AppTheme.textSecondary),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        _increaseQuantity(index);
                      },
                      onLongPress: () => _showQuickQtyEditDialog(index),
                      borderRadius: BorderRadius.circular(4),
                      child: Tooltip(
                        message: 'اضغط للزيادة (+1) أو علّق لتعديل الرقم',
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 34),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          alignment: Alignment.center,
                          child: Text(
                            Formatters.formatNumber(item.quantity),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _increaseQuantity(index),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Icon(Icons.add, size: 18, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // إجمالي البند
              Text(
                Formatters.formatCurrency(item.total),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 14),
              ),

              const SizedBox(width: 6),

              // تعديل أو حذف البند
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.neutral),
                tooltip: 'تعديل السعر أو الخصم',
                onPressed: () => _showItemDetailDialog(index),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                tooltip: 'حذف من السلة',
                onPressed: () {
                  setState(() => _cartItems.removeAt(index));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCheckoutBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('إجمالي الفاتورة:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              Text(
                Formatters.formatCurrency(_subtotal),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _cartItems.isEmpty ? null : () => setState(() => _cartItems.clear()),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('إلغاء'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _cartItems.isEmpty ? null : _showCheckoutDialog,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('حاسب / إتمام الفاتورة', style: TextStyle(fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
