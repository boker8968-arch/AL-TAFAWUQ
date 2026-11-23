import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../data/content_package_importer.dart';
import 'content_review_page.dart';

class ContentManagementPage extends StatefulWidget {
  const ContentManagementPage({super.key});

  @override
  State<ContentManagementPage> createState() => _ContentManagementPageState();
}

class _ContentManagementPageState extends State<ContentManagementPage> {
  bool _busy = false;
  String? _selectedDirectory;
  String? _message;
  bool _messageIsError = false;
  List<Map<String, Object?>> _installedPackages = const [];

  @override
  void initState() {
    super.initState();
    _loadInstalledPackages();
  }

  Future<void> _loadInstalledPackages() async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'content_packages',
        columns: ['id', 'package_code', 'version', 'imported_at'],
        orderBy: 'imported_at DESC',
      );
      if (!mounted) return;
      setState(() => _installedPackages = rows);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = 'تعذر قراءة الحزم المثبتة: ' + error.toString();
        _messageIsError = true;
      });
    }
  }

  Future<void> _chooseAndImport() async {
    if (_busy) return;

    String? directoryPath;
    try {
      directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'اختر مجلد حزمة المحتوى (يحتوي manifest.json)',
      );
    } catch (error) {
      _showMessage('تعذر فتح مستعرض المجلدات: ' + error.toString(), isError: true);
      return;
    }

    if (directoryPath == null || directoryPath.trim().isEmpty) return;
    if (!mounted) return;

    setState(() {
      _selectedDirectory = directoryPath;
      _busy = true;
      _message = null;
    });

    try {
      final db = await AppDatabase.instance.database;
      final databaseDirectory = await getDatabasesPath();
      final packagesDirectory = Directory(
        p.join(databaseDirectory, 'al_tafawuq_content', 'packages'),
      );
      final importer = ContentPackageImporter(
        database: db,
        packagesDirectory: packagesDirectory,
      );
      final result = await importer.importDirectory(Directory(directoryPath));

      if (!mounted) return;
      setState(() {
        _message = 'تم استيراد الحزمة ' + result.packageCode +
            ' بنجاح. الوحدات: ' + result.importedUnits.toString() +
            '، الدروس: ' + result.importedLessons.toString() + '.';
        _messageIsError = false;
      });
      await _loadInstalledPackages();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = _friendlyError(error);
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object error) {
    if (error is FormatException) {
      return 'الحزمة غير سليمة أو أن أحد الملفات لا يطابق بيانات manifest. التفاصيل: ' + error.message;
    }
    if (error is StateError) {
      return 'لم يتم الاستيراد: ' + error.message;
    }
    if (error is FileSystemException) {
      return 'تعذر الوصول إلى ملفات الحزمة: ' + error.message;
    }
    if (error is DatabaseException) {
      return 'تعذر حفظ الحزمة في قاعدة البيانات. لم يُعتمد الاستيراد.';
    }
    return 'حدث خطأ أثناء الاستيراد: ' + error.toString();
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageIsError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المحتوى', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'مراجعة واعتماد المحتوى',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ContentReviewPage()),
            ),
            icon: const Icon(Icons.fact_check_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadInstalledPackages,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              _buildIntroCard(),
              const SizedBox(height: 18),
              _buildImportCard(),
              if (_message != null) ...[
                const SizedBox(height: 14),
                _buildMessageCard(),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'الحزم المثبتة',
                      style: TextStyle(color: AppColors.ink, fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    _installedPackages.length.toString() + ' حزمة',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_installedPackages.isEmpty)
                _buildEmptyState()
              else
                ..._installedPackages.map(_buildPackageTile),
              const SizedBox(height: 22),
              _buildRulesCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.emerald, AppColors.deepEmerald],
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.inventory_2_outlined, color: AppColors.gold, size: 30),
          SizedBox(height: 12),
          Text(
            'مركز حزم المحتوى',
            style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'استورد وحدات ودروس المواد من مجلد محلي. تعمل عملية الاستيراد دون الحاجة إلى اتصال بالإنترنت.',
            style: TextStyle(color: Color(0xFFE2F1E9), height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildImportCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.folder_open_rounded, color: AppColors.emerald),
                SizedBox(width: 9),
                Text('استيراد حزمة جديدة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 9),
            const Text(
              'اختر المجلد الذي يحتوي على manifest.json ومجلدات الملفات التابعة له.',
              style: TextStyle(color: AppColors.muted, height: 1.5, fontSize: 13),
            ),
            if (_selectedDirectory != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  _selectedDirectory!,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _chooseAndImport,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.folder_open_rounded),
                label: Text(_busy ? 'جارٍ التحقق والاستيراد...' : 'اختيار مجلد الحزمة'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageCard() {
    final color = _messageIsError ? Colors.red.shade700 : AppColors.emerald;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _messageIsError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(_message!, style: TextStyle(color: color, height: 1.5, fontSize: 13))),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 34, color: AppColors.muted.withValues(alpha: 0.7)),
            const SizedBox(height: 10),
            const Text('لا توجد حزم مثبتة حتى الآن', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 4),
            const Text(
              'ستظهر هنا الحزم التي يتم استيرادها بنجاح.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageTile(Map<String, Object?> package) {
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE7F3EC),
          child: Icon(Icons.inventory_2_outlined, color: AppColors.emerald),
        ),
        title: Text(package['package_code']! as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text('الإصدار ' + (package['version']! as String)),
        trailing: const Icon(Icons.verified_outlined, color: AppColors.emerald),
      ),
    );
  }

  Widget _buildRulesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ضوابط الاستيراد', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _rule('لا تُستورد إلا المواد المرتبطة بإصدار منهج ومادة معتمدين.'),
            _rule('يُفحص حجم كل ملف وبصمة SHA-256 قبل الحفظ.'),
            _rule('الحزم ذات المصدر الرسمي موقوفة حتى تفعيل مراجعة المصدر واعتماده.'),
            _rule('لا يدعم الإصدار الحالي استبدال الحزم المثبتة أو حذفها.'),
          ],
        ),
      ),
    );
  }

  Widget _rule(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.emerald, size: 17),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, height: 1.45))),
        ],
      ),
    );
  }
}
