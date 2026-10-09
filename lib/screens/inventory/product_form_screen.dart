import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/database_helper.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import '../../models/unit_model.dart';

/// شاشة مستقلة وواسعة لإضافة وتعديل بيانات المنتجات
class ProductFormScreen extends StatefulWidget {
  final ProductModel? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _salePrice1Controller;
  late final TextEditingController _salePrice2Controller;
  late final TextEditingController _salePrice3Controller;
  late final TextEditingController _costPriceController;
  late final TextEditingController _stockQuantityController;
  late final TextEditingController _minQuantityController;
  late final TextEditingController _notesController;
  late final TextEditingController _weightController;
  late final TextEditingController _serialNumberController;
  late final TextEditingController _descriptionController;

  int? _selectedCategoryId;
  int? _selectedUnitId;
  String _selectedStatus = 'متوفر';

  List<CategoryModel> _categories = [];
  List<UnitModel> _units = [];
  bool _isLoading = true;
  bool _isSaving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _salePrice1Controller = TextEditingController(
      text: p != null ? p.salePrice1.toString() : '',
    );
    _salePrice2Controller = TextEditingController(
      text: p?.salePrice2 != null ? p!.salePrice2.toString() : '',
    );
    _salePrice3Controller = TextEditingController(
      text: p?.salePrice3 != null ? p!.salePrice3.toString() : '',
    );
    _costPriceController = TextEditingController(
      text: p != null ? p.costPrice.toString() : '0',
    );
    _stockQuantityController = TextEditingController(
      text: p != null ? Formatters.formatNumber(p.stockQuantity) : '0',
    );
    _minQuantityController = TextEditingController(
      text: p != null ? Formatters.formatNumber(p.minQuantity) : '5',
    );
    _notesController = TextEditingController(text: p?.notes ?? '');
    _weightController = TextEditingController(
      text: p?.weight != null ? p!.weight.toString() : '',
    );
    _serialNumberController = TextEditingController(text: p?.serialNumber ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');

    _selectedCategoryId = p?.categoryId;
    _selectedUnitId = p?.unitId;
    _selectedStatus = p?.status ?? 'متوفر';

    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _salePrice1Controller.dispose();
    _salePrice2Controller.dispose();
    _salePrice3Controller.dispose();
    _costPriceController.dispose();
    _stockQuantityController.dispose();
    _minQuantityController.dispose();
    _notesController.dispose();
    _weightController.dispose();
    _serialNumberController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final categories = await DatabaseHelper.instance.getAllCategories();
    final units = await DatabaseHelper.instance.getAllUnits();
    if (mounted) {
      setState(() {
        _categories = categories;
        _units = units;
        if (!_isEditing) {
          if (_selectedCategoryId == null && categories.isNotEmpty) {
            _selectedCategoryId = categories.first.id;
          }
          if (_selectedUnitId == null && units.isNotEmpty) {
            _selectedUnitId = units.first.id;
          }
        }
        _isLoading = false;
      });
    }
  }

  void _generateBarcode() {
    final randomDigits = 10000000 + Random().nextInt(90000000);
    setState(() {
      _barcodeController.text = randomDigits.toString();
    });
  }

