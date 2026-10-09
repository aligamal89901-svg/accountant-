import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/database_helper.dart';
import '../../services/excel_product_service.dart';
import '../inventory/product_excel_screen.dart';

/// شاشة النسخ الاحتياطي والاسترداد الذكي للنظام المحاسبي
class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _isLoading = true;
  bool _isProcessing = false;
  Map<String, int> _dbStats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final products = await DatabaseHelper.instance.getProducts();
    final customers = await DatabaseHelper.instance.getCustomers();
    final suppliers = await DatabaseHelper.instance.getSuppliers();
    final invoices = await DatabaseHelper.instance.getInvoices();
    final cashBoxes = await DatabaseHelper.instance.getCashBoxes();
    final cashTransactions = await DatabaseHelper.instance.getCashTransactions();

    if (mounted) {
      setState(() {
        _dbStats = {
          'products': products.length,
          'customers': customers.length,
          'suppliers': suppliers.length,
          'invoices': invoices.length,
          'cashBoxes': cashBoxes.length,
          'cashTransactions': cashTransactions.length,
        };
        _isLoading = false;
      });
    }
  }

  /// 1. تصدير نسخة احتياطية شاملة للنظام (JSON)
  Future<void> _exportFullSystemBackup() async {
    setState(() => _isProcessing = true);
    try {
      final backupData = await DatabaseHelper.instance.exportFullBackupJson();
      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      final bytes = utf8.encode(jsonString);

      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      final filename = 'accounting_system_backup_$dateStr.json';

      await Printing.sharePdf(
        bytes: bytes,
        filename: filename,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تصدير النسخة الاحتياطية الكاملة للنظام بنجاح ($filename)'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء تصدير النسخة الاحتياطية: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// 2. تصدير ملف Excel للمنتجات فقط (XLSX)
  Future<void> _exportProductsExcel() async {
    setState(() => _isProcessing = true);
    try {
      final products = await DatabaseHelper.instance.getProducts();
      final bytes = ExcelProductService.exportProductsToXlsx(products);
      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      final filename = 'منتجات_المخزون_$dateStr.xlsx';

      await Printing.sharePdf(
        bytes: bytes,
        filename: filename,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تصدير ${products.length} منتج بصيغة Excel (XLSX) بنجاح'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء تصدير ملف Excel: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// 3. استرداد ذكي: فحص نوع الملف (JSON للنظام أو XLSX للمنتجات) وتوجيهه تلقائياً
  Future<void> _pickAndSmartRestore() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'xlsx', 'xls', 'db'],
      );

      if (files.isEmpty) return;

      final file = files.first;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الملف المحدد فارغ'), backgroundColor: AppTheme.warning),
          );
        }
        return;
      }

      final ext = file.name.split('.').last.toLowerCase();

      // التحقق: هل الملف XLSX (يبدأ بـ PK\x03\x04 أو امتداد xlsx)
      final isXlsx = ext == 'xlsx' || ext == 'xls' ||
          (bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04);

      if (isXlsx) {
        // توجيه تلقائي لاستيراد المنتجات فقط دون المساس بباقي الجداول
        if (!mounted) return;
        await _handleExcelProductsImport(file.name, bytes);
        return;
      }

      // إذا كان JSON: استرداد النسخة الاحتياطية الشاملة للنظام
      if (ext == 'json') {
        if (!mounted) return;
        await _handleJsonSystemRestore(file.name, bytes);
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('نوع الملف (${file.name}) غير مدعوم للاسترداد. يرجى اختيار ملف .json أو .xlsx'), backgroundColor: AppTheme.warning),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء قراءة الملف: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  /// معالجة استيراد ملف Excel للمنتجات فقط دون مسح قاعدة البيانات
  Future<void> _handleExcelProductsImport(String fileName, List<int> bytes) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.table_view_outlined, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('اكتشاف ملف Excel للمنتجات'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تم التعرف على الملف المرفوع ($fileName) كملف Excel مخصص للمنتجات.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security_outlined, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سيتم توجيه العملية تلقائياً لتحديث وإضافة المنتجات فقط دون المساس بباقي بيانات النظام (الفواتير، العملاء، الموردين، الصناديق).',
                      style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('الانتقال لمعاينة واستيراد المنتجات'),
          ),
        ],
      ),
    );

    if (proceed == true && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (ctx) => const ProductExcelScreen()),
      );
      _loadStats();
    }
  }

  /// معالجة استرداد النسخة الاحتياطية الشاملة للنظام (JSON)
  Future<void> _handleJsonSystemRestore(String fileName, List<int> bytes) async {
    Map<String, dynamic> data;
    try {
      final jsonString = utf8.decode(bytes);
      data = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('الملف المحدد ليس ملف JSON صالح: $e'), backgroundColor: AppTheme.danger),
        );
      }
      return;
    }

    // التحقق من صحة الملف وإصداره
    if (data['system'] != 'AccountingApp' || !data.containsKey('tables')) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('ملف غير متوافق'),
            content: const Text(
              'الملف المحدد ليس نسخة احتياطية صالحة لهذا النظام المحاسبي.\n'
              'تأكد من أن الملف صادر عن وظيفة «تصدير نسخة احتياطية شاملة».',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً')),
            ],
          ),
        );
      }
      return;
    }

    final schemaVersion = data['schema_version'] ?? 1;
    final createdAt = data['created_at'] ?? 'غير معروف';
    final tables = data['tables'] as Map<String, dynamic>? ?? {};

    final productsCount = (tables['products'] as List?)?.length ?? 0;
    final invoicesCount = (tables['invoices'] as List?)?.length ?? 0;
    final customersCount = (tables['customers'] as List?)?.length ?? 0;
    final suppliersCount = (tables['suppliers'] as List?)?.length ?? 0;
    final cashCount = (tables['cash_transactions'] as List?)?.length ?? 0;

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.danger),
            SizedBox(width: 8),
            Text('تأكيد استرداد نسخة النظام الشاملة'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الملف: $fileName', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('تاريخ النسخة: $createdAt', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              Text('إصدار البنية: الإصدار $schemaVersion', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              const Text('محتويات النسخة الاحتياطية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildPreviewRow('المنتجات والأصناف', '$productsCount منتج'),
                    _buildPreviewRow('الفواتير المحاسبية', '$invoicesCount فاتورة'),
                    _buildPreviewRow('العملاء', '$customersCount عميل'),
                    _buildPreviewRow('الموردون', '$suppliersCount مورد'),
                    _buildPreviewRow('حركات الصندوق', '$cashCount حركة نقدية'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_rounded, color: AppTheme.danger, size: 22),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تحذير هام: سيتم استبدال قاعدة البيانات الحالية بالكامل ببيانات هذه النسخة داخل معاملة مصرفية ذرية آمنة.',
                        style: TextStyle(color: AppTheme.danger, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('نعم، استبدل البيانات الآن'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      try {
        final result = await DatabaseHelper.instance.importFullBackupJson(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم استرداد البيانات بنجاح: ${result['products']} منتج، ${result['invoices']} فاتورة'),
              backgroundColor: AppTheme.success,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        await _loadStats();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل استرداد البيانات: $e'), backgroundColor: AppTheme.danger),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('النسخ الاحتياطي والاسترداد الذكي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث الإحصائيات',
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _isLoading || _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_isProcessing ? 'جاري معالجة البيانات بأمان...' : 'جاري تحميل الإحصائيات...'),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 800;
                final contentWidth = isWide ? 760.0 : double.infinity;

                return Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      children: [
                        // بطاقة إحصائيات قاعدة البيانات الحالية
                        _buildDatabaseStatsCard(),
                        const SizedBox(height: 24),

                        const Text(
                          'تصدير النسخ والبيانات',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 12),

                        // خيار 1: تصدير نسخة احتياطية كاملة (JSON)
                        _buildActionTile(
                          title: 'تصدير نسخة احتياطية شاملة للنظام (JSON)',
                          subtitle: 'نسخ كامل لكافة المنتجات، الفواتير، الحسابات، الصناديق، والإعدادات داخل ملف JSON مهيكل ومحمي',
                          icon: Icons.cloud_download_outlined,
                          iconColor: AppTheme.primary,
                          iconBgColor: AppTheme.primary.withValues(alpha: 0.1),
                          buttonLabel: 'تصدير النظام بالكامل',
                          onTap: _exportFullSystemBackup,
                        ),
                        const SizedBox(height: 12),

                        // خيار 2: تصدير المنتجات إلى ملف Excel (XLSX)
                        _buildActionTile(
                          title: 'تصدير المنتجات إلى ملف Excel (XLSX)',
                          subtitle: 'تصدير جدول المنتجات بالأسعار والكميات والتصنيفات والباركودات لفتحه في Microsoft Excel',
                          icon: Icons.table_view_outlined,
                          iconColor: const Color(0xFF10B981),
                          iconBgColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                          buttonLabel: 'تصدير ملف Excel',
                          onTap: _exportProductsExcel,
                        ),
                        const SizedBox(height: 24),

                        const Text(
                          'استرداد البيانات الذكي',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 8),

                        // بطاقة الاسترداد الذكي
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.border),
                            boxShadow: const [
                              BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.settings_backup_restore_outlined, color: Color(0xFF7C3AED), size: 26),
                                  ),
                                  const SizedBox(width: 14),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('استرداد ملف (كشف تلقائي لنوع الملف)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        SizedBox(height: 4),
                                        Text('اختر ملف .json أو .xlsx وسيتعرف النظام عليه تلقائياً', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.background,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'ملف Excel (XLSX): يوجه تلقائياً لتحديث وإضافة المنتجات دون المساس بأي جدول آخر.',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.check_circle_outline, size: 16, color: AppTheme.primary),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'ملف JSON للنظام: يتحقق من سلامة البنية والإصدار ويستبدل البيانات بأمان بعد تأكيدك.',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _pickAndSmartRestore,
                                  icon: const Icon(Icons.file_open_outlined),
                                  label: const Text('اختيار ملف واسترداده الآن'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    backgroundColor: const Color(0xFF7C3AED),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDatabaseStatsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.dns_outlined, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('حالة قاعدة البيانات الحالية للنظام', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('المنتجات', '${_dbStats['products'] ?? 0}', Icons.inventory_2_outlined, AppTheme.primary),
              ),
              Expanded(
                child: _buildStatItem('الفواتير', '${_dbStats['invoices'] ?? 0}', Icons.receipt_long_outlined, const Color(0xFF0284C7)),
              ),
              Expanded(
                child: _buildStatItem('العملاء', '${_dbStats['customers'] ?? 0}', Icons.people_outline, AppTheme.success),
              ),
              Expanded(
                child: _buildStatItem('الموردون', '${_dbStats['suppliers'] ?? 0}', Icons.store_outlined, const Color(0xFFD97706)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: iconColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}
