import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/home/presentation/home_page.dart';
import 'features/student/data/student_pin_service.dart';
import 'features/student/data/student_repository.dart';
import 'features/student/presentation/student_pin_page.dart';
import 'features/student/presentation/student_setup_page.dart';

class AlTafawuqApp extends StatelessWidget {
  const AlTafawuqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'منصة التفوق',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: _StudentEntryGate(),
      ),
    );
  }
}

class _StudentEntryGate extends StatefulWidget {
  const _StudentEntryGate();

  @override
  State<_StudentEntryGate> createState() => _StudentEntryGateState();
}

class _StudentEntryGateState extends State<_StudentEntryGate> {
  final _repository = StudentRepository();
  final _pinService = StudentPinService();
  late Future<int> _entryState;

  @override
  void initState() {
    super.initState();
    _entryState = _loadEntryState();
  }

  Future<int> _loadEntryState() async {
    final profile = await _repository.getStudentProfile();
    if (profile == null) return 0;
    return await _pinService.isEnabled() ? 2 : 1;
  }

  void _completeSetup() {
    setState(() => _entryState = Future<int>.value(1));
  }

  void _unlock() {
    setState(() => _entryState = Future<int>.value(1));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _entryState,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('تعذر فتح ملف الطالب. أعد تشغيل التطبيق.')),
          );
        }
        switch (snapshot.data) {
          case 0:
            return StudentSetupPage(onSaved: _completeSetup, isFirstRun: true);
          case 2:
            return StudentPinPage(onUnlocked: _unlock);
          default:
            return const HomePage();
        }
      },
    );
  }
}
