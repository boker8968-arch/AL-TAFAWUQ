import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../data/content_package_review_repository.dart';

class ContentReviewPage extends StatefulWidget {
  const ContentReviewPage({super.key});

  @override
  State<ContentReviewPage> createState() => _ContentReviewPageState();
}

class _ContentReviewPageState extends State<ContentReviewPage> {
  final _reviewerController = TextEditingController();
  final _notesController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, Object?>> _packages = const [];
  late ContentPackageReviewRepository _repository;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reviewerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final db = await AppDatabase.instance.database;
      _repository = ContentPackageReviewRepository(db);
      final packages = await _repository.getPackages(reviewStatus: 'pending_review');
      if (!mounted) return;
      setState(() {
        _packages = packages;
        _loading = false;
      });
    } on DatabaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل قائمة المراجعة: $error';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _decide(Map<String, Object?> package, String decision) async {
    if (_saving) return;
    final reviewer = _reviewerController.text.trim();
    final notes = _notesController.text.trim();
    if (reviewer.isEmpty) {
      _show('أدخل اسم المراجع لتوثيق القرار.', true);
      return;
    }
    if (decision == 'rejected' && notes.isEmpty) {
      _show('اكتب سبب الرفض قبل تسجيل القرار.', true);
      return;
    }
    setState(() => _saving = true);
    try {
      await _repository.reviewPackage(
        packageId: package['id']! as int,
        decision: decision,
        reviewerLabel: reviewer,
        notes: notes,
      );
      _notesController.clear();
      await _load();
      if (!mounted) return;
      _show(decision == 'approved' ? 'تم اعتماد الحزمة.' : 'تم رفض الحزمة وتسجيل السبب.', false);
    } catch (error) {
      if (!mounted) return;
      _show('لم يُسجل القرار: $error', true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _show(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : AppColors.deepEmerald,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مراجعة واعتماد المحتوى')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('بيانات المراجعة', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _reviewerController,
                        decoration: const InputDecoration(
                          labelText: 'اسم المراجع',
                          hintText: 'يُسجل كاسم وصفي في سجل المراجعة',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _notesController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات أو سبب الرفض',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('الحزم بانتظار المراجعة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!)))
              else if (_packages.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Text('لا توجد حزم بانتظار المراجعة حالياً.', textAlign: TextAlign.center),
                  ),
                )
              else
                ..._packages.map(_buildPackageCard),
              const SizedBox(height: 18),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'تنبيه: اسم المراجع هنا للتوثيق فقط وليس إثباتاً للهوية أو صلاحية الوصول. كما أن اعتماد الحزم الرسمية موقوف حتى إضافة والتحقق من بيانات مصدرها الرسمي.',
                    style: TextStyle(height: 1.55, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackageCard(Map<String, Object?> package) {
    final official = package['source_label'] == 'official';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(package['package_code']! as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 5),
            Text('الإصدار: ${package['version']}'),
            const SizedBox(height: 5),
            Row(
              children: [
                const Text('نوع المصدر: '),
                Text(
                  official ? 'رسمي — يحتاج إثبات مصدر' : 'تكميلي',
                  style: TextStyle(
                    color: official ? Colors.deepOrange : AppColors.emerald,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : () => _decide(package, 'rejected'),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('رفض'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving || official ? null : () => _decide(package, 'approved'),
                    icon: const Icon(Icons.verified_outlined),
                    label: Text(official ? 'الاعتماد موقوف' : 'اعتماد'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
