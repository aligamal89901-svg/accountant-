import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/database_helper.dart';
import '../../models/invoice_model.dart';
import '../../models/product_model.dart';
import '../sales/invoice_receipt_dialog.dart';

/// شاشة الاستعلامات والتقارير المالية المركزية
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _metrics = {};
  Map<String, dynamic> _financialSummary = {};
  List<InvoiceModel> _invoices = [];
  List<ProductModel> _lowStockProducts = [];
  bool _isLoading = true;
  String _invoiceTypeFilter = 'all';

  List<InvoiceModel> get _filteredInvoices {
    if (_invoiceTypeFilter == 'sale') {
      return _invoices.where((i) => i.type == 'sale').toList();
    } else if (_invoiceTypeFilter == 'purchase') {
      return _invoices.where((i) => i.type == 'purchase').toList();
    }
    return _invoices;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadReportData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    final metrics = await DatabaseHelper.instance.getDashboardMetrics();
    final summary = await DatabaseHelper.instance.getFinancialReportSummary();
    final invoices = await DatabaseHelper.instance.getInvoices(limit: 100);
    final allProducts = await DatabaseHelper.instance.getProducts();
    final lowStock = allProducts.where((p) => p.isLowStock || p.isOutOfStock).toList();

    if (mounted) {
      setState(() {
        _metrics = metrics;
        _financialSummary = summary;
        _invoices = invoices;
        _lowStockProducts = lowStock;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final salesToday = (_metrics['totalSalesToday'] as num?)?.toDouble() ?? 0.0;
    final totalDebt = (_metrics['totalCustomersDebt'] as num?)?.toDouble() ?? 0.0;
    final cashBalance = (_metrics['totalCashBalance'] as num?)?.toDouble() ?? 0.0;
    final productsCount = (_metrics['totalProductsCount'] as num?)?.toInt() ?? 0;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // بطاقات المؤشرات المالية السريعة المتجاوبة
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;
                if (isNarrow) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'مبيعات اليوم',
                              value: Formatters.formatCurrency(salesToday),
                              icon: Icons.trending_up,
                              color: AppTheme.success,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'ذمم العملاء',
                              value: Formatters.formatCurrency(totalDebt),
                              icon: Icons.money_off_outlined,
                              color: AppTheme.danger,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'السيولة في الصناديق',
                              value: Formatters.formatCurrency(cashBalance),
                              icon: Icons.account_balance_wallet_outlined,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'الأصناف المتوفرة',
                              value: '$productsCount صنف',
                              icon: Icons.category_outlined,
                              color: AppTheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'مبيعات اليوم',
                          value: Formatters.formatCurrency(salesToday),
                          icon: Icons.trending_up,
                          color: AppTheme.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'إجمالي ذمم العملاء',
                          value: Formatters.formatCurrency(totalDebt),
                          icon: Icons.money_off_outlined,
                          color: AppTheme.danger,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'السيولة في الصناديق',
                          value: Formatters.formatCurrency(cashBalance),
                          icon: Icons.account_balance_wallet_outlined,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'الأصناف المتوفرة',
                          value: '$productsCount صنف',
                          icon: Icons.category_outlined,
                          color: AppTheme.secondary,
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            // ألسنة التبويب للتقارير التفصيلية
            TabBar(
              controller: _tabController,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textMuted,
              indicatorColor: AppTheme.primary,
              tabs: [
                Tab(
                  icon: const Icon(Icons.receipt_long_outlined),
                  text: 'سجل الفواتير (${_invoices.length})',
                ),
                Tab(
                  icon: const Icon(Icons.warning_amber_outlined),
                  text: 'تنبيهات المخزون (${_lowStockProducts.length})',
                ),
                const Tab(
                  icon: Icon(Icons.summarize_outlined),
                  text: 'ملخص الحركات',
                ),
              ],
            ),
            const SizedBox(height: 12),
            // محتوى التبويبات
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // تبويب الفواتير (مبيعات ومشتريات)
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    ChoiceChip(
                                      label: Text('الكل (${_invoices.length})'),
                                      selected: _invoiceTypeFilter == 'all',
                                      onSelected: (val) => setState(() => _invoiceTypeFilter = 'all'),
                                    ),
                                    const SizedBox(width: 8),
                                    ChoiceChip(
                                      label: Text('فواتير المبيعات (${_invoices.where((i) => i.type == 'sale').length})'),
                                      selected: _invoiceTypeFilter == 'sale',
                                      onSelected: (val) => setState(() => _invoiceTypeFilter = 'sale'),
                                      selectedColor: AppTheme.primary.withValues(alpha: 0.15),
                                    ),
                                    const SizedBox(width: 8),
                                    ChoiceChip(
                                      label: Text('فواتير المشتريات (${_invoices.where((i) => i.type == 'purchase').length})'),
                                      selected: _invoiceTypeFilter == 'purchase',
                                      onSelected: (val) => setState(() => _invoiceTypeFilter = 'purchase'),
                                      selectedColor: AppTheme.secondary.withValues(alpha: 0.15),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: _filteredInvoices.isEmpty
                                  ? const Center(child: Text('لا توجد فواتير مطابقة للتصفية'))
                                  : ListView.separated(
                                      itemCount: _filteredInvoices.length,
                                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                                      itemBuilder: (context, index) {
                                        final inv = _filteredInvoices[index];
                                        final isSale = inv.type == 'sale';
                                        return Card(
                                          child: ListTile(
                                            onTap: () => InvoiceReceiptDialog.show(context, inv),
                                            leading: CircleAvatar(
                                              backgroundColor: isSale
                                                  ? AppTheme.primary.withValues(alpha: 0.1)
                                                  : AppTheme.secondary.withValues(alpha: 0.1),
                                              child: Icon(
                                                isSale ? Icons.point_of_sale : Icons.shopping_bag,
                                                color: isSale ? AppTheme.primary : AppTheme.secondary,
                                              ),
                                            ),
                                            title: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isSale ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.secondary.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    isSale ? 'مبيعات' : 'مشتريات',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: isSale ? AppTheme.primary : AppTheme.secondary,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(inv.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                const SizedBox(width: 8),
                                                Text('(${isSale ? (inv.customerName ?? "عميل نقدي") : (inv.supplierName ?? "مورد عام")})',
                                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                              ],
                                            ),
                                            subtitle: Text(
                                              'التاريخ: ${Formatters.formatDateTime(DateTime.parse(inv.date))} | الدفع: ${inv.paymentMethod}',
                                            ),
                                            trailing: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  Formatters.formatCurrency(inv.total),
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                                if (inv.hasRemaining)
                                                  Text(
                                                    'متبقي: ${Formatters.formatCurrency(inv.remaining)}',
                                                    style: const TextStyle(fontSize: 11, color: AppTheme.danger, fontWeight: FontWeight.bold),
                                                  )
                                                else
                                                  const Text('مسددة بالكامل', style: TextStyle(fontSize: 10, color: AppTheme.success)),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                        // تبويب تنبيهات المخزون
                        _lowStockProducts.isEmpty
                            ? const Center(
                                child: Text('جميع الأصناف في مستوى مخزون آمن ومكتمل',
                                    style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold)),
                              )
                            : ListView.separated(
                                itemCount: _lowStockProducts.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final p = _lowStockProducts[index];
                                  return Card(
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.warning,
                                        color: p.isOutOfStock ? AppTheme.danger : AppTheme.warning,
                                      ),
                                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text('الباركود: ${p.barcode} | حد التنبيه: ${Formatters.formatNumber(p.minQuantity)}'),
                                      trailing: Text(
                                        'المتبقي: ${Formatters.formatNumber(p.stockQuantity)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: p.isOutOfStock ? AppTheme.danger : AppTheme.warning,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                        // تبويب ملخص الحركات والتقرير المالي العام
                        SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Card(
                                color: AppTheme.surfaceVariant,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('إجمالي المبيعات المحققة:', style: TextStyle(fontWeight: FontWeight.bold)),
                                          Text(
                                            Formatters.formatCurrency((_financialSummary['totalSales'] as num?)?.toDouble() ?? 0.0),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('تكلفة البضاعة المباعة (COGS):', style: TextStyle(color: AppTheme.textSecondary)),
                                          Text(
                                            Formatters.formatCurrency((_financialSummary['totalCost'] as num?)?.toDouble() ?? 0.0),
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('إجمالي الأرباح التقديرية (Gross Profit):', style: TextStyle(fontWeight: FontWeight.bold)),
                                          Text(
                                            Formatters.formatCurrency((_financialSummary['totalProfit'] as num?)?.toDouble() ?? 0.0),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: ((_financialSummary['totalProfit'] as num?)?.toDouble() ?? 0) >= 0 ? AppTheme.success : AppTheme.danger,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(14.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('المحصل نقدياً وبنكياً', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                            const SizedBox(height: 6),
                                            Text(
                                              Formatters.formatCurrency((_financialSummary['totalPaid'] as num?)?.toDouble() ?? 0.0),
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.success),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(14.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('الذمم والآجل المتبقي', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                            const SizedBox(height: 6),
                                            Text(
                                              Formatters.formatCurrency((_financialSummary['totalRemaining'] as num?)?.toDouble() ?? 0.0),
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.danger),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(14.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('إجمالي الخصومات الممنوحة', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                            const SizedBox(height: 6),
                                            Text(
                                              Formatters.formatCurrency((_financialSummary['totalDiscount'] as num?)?.toDouble() ?? 0.0),
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.secondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Card(
                                color: AppTheme.surfaceVariant,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('إجمالي المشتريات والتوريد:', style: TextStyle(fontWeight: FontWeight.bold)),
                                          Text(
                                            Formatters.formatCurrency((_financialSummary['totalPurchases'] as num?)?.toDouble() ?? 0.0),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.secondary),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('المسدد للموردين:', style: TextStyle(color: AppTheme.textSecondary)),
                                          Text(
                                            Formatters.formatCurrency((_financialSummary['totalPurchasesPaid'] as num?)?.toDouble() ?? 0.0),
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('المتبقي للموردين (آجل):', style: TextStyle(color: AppTheme.danger)),
                                          Text(
                                            Formatters.formatCurrency((_financialSummary['totalPurchasesRemaining'] as num?)?.toDouble() ?? 0.0),
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.danger),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      Column(
                                        children: [
                                          const Text('تقييم المخزون بسعر التكلفة', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                          const SizedBox(height: 4),
                                          Text(
                                            Formatters.formatCurrency((_financialSummary['inventoryCostValue'] as num?)?.toDouble() ?? 0.0),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ],
                                      ),
                                      Container(height: 35, width: 1, color: Colors.grey.shade300),
                                      Column(
                                        children: [
                                          const Text('تقييم المخزون بسعر البيع المتوقع', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                          const SizedBox(height: 4),
                                          Text(
                                            Formatters.formatCurrency((_financialSummary['inventorySaleValue'] as num?)?.toDouble() ?? 0.0),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
