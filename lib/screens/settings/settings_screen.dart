import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../data/database/database_helper.dart';
import '../backup/backup_restore_screen.dart';

/// شاشة الإعدادات العامة والنسخ الاحتياطي والاسترجاع (حسب البند 16 من المواصفات)
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _shopPhoneController = TextEditingController();
  final TextEditingController _shopAddressController = TextEditingController();
  final TextEditingController _shopTaxNumberController = TextEditingController();
  final TextEditingController _currencyController = TextEditingController();
  bool _enableBeep = true;
  bool _isLoading = true;
  List<String> _backups = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final shopName = await DatabaseHelper.instance.getSetting(AppConstants.keyShopName) ?? AppConstants.defaultShopName;
    final shopPhone = await DatabaseHelper.instance.getSetting(AppConstants.keyShopPhone) ?? '';
    final shopAddress = await DatabaseHelper.instance.getSetting(AppConstants.keyShopAddress) ?? '';
    final shopTax = await DatabaseHelper.instance.getSetting(AppConstants.keyShopTaxNumber) ?? '';
    final currency = await DatabaseHelper.instance.getSetting(AppConstants.keyCurrencySymbol) ?? AppConstants.defaultCurrency;
    final beep = await DatabaseHelper.instance.getSetting(AppConstants.keyEnableBeep) ?? '1';
    final backups = await DatabaseHelper.instance.listLocalBackups();

    if (mounted) {
      setState(() {
        _shopNameController.text = shopName;
        _shopPhoneController.text = shopPhone;
        _shopAddressController.text = shopAddress;
        _shopTaxNumberController.text = shopTax;
        _currencyController.text = currency;
        _enableBeep = beep == '1';
        _backups = backups;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    await DatabaseHelper.instance.setSetting(AppConstants.keyShopName, _shopNameController.text.trim());
    await DatabaseHelper.instance.setSetting(AppConstants.keyShopPhone, _shopPhoneController.text.trim());
    await DatabaseHelper.instance.setSetting(AppConstants.keyShopAddress, _shopAddressController.text.trim());
    await DatabaseHelper.instance.setSetting(AppConstants.keyShopTaxNumber, _shopTaxNumberController.text.trim());
    await DatabaseHelper.instance.setSetting(AppConstants.keyCurrencySymbol, _currencyController.text.trim());
    await DatabaseHelper.instance.setSetting(AppConstants.keyEnableBeep, _enableBeep ? '1' : '0');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الإعدادات بنجاح'), backgroundColor: AppTheme.success),
      );
    }
  }


  Future<void> _restoreBackup(String backupPath) async {
    final fileName = backupPath.split('/').last;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد استرجاع النسخة الاحتياطية'),
        content: Text(
          'تحذير: سيتم استبدال قاعدة البيانات الحالية ببيانات النسخة المحددة ($fileName).\n'
          'يرجى التأكد من أنك تريد المتابعة.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('تأكيد الاسترجاع'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await DatabaseHelper.instance.restoreLocalBackup(backupPath);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم استرجاع النسخة الاحتياطية بنجاح!'),
              backgroundColor: AppTheme.success,
            ),
          );
          _loadSettings();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل في استرجاع النسخة الاحتياطية.'),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('بيانات المنشأة والفاتورة',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _shopNameController,
                            decoration: const InputDecoration(labelText: 'اسم المحل / المنشأة *'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _shopPhoneController,
                            decoration: const InputDecoration(labelText: 'رقم الهاتف للتواصل'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _shopAddressController,
                            decoration: const InputDecoration(labelText: 'العنوان الرسمي للمنشأة'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _shopTaxNumberController,
                            decoration: const InputDecoration(labelText: 'الرقم الضريبي للمنشأة'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('خيارات النظام ونقطة البيع',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _currencyController,
                            decoration: const InputDecoration(labelText: 'رمز العملة الافتراضية (مثال: ر.س)'),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('صوت التنبيه (Beep) عند قراءة الباركود'),
                            subtitle: const Text('إصدار صوت خفيف ومميز عند اختيار أو مسح صنف في المبيعات'),
                            value: _enableBeep,
                            onChanged: (v) => setState(() => _enableBeep = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // قسم النسخ الاحتياطي والاسترجاع
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      const Text(
                        'النسخ الاحتياطي واسترجاع البيانات',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (ctx) => const BackupRestoreScreen()),
                        ),
                        icon: const Icon(Icons.settings_backup_restore, size: 18),
                        label: const Text('النسخ والاسترداد الذكي (JSON & Excel)'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'يحفظ النظام نسخاً احتياطية كاملة ومترابطة لقاعدة البيانات (الأصناف، الفواتير، الحسابات، الصندوق).',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (ctx) => const BackupRestoreScreen()),
                              ),
                              icon: const Icon(Icons.cloud_sync_outlined),
                              label: const Text('فتح مركز النسخ الاحتياطي والاسترداد الشامل'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _backups.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text('لا توجد نسخ احتياطية محفوظة محلياً بعد'),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _backups.length,
                                  separatorBuilder: (_, _) => const Divider(height: 1),
                                  itemBuilder: (ctx, index) {
                                    final backupPath = _backups[index];
                                    final fileName = backupPath.split('/').last;
                                    final String sizeKb;
                                    if (!kIsWeb) {
                                      final file = File(backupPath);
                                      sizeKb = file.existsSync() ? (file.lengthSync() / 1024).toStringAsFixed(1) : '0';
                                    } else {
                                      sizeKb = '0';
                                    }

                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.storage_outlined, color: AppTheme.primary),
                                      title: Text(fileName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                      subtitle: Text('الحجم: $sizeKb ك.ب'),
                                      trailing: ElevatedButton.icon(
                                        onPressed: () => _restoreBackup(backupPath),
                                        icon: const Icon(Icons.restore, size: 16),
                                        label: const Text('استرجاع'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.surfaceVariant,
                                          foregroundColor: AppTheme.primary,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('حفظ جميع الإعدادات', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
