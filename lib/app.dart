import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';

import 'features/home/presentation/home_page.dart';
import 'features/student/data/student_repository.dart';
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
  late Future<bool> _hasProfile;

  @override
  void initState() {
    super.initState();
    _hasProfile = _repository.getStudentProfile().then((profile) => profile != null);
  }

  void _completeSetup() {
    setState(() => _hasProfile = Future<bool>.value(true));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasProfile,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('تعذر فتح ملف الطالب. أعد تشغيل التطبيق.')),
          );
        }
        if (snapshot.data == true) return const HomePage();
        return StudentSetupPage(onSaved: _completeSetup, isFirstRun: true);
      },
    );
  }
}
