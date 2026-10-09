import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/database_helper.dart';
import '../../models/supplier_model.dart';
import 'suppliers_screen.dart';
import 'supplier_debts_screen.dart';
import 'supplier_opening_balance_screen.dart';
import 'supplier_payment_screen.dart';
import 'supplier_debt_report_screen.dart';
import 'supplier_audit_screen.dart';

/// الصفحة الرئيسية المستقلة لقسم الموردين (Suppliers Hub)
/// تحتوي على أزرار طولية كبيرة وحديثة مرتبة رأسياً بالخيارات الـ 7 المحددة
class SuppliersHubScreen extends StatefulWidget {
  const SuppliersHubScreen({super.key});

  @override
  State<SuppliersHubScreen> createState() => _SuppliersHubScreenState();
}

class _SuppliersHubScreenState extends State<SuppliersHubScreen> {
  int _totalSuppliers = 0;
  int _creditorsCount = 0;
  double _totalPayables = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final suppliers = await DatabaseHelper.instance.getSuppliers();
    if (mounted) {
      setState(() {
        _totalSuppliers = suppliers.length;
        _creditorsCount = suppliers.where((s) => s.hasPayables).length;
        _totalPayables = suppliers.fold(0.0, (sum, s) => sum + s.currentBalance);
        _isLoading = false;
      });
    }
  }

  void _showAddSupplierDialog() async {
    final nextCode = await DatabaseHelper.instance.generateNextSupplierCode();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final taxNumberController = TextEditingController();
    final crNumberController = TextEditingController();
    final notesController = TextEditingController();

    if (!mounted) return;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add_alt, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('إضافة مورد جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'اسم المورد *', prefixIcon: Icon(Icons.store_outlined)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_outlined)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: addressController,
                          decoration: const InputDecoration(labelText: 'العنوان', prefixIcon: Icon(Icons.location_on_outlined)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: taxNumberController,
                          decoration: const InputDecoration(labelText: 'الرقم الضريبي', prefixIcon: Icon(Icons.receipt_outlined)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: crNumberController,
                          decoration: const InputDecoration(labelText: 'السجل التجاري', prefixIcon: Icon(Icons.badge_outlined)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'ملاحظات إضافية', prefixIcon: Icon(Icons.notes_outlined)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('اسم المورد مطلوب'), backgroundColor: AppTheme.warning),
                  );
                  return;
                }

                final newSupplier = SupplierModel(
                  code: nextCode,
                  name: name,
                  phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                  address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                  taxNumber: taxNumberController.text.trim().isEmpty ? null : taxNumberController.text.trim(),
                  crNumber: crNumberController.text.trim().isEmpty ? null : crNumberController.text.trim(),
                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                );

                await DatabaseHelper.instance.insertSupplier(newSupplier);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('حفظ المورد'),
            ),
          ],
        ),
      ),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة المورد بنجاح'), backgroundColor: AppTheme.success),
      );
      _loadStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل وإدارة الموردين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث البيانات',
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
                  // بطاقة ملخص الموردين السريع
                  _buildQuickStatsCard(),
                  const SizedBox(height: 24),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Text(
                      'الخيارات الرئيسية للموردين',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 1. إضافة مورد
                  _buildHubActionCard(
                    title: 'إضافة مورد جديد',
                    subtitle: 'إدخال مورد جديد بالاسم والبيانات الضريبية والسجل التجاري ومعلومات الاتصال',
                    icon: Icons.person_add_alt_1_outlined,
                    iconColor: AppTheme.primary,
                    iconBgColor: AppTheme.primary.withValues(alpha: 0.1),
                    onTap: _showAddSupplierDialog,
                  ),
                  const SizedBox(height: 12),

                  // 2. الأرصدة الافتتاحية للموردين
                  _buildHubActionCard(
                    title: 'الأرصدة الافتتاحية للموردين',
                    subtitle: 'إدخال وتعديل الأرصدة الافتتاحية الدائنة للموردين وتواريخها وملاحظاتها',
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: const Color(0xFF0284C7),
                    iconBgColor: const Color(0xFF0284C7).withValues(alpha: 0.1),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const SupplierOpeningBalanceScreen()),
                      );
                      _loadStats();
                    },
                  ),
                  const SizedBox(height: 12),

                  // 3. تسجيل المدفوعات للموردين
                  _buildHubActionCard(
                    title: 'تسجيل المدفوعات للموردين (سندات الصرف)',
                    subtitle: 'تسجيل سندات الصرف النقدية للموردين والخصم المباشر من صناديق الخزينة',
                    icon: Icons.payments_outlined,
                    iconColor: AppTheme.danger,
                    iconBgColor: AppTheme.danger.withValues(alpha: 0.1),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const SupplierPaymentScreen()),
                      );
                      _loadStats();
                    },
                  ),
                  const SizedBox(height: 12),

                  // 4. ذمم الموردين
                  _buildHubActionCard(
                    title: 'ذمم الموردين (المستحقات والحسابات الدائنة)',
                    subtitle: 'كشف الأرصدة المستحقة للموردين علينا وسداد الدفعات وتصفية الحسابات',
                    icon: Icons.request_quote_outlined,
                    iconColor: const Color(0xFFE11D48),
                    iconBgColor: const Color(0xFFE11D48).withValues(alpha: 0.1),
                    badgeText: '$_creditorsCount مستحق له',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const SupplierDebtsScreen()),
                      );
                      _loadStats();
                    },
                  ),
                  const SizedBox(height: 12),

                  // 5. تقرير ذمم الموردين
                  _buildHubActionCard(
                    title: 'تقرير ذمم الموردين',
                    subtitle: 'تقرير تفصيلي وجاهز للطباعة والتصدير بكافة الحسابات الدائنة والمستحقة',
                    icon: Icons.picture_as_pdf_outlined,
                    iconColor: const Color(0xFF7C3AED),
                    iconBgColor: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                    badgeText: 'PDF',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const SupplierDebtReportScreen()),
                      );
                      _loadStats();
                    },
                  ),
                  const SizedBox(height: 12),

                  // 6. فحص وتدقيق أرصدة الموردين
                  _buildHubActionCard(
                    title: 'فحص وتدقيق أرصدة الموردين',
                    subtitle: 'مطابقة محاسبية رياضية دقيقة (الافتتاحي + المشتريات الآجلة - المدفوعات = الرصيد)',
                    icon: Icons.fact_check_outlined,
                    iconColor: const Color(0xFFD97706),
                    iconBgColor: const Color(0xFFD97706).withValues(alpha: 0.1),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const SupplierAuditScreen()),
                      );
                      _loadStats();
                    },
                  ),
                  const SizedBox(height: 12),

                  // 7. عرض الموردين
                  _buildHubActionCard(
                    title: 'عرض وسجل الموردين',
                    subtitle: 'سجل شامل لكافة الموردين، كشوفات الحساب الفردية، والبحث والتعديل',
                    icon: Icons.storefront_outlined,
                    iconColor: AppTheme.primary,
                    iconBgColor: AppTheme.primary.withValues(alpha: 0.1),
                    badgeText: '$_totalSuppliers مورد',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const SuppliersScreen()),
                      );
                      _loadStats();
                    },
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

  Widget _buildQuickStatsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              title: 'إجمالي الموردين',
              value: '$_totalSuppliers',
              icon: Icons.store_outlined,
              color: AppTheme.primary,
            ),
          ),
          Container(width: 1, height: 44, color: AppTheme.border),
          Expanded(
            child: _buildStatItem(
              title: 'موردون بمستحقات',
              value: '$_creditorsCount',
              icon: Icons.warning_amber_rounded,
              color: _creditorsCount > 0 ? AppTheme.danger : AppTheme.neutral,
            ),
          ),
          Container(width: 1, height: 44, color: AppTheme.border),
          Expanded(
            child: _buildStatItem(
              title: 'إجمالي المستحقات علينا',
              value: Formatters.formatCurrency(_totalPayables),
              icon: Icons.account_balance_wallet_outlined,
              color: _totalPayables > 0 ? AppTheme.danger : AppTheme.success,
              isCurrency: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isCurrency = false,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _isLoading
            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(
                value,
                style: TextStyle(
                  fontSize: isCurrency ? 15 : 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
      ],
    );
  }

  Widget _buildHubActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        hoverColor: iconColor.withValues(alpha: 0.04),
        splashColor: iconColor.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
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
              const SizedBox(width: 16),
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
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
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
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
