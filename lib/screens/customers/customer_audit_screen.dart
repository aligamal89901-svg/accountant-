import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/database_helper.dart';
import '../../models/customer_model.dart';

/// شاشة فحص وتدقيق أرصدة العملاء
/// تقوم بمطابقة رياضية دقيقة بين:
/// (الرصيد الافتتاحي + فواتير المبيعات الآجلة - سندات القبض النقدية) والرصيد الحالي
class CustomerAuditScreen extends StatefulWidget {
  const CustomerAuditScreen({super.key});

  @override
  State<CustomerAuditScreen> createState() => _CustomerAuditScreenState();
}

class _CustomerAuditScreenState extends State<CustomerAuditScreen> {
  List<Map<String, dynamic>> _auditResults = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _runAudit();
  }

  Future<void> _runAudit() async {
    setState(() => _isLoading = true);
    final results = await DatabaseHelper.instance.auditCustomerBalances();
    if (mounted) {
      setState(() {
        _auditResults = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final int matchedCount = _auditResults.where((r) => r['isMatched'] == true).length;
    final int mismatchCount = _auditResults.length - matchedCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('فحص وتدقيق أرصدة العملاء'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'إعادة التدقيق',
            onPressed: _runAudit,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 800;
                final contentWidth = isWide ? 850.0 : double.infinity;

                return Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      children: [
                        // بطاقة ملخص التدقيق
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.border),
                            boxShadow: const [
                              BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.verified_user_outlined, color: AppTheme.primary, size: 22),
                                  SizedBox(width: 8),
                                  Text(
                                    'نتيجة المطابقة المحاسبية لسجلات العملاء',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMiniStat(
                                      label: 'إجمالي العملاء',
                                      value: '${_auditResults.length}',
                                      color: AppTheme.primary,
                                      icon: Icons.people_outline,
                                    ),
                                  ),
                                  Container(width: 1, height: 40, color: AppTheme.border),
                                  Expanded(
                                    child: _buildMiniStat(
                                      label: 'حسابات مطابقة 100%',
                                      value: '$matchedCount',
                                      color: AppTheme.success,
                                      icon: Icons.check_circle_outline,
                                    ),
                                  ),
                                  Container(width: 1, height: 40, color: AppTheme.border),
                                  Expanded(
                                    child: _buildMiniStat(
                                      label: 'حسابات بفارق/فحص',
                                      value: '$mismatchCount',
                                      color: mismatchCount > 0 ? AppTheme.danger : AppTheme.neutral,
                                      icon: Icons.warning_amber_rounded,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // قائمة العملاء وتفاصيل معادلة التدقيق
                        const Text(
                          'تفاصيل الحسابات والمعادلة المحاسبية (الافتتاحي + المبيعات - السداد = الرصيد)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 10),

                        ..._auditResults.map((audit) {
                          final customer = audit['customer'] as CustomerModel;
                          final bool isMatched = audit['isMatched'] as bool;
                          final double openingBalance = (audit['openingBalance'] as num).toDouble();
                          final double invoicesRemaining = (audit['totalInvoicesRemaining'] as num).toDouble();
                          final double directPayments = (audit['totalDirectPayments'] as num).toDouble();
                          final double currentBalance = (audit['currentBalance'] as num).toDouble();
                          final double expectedBalance = (audit['expectedBalance'] as num).toDouble();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isMatched ? AppTheme.border : AppTheme.danger.withValues(alpha: 0.5),
                                width: isMatched ? 1 : 1.5,
                              ),
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: (isMatched ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            isMatched ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                            size: 20,
                                            color: isMatched ? AppTheme.success : AppTheme.danger,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          customer.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '(${customer.code})',
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (isMatched ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isMatched ? 'رصيد مطابق سليماً' : 'يوجد فارق حسابي',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: isMatched ? AppTheme.success : AppTheme.danger,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildEquationPart(
                                        title: 'الرصيد الافتتاحي',
                                        amount: openingBalance,
                                        color: AppTheme.neutral,
                                      ),
                                    ),
                                    const Text('+', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                    Expanded(
                                      child: _buildEquationPart(
                                        title: 'ذمم الفواتير (${audit['totalInvoicesCount']})',
                                        amount: invoicesRemaining,
                                        color: AppTheme.warning,
                                      ),
                                    ),
                                    const Text('-', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                    Expanded(
                                      child: _buildEquationPart(
                                        title: 'سندات التحصيل',
                                        amount: directPayments,
                                        color: AppTheme.success,
                                      ),
                                    ),
                                    const Text('=', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                    Expanded(
                                      child: _buildEquationPart(
                                        title: 'الرصيد المحسوب',
                                        amount: expectedBalance,
                                        color: isMatched ? AppTheme.primary : AppTheme.danger,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'الرصيد الحالي بالدفتر: ${Formatters.formatCurrency(currentBalance)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: currentBalance > 0 ? AppTheme.danger : AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMiniStat({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildEquationPart({
    required String title,
    required double amount,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          Formatters.formatCurrency(amount),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
