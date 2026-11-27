import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/branding/tafwauq_brand.dart';
import '../data/student_models.dart';
import '../data/student_repository.dart';

class StudentSetupPage extends StatefulWidget {
  const StudentSetupPage({super.key, this.onSaved, this.isFirstRun = false});

  final VoidCallback? onSaved;
  final bool isFirstRun;

  @override
  State<StudentSetupPage> createState() => _StudentSetupPageState();
}

class _StudentSetupPageState extends State<StudentSetupPage> {
  final _repository = StudentRepository();
  final _nameController = TextEditingController();

  late Future<List<Grade>> _gradesFuture;
  Future<List<StudyTrack>>? _tracksFuture;
  int? _selectedGradeId;
  int? _selectedTrackId;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _gradesFuture = _repository.getGrades();
    _loadSavedProfile();
  }

  Future<void> _loadSavedProfile() async {
    try {
      final profile = await _repository.getStudentProfile();
      if (!mounted || profile == null) return;
      setState(() {
        _nameController.text = profile.displayName ?? '';
        _selectedGradeId = profile.gradeId;
        _selectedTrackId = profile.trackId;
        _tracksFuture = _repository.getTracksForGrade(profile.gradeId);
      });
    } catch (_) {
      // A new installation has no saved profile; the form remains available.
    }
  }

  void _onGradeChanged(int? gradeId) {
    if (gradeId == null) return;
    setState(() {
      _selectedGradeId = gradeId;
      _selectedTrackId = null;
      _tracksFuture = _repository.getTracksForGrade(gradeId);
    });
  }

  Future<void> _save() async {
    final gradeId = _selectedGradeId;
    if (gradeId == null) {
      setState(() => _errorMessage = 'يرجى اختيار الصف الدراسي.');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      await _repository.saveStudentProfile(
        StudentProfile(
          displayName: _nameController.text,
          gradeId: gradeId,
          trackId: _selectedTrackId,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ بيانات الطالب على الجهاز.')),
      );
      if (widget.onSaved != null) {
        widget.onSaved!();
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذر حفظ البيانات. تحقق من اختيار الصف والمسار.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isFirstRun ? 'مرحباً بك في التفوق' : 'إعداد الطالب'), automaticallyImplyLeading: !widget.isFirstRun),
      body: SafeArea(
        child: FutureBuilder<List<Grade>>(
          future: _gradesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('تعذر تحميل الصفوف الدراسية.'));
            }

            final grades = snapshot.data!;
            final selectedGradeId = grades.any((g) => g.id == _selectedGradeId)
                ? _selectedGradeId
                : grades.first.id;

            if (_selectedGradeId == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _selectedGradeId == null) {
                  setState(() {
                    _selectedGradeId = grades.first.id;
                    _tracksFuture =
                        _repository.getTracksForGrade(grades.first.id);
                  });
                }
              });
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (widget.isFirstRun) ...[
                  const SizedBox(height: 20),
                  const Center(child: TafawuqBrandMark(size: 82)),
                  const SizedBox(height: 18),
                ],
                const Text(
                  'لنجهّز تجربتك التعليمية',
                  style: TextStyle(
                    color: AppColors.deepEmerald,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'تُحفظ هذه البيانات محلياً على جهازك، ولا تحتاج إلى إنشاء حساب.',
                  style: TextStyle(color: AppColors.muted, height: 1.5),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'اسم الطالب (اختياري)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<int>(
                  value: selectedGradeId,
                  decoration: const InputDecoration(
                    labelText: 'الصف الدراسي',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                  items: grades
                      .map(
                        (grade) => DropdownMenuItem(
                          value: grade.id,
                          child: Text(grade.name),
                        ),
                      )
                      .toList(),
                  onChanged: _onGradeChanged,
                ),
                const SizedBox(height: 18),
                FutureBuilder<List<StudyTrack>>(
                  future: _tracksFuture ??
                      _repository.getTracksForGrade(selectedGradeId!),
                  builder: (context, trackSnapshot) {
                    if (trackSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const LinearProgressIndicator();
                    }
                    final tracks = trackSnapshot.data ?? const <StudyTrack>[];
                    if (tracks.isEmpty) {
                      return const InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'المسار الدراسي',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          'لم تُضف المسارات لهذا الصف بعد. يمكنك حفظ الصف الآن.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      );
                    }
                    return DropdownButtonFormField<int>(
                      value: tracks.any((t) => t.id == _selectedTrackId)
                          ? _selectedTrackId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'المسار الدراسي',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.route_outlined),
                      ),
                      items: tracks
                          .map(
                            (track) => DropdownMenuItem(
                              value: track.id,
                              child: Text(track.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedTrackId = value),
                    );
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('حفظ البيانات'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
