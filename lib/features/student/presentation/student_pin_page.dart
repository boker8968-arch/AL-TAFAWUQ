import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/student_pin_service.dart';

class StudentPinPage extends StatefulWidget {
  const StudentPinPage({
    super.key,
    required this.onUnlocked,
    this.settingsMode = false,
  });

  final VoidCallback onUnlocked;
  final bool settingsMode;

  @override
  State<StudentPinPage> createState() => _StudentPinPageState();
}

class _StudentPinPageState extends State<StudentPinPage> {
  final _pinService = StudentPinService();
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  final _currentPinController = TextEditingController();
  bool _hasExistingPin = false;
  bool _pinStateLoaded = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPinState();
  }

  Future<void> _loadPinState() async {
    final enabled = await _pinService.isEnabled();
    if (mounted) {
      setState(() {
        _hasExistingPin = enabled;
        _pinStateLoaded = true;
      });
    }
  }

  Future<void> _submit() async {
    final pin = _pinController.text;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.settingsMode) {
        if (_hasExistingPin) {
          final currentValid = await _pinService.verify(_currentPinController.text);
          if (!currentValid) {
            throw const FormatException('رمز PIN الحالي غير صحيح.');
          }
        }
        if (pin.length != 4 || !RegExp(r'^\\d{4}$').hasMatch(pin)) {
          throw const FormatException('أدخل رمزاً مكوناً من أربعة أرقام.');
        }
        if (pin != _confirmController.text) {
          throw const FormatException('الرمزان غير متطابقين.');
        }
        await _pinService.enable(pin);
      } else {
        final valid = await _pinService.verify(pin);
        if (!valid) {
          throw const FormatException('رمز PIN غير صحيح.');
        }
      }
      if (!mounted) return;
      if (widget.settingsMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تفعيل حماية ملف الطالب.')),
        );
      }
      widget.onUnlocked();
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر إتمام العملية. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    _currentPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settingsMode;
    return Scaffold(
      appBar: AppBar(
        title: Text(settings ? 'حماية ملف الطالب' : 'أدخل رمز الحماية'),
        automaticallyImplyLeading: settings,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_rounded, size: 54, color: AppColors.emerald),
                  const SizedBox(height: 18),
                  Text(
                    settings ? 'فعّل رمز PIN اختياري' : 'ملفك الدراسي محمي',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepEmerald,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    settings
                        ? 'أنشئ رمزاً من أربعة أرقام. سيُطلب عند فتح التطبيق على هذا الجهاز.'
                        : 'أدخل رمز PIN المكوّن من أربعة أرقام للمتابعة.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  if (settings && _hasExistingPin) ...[
                    TextField(
                      controller: _currentPinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        labelText: 'رمز PIN الحالي',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'رمز PIN',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (settings) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _confirmController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        labelText: 'تأكيد رمز PIN',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (_busy || (settings && !_pinStateLoaded)) ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(settings ? (_hasExistingPin ? 'تغيير رمز PIN' : 'تفعيل الحماية') : 'متابعة'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
