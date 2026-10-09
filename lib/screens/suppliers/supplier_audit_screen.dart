import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/database_helper.dart';
import '../../models/supplier_model.dart';

/// شاشة فحص وتدقيق أرصدة الموردين
/// تقوم بمطابقة رياضية دقيقة بين:
/// (الرصيد الافتتاحي + فواتير المشتريات الآجلة - سندات الصرف والمدفوعات) والرصيد الحالي للمورد
class SupplierAuditScreen extends StatefulWidget {
  const SupplierAuditScreen({super.key});

  @override
  State<SupplierAuditScreen> createState() => _SupplierAuditScreenState();
}

class _SupplierAuditScreenState extends State<SupplierAuditScreen> {
  List<Map<String, dynamic>> _auditResults = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _runAudit();
  }

  Future<void> _runAudit() async {
    setState(() => _isLoading = true);
    final results = await DatabaseHelper.instance.auditSupplierBalances();
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
        title: const Text('فحص وتدقيق أرصدة الموردين'),
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
                                    'نتيجة المطابقة المحاسبية لسجلات الموردين',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMiniStat(
                                      label: 'إجمالي الموردين',
                                      value: '${_auditResults.length}',
                                      color: AppTheme.primary,
                                      icon: Icons.store_outlined,
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

                        // قائمة الموردين وتفاصيل معادلة التدقيق
                        const Text(
                          'تفاصيل الحسابات والمعادلة المحاسبية (الافتتاحي + المشتريات الآجلة - المدفوعات = الرصيد)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 10),

                        if (_auditResults.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            alignment: Alignment.center,
                            child: const Text('لا توجد سجلات موردين مسجلة بعد'),
                          ),

                        ..._auditResults.map((audit) {
                          final supplier = audit['supplier'] as SupplierModel;
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
                                          supplier.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.background,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            supplier.code,
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (isMatched ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        isMatched ? 'مطابق تماماً' : 'فارق غير مطابق',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isMatched ? AppTheme.success : AppTheme.danger,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 12),

                                // المعادلة الرياضية للتدقيق
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildEquationPill('الافتتاحي', Formatters.formatCurrency(openingBalance), Colors.blueGrey),
                                    const Padding(padding: EdgeInsets.only(top: 6), child: Text('+', style: TextStyle(fontWeight: FontWeight.bold))),
                                    _buildEquationPill('مشتريات آجلة', Formatters.formatCurrency(invoicesRemaining), Colors.purple),
                                    const Padding(padding: EdgeInsets.only(top: 6), child: Text('-', style: TextStyle(fontWeight: FontWeight.bold))),
                                    _buildEquationPill('مدفوعات صرف', Formatters.formatCurrency(directPayments), AppTheme.danger),
                                    const Padding(padding: EdgeInsets.only(top: 6), child: Text('=', style: TextStyle(fontWeight: FontWeight.bold))),
                                    _buildEquationPill('الرصيد المحسوب', Formatters.formatCurrency(expectedBalance), isMatched ? AppTheme.success : Colors.orange),
                                    const Padding(padding: EdgeInsets.only(top: 6), child: Text('مقابل', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary))),
                                    _buildEquationPill('الرصيد الحالي', Formatters.formatCurrency(currentBalance), AppTheme.primary),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMiniStat({required String label, required String value, required Color color, required IconData icon}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildEquationPill(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
