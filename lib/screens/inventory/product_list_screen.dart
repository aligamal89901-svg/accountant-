import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/database_helper.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../models/unit_model.dart';
import 'product_form_screen.dart';

/// صفحة مخصصة لعرض المنتجات وإدارتها (بحث، تصفية، باركود، تغيير الصنف والوحدة والوزن، وتقرير المخزون)
/// خالية من زر إضافة منتج رئيسي تماشياً مع متطلبات التخصيص
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ProductModel> _products = [];
  List<CategoryModel> _categories = [];
  List<UnitModel> _units = [];
  int? _selectedCategoryId;
  String _filterStatus = 'all'; // all, lowStock, outOfStock
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
    final units = await DatabaseHelper.instance.getAllUnits();

    if (mounted) {
      setState(() {
        _products = products;
        _categories = categories;
        _units = units;
        _isLoading = false;
      });
    }
  }

  List<ProductModel> get _filteredProducts {
    if (_filterStatus == 'lowStock') {
      return _products.where((p) => p.isLowStock).toList();
    } else if (_filterStatus == 'outOfStock') {
      return _products.where((p) => p.isOutOfStock).toList();
    }
    return _products;
  }

  /// تغيير الصنف والوحدة والوزن مباشرة
  Future<void> _showChangeAttributesDialog(ProductModel product) async {
    int? selectedCategory = product.categoryId;
    int? selectedUnit = product.unitId;
    final weightCtrl = TextEditingController(text: product.weight != null ? product.weight.toString() : '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('تعديل خصائص: ${product.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('التصنيف:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int?>(
                initialValue: selectedCategory,
                items: [
                  const DropdownMenuItem(value: null, child: Text('بدون تصنيف')),
                  ..._categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) => setDlgState(() => selectedCategory = v),
              ),
              const SizedBox(height: 12),
              const Text('وحدة القياس:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int?>(
                initialValue: selectedUnit,
                items: [
                  const DropdownMenuItem(value: null, child: Text('بدون وحدة')),
                  ..._units.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))),
                ],
                onChanged: (v) => setDlgState(() => selectedUnit = v),
              ),
              const SizedBox(height: 12),
              const Text('الوزن (اختياري):', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: 'مثال: 0.5 كجم'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حفظ التعديل'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final updated = product.copyWith(
        categoryId: selectedCategory,
        unitId: selectedUnit,
        weight: double.tryParse(weightCtrl.text.trim()),
      );
      await DatabaseHelper.instance.updateProduct(updated);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث خصائص المنتج بنجاح'), backgroundColor: AppTheme.success),
        );
      }
    }
  }

  /// إنشاء وطباعة ملصق الباركود للصنف
  Future<void> _printProductBarcode(ProductModel product) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(50 * PdfPageFormat.mm, 30 * PdfPageFormat.mm),
        margin: const pw.EdgeInsets.all(3 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  product.name,
                  style: pw.TextStyle(font: fontBold, fontSize: 8),
                  maxLines: 1,
                ),
                pw.SizedBox(height: 2),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: product.barcode.isNotEmpty ? product.barcode : '000000',
                  width: 40 * PdfPageFormat.mm,
                  height: 14 * PdfPageFormat.mm,
                  drawText: true,
                  textStyle: pw.TextStyle(font: font, fontSize: 6),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'السعر: ${Formatters.formatCurrency(product.salePrice1)}',
                  style: pw.TextStyle(font: fontBold, fontSize: 7),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'باركود_${product.name}.pdf',
    );
  }

  /// طباعة تقرير شامل للمخزون
  Future<void> _printInventoryReport() async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final shopName = await DatabaseHelper.instance.getSetting('shop_name') ?? 'النظام المحاسبي';
    final products = _filteredProducts;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Center(
                    child: pw.Text(
                      shopName,
                      style: pw.TextStyle(font: fontBold, fontSize: 16),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Center(
                    child: pw.Text(
                      'تقرير جرد وتقييم المخزون الحالي',
                      style: pw.TextStyle(font: fontBold, fontSize: 14),
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.TableHelper.fromTextArray(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    headers: ['#', 'المنتج', 'الباركود', 'التصنيف', 'الكمية', 'التكلفة', 'سعر البيع', 'القيمة الإجمالية'],
                    headerStyle: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white),
                    headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E3A5F)),
                    cellStyle: pw.TextStyle(font: font, fontSize: 8),
                    cellAlignment: pw.Alignment.center,
                    data: List.generate(products.length, (i) {
                      final p = products[i];
                      final totalValue = p.stockQuantity * p.costPrice;
                      return [
                        '${i + 1}',
                        p.name,
                        p.barcode,
                        p.categoryName ?? '-',
                        '${Formatters.formatNumber(p.stockQuantity)} ${p.unitName ?? ""}',
                        Formatters.formatCurrency(p.costPrice),
                        Formatters.formatCurrency(p.salePrice1),
                        Formatters.formatCurrency(totalValue),
                      ];
                    }),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'تقرير_المخزون.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('عرض وإدارة المنتجات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'طباعة تقرير المخزون',
            onPressed: _printInventoryReport,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث البيانات',
            onPressed: _loadData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final filtered = _filteredProducts;

          return Column(
            children: [
              // شريط البحث والفلترة
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'ابحث بالاسم أو الباركود...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
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
                        // قائمة التصنيفات
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              value: _selectedCategoryId,
                              hint: const Text('كل التصنيفات', style: TextStyle(fontSize: 13)),
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // فلاتر الحالة السريعة (الكل، النواقص، نفد)
                    Row(
                      children: [
                        _buildFilterChip('الكل (${_products.length})', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'نواقص (${_products.where((p) => p.isLowStock).length})',
                          'lowStock',
                          color: AppTheme.warning,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'نفد المخزون (${_products.where((p) => p.isOutOfStock).length})',
                          'outOfStock',
                          color: AppTheme.danger,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // قائمة أو جدول المنتجات
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.inventory_2_outlined, size: 64, color: AppTheme.border),
                                const SizedBox(height: 12),
                                Text(
                                  _searchController.text.isNotEmpty
                                      ? 'لا توجد نتائج مطابقة للبحث'
                                      : 'لا توجد منتجات مسجلة في هذا القسم',
                                  style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (ctx, index) {
                              final p = filtered[index];
                              return _buildProductCard(p, isWide);
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, {Color? color}) {
    final isSelected = _filterStatus == value;
    final activeColor = color ?? AppTheme.primary;

    return InkWell(
      onTap: () => setState(() => _filterStatus = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? activeColor : AppTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? activeColor : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(ProductModel p, bool isWide) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // أيقونة وحالة المنتج
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.isOutOfStock
                  ? AppTheme.danger.withValues(alpha: 0.1)
                  : p.isLowStock
                      ? AppTheme.warning.withValues(alpha: 0.1)
                      : AppTheme.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              p.isOutOfStock
                  ? Icons.remove_shopping_cart_outlined
                  : p.isLowStock
                      ? Icons.warning_amber_rounded
                      : Icons.inventory_2_outlined,
              color: p.isOutOfStock
                  ? AppTheme.danger
                  : p.isLowStock
                      ? AppTheme.warning
                      : AppTheme.secondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          // بيانات المنتج الأساسية
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (p.categoryName != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          p.categoryName!,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  children: [
                    Text(
                      'الباركود: ${p.barcode.isNotEmpty ? p.barcode : "بدون"}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    Text(
                      'المخزون: ${Formatters.formatNumber(p.stockQuantity)} ${p.unitName ?? "قطعة"}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: p.isOutOfStock
                            ? AppTheme.danger
                            : p.isLowStock
                                ? AppTheme.warning
                                : AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'البيع: ${Formatters.formatCurrency(p.salePrice1)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                    Text(
                      'التكلفة: ${Formatters.formatCurrency(p.costPrice)}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    if (p.weight != null && p.weight! > 0)
                      Text(
                        'الوزن: ${p.weight} كجم',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // أزرار العمليات المخصصة
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // زر تعديل الخصائص (الصنف، الوحدة، الوزن)
              IconButton(
                icon: const Icon(Icons.tune_outlined, size: 20, color: AppTheme.textSecondary),
                tooltip: 'تغيير الصنف أو الوحدة أو الوزن',
                onPressed: () => _showChangeAttributesDialog(p),
              ),
              // زر طباعة الباركود
              IconButton(
                icon: const Icon(Icons.qr_code_2_outlined, size: 20, color: AppTheme.secondary),
                tooltip: 'طباعة ملصق الباركود',
                onPressed: () => _printProductBarcode(p),
              ),
              // زر تعديل المنتج كاملاً
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.primary),
                tooltip: 'تعديل بيانات المنتج',
                onPressed: () async {
                  final edited = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (ctx) => ProductFormScreen(product: p)),
                  );
                  if (edited == true) _loadData();
                },
              ),
              // زر الحذف الآمن
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
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('تأكيد الحذف'),
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
  }
}
