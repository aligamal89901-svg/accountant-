import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/database_helper.dart';
import 'product_form_screen.dart';
import 'product_list_screen.dart';
import 'product_price_update_screen.dart';
import 'product_excel_screen.dart';

/// الصفحة الرئيسية المستقلة للمخزون (Inventory Hub)
/// تحتوي على أزرار طولية كبيرة وحديثة مرتبة رأسياً لخيارات المخزون الأساسية
class InventoryHubScreen extends StatefulWidget {
  const InventoryHubScreen({super.key});

  @override
  State<InventoryHubScreen> createState() => _InventoryHubScreenState();
}

class _InventoryHubScreenState extends State<InventoryHubScreen> {
  int _totalProducts = 0;
  int _lowStockCount = 0;
  int _categoriesCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final products = await DatabaseHelper.instance.getProducts();
    final categories = await DatabaseHelper.instance.getAllCategories();
    if (mounted) {
      setState(() {
        _totalProducts = products.length;
        _lowStockCount = products.where((p) => p.isLowStock || p.isOutOfStock).length;
        _categoriesCount = categories.length;
        _isLoading = false;
      });
    }
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.category_outlined, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('إضافة تصنيف جديد', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اسم التصنيف الجديد:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'مثال: مواد غذائية، مشروبات، إلكترونيات...',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final exists = await DatabaseHelper.instance.categoryExists(name);
              if (exists) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('هذا التصنيف موجود بالفعل!'), backgroundColor: AppTheme.warning),
                  );
                }
                return;
              }
              await DatabaseHelper.instance.insertCategory(name);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تمت إضافة التصنيف "$name" بنجاح'), backgroundColor: AppTheme.success),
                );
                _loadStats();
              }
            },
            child: const Text('حفظ التصنيف'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المخزون والمنتجات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث الإحصائيات',
            onPressed: _loadStats,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 800;
          final contentWidth = isWide ? 760.0 : double.infinity;

          return Center(
            child: SizedBox(
              width: contentWidth,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                children: [
                  // بطاقة ملخص المخزون السريع
                  _buildQuickStatsCard(),
                  const SizedBox(height: 24),

                  // عنوان القسم
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Text(
                      'الخيارات الرئيسية للمخزون',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 1. إضافة منتج
                  _buildHubActionCard(
                    title: 'إضافة منتج جديد',
                    subtitle: 'إدخال صنف جديد بالباركود والأسعار والكمية الافتتاحية والحد الأدنى',
                    icon: Icons.add_circle_outline,
                    iconColor: AppTheme.primary,
                    iconBgColor: AppTheme.primary.withValues(alpha: 0.1),
                    onTap: () async {
                      final added = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (ctx) => const ProductFormScreen()),
                      );
                      if (added == true) _loadStats();
                    },
                  ),
                  const SizedBox(height: 12),

                  // 2. عرض المنتجات
                  _buildHubActionCard(
                    title: 'عرض وإدارة المنتجات',
                    subtitle: 'البحث، التصفية حسب الصنف، تقارير النواقص، وتوليد وطباعة الباركود',
                    icon: Icons.inventory_2_outlined,
                    iconColor: AppTheme.secondary,
                    iconBgColor: AppTheme.secondary.withValues(alpha: 0.1),
                    badgeText: '$_totalProducts صنف',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const ProductListScreen()),
                      );
                      _loadStats();
                    },
                  ),
                  const SizedBox(height: 12),

                  // 3. إضافة تصنيف
                  _buildHubActionCard(
                    title: 'إضافة تصنيف جديد',
                    subtitle: 'إنشاء تصنيفات الأصناف مع التحقق من عدم التكرار وربطها بالمنتجات',
                    icon: Icons.category_outlined,
                    iconColor: const Color(0xFF8B5CF6),
                    iconBgColor: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    badgeText: '$_categoriesCount تصنيف',
                    onTap: _showAddCategoryDialog,
                  ),
                  const SizedBox(height: 12),

                  // 4. تعديل أسعار المنتجات
                  _buildHubActionCard(
                    title: 'تعديل أسعار المنتجات',
                    subtitle: 'تعديل سعر الشراء وأسعار البيع 1 و 2 و 3 بشكل فردي أو جماعي بنسب مئوية',
                    icon: Icons.price_change_outlined,
                    iconColor: const Color(0xFFF59E0B),
                    iconBgColor: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const ProductPriceUpdateScreen()),
                      );
                      _loadStats();
                    },
                  ),
                  const SizedBox(height: 12),

                  // 5. تصدير واستيراد المنتجات عبر Excel
                  _buildHubActionCard(
                    title: 'تصدير واستيراد المنتجات (Excel)',
                    subtitle: 'تصدير واستيراد ملفات XLSX حقيقية لآلاف الأصناف مع معالجة التكرارات',
                    icon: Icons.table_view_outlined,
                    iconColor: const Color(0xFF10B981),
                    iconBgColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                    badgeText: 'XLSX',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const ProductExcelScreen()),
                      );
                      _loadStats();
                    },
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickStatsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          _buildStatMini(
            label: 'إجمالي الأصناف',
            value: _isLoading ? '...' : '$_totalProducts',
            color: AppTheme.primary,
            icon: Icons.inventory_2_outlined,
          ),
          Container(width: 1, height: 36, color: AppTheme.border),
          _buildStatMini(
            label: 'نواقص المخزون',
            value: _isLoading ? '...' : '$_lowStockCount',
            color: _lowStockCount > 0 ? AppTheme.danger : AppTheme.secondary,
            icon: Icons.warning_amber_rounded,
          ),
          Container(width: 1, height: 36, color: AppTheme.border),
          _buildStatMini(
            label: 'التصنيفات',
            value: _isLoading ? '...' : '$_categoriesCount',
            color: const Color(0xFF8B5CF6),
            icon: Icons.folder_open_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildStatMini({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHubActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    String? badgeText,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
            boxShadow: const [
              BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: iconColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
