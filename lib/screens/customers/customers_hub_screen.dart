import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/database_helper.dart';
import '../../models/customer_model.dart';
import 'customers_screen.dart';
import 'customer_debts_screen.dart';
import 'customer_opening_balance_screen.dart';
import 'customer_cash_screen.dart';
import 'customer_debt_report_screen.dart';
import 'customer_audit_screen.dart';

/// الصفحة الرئيسية المستقلة لقسم العملاء (Customers Hub)
/// تحتوي على أزرار طولية كبيرة وحديثة مرتبة رأسياً بالخيارات الـ 7 المحددة
class CustomersHubScreen extends StatefulWidget {
  const CustomersHubScreen({super.key});

  @override
  State<CustomersHubScreen> createState() => _CustomersHubScreenState();
}

class _CustomersHubScreenState extends State<CustomersHubScreen> {
  int _totalCustomers = 0;
  int _debtorsCount = 0;
  double _totalDebt = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final customers = await DatabaseHelper.instance.getCustomers();
    if (mounted) {
      setState(() {
        _totalCustomers = customers.length;
        _debtorsCount = customers.where((c) => c.hasDebt).length;
        _totalDebt = customers.fold(0.0, (sum, c) => sum + c.currentBalance);
        _isLoading = false;
      });
    }
  }

  void _showAddCustomerDialog() async {
    final nextCode = await DatabaseHelper.instance.generateNextCustomerCode();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final creditLimitController = TextEditingController();
    final dueDaysController = TextEditingController();
    int priceTier = 1;

    if (!mounted) return;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add_alt, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('إضافة عميل جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                    decoration: const InputDecoration(labelText: 'اسم العميل *', prefixIcon: Icon(Icons.person_outline)),
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
                          controller: creditLimitController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'سقف الائتمان (ر.س)', prefixIcon: Icon(Icons.credit_card)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: dueDaysController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'فترة السداد (أيام)', prefixIcon: Icon(Icons.calendar_month_outlined)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: priceTier,
                    decoration: const InputDecoration(labelText: 'فئة سعر البيع الافتراضية', prefixIcon: Icon(Icons.sell_outlined)),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('سعر 1 (المفرق / العادي)')),
                      DropdownMenuItem(value: 2, child: Text('سعر 2 (الجملة)')),
                      DropdownMenuItem(value: 3, child: Text('سعر 3 (الخاص / الموزع)')),
                    ],
                    onChanged: (v) => setDialogState(() => priceTier = v!),
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
                    const SnackBar(content: Text('اسم العميل مطلوب'), backgroundColor: AppTheme.warning),
                  );
                  return;
                }

                final newCustomer = CustomerModel(
                  code: nextCode,
                  name: name,
                  phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                  address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                  creditLimit: double.tryParse(creditLimitController.text.trim()),
                  dueDays: int.tryParse(dueDaysController.text.trim()),
                  defaultPriceTier: priceTier,
                );

                await DatabaseHelper.instance.insertCustomer(newCustomer);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('حفظ العميل'),
            ),
          ],
        ),
      ),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة العميل بنجاح'), backgroundColor: AppTheme.success),
      );
      _loadStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل وإدارة العملاء'),
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
                  // بطاقة ملخص العملاء السريع
                  _buildQuickStatsCard(),
                  const SizedBox(height: 24),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Text(
                      'الخيارات الرئيسية للعملاء',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 1. إضافة عميل
                  _buildHubActionCard(
                    title: 'إضافة عميل جديد',
                    subtitle: 'إدخال عميل جديد بالاسم والهاتف وسقف الائتمان وفئة السعر الافتراضية',
                    icon: Icons.person_add_alt_1_outlined,
                    iconColor: AppTheme.primary,
                    iconBgColor: AppTheme.primary.withValues(alpha: 0.1),
                    onTap: _showAddCustomerDialog,
                  ),
                  const SizedBox(height: 12),

                  // 2. الأرصدة الافتتاحية للعملاء
                  _buildHubActionCard(
                    title: 'الأرصدة الافتتاحية للعملاء',
                    subtitle: 'إدخال وتعديل الأرصدة الافتتاحية وتواريخها وملاحظاتها لكافة العملاء',
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: const Color(0xFF0284C7),
                    iconBgColor: const Color(0xFF0284C7).withValues(alpha: 0.1),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const CustomerOpeningBalanceScreen()),
                      );
                      _loadStats();
                    },
                  ),
                  const SizedBox(height: 12),

                  // 3. المبالغ النقدية للعملاء
                  _buildHubActionCard(
                    title: 'المبالغ النقدية للعملاء (سندات القبض)',
                    subtitle: 'تسجيل سندات القبض والدفعات النقدية وتوريدها المباشر للصناديق الخزينة',
                    icon: Icons.payments_outlined,
                    iconColor: AppTheme.success,
                    iconBgColor: AppTheme.success.withValues(alpha: 0.1),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const CustomerCashScreen()),
                      );
                      _loadStats();
                    },
                  ),
                  const SizedBox(height: 12),

                  // 4. ذمم العملاء
                  _buildHubActionCard(
                    title: 'ذمم العملاء (الحسابات المدينة)',
                    subtitle: 'كشف الأرصدة المستحقة على العملاء، وسداد الدفعات وتصفية الذمم',
                    icon: Icons.request_quote_outlined,
                    iconColor: AppTheme.danger,
                    iconBgColor: AppTheme.danger.withValues(alpha: 0.1),
                    badgeText: '$_debtorsCount مدين',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const CustomerDebtsScreen()),
                      );
                      _loadStats();
                    },
                  ),
                  const SizedBox(height: 12),

                  // 5. تقرير ذمم العملاء
                  _buildHubActionCard(
                    title: 'تقرير ذمم العملاء',
                    subtitle: 'تقرير تفصيلي وجاهز للطباعة والتصدير بكافة الحسابات المدينة والآجلة',
                    icon: Icons.picture_as_pdf_outlined,
                    iconColor: const Color(0xFF7C3AED),
                    iconBgColor: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                    badgeText: 'PDF',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const CustomerDebtReportScreen()),
                      );
                      _loadStats();
                    },
                  ),
                  const SizedBox(height: 12),

                  // 6. فحص وتدقيق أرصدة العملاء
                  _buildHubActionCard(
                    title: 'فحص وتدقيق أرصدة العملاء',
                    subtitle: 'مطابقة رياضية دقيقة بين الرصيد الافتتاحي + المبيعات - السداد والرصيد الحالي',
                    icon: Icons.fact_check_outlined,
                    iconColor: const Color(0xFFD97706),
                    iconBgColor: const Color(0xFFD97706).withValues(alpha: 0.1),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const CustomerAuditScreen()),
                      );
                      _loadStats();
                    },
                  ),
                  const SizedBox(height: 12),

                  // 7. عرض العملاء
                  _buildHubActionCard(
                    title: 'عرض وسجل العملاء',
                    subtitle: 'سجل شامل لكافة العملاء، كشوفات الحساب الفردية، والبحث والتعديل',
                    icon: Icons.people_outline,
                    iconColor: AppTheme.primary,
                    iconBgColor: AppTheme.primary.withValues(alpha: 0.1),
                    badgeText: '$_totalCustomers عميل',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const CustomersScreen()),
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
            label: 'إجمالي العملاء',
            value: _isLoading ? '...' : '$_totalCustomers',
            color: AppTheme.primary,
            icon: Icons.people_outline,
          ),
          Container(width: 1, height: 36, color: AppTheme.border),
          _buildStatMini(
            label: 'العملاء المدينين',
            value: _isLoading ? '...' : '$_debtorsCount',
            color: _debtorsCount > 0 ? AppTheme.danger : AppTheme.success,
            icon: Icons.request_quote_outlined,
          ),
          Container(width: 1, height: 36, color: AppTheme.border),
          _buildStatMini(
            label: 'إجمالي الذمم',
            value: _isLoading ? '...' : Formatters.formatCurrency(_totalDebt),
            color: _totalDebt > 0 ? AppTheme.danger : AppTheme.success,
            icon: Icons.monetization_on_outlined,
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
