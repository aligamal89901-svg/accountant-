import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/database_helper.dart';
import '../../models/product_model.dart';
import '../../models/supplier_model.dart';
import '../../models/invoice_model.dart';
import '../../models/invoice_item_model.dart';
import '../../models/cash_box_model.dart';
import '../sales/invoice_receipt_dialog.dart';

/// شاشة المبيعات وفواتير التوريد من الموردين
class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ProductModel> _searchResults = [];
  final List<InvoiceItemModel> _cartItems = [];
  List<SupplierModel> _suppliers = [];
  SupplierModel? _selectedSupplier;
  List<CashBoxModel> _cashBoxes = [];
  CashBoxModel? _selectedCashBox;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final suppliers = await DatabaseHelper.instance.getSuppliers();
    final cashBoxes = await DatabaseHelper.instance.getCashBoxes();
    if (mounted) {
      setState(() {
        _suppliers = suppliers;
        if (suppliers.isNotEmpty) {
          _selectedSupplier = suppliers.first;
        }
        _cashBoxes = cashBoxes;
        if (cashBoxes.isNotEmpty) {
          _selectedCashBox = cashBoxes.first;
        }
      });
    }
  }

  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    final exactBarcode = await DatabaseHelper.instance.getProductByBarcode(query.trim());
    if (exactBarcode != null) {
      _addProductToCart(exactBarcode);
      _searchController.clear();
      setState(() {
        _searchResults = [];
      });
      return;
    }

    final products = await DatabaseHelper.instance.getProducts(query: query.trim());
    if (mounted) {
      setState(() {
        _searchResults = products;
      });
    }
  }

  void _addProductToCart(ProductModel product) {
    SystemSound.play(SystemSoundType.click);
    final existingIndex = _cartItems.indexWhere((item) => item.productId == product.id);
    setState(() {
      if (existingIndex >= 0) {
        final item = _cartItems[existingIndex];
        _cartItems[existingIndex] = item.copyWith(quantity: item.quantity + 1);
      } else {
        _cartItems.add(InvoiceItemModel(
          productId: product.id!,
          productName: product.name,
          unitName: product.unitName,
          quantity: 1.0,
          unitPrice: product.costPrice > 0 ? product.costPrice : product.salePrice1,
          costPrice: product.costPrice,
        ));
      }
    });
  }

  void _increaseQuantity(int index) {
    SystemSound.play(SystemSoundType.click);
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
        title: Text('تعديل كمية الشراء: ${item.productName}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'الكمية المشتراة',
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
                SystemSound.play(SystemSoundType.click);
                Navigator.pop(ctx);
              }
            },
            child: const Text('تطبيق'),
          ),
        ],
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
            Icon(Icons.qr_code_scanner, color: AppTheme.secondary),
            SizedBox(width: 8),
            Text('مسح وإدخال باركود المشتريات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل باركود الصنف يدويًا، أو امسحه بالقارئ، أو اختر صورة لفحصها:',
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
            content: Text('تمت إضافة: ${product.name} إلى سلة المشتريات'),
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

  void _showQuickAddProductDialog() async {
    final nameCtrl = TextEditingController();
    final barcodeCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final saleCtrl = TextEditingController();
    final units = await DatabaseHelper.instance.getAllUnits();
    final categories = await DatabaseHelper.instance.getAllCategories();
    int? selectedUnitId = units.isNotEmpty ? units.first.id : null;
    int? selectedCatId = categories.isNotEmpty ? categories.first.id : null;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('إضافة صنف جديد سريع للمشتريات'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الصنف *')),
                  const SizedBox(height: 10),
                  TextField(controller: barcodeCtrl, decoration: const InputDecoration(labelText: 'الباركود (اختياري)')),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: costCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'سعر الشراء / التكلفة *'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: saleCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'سعر البيع 1 *'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          initialValue: selectedCatId,
                          decoration: const InputDecoration(labelText: 'التصنيف'),
                          items: categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                          onChanged: (v) => setDialogState(() => selectedCatId = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          initialValue: selectedUnitId,
                          decoration: const InputDecoration(labelText: 'الوحدة'),
                          items: units.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))).toList(),
                          onChanged: (v) => setDialogState(() => selectedUnitId = v),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
                final sale = double.tryParse(saleCtrl.text.trim()) ?? cost;
                if (name.isEmpty) return;

                final newProd = ProductModel(
                  name: name,
                  barcode: barcodeCtrl.text.trim().isEmpty
                      ? 'BAR-${DateTime.now().millisecondsSinceEpoch}'
                      : barcodeCtrl.text.trim(),
                  categoryId: selectedCatId,
                  unitId: selectedUnitId,
                  costPrice: cost,
                  salePrice1: sale,
                  stockQuantity: 0.0,
                  minQuantity: 5.0,
                );

                final id = await DatabaseHelper.instance.insertProduct(newProd);
                final savedProduct = newProd.copyWith(id: id);
                if (ctx.mounted) Navigator.pop(ctx);
                _addProductToCart(savedProduct);
              },
              child: const Text('إضافة وإدراج بالسلة'),
            ),
          ],
        ),
      ),
    );
  }

  double get _subtotal => _cartItems.fold(0.0, (sum, i) => sum + i.total);

  void _showItemDetailDialog(int index) {
    final item = _cartItems[index];
    final qtyController = TextEditingController(text: Formatters.formatNumber(item.quantity));
    final priceController = TextEditingController(text: item.unitPrice.toString());
    final discountController = TextEditingController(text: item.discount.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل بند الشراء: ${item.productName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'الكمية المشتراة'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'سعر الشراء للوحدة'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: discountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'الخصم من المورد على هذا البند'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final newQty = double.tryParse(qtyController.text.trim()) ?? item.quantity;
              final newPrice = double.tryParse(priceController.text.trim()) ?? item.unitPrice;
              final newDisc = double.tryParse(discountController.text.trim()) ?? item.discount;

              setState(() {
                _cartItems[index] = item.copyWith(
                  quantity: newQty,
                  unitPrice: newPrice,
                  discount: newDisc,
                  costPrice: newPrice,
                );
              });
              Navigator.pop(ctx);
            },
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }

  void _showCheckoutDialog() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سلة المشتريات فارغة، أضف أصنافاً أولاً')),
      );
      return;
    }

    final totalAmount = _subtotal;
    final paidController = TextEditingController(text: totalAmount.toStringAsFixed(2));
    final discountController = TextEditingController(text: '0.0');
    final notesController = TextEditingController();
    String paymentMethod = AppConstants.paymentCash;
    SupplierModel? currentSupplier = _selectedSupplier;
    CashBoxModel? currentCashBox = _selectedCashBox;

    final nextInvoiceNumber = await DatabaseHelper.instance.generateNextInvoiceNumber('purchase');

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
                const Text('حفظ فاتورة المشتريات', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(nextInvoiceNumber, style: const TextStyle(fontSize: 13, color: AppTheme.secondary)),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // اختيار المورد
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<SupplierModel?>(
                            initialValue: currentSupplier,
                            decoration: const InputDecoration(labelText: 'المورد *'),
                            items: _suppliers.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                            onChanged: (v) => setCheckoutState(() => currentSupplier = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.person_add_alt, color: AppTheme.primary),
                          tooltip: 'إضافة مورد سريع',
                          onPressed: () async {
                            final nameCtrl = TextEditingController();
                            final phoneCtrl = TextEditingController();
                            final newCode = await DatabaseHelper.instance.generateNextSupplierCode();
                            if (!ctx.mounted) return;
                            final created = await showDialog<SupplierModel>(
                              context: ctx,
                              builder: (subCtx) => AlertDialog(
                                title: const Text('إضافة مورد سريع'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المورد *')),
                                    const SizedBox(height: 10),
                                    TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'الهاتف')),
                                  ],
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(subCtx), child: const Text('إلغاء')),
                                  ElevatedButton(
                                    onPressed: () async {
                                      if (nameCtrl.text.trim().isEmpty) return;
                                      final newSup = SupplierModel(
                                        code: newCode,
                                        name: nameCtrl.text.trim(),
                                        phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                                      );
                                      await DatabaseHelper.instance.insertSupplier(newSup);
                                      if (subCtx.mounted) Navigator.pop(subCtx, newSup);
                                    },
                                    child: const Text('إضافة'),
                                  ),
                                ],
                              ),
                            );

                            if (created != null) {
                              await _loadInitialData();
                              setCheckoutState(() {
                                currentSupplier = _suppliers.firstWhere((s) => s.code == created.code, orElse: () => created);
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
                              DropdownMenuItem(value: AppConstants.paymentCredit, child: Text('آجل (مستحق للمورد)')),
                            ],
                            onChanged: (v) {
                              setCheckoutState(() {
                                paymentMethod = v!;
                                if (paymentMethod == 'آجل (مستحق للمورد)' || paymentMethod == AppConstants.paymentCredit) {
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
                            decoration: const InputDecoration(labelText: 'صندوق الدفع'),
                            items: _cashBoxes.map((b) => DropdownMenuItem(value: b, child: Text(b.name))).toList(),
                            onChanged: (v) => setCheckoutState(() => currentCashBox = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // المبالغ والخصم
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: discountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'الخصم الإجمالي'),
                            onChanged: (_) => setCheckoutState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: paidController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'المبلغ المسدد للمورد *'),
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
                              const Text('صافي فاتورة المشتريات:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(Formatters.formatCurrency(netTotal),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.secondary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('المتبقي للمورد (آجل):', style: TextStyle(color: AppTheme.danger)),
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
                      decoration: const InputDecoration(labelText: 'ملاحظة أو رقم فاتورة المورد الورقية'),
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
                  backgroundColor: AppTheme.secondary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                icon: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(isSubmitting ? 'جارٍ الحفظ...' : 'حفظ المشتريات'),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (netTotal < 0 || paidVal < 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('القيم المالية غير صحيحة')),
                          );
                          return;
                        }

                        setCheckoutState(() => isSubmitting = true);

                        final invoice = InvoiceModel(
                          invoiceNumber: nextInvoiceNumber,
                          type: 'purchase',
                          supplierId: currentSupplier?.id,
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
                        final invoiceWithSupplier = invoice.copyWith(
                          supplierName: currentSupplier?.name,
                        );

                        try {
                          await DatabaseHelper.instance.createInvoiceTransaction(invoice, _cartItems);

                          if (ctx.mounted) Navigator.pop(ctx);

                          // لا يتم مسح محتويات الفاتورة إلا بعد نجاح الحفظ بالكامل
                          setState(() {
                            _cartItems.clear();
                          });

                          SystemSound.play(SystemSoundType.click);

                          if (mounted) {
                            InvoiceReceiptDialog.show(context, invoiceWithSupplier, savedItems);
                          }
                        } catch (e) {
                          setCheckoutState(() => isSubmitting = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('فشل حفظ فاتورة المشتريات: $e'), backgroundColor: AppTheme.danger),
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
                // الجانب الأيمن: البحث عن أصناف للتوريد وإضافتها
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
                                        'ابحث بالاسم أو امسح الباركود لإضافة بضائع التوريد',
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

                // الجانب الأيسر: سلة المشتريات وإتمام التوريد
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
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحث عن صنف لشرائه أو امسح الباركود...',
                prefixIcon: const Icon(Icons.qr_code_scanner, color: AppTheme.secondary),
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
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'مسح الباركود (قارئ / يدوي / صورة)',
            onPressed: _showBarcodeScanModal,
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: AppTheme.secondary),
            onPressed: _showQuickAddProductDialog,
            icon: const Icon(Icons.add),
            tooltip: 'إضافة صنف جديد سريع',
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
          'التكلفة: ${Formatters.formatCurrency(p.costPrice)} | المخزون الحالي: ${Formatters.formatNumber(p.stockQuantity)}',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing: ElevatedButton.icon(
          onPressed: () {
            _addProductToCart(p);
            _searchController.clear();
            setState(() => _searchResults = []);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.secondary,
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          icon: const Icon(Icons.add_shopping_cart, size: 16),
          label: const Text('إضافة', style: TextStyle(fontSize: 12)),
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
              const Icon(Icons.shopping_bag_outlined, size: 20, color: AppTheme.secondary),
              const SizedBox(width: 8),
              Text(
                'سلة المشتريات (${_cartItems.length} صنف)',
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
                    content: const Text('هل تريد إفراغ جميع بنود المشتريات الحالية؟'),
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
            Icon(Icons.shopping_bag_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'فاتورة المشتريات فارغة حالياً',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            const Text(
              'امسح الباركود أو ابحث عن الأصناف لإضافتها للتوريد',
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
                      'سعر التكلفة: ${Formatters.formatCurrency(item.unitPrice)}',
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
                      onTap: () => _increaseQuantity(index),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.secondary),
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _increaseQuantity(index),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Icon(Icons.add, size: 18, color: AppTheme.secondary),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // إجمالي البند
              Text(
                Formatters.formatCurrency(item.total),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondary, fontSize: 14),
              ),

              const SizedBox(width: 4),

              // تعديل البند
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textSecondary),
                tooltip: 'تعديل السعر والكمية',
                onPressed: () => _showItemDetailDialog(index),
              ),

              // حذف البند
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
              const Text('إجمالي المشتريات:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              Text(
                Formatters.formatCurrency(_subtotal),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.secondary),
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
                  label: const Text('حفظ المشتريات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
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
