import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/database_helper.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';

/// صفحة مستقلة للبحث عن المنتجات وتعديل أسعارها فردياً أو جماعياً
class ProductPriceUpdateScreen extends StatefulWidget {
  const ProductPriceUpdateScreen({super.key});

  @override
  State<ProductPriceUpdateScreen> createState() => _ProductPriceUpdateScreenState();
}

class _ProductPriceUpdateScreenState extends State<ProductPriceUpdateScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<ProductModel> _products = [];
  List<CategoryModel> _categories = [];
  int? _selectedCategoryId;
  bool _isLoading = true;

  // حالة التعديل الجماعي
  final Set<int> _selectedProductIds = {};
  int? _bulkCategoryId;
  final TextEditingController _changeValueCtrl = TextEditingController(text: '10');
  bool _isPercentage = true;
  bool _isIncrease = true;
  bool _updateSale1 = true;
  bool _updateSale2 = true;
  bool _updateSale3 = true;
  bool _updateCost = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _changeValueCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final products = await DatabaseHelper.instance.getProducts(
      query: _searchController.text,
      categoryId: _selectedCategoryId,
    );
    final categories = await DatabaseHelper.instance.getAllCategories();
    if (mounted) {
      setState(() {
        _products = products;
        _categories = categories;
        _isLoading = false;
      });
    }
  }

  /// فتح نافذة التعديل الفردي للأسعار
  Future<void> _openIndividualPriceDialog(ProductModel p) async {
    final costCtrl = TextEditingController(text: p.costPrice.toString());
    final sale1Ctrl = TextEditingController(text: p.salePrice1.toString());
    final sale2Ctrl = TextEditingController(text: p.salePrice2?.toString() ?? '');
    final sale3Ctrl = TextEditingController(text: p.salePrice3?.toString() ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تعديل أسعار: ${p.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('سعر الشراء (التكلفة):', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              TextField(
                controller: costCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.shopping_bag_outlined)),
              ),
              const SizedBox(height: 12),
              const Text('سعر البيع الأول (القطاعي) *:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              TextField(
                controller: sale1Ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.attach_money)),
              ),
              const SizedBox(height: 12),
              const Text('سعر البيع الثاني (الجملة):', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              TextField(
                controller: sale2Ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.payments_outlined)),
              ),
              const SizedBox(height: 12),
              const Text('سعر البيع الثالث (الخاص):', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              TextField(
                controller: sale3Ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.price_check_outlined)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حفظ الأسعار'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final cost = double.tryParse(costCtrl.text.trim()) ?? p.costPrice;
      final sale1 = double.tryParse(sale1Ctrl.text.trim()) ?? p.salePrice1;
      final sale2 = double.tryParse(sale2Ctrl.text.trim());
      final sale3 = double.tryParse(sale3Ctrl.text.trim());

      await DatabaseHelper.instance.updateProductPrices(
        productId: p.id!,
        costPrice: cost,
        salePrice1: sale1,
        salePrice2: sale2,
        salePrice3: sale3,
      );
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحديث أسعار "${p.name}" بنجاح'), backgroundColor: AppTheme.success),
        );
      }
    }
  }

  /// تطبيق التعديل الجماعي مع ملخص معاينة مسبق
  Future<void> _applyBulkPriceUpdate() async {
    final changeVal = double.tryParse(_changeValueCtrl.text.trim());
    if (changeVal == null || changeVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال قيمة تعديل صحيحة أكبر من صفر'), backgroundColor: AppTheme.danger),
      );
      return;
    }

    // تحديد قائمة المنتجات المستهدفة
    List<ProductModel> targetProducts;
    if (_bulkCategoryId != null) {
      targetProducts = _products.where((p) => p.categoryId == _bulkCategoryId).toList();
    } else if (_selectedProductIds.isNotEmpty) {
      targetProducts = _products.where((p) => _selectedProductIds.contains(p.id)).toList();
    } else {
      targetProducts = List.from(_products);
    }

    if (targetProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد منتجات محددة لتطبيق التعديل عليها'), backgroundColor: AppTheme.warning),
      );
      return;
    }

    // فتح نافذة الملخص والمعاينة قبل التطبيق
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.assignment_outlined, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('ملخص ومعاينة التعديل الجماعي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryRow('عدد المنتجات المستهدفة:', '${targetProducts.length} منتج'),
            _buildSummaryRow(
              'نوع العملية:',
              '${_isIncrease ? "زيادة" : "تخفيض"} بنسبة ${_isPercentage ? "$changeVal%" : "$changeVal ر.س"}',
            ),
            _buildSummaryRow('الأسعار المتأثرة:', [
              if (_updateSale1) 'سعر البيع 1',
              if (_updateSale2) 'سعر البيع 2',
              if (_updateSale3) 'سعر البيع 3',
              if (_updateCost) 'سعر التكلفة',
            ].join('، ')),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'تنبيه: سيتم تحديث الأسعار فعلياً في قاعدة البيانات لكافة الأصناف المذكورة أعلاه.',
                style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد وتطبيق التعديل'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final double? pctChange = _isPercentage ? (_isIncrease ? changeVal : -changeVal) : null;
      final double? fixedChange = !_isPercentage ? (_isIncrease ? changeVal : -changeVal) : null;

      final count = await DatabaseHelper.instance.bulkUpdatePricesForProductIds(
        productIds: targetProducts.map((p) => p.id!).toList(),
        percentageChange: pctChange,
        fixedAmountChange: fixedChange,
        updateCost: _updateCost,
        updateSale1: _updateSale1,
        updateSale2: _updateSale2,
        updateSale3: _updateSale3,
      );

      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحديث أسعار $count منتج بنجاح في قاعدة البيانات'), backgroundColor: AppTheme.success),
        );
      }
    }
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: AppTheme.primary))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل أسعار المنتجات'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.edit_outlined), text: 'تعديل فردي وسريع'),
            Tab(icon: Icon(Icons.tune_outlined), text: 'تعديل جماعي للأسعار'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildIndividualTab(),
          _buildBulkTab(),
        ],
      ),
    );
  }

  /// تبويب التعديل الفردي
  Widget _buildIndividualTab() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'ابحث عن منتج لتعديل سعره...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => _loadData(),
                ),
              ),
              const SizedBox(width: 10),
              DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _selectedCategoryId,
                  hint: const Text('التصنيف'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('كل التصنيفات')),
                    ..._categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedCategoryId = v);
                    _loadData();
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _products.isEmpty
                  ? const Center(child: Text('لا توجد منتجات مطابقة'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _products.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final p = _products[i];
                        return Container(
                          decoration: AppTheme.cardDecoration(),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Text(
                                      'البيع 1: ${Formatters.formatCurrency(p.salePrice1)} | التكلفة: ${Formatters.formatCurrency(p.costPrice)}',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                    if (p.salePrice2 != null || p.salePrice3 != null)
                                      Text(
                                        'البيع 2: ${Formatters.formatCurrency(p.salePrice2 ?? 0)} | البيع 3: ${Formatters.formatCurrency(p.salePrice3 ?? 0)}',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                      ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('تعديل الأسعار'),
                                onPressed: () => _openIndividualPriceDialog(p),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  /// تبويب التعديل الجماعي
  Widget _buildBulkTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // بطاقة خيارات التعديل
              Container(
                decoration: AppTheme.cardDecoration(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('1. نطاق المنتجات المستهدفة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      initialValue: _bulkCategoryId,
                      decoration: const InputDecoration(labelText: 'تطبيق على تصنيف محدد (أو الكل)'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('كافة المنتجات المسجلة')),
                        ..._categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (v) => setState(() => _bulkCategoryId = v),
                    ),
                    const SizedBox(height: 20),
                    const Text('2. نوع التعديل والقيمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(value: true, label: Text('زيادة (+)')),
                              ButtonSegment(value: false, label: Text('تخفيض (-)')),
                            ],
                            selected: {_isIncrease},
                            onSelectionChanged: (val) => setState(() => _isIncrease = val.first),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(value: true, label: Text('نسبة مئوية (%)')),
                              ButtonSegment(value: false, label: Text('مبلغ ثابت (ر.س)')),
                            ],
                            selected: {_isPercentage},
                            onSelectionChanged: (val) => setState(() => _isPercentage = val.first),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _changeValueCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: _isPercentage ? 'نسبة التعديل المئوية (%)' : 'قيمة المبلغ (ر.س)',
                        prefixIcon: Icon(_isPercentage ? Icons.percent : Icons.attach_money),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('3. الأسعار المراد تعديلها', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: const Text('سعر البيع الأول (الأساسي)'),
                      value: _updateSale1,
                      onChanged: (v) => setState(() => _updateSale1 = v ?? true),
                      dense: true,
                    ),
                    CheckboxListTile(
                      title: const Text('سعر البيع الثاني (الجملة)'),
                      value: _updateSale2,
                      onChanged: (v) => setState(() => _updateSale2 = v ?? false),
                      dense: true,
                    ),
                    CheckboxListTile(
                      title: const Text('سعر البيع الثالث (الخاص)'),
                      value: _updateSale3,
                      onChanged: (v) => setState(() => _updateSale3 = v ?? false),
                      dense: true,
                    ),
                    CheckboxListTile(
                      title: const Text('سعر الشراء (التكلفة)'),
                      value: _updateCost,
                      onChanged: (v) => setState(() => _updateCost = v ?? false),
                      dense: true,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      icon: const Icon(Icons.preview_outlined),
                      label: const Text('معاينة وتطبيق التعديل الجماعي'),
                      onPressed: _applyBulkPriceUpdate,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
