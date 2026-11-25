import 'package:flutter/material.dart';

import '../../../core/branding/tafwauq_brand.dart';
import '../../../core/theme/app_theme.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عن منصة التفوق')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const SizedBox(height: 18),
          const Center(child: TafawuqBrandMark(size: 92)),
          const SizedBox(height: 18),
          const Center(child: Text(
            'منصة التفوق',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: AppColors.deepEmerald),
          )),
          const SizedBox(height: 8),
          const Center(child: Text(
            'طريقك نحو التفوق الدراسي',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          )),
          const SizedBox(height: 30),
          _InfoTile(title: 'الجهة المطورة', value: 'BOKER PHARMA'),
          _InfoTile(title: 'القسم', value: 'قسم تقنية المعلومات'),
          _InfoTile(title: 'الفئة المستهدفة', value: 'طلاب المرحلة الثانوية في السودان'),
          _InfoTile(title: 'الإصدار', value: '0.1.0 – نسخة اختبارية'),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.paleGold.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.gold.withValues(alpha: .55)),
            ),
            child: const Column(
              children: [
                Icon(Icons.verified_outlined, color: AppColors.deepEmerald, size: 28),
                SizedBox(height: 10),
                Text(
                  '© 2026 BOKER PHARMA. جميع الحقوق محفوظة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.deepEmerald),
                ),
                SizedBox(height: 8),
                Text(
                  'منصة التفوق علامة وهوية تعليمية تابعة للجهة المطورة. تُحترم حقوق أصحاب المناهج والمذكرات والمواد التعليمية، ويجب الرجوع إلى مصادر كل مادة لمعرفة شروط استخدامها.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.6, color: AppColors.ink, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Center(child: Text(
            'صُنع لخدمة طلاب السودان',
            style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
          )),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          title: Text(title, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
        ),
      ),
    );
  }
}
