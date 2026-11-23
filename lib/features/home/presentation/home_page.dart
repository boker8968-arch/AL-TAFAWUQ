import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../student/presentation/student_setup_page.dart';
import '../../content/presentation/content_management_page.dart';
import '../../library/presentation/learning_library_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _openContentManagement(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ContentManagementPage()),
    );
  }

  void _openLibrary(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LearningLibraryPage()),
    );
  }

  Future<void> _openStudentSetup(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => const StudentSetupPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'منصة التفوق',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            Text(
              'طريقك نحو التفوق الدراسي',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'إدارة المحتوى للمشرفين',
            onPressed: () => _openContentManagement(context),
            icon: const Icon(Icons.admin_panel_settings_outlined),
          ),
          IconButton(
            tooltip: 'الإشعارات',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _WelcomeCard(onSetupTap: () => _openStudentSetup(context)),
            const SizedBox(height: 24),
            const _SectionHeading(title: 'ماذا تريد أن تدرس اليوم؟'),
            const SizedBox(height: 12),
            _StudyGrid(onOpenLibrary: () => _openLibrary(context)),
            const SizedBox(height: 24),
            const _SectionHeading(title: 'تابع رحلتك التعليمية'),
            const SizedBox(height: 12),
            const _ProgressCard(),
            const SizedBox(height: 24),
            const _SectionHeading(title: 'محتوى المنصة'),
            const SizedBox(height: 12),
            const _OfflineNotice(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) _openLibrary(context);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: 'المكتبة',
          ),
          NavigationDestination(
            icon: Icon(Icons.quiz_outlined),
            label: 'الامتحانات',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.onSetupTap});

  final VoidCallback onSetupTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.emerald, AppColors.deepEmerald],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.gold, size: 28),
          const SizedBox(height: 14),
          const Text(
            'ابدأ يومك بالإنجاز',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'كل خطوة صغيرة تقرّبك من هدفك.',
            style: TextStyle(color: Color(0xFFE2F1E9), fontSize: 13),
          ),
          const SizedBox(height: 18),
          const Text(
            'اختر صفك الدراسي لإعداد تجربتك التعليمية',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: onSetupTap,
            icon: const Icon(Icons.school_outlined),
            label: const Text('إعداد بيانات الطالب'),
            style: FilledButton.styleFrom(
              foregroundColor: AppColors.deepEmerald,
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.ink,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _StudyGrid extends StatelessWidget {
  const _StudyGrid({required this.onOpenLibrary});

  final VoidCallback onOpenLibrary;

  static const _items = [
    (title: 'المناهج', icon: Icons.menu_book_rounded),
    (title: 'الشروحات', icon: Icons.play_circle_outline_rounded),
    (title: 'الملخصات', icon: Icons.summarize_outlined),
    (title: 'الامتحانات', icon: Icons.edit_note_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: item.title == 'الامتحانات' ? null : onOpenLibrary,
            child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, color: AppColors.emerald, size: 27),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            ),
          ),
        );
      },
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Color(0xFFE7F3EC),
              child: Icon(Icons.flag_outlined, color: AppColors.emerald),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إنجازك الدراسي',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'سيظهر تقدمك هنا بعد بدء الدراسة',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.offline_bolt_rounded, color: AppColors.emerald),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تعلم دون إنترنت',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'صُممت المنصة لتكون المناهج والدروس والامتحانات متاحة محلياً بعد تثبيت المحتوى.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          height: 1.5,
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
}
