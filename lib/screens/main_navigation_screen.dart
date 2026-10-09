import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/formatters.dart';
import '../data/database/database_helper.dart';
import 'sales/sales_screen.dart';
import 'purchases/purchases_screen.dart';
import 'inventory/inventory_hub_screen.dart';
import 'customers/customers_hub_screen.dart';
import 'suppliers/suppliers_hub_screen.dart';
import 'cash/cash_screen.dart';
import 'reports/reports_screen.dart';
import 'settings/settings_screen.dart';

/// الشاشة الرئيسية ونظام التنقل المتجاوب (Dashboard & Adaptive Shell)
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  // 0: الرئيسية (Dashboard), 1..8: الأقسام
  int _currentSectionIndex = 0;
  String _shopName = AppConstants.defaultShopName;
  Map<String, dynamic> _metrics = {};
  bool _isLoadingMetrics = true;

  final List<String> _sectionTitles = [
    'لوحة التحكم الرئيسية',
    'نقاط البيع والمبيعات',
    'فواتير المشتريات والتوريد',
    'إدارة المخزون والمنتجات',
    'سجل العملاء والتحصيلات',
    'سجل الموردين والمستحقات',
    'إدارة الصناديق والخزائن',
    'التقارير والمؤشرات المالية',
    'إعدادات النظام والمنشأة',
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final name = await DatabaseHelper.instance.getSetting(AppConstants.keyShopName);
    final metrics = await DatabaseHelper.instance.getDashboardMetrics();

    if (mounted) {
      setState(() {
        if (name != null && name.trim().isNotEmpty) {
          _shopName = name;
        }
        _metrics = metrics;
        _isLoadingMetrics = false;
      });
    }
  }

  void _navigateToSection(int index) {
    setState(() {
      _currentSectionIndex = index;
    });
  }

  Widget _buildCurrentBody() {
    switch (_currentSectionIndex) {
      case 0:
        return _buildDashboardView();
      case 1:
        return const SalesScreen();
      case 2:
        return const PurchasesScreen();
      case 3:
        return const InventoryHubScreen();
      case 4:
        return const CustomersHubScreen();
      case 5:
        return const SuppliersHubScreen();
      case 6:
        return const CashScreen();
      case 7:
        return const ReportsScreen();
      case 8:
        return const SettingsScreen();
      default:
        return _buildDashboardView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= 900;
        final isMobile = constraints.maxWidth < 650;

        return Scaffold(
          appBar: AppBar(
            leading: _currentSectionIndex != 0
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'العودة للرئيسية',
                    onPressed: () {
                      _navigateToSection(0);
                      _loadDashboardData();
                    },
                  )
                : null,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _shopName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_currentSectionIndex != 0)
                        Text(
                          _sectionTitles[_currentSectionIndex],
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (_currentSectionIndex != 0)
                TextButton.icon(
                  onPressed: () {
                    _navigateToSection(0);
                    _loadDashboardData();
                  },
                  icon: const Icon(Icons.home_outlined, size: 18),
                  label: const Text('الرئيسية'),
                ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'تحديث البيانات',
                onPressed: () {
                  _loadDashboardData();
                },
              ),
              const SizedBox(width: 6),
            ],
          ),
          drawer: _buildAppDrawer(),
          body: Row(
            children: [
              // القائمة الجانبية للشاشات الكبيرة والكمبيوتر
              if (isWideScreen) _buildSideNavRail(),

              // مساحة المحتوى الرئيسية
              Expanded(
                child: Container(
                  color: AppTheme.background,
                  child: _buildCurrentBody(),
                ),
              ),
            ],
          ),
          // شريط تنقل سفلي أنيق ومريح للهاتف (فقط 4 أقسام رئيسية لتجنب الازدحام)
          bottomNavigationBar: isMobile
              ? NavigationBar(
                  selectedIndex: _currentSectionIndex == 0
                      ? 0
                      : _currentSectionIndex == 1
                          ? 1
                          : _currentSectionIndex == 3
                              ? 2
                              : _currentSectionIndex == 6
                                  ? 3
                                  : 0,
                  onDestinationSelected: (idx) {
                    if (idx == 0) _navigateToSection(0);
                    if (idx == 1) _navigateToSection(1); // مبيعات
                    if (idx == 2) _navigateToSection(3); // مخزون
                    if (idx == 3) _navigateToSection(6); // صندوق
                  },
                  backgroundColor: Colors.white,
                  elevation: 2,
                  indicatorColor: AppTheme.primary.withValues(alpha: 0.12),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard, color: AppTheme.primary),
                      label: 'الرئيسية',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.point_of_sale_outlined),
                      selectedIcon: Icon(Icons.point_of_sale, color: AppTheme.primary),
                      label: 'المبيعات',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2, color: AppTheme.primary),
                      label: 'المخزون',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.account_balance_wallet_outlined),
                      selectedIcon: Icon(Icons.account_balance_wallet, color: AppTheme.primary),
                      label: 'الصندوق',
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }

  /// القائمة الجانبية للشاشات العريضة (Desktop Navigation Rail)
  Widget _buildSideNavRail() {
    return Container(
      width: 230,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        children: [
          _buildSideNavItem(
            icon: Icons.dashboard_outlined,
            title: 'لوحة التحكم',
            index: 0,
          ),
          const Divider(height: 16),
          _buildSideNavItem(
            icon: Icons.point_of_sale_outlined,
            title: 'المبيعات (POS)',
            index: 1,
            badgeColor: AppTheme.primary,
          ),
          _buildSideNavItem(
            icon: Icons.shopping_cart_checkout_outlined,
            title: 'المشتريات',
            index: 2,
            badgeColor: AppTheme.secondary,
          ),
          _buildSideNavItem(
            icon: Icons.inventory_2_outlined,
            title: 'المخزون والأصناف',
            index: 3,
            badgeColor: AppTheme.warning,
          ),
          _buildSideNavItem(
            icon: Icons.people_outline,
            title: 'العملاء والذمم',
            index: 4,
          ),
          _buildSideNavItem(
            icon: Icons.local_shipping_outlined,
            title: 'الموردون والمستحقات',
            index: 5,
          ),
          _buildSideNavItem(
            icon: Icons.account_balance_outlined,
            title: 'الصندوق والخزينة',
            index: 6,
            badgeColor: AppTheme.success,
          ),
          _buildSideNavItem(
            icon: Icons.bar_chart_outlined,
            title: 'التقارير المالية',
            index: 7,
          ),
          const Divider(height: 16),
          _buildSideNavItem(
            icon: Icons.settings_outlined,
            title: 'الإعدادات',
            index: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildSideNavItem({
    required IconData icon,
    required String title,
    required int index,
    Color? badgeColor,
  }) {
    final isSelected = _currentSectionIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: isSelected ? AppTheme.primary : (badgeColor ?? AppTheme.textSecondary),
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
          ),
        ),
        onTap: () {
          _navigateToSection(index);
        },
      ),
    );
  }

  /// القائمة الجانبية المنسدلة (Drawer) للهاتف
  Widget _buildAppDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppTheme.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.storefront_outlined, color: Colors.white, size: 36),
                const SizedBox(height: 10),
                Text(
                  _shopName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'النظام المالي والمحاسبي المتكامل',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          _buildDrawerItem(Icons.dashboard_outlined, 'الرئيسية (لوحة التحكم)', 0),
          _buildDrawerItem(Icons.point_of_sale_outlined, 'المبيعات', 1),
          _buildDrawerItem(Icons.shopping_cart_checkout_outlined, 'المشتريات', 2),
          _buildDrawerItem(Icons.inventory_2_outlined, 'المخزون والمنتجات', 3),
          _buildDrawerItem(Icons.people_outline, 'العملاء والذمم', 4),
          _buildDrawerItem(Icons.local_shipping_outlined, 'الموردون والمستحقات', 5),
          _buildDrawerItem(Icons.account_balance_outlined, 'الصندوق والخزينة', 6),
          _buildDrawerItem(Icons.bar_chart_outlined, 'التقارير المالية', 7),
          const Divider(),
          _buildDrawerItem(Icons.settings_outlined, 'الإعدادات والنسخ الاحتياطي', 8),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, int index) {
    final isSelected = _currentSectionIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppTheme.primary : AppTheme.textSecondary),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
        ),
      ),
      selected: isSelected,
      onTap: () {
        Navigator.pop(context); // إغلاق الدرج
        _navigateToSection(index);
      },
    );
  }

  /// واجهة لوحة التحكم المركزية وبطاقات الأقسام الـ 8
  Widget _buildDashboardView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        // تحديد عدد أعمدة الـ Grid بتجاوب ذكي
        int crossAxisCount;
        if (screenWidth < 360) {
          crossAxisCount = 1;
        } else if (screenWidth < 650) {
          crossAxisCount = 2;
        } else if (screenWidth < 1050) {
          crossAxisCount = 3;
        } else {
          crossAxisCount = 4;
        }

        final double childAspectRatio = screenWidth < 450 ? 1.15 : (screenWidth < 750 ? 1.25 : 1.35);

        return RefreshIndicator(
          onRefresh: _loadDashboardData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الملخص المالي السريع عند توفر بيانات فعلية
                _buildFinancialSummaryCards(screenWidth),

                const SizedBox(height: 20),

                // عنوان بطاقات أقسام النظام
                const Row(
                  children: [
                    Icon(Icons.apps_rounded, size: 20, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Text(
                      'أقسام النظام الرئيسية',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // شبكة البطاقات المتجاوبة (Responsive Grid)
                GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: childAspectRatio,
                  children: [
                    _buildSectionCard(
                      title: 'المبيعات',
                      subtitle: 'نقاط البيع والفواتير والباركود',
                      icon: Icons.point_of_sale_rounded,
                      color: AppTheme.primary,
                      onTap: () => _navigateToSection(1),
                    ),
                    _buildSectionCard(
                      title: 'المشتريات',
                      subtitle: 'فواتير التوريد وإدخال البضائع',
                      icon: Icons.shopping_cart_checkout_rounded,
                      color: AppTheme.secondary,
                      onTap: () => _navigateToSection(2),
                    ),
                    _buildSectionCard(
                      title: 'المخزون',
                      subtitle: 'الأصناف والأسعار وتنبيه النواقص',
                      icon: Icons.inventory_2_rounded,
                      color: const Color(0xFFD97706),
                      onTap: () => _navigateToSection(3),
                    ),
                    _buildSectionCard(
                      title: 'العملاء',
                      subtitle: 'كشوف الحساب والذمم والتحصيلات',
                      icon: Icons.people_alt_rounded,
                      color: const Color(0xFF2563EB),
                      onTap: () => _navigateToSection(4),
                    ),
                    _buildSectionCard(
                      title: 'الموردون',
                      subtitle: 'المستحقات ومتابعة حسابات الموردين',
                      icon: Icons.local_shipping_rounded,
                      color: const Color(0xFF7C3AED),
                      onTap: () => _navigateToSection(5),
                    ),
                    _buildSectionCard(
                      title: 'الصندوق',
                      subtitle: 'حركات الخزينة وسندات الصرف والقبض',
                      icon: Icons.account_balance_wallet_rounded,
                      color: AppTheme.success,
                      onTap: () => _navigateToSection(6),
                    ),
                    _buildSectionCard(
                      title: 'التقارير',
                      subtitle: 'الأرباح والمبيعات وكشوفات الحساب',
                      icon: Icons.analytics_rounded,
                      color: const Color(0xFF0284C7),
                      onTap: () => _navigateToSection(7),
                    ),
                    _buildSectionCard(
                      title: 'الإعدادات',
                      subtitle: 'بيانات المنشأة والنسخ الاحتياطي',
                      icon: Icons.settings_suggest_rounded,
                      color: AppTheme.neutral,
                      onTap: () => _navigateToSection(8),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  /// بطاقات الملخص المالي السريع بأرقام حقيقية من قاعدة البيانات
  Widget _buildFinancialSummaryCards(double screenWidth) {
    if (_isLoadingMetrics) {
      return Container(
        height: 80,
        decoration: AppTheme.cardDecoration(),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final totalSalesToday = (_metrics['totalSalesToday'] as num?)?.toDouble() ?? 0.0;
    final totalCashBalance = (_metrics['totalCashBalance'] as num?)?.toDouble() ?? 0.0;
    final totalDebts = (_metrics['totalCustomersDebt'] as num?)?.toDouble() ?? 0.0;
    final totalProducts = (_metrics['totalProductsCount'] as num?)?.toInt() ?? 0;

    final isNarrow = screenWidth < 500;

    return Container(
      decoration: AppTheme.cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.insights_rounded, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'الملخص المالي اليومي',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              Text(
                'مُحدّث مباشرة من السجلات',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isNarrow)
            Column(
              children: [
                _buildStatTile('مبيعات اليوم', Formatters.formatCurrency(totalSalesToday), Icons.trending_up, AppTheme.primary),
                const Divider(height: 14),
                _buildStatTile('رصيد الصناديق', Formatters.formatCurrency(totalCashBalance), Icons.account_balance_wallet, AppTheme.success),
                const Divider(height: 14),
                _buildStatTile('إجمالي الذمم المدينة', Formatters.formatCurrency(totalDebts), Icons.request_quote_outlined, AppTheme.danger),
                const Divider(height: 14),
                _buildStatTile('الأصناف بالمخزون', '$totalProducts صنف', Icons.inventory_2_outlined, AppTheme.warning),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildStatTile('مبيعات اليوم', Formatters.formatCurrency(totalSalesToday), Icons.trending_up, AppTheme.primary),
                ),
                Container(width: 1, height: 44, color: AppTheme.border),
                Expanded(
                  child: _buildStatTile('رصيد الصندوق', Formatters.formatCurrency(totalCashBalance), Icons.account_balance_wallet, AppTheme.success),
                ),
                Container(width: 1, height: 44, color: AppTheme.border),
                Expanded(
                  child: _buildStatTile('الذمم المدينة', Formatters.formatCurrency(totalDebts), Icons.request_quote_outlined, AppTheme.danger),
                ),
                Container(width: 1, height: 44, color: AppTheme.border),
                Expanded(
                  child: _buildStatTile('الأصناف بالمخزون', '$totalProducts صنف', Icons.inventory_2_outlined, AppTheme.warning),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color == AppTheme.danger ? AppTheme.danger : AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// بطاقة القسم الكبيرة والواضحة في الـ Grid
  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        hoverColor: color.withValues(alpha: 0.05),
        splashColor: color.withValues(alpha: 0.1),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 26),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