  Future<void> _showAddCategoryDialog() async {
    final nameCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة تصنيف جديد'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'اسم التصنيف *', hintText: 'مثال: مواد غذائية'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final id = await DatabaseHelper.instance.insertCategory(result);
      await _loadData();
      setState(() {
        _selectedCategoryId = id;
      });
    }
  }

  Future<void> _showAddUnitDialog() async {
    final nameCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة وحدة قياس جديدة'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'اسم الوحدة *', hintText: 'مثال: كرتون، حبة، كجم'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final id = await DatabaseHelper.instance.insertUnit(result);
      await _loadData();
      setState(() {
        _selectedUnitId = id;
      });
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final barcode = _barcodeController.text.trim().isEmpty
        ? 'PRD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}'
        : _barcodeController.text.trim();

    final salePrice1 = double.tryParse(_salePrice1Controller.text.trim());
    if (salePrice1 == null || salePrice1 < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال سعر بيع أساسي صحيح')),
      );
      return;
    }

    final salePrice2 = double.tryParse(_salePrice2Controller.text.trim());
    final salePrice3 = double.tryParse(_salePrice3Controller.text.trim());
    final costPrice = double.tryParse(_costPriceController.text.trim()) ?? 0.0;
    final stockQty = double.tryParse(_stockQuantityController.text.trim()) ?? 0.0;
    final minQty = double.tryParse(_minQuantityController.text.trim()) ?? 5.0;

    final weight = double.tryParse(_weightController.text.trim());
    final serialNumber = _serialNumberController.text.trim().isEmpty ? null : _serialNumberController.text.trim();
    final description = _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim();

    setState(() => _isSaving = true);

    try {
      final productModel = ProductModel(
        id: widget.product?.id,
        name: name,
        barcode: barcode,
        categoryId: _selectedCategoryId,
        unitId: _selectedUnitId,
        salePrice1: salePrice1,
        salePrice2: salePrice2,
        salePrice3: salePrice3,
        costPrice: costPrice,
        stockQuantity: stockQty,
        minQuantity: minQty,
        status: _selectedStatus,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        weight: weight,
        serialNumber: serialNumber,
        description: description,
        openingStock: _isEditing ? (widget.product?.openingStock ?? widget.product?.stockQuantity) : stockQty,
      );

      if (_isEditing) {
        await DatabaseHelper.instance.updateProduct(productModel);
      } else {
        await DatabaseHelper.instance.insertProduct(productModel);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'تم تحديث بيانات المنتج بنجاح' : 'تمت إضافة المنتج الجديد بنجاح'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'تعديل منتج: ${widget.product!.name}' : 'إضافة منتج جديد',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveProduct,
            icon: const Icon(Icons.check, color: AppTheme.secondary),
            label: const Text('حفظ', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondary)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 650;
                final contentWidth = constraints.maxWidth > 900 ? 860.0 : constraints.maxWidth;

                return Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        children: [
                          _buildSectionCard(
                            title: 'المعلومات الأساسية',
                            icon: Icons.info_outline,
                            children: [
                              _buildField(
                                label: 'اسم المنتج *',
                                child: TextFormField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    hintText: 'مثال: أرز بسمتي فاخر 5 كجم',
                                    prefixIcon: Icon(Icons.shopping_bag_outlined),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'اسم المنتج مطلوب' : null,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _buildResponsiveRow(
                                isWide: isWide,
                                first: _buildField(
                                  label: 'رمز الباركود',
                                  child: TextFormField(
                                    controller: _barcodeController,
                                    decoration: InputDecoration(
                                      hintText: 'الباركود الدولي أو الرمز الداخلي',
                                      prefixIcon: const Icon(Icons.qr_code_scanner),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.auto_fix_high, size: 20),
                                        tooltip: 'توليد باركود تلقائي',
                                        onPressed: _generateBarcode,
                                      ),
                                    ),
                                  ),
                                ),
                                second: _buildField(
                                  label: 'التصنيف',
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<int?>(
                                          initialValue: _selectedCategoryId,
                                          decoration: const InputDecoration(
                                            prefixIcon: Icon(Icons.category_outlined),
                                          ),
                                          items: [
                                            const DropdownMenuItem(value: null, child: Text('بدون تصنيف')),
                                            ..._categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                                          ],
                                          onChanged: (v) => setState(() => _selectedCategoryId = v),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton.outlined(
                                        icon: const Icon(Icons.add, size: 20),
                                        tooltip: 'إضافة تصنيف',
                                        onPressed: _showAddCategoryDialog,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _buildResponsiveRow(
                                isWide: isWide,
                                first: _buildField(
                                  label: 'وحدة القياس',
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<int?>(
                                          initialValue: _selectedUnitId,
                                          decoration: const InputDecoration(
                                            prefixIcon: Icon(Icons.straighten_outlined),
                                          ),
                                          items: _units.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))).toList(),
                                          onChanged: (v) => setState(() => _selectedUnitId = v),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton.outlined(
                                        icon: const Icon(Icons.add, size: 20),
                                        tooltip: 'إضافة وحدة',
                                        onPressed: _showAddUnitDialog,
                                      ),
                                    ],
                                  ),
                                ),
                                second: _buildField(
                                  label: 'حالة المنتج',
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedStatus,
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.check_circle_outline),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'متوفر', child: Text('متوفر للبيع')),
                                      DropdownMenuItem(value: 'مجمد', child: Text('مجمد (إيقاف مؤقت)')),
                                      DropdownMenuItem(value: 'غير متوفر', child: Text('غير متوفر')),
                                    ],
                                    onChanged: (v) => setState(() => _selectedStatus = v!),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _buildResponsiveRow(
                                isWide: isWide,
                                first: _buildField(
                                  label: 'الرقم التسلسلي (اختياري)',
                                  child: TextFormField(
                                    controller: _serialNumberController,
                                    decoration: const InputDecoration(
                                      hintText: 'مثال: SN-10928374',
                                      prefixIcon: Icon(Icons.pin_outlined),
                                    ),
                                  ),
                                ),
                                second: _buildField(
                                  label: 'الوزن (كجم / جرام - اختياري)',
                                  child: TextFormField(
                                    controller: _weightController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      hintText: '0.00',
                                      prefixIcon: Icon(Icons.scale_outlined),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildSectionCard(
                            title: 'الأسعار والمخزون',
                            icon: Icons.price_change_outlined,
                            children: [
                              _buildResponsiveRow(
                                isWide: isWide,
                                first: _buildField(
                                  label: 'سعر البيع الأساسي (1) *',
                                  child: TextFormField(
                                    controller: _salePrice1Controller,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      hintText: '0.00',
                                      suffixText: 'ر.س',
                                      prefixIcon: Icon(Icons.attach_money),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'سعر البيع 1 مطلوب';
                                      if (double.tryParse(v.trim()) == null) return 'قيمة غير صالحة';
                                      return null;
                                    },
                                  ),
                                ),
                                second: _buildField(
                                  label: 'سعر التكلفة / الشراء',
                                  child: TextFormField(
                                    controller: _costPriceController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      hintText: '0.00',
                                      suffixText: 'ر.س',
                                      prefixIcon: Icon(Icons.shopping_cart_outlined),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _buildResponsiveRow(
                                isWide: isWide,
                                first: _buildField(
                                  label: 'سعر البيع الثاني (جملة - اختياري)',
                                  child: TextFormField(
                                    controller: _salePrice2Controller,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      hintText: '0.00',
                                      suffixText: 'ر.س',
                                      prefixIcon: Icon(Icons.tag_outlined),
                                    ),
                                  ),
                                ),
                                second: _buildField(
                                  label: 'سعر البيع الثالث (خاص - اختياري)',
                                  child: TextFormField(
                                    controller: _salePrice3Controller,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      hintText: '0.00',
                                      suffixText: 'ر.س',
                                      prefixIcon: Icon(Icons.loyalty_outlined),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _buildResponsiveRow(
                                isWide: isWide,
                                first: _buildField(
                                  label: 'الكمية الحالية / الافتتاحية بالمخزون',
                                  child: TextFormField(
                                    controller: _stockQuantityController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      hintText: '0',
                                      prefixIcon: Icon(Icons.inventory_2_outlined),
                                    ),
                                  ),
                                ),
                                second: _buildField(
                                  label: 'حد إعادة الطلب (تنبيه نقص الكمية)',
                                  child: TextFormField(
                                    controller: _minQuantityController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      hintText: '5',
                                      prefixIcon: Icon(Icons.warning_amber_outlined),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildSectionCard(
                            title: 'تفاصيل إضافية ووصف المنتج',
                            icon: Icons.notes_outlined,
                            children: [
                              _buildField(
                                label: 'الوصف التفصيلي للمنتج (اختياري)',
                                child: TextFormField(
                                  controller: _descriptionController,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    hintText: 'وصف تسويقي أو مواصفات فنية للمنتج...',
                                    prefixIcon: Icon(Icons.description_outlined),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _buildField(
                                label: 'ملاحظات إضافية',
                                child: TextFormField(
                                  controller: _notesController,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    hintText: 'اكتب أي تفاصيل وملاحظات خاصة بالمنتج أو طريقة حفظه ومصدره...',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // أزرار الإجراءات السفلية
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: _isSaving ? null : _saveProduct,
                                  icon: _isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Icon(Icons.save_outlined),
                                  label: Text(
                                    _isSaving ? 'جارٍ الحفظ...' : (_isEditing ? 'حفظ التعديلات' : 'حفظ المنتج الجديد'),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    minimumSize: const Size(0, 52),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: OutlinedButton(
                                  onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 52),
                                  ),
                                  child: const Text('إلغاء', style: TextStyle(fontSize: 15)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildResponsiveRow({
    required bool isWide,
    required Widget first,
    required Widget second,
  }) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const SizedBox(width: 16),
          Expanded(child: second),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          first,
          const SizedBox(height: 14),
          second,
        ],
      );
    }
  }
}
