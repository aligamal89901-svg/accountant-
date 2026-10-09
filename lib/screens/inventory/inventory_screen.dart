import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/database_helper.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import 'product_form_screen.dart';

/// شاشة المخزون وإدارة المنتجات والتعديل الجماعي للأسعار (حسب البنود 10 و 11 و 13 من المواصفات)
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ProductModel> _products = [];
  List<CategoryModel> _categories = [];
  int? _selectedCategoryId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
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

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة تصنيف جديد'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'اسم التصنيف *', hintText: 'مثال: مشروبات، حبوب، مجمدات'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                await DatabaseHelper.instance.insertCategory(name);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showAddUnitDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة وحدة قياس جديدة'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'اسم الوحدة *', hintText: 'مثال: كرتون، شوال، طرد، لفة'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                await DatabaseHelper.instance.insertUnit(name);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showBulkPriceUpdateDialog() {
    int? targetCategoryId = _selectedCategoryId;
    String priceColumn = 'sale_price1';
    bool isPercentage = true;
    bool isIncrease = true;
    final valueController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.price_change_outlined, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('التعديل الجماعي للأسعار'),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'يتيح هذا الخيار تعديل الأسعار دفعة واحدة لجميع المنتجات أو لتصنيف محدد.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int?>(
                    initialValue: targetCategoryId,
                    decoration: const InputDecoration(labelText: 'التصنيف المستهدف'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('جميع التصنيفات والأصناف')),
                      ..._categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (v) => setDialogState(() => targetCategoryId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: priceColumn,
                    decoration: const InputDecoration(labelText: 'السعر المستهدف بالتعديل'),
                    items: const [
                      DropdownMenuItem(value: 'sale_price1', child: Text('سعر البيع 1 (الأساسي)')),
                      DropdownMenuItem(value: 'sale_price2', child: Text('سعر البيع 2 (جملة)')),
                      DropdownMenuItem(value: 'sale_price3', child: Text('سعر البيع 3 (خاص)')),
                      DropdownMenuItem(value: 'cost_price', child: Text('سعر التكلفة / الشراء')),
                    ],
                    onChanged: (v) => setDialogState(() => priceColumn = v!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<bool>(
                          initialValue: isIncrease,
                          decoration: const InputDecoration(labelText: 'العملية'),
                          items: const [
                            DropdownMenuItem(value: true, child: Text('زيادة (+)')),
                            DropdownMenuItem(value: false, child: Text('تخفيض (-)')),
                          ],
                          onChanged: (v) => setDialogState(() => isIncrease = v!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<bool>(
                          initialValue: isPercentage,
                          decoration: const InputDecoration(labelText: 'نوع التعديل'),
                          items: const [
                            DropdownMenuItem(value: true, child: Text('نسبة مئوية (%)')),
                            DropdownMenuItem(value: false, child: Text('مبلغ ثابت (ر.س)')),
                          ],
                          onChanged: (v) => setDialogState(() => isPercentage = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: valueController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: isPercentage ? 'النسبة المئوية (مثال: 5 أو 10)' : 'المبلغ الثابت (مثال: 2.50)',
                      suffixText: isPercentage ? '%' : 'ر.س',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final val = double.tryParse(valueController.text.trim());
                if (val == null || val <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال قيمة تعديل صحيحة أكبر من الصفر')),
                  );
                  return;
                }

                // تأكيد مسبق للعملية لتجنب الأخطاء
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (confirmCtx) => AlertDialog(
                    title: const Text('تأكيد تعديل الأسعار'),
                    content: Text(
                      'هل أنت متأكد من تطبيق ${isIncrease ? "زيادة" : "تخفيض"} بمقدار $val ${isPercentage ? "%" : "ر.س"} على الأسعار المستهدفة؟',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(confirmCtx, false), child: const Text('تراجع')),
                      ElevatedButton(onPressed: () => Navigator.pop(confirmCtx, true), child: const Text('تأكيد التطبيق')),
                    ],
                  ),
                );

                if (confirmed == true) {
                  final affected = await DatabaseHelper.instance.bulkUpdatePrices(
                    categoryId: targetCategoryId,
                    priceColumn: priceColumn,
                    changeValue: val,
                    isPercentage: isPercentage,
                    isIncrease: isIncrease,
                  );

                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم تعديل أسعار $affected صنف بنجاح'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                }
              },
              child: const Text('تطبيق التعديل'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openProductForm([ProductModel? existingProduct]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => ProductFormScreen(product: existingProduct),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 650;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // رأس الشاشة مع البحث وأزرار الإجراءات المتجاوبة
                if (isMobile) ...[
                  // على الهاتف: شريط البحث بالأعلى
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'بحث بالاسم أو الباركود...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _loadData();
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => _loadData(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openProductForm(),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('إضافة منتج'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            minimumSize: const Size(0, 44),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _showBulkPriceUpdateDialog,
                        icon: const Icon(Icons.tune, size: 18),
                        label: const Text('تعديل الأسعار'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // على الكمبيوتر والشاشات الأوسع: سطر واحد مريح
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'بحث بالاسم أو الباركود في المخزون...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      _loadData();
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (_) => _loadData(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _showBulkPriceUpdateDialog,
                        icon: const Icon(Icons.tune, size: 18),
                        label: const Text('تعديل جماعي للأسعار'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => _openProductForm(),
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة منتج جديد'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // تصنيفات المنتجات وفلاترها
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('جميع الأصناف'),
                              selected: _selectedCategoryId == null,
                              onSelected: (val) {
                                setState(() => _selectedCategoryId = null);
                                _loadData();
                              },
                            ),
                            const SizedBox(width: 8),
                            ..._categories.map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: ChoiceChip(
                                  label: Text(c.name),
                                  selected: _selectedCategoryId == c.id,
                                  onSelected: (val) {
                                    setState(() => _selectedCategoryId = val ? c.id : null);
                                    _loadData();
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: AppTheme.primary),
                      tooltip: 'إضافة تصنيف جديد',
                      onPressed: _showAddCategoryDialog,
                    ),
                    IconButton(
                      icon: const Icon(Icons.straighten_outlined, color: AppTheme.secondary),
                      tooltip: 'إضافة وحدة قياس جديدة',
                      onPressed: _showAddUnitDialog,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // قائمة الأصناف
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _products.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'لا توجد منتجات مسجلة حالياً في المخزون',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'اضغط على "إضافة منتج جديد" لإدخال الأصناف وبياناتها',
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => _openProductForm(),
                                    icon: const Icon(Icons.add),
                                    label: const Text('إضافة منتج الآن'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: _products.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final p = _products[index];
                                final isLow = p.isLowStock;
                                final isOut = p.isOutOfStock;

                                return Container(
                                  decoration: AppTheme.cardDecoration(),
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // أيقونة حالة المخزون
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: isOut
                                              ? AppTheme.danger.withValues(alpha: 0.1)
                                              : isLow
                                                  ? AppTheme.warning.withValues(alpha: 0.1)
                                                  : AppTheme.secondary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.inventory_2_outlined,
                                          color: isOut
                                              ? AppTheme.danger
                                              : isLow
                                                  ? AppTheme.warning
                                                  : AppTheme.secondary,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // تفاصيل المنتج
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    p.name,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15,
                                                      color: AppTheme.textPrimary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                if (p.isFrozen)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blueGrey.shade100,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text('مجمد', style: TextStyle(fontSize: 10)),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 4,
                                              children: [
                                                Text(
                                                  'الباركود: ${p.barcode}',
                                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                                ),
                                                Text(
                                                  'الوحدة: ${p.unitName ?? "قطعة"}',
                                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: isOut
                                                        ? AppTheme.danger.withValues(alpha: 0.1)
                                                        : isLow
                                                            ? AppTheme.warning.withValues(alpha: 0.1)
                                                            : AppTheme.success.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    isOut
                                                        ? 'نفد المخزون'
                                                        : isLow
                                                            ? 'منخفض (${Formatters.formatNumber(p.stockQuantity)})'
                                                            : 'متوفر (${Formatters.formatNumber(p.stockQuantity)})',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: isOut
                                                          ? AppTheme.danger
                                                          : isLow
                                                              ? AppTheme.warning
                                                              : AppTheme.success,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 8),

                                      // السعر والإجراءات
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            Formatters.formatCurrency(p.salePrice1),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                          Text(
                                            'تكلفة: ${Formatters.formatCurrency(p.costPrice)}',
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(width: 6),

                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.primary),
                                            tooltip: 'تعديل بيانات المنتج',
                                            onPressed: () => _openProductForm(p),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.danger),
                                            tooltip: 'حذف المنتج',
                                            onPressed: () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text('تأكيد الحذف'),
                                                  content: Text('هل أنت متأكد من حذف المنتج "${p.name}"؟'),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                                    ElevatedButton(
                                                      onPressed: () => Navigator.pop(ctx, true),
                                                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                                                      child: const Text('حذف'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) {
                                                await DatabaseHelper.instance.deleteProductSafely(p.id!);
                                                _loadData();
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
