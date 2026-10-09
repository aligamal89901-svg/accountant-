import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/database_helper.dart';
import '../../services/excel_product_service.dart';

/// شاشة تصدير واستيراد المنتجات الحقيقية عبر ملفات Excel (XLSX)
class ProductExcelScreen extends StatefulWidget {
  const ProductExcelScreen({super.key});

  @override
  State<ProductExcelScreen> createState() => _ProductExcelScreenState();
}

class _ProductExcelScreenState extends State<ProductExcelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isExporting = false;
  bool _isAnalyzing = false;
  bool _isImporting = false;
  double _importProgress = 0.0;
  String _importProgressText = '';

  // بيانات المعاينة
  ExcelParseResult? _parseResult;
  String? _selectedFileName;
  String _duplicatePolicy = 'update'; // 'update' or 'skip'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// تصدير المنتجات إلى ملف XLSX حقيقي
  Future<void> _exportProducts() async {
    setState(() => _isExporting = true);
    try {
      final products = await DatabaseHelper.instance.getProducts();
      final bytes = ExcelProductService.exportProductsToXlsx(products);

      // مشاركة أو تنزيل الملف
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'منتجات_النظام_المحاسبي_${DateTime.now().year}_${DateTime.now().month}_${DateTime.now().day}.xlsx',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تصدير ${products.length} منتج بنجاح بصيغة XLSX'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء التصدير: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// اختيار ملف XLSX وقراءته ومعاينته
  Future<void> _pickAndAnalyzeFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (files.isEmpty) return;

      final file = files.first;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر قراءة بيانات الملف المختار'), backgroundColor: AppTheme.danger),
          );
        }
        return;
      }

      setState(() {
        _isAnalyzing = true;
        _selectedFileName = file.name;
      });

      final parsed = await ExcelProductService.parseAndAnalyze(bytes: bytes);

      setState(() {
        _parseResult = parsed;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في فحص ملف Excel: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  /// تنفيذ عملية الاستيراد بعد المعاينة والتأكيد
  Future<void> _confirmAndExecuteImport() async {
    if (_parseResult == null) return;

    final allItems = [
      ..._parseResult!.validItems,
      ..._parseResult!.duplicateItems,
    ];

    if (allItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد صفوف صالحة للاستيراد في هذا الملف'), backgroundColor: AppTheme.warning),
      );
      return;
    }

    setState(() {
      _isImporting = true;
      _importProgress = 0.0;
      _importProgressText = 'جاري تهيئة قاعدة البيانات...';
    });

    try {
      final res = await ExcelProductService.executeImport(
        itemsToImport: allItems,
        duplicatePolicy: _duplicatePolicy,
        onProgress: (current, total) {
          setState(() {
            _importProgress = current / total;
            _importProgressText = 'جاري استيراد $current من $total صنف...';
          });
        },
      );

      setState(() {
        _isImporting = false;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.success),
                SizedBox(width: 8),
                Text('تقرير اكتمال الاستيراد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إجمالي السجلات المعالجة: ${res["total"]}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('✓ سجلات جديدة أُضيفت: ${res["inserted"]}', style: const TextStyle(color: AppTheme.success)),
                Text('✓ سجلات موجودة حُدثت: ${res["updated"]}', style: const TextStyle(color: AppTheme.primary)),
                Text('• سجلات تم تخطيها: ${res["skipped"]}', style: const TextStyle(color: AppTheme.textSecondary)),
                if (res["failed"] > 0)
                  Text('✗ سجلات تعذر استيرادها: ${res["failed"]}', style: const TextStyle(color: AppTheme.danger)),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _parseResult = null;
                    _selectedFileName = null;
                  });
                },
                child: const Text('تم'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isImporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الاستيراد: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تصدير واستيراد المنتجات (Excel)'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.file_upload_outlined), text: 'استيراد من ملف Excel'),
            Tab(icon: Icon(Icons.file_download_outlined), text: 'تصدير المنتجات الحالية'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildImportTab(),
          _buildExportTab(),
        ],
      ),
    );
  }

  /// تبويب الاستيراد والمعاينة
  Widget _buildImportTab() {
    if (_isImporting) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(_importProgressText, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _importProgress),
              const SizedBox(height: 8),
              Text('${(_importProgress * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
    }

    if (_isAnalyzing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري فحص ملف Excel وتحليل الأعمدة والمطابقة...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // بطاقة اختيار الملف
              Container(
                decoration: AppTheme.cardDecoration(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.table_view_rounded, size: 56, color: Color(0xFF10B981)),
                    const SizedBox(height: 12),
                    const Text(
                      'استيراد الأصناف والمنتجات من ملف XLSX',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'يدعم الملفات الكبيرة حتى 4000+ صنف. يتم استيراد بيانات المنتجات والتصنيفات فقط دون حذف أو مساس ببيانات العملاء أو الفواتير.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        minimumSize: const Size(220, 48),
                      ),
                      icon: const Icon(Icons.file_open_outlined),
                      label: Text(_selectedFileName == null ? 'اختيار ملف Excel (XLSX)' : 'تغيير الملف ($_selectedFileName)'),
                      onPressed: _pickAndAnalyzeFile,
                    ),
                  ],
                ),
              ),

              if (_parseResult != null) ...[
                const SizedBox(height: 20),
                // ملخص الفحص والمعاينة
                Container(
                  decoration: AppTheme.cardDecoration(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.analytics_outlined, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Text('نتائج فحص ومعاينة الملف', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildBadgeCount('إجمالي الصفوف', '${_parseResult!.totalRows}', AppTheme.primary),
                          _buildBadgeCount('منتجات جديدة', '${_parseResult!.validItems.length}', AppTheme.success),
                          _buildBadgeCount('منتجات مكررة', '${_parseResult!.duplicateItems.length}', AppTheme.warning),
                          _buildBadgeCount('صفوف مرفوضة', '${_parseResult!.invalidItems.length}', AppTheme.danger),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('سياسة معالجة المنتجات المكررة (الموجودة مسبقاً):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      RadioListTile<String>(
                        title: const Text('تحديث بيانات المنتج (تحديث الأسعار والمخزون والوصف)'),
                        subtitle: const Text('يحتفظ بالمنتج الحالي ويحدث أسعاره ومخزونه وفق الملف الجديد'),
                        value: 'update',
                        groupValue: _duplicatePolicy,
                        onChanged: (v) => setState(() => _duplicatePolicy = v!),
                        dense: true,
                      ),
                      RadioListTile<String>(
                        title: const Text('تخطي المنتجات الموجودة مسبقاً (إبقاء القديم دون تعديل)'),
                        subtitle: const Text('يستورد فقط المنتجات الجديدة كلياً ويتجاهل الأصناف المسجلة'),
                        value: 'skip',
                        groupValue: _duplicatePolicy,
                        onChanged: (v) => setState(() => _duplicatePolicy = v!),
                        dense: true,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        icon: const Icon(Icons.check),
                        label: Text('تأكيد وبدء الاستيراد (${_parseResult!.validItems.length + _parseResult!.duplicateItems.length} صنف)'),
                        onPressed: _confirmAndExecuteImport,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeCount(String label, String count, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  /// تبويب التصدير
  Widget _buildExportTab() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550),
        padding: const EdgeInsets.all(24),
        child: Container(
          decoration: AppTheme.cardDecoration(),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.download_for_offline_outlined, size: 64, color: AppTheme.primary),
              const SizedBox(height: 16),
              const Text('تصدير كافة الأصناف إلى ملف Excel (XLSX)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'يقوم بإنشاء ملف Excel رسمي يتضمن كافة بيانات المنتجات:\nالاسم، الباركود، التصنيف، الوحدة، أسعار البيع الثلاثة، سعر التكلفة، المخزون، والوزن والوصف.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              if (_isExporting)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size(220, 50),
                  ),
                  icon: const Icon(Icons.file_download),
                  label: const Text('تصدير وتحميل ملف Excel الآن'),
                  onPressed: _exportProducts,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
