import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/w_lang_toggle.dart';
import '../../app_state/app_state.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.language,
    required this.onLanguageChanged,
    required this.onCompleted,
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final VoidCallback onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const List<IconData> _icons = <IconData>[
    Icons.sensors,
    Icons.graphic_eq,
    Icons.notifications_active,
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<_OnboardingData> pages = <_OnboardingData>[
      const _OnboardingData(
        titleEn: 'Continuous respiratory monitoring for children',
        titleAr: 'مراقبة تنفس الأطفال بشكل مستمر',
        bodyEn:
            'Track wheeze, oxygen, pulse, and temperature from one calm medical dashboard.',
        bodyAr:
            'تابع الأزيز والأكسجين والنبض والحرارة من شاشة طبية هادئة واحدة.',
      ),
      const _OnboardingData(
        titleEn: 'Instant alerts with smart home actions',
        titleAr: 'تنبيهات فورية وتحكم ذكي بالمنزل',
        bodyEn:
            'When risk rises, WaveMed can trigger purifier and humidity support automatically.',
        bodyAr:
            'عند ارتفاع الخطر، يمكن لـ WaveMed تشغيل المنقي ودعم الرطوبة تلقائياً.',
      ),
      const _OnboardingData(
        titleEn: 'Bilingual support for parents and doctors',
        titleAr: 'دعم ثنائي اللغة للأهل والأطباء',
        bodyEn:
            'Switch between English and Arabic, review trends, and prepare doctor-ready summaries.',
        bodyAr:
            'بدّل بين العربية والإنجليزية، راجع الاتجاهات، وجهز ملخصات للطبيب.',
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                          child: const Icon(Icons.air, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'WaveMed',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  LanguageToggle(
                    language: widget.language,
                    onChanged: widget.onLanguageChanged,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF0F4C73), AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            tr(
                              widget.language,
                              'Smart Wheeze Monitor',
                              'مراقب الأزيز الذكي',
                            ),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tr(
                              widget.language,
                              'Built for pediatric care at home',
                              'مصمم للرعاية المنزلية للأطفال',
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    const _VitalsPreview(),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  onPageChanged: (int value) {
                    setState(() {
                      _page = value;
                    });
                  },
                  itemBuilder: (BuildContext context, int index) {
                    final _OnboardingData item = pages[index];
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 360),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                width: 74,
                                height: 74,
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Icon(
                                  _icons[index],
                                  color: AppColors.primary,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(height: 28),
                              Text(
                                tr(widget.language, item.titleEn, item.titleAr),
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                tr(widget.language, item.bodyEn, item.bodyAr),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textMuted,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: List<Widget>.generate(
                  pages.length,
                  (int index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: _page == index ? 26 : 8,
                    height: 8,
                    margin: const EdgeInsetsDirectional.only(end: 8),
                    decoration: BoxDecoration(
                      color: _page == index
                          ? AppColors.primary
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _page == pages.length - 1
                    ? widget.onCompleted
                    : () => _controller.nextPage(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                      ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: AppColors.primary,
                ),
                child: Text(
                  _page == pages.length - 1
                      ? tr(widget.language, 'Get started', 'ابدأ الآن')
                      : tr(widget.language, 'Continue', 'متابعة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingData {
  const _OnboardingData({
    required this.titleEn,
    required this.titleAr,
    required this.bodyEn,
    required this.bodyAr,
  });

  final String titleEn;
  final String titleAr;
  final String bodyEn;
  final String bodyAr;
}

class _VitalsPreview extends StatelessWidget {
  const _VitalsPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        children: <Widget>[
          _PreviewLine(label: 'SpO2', value: '95%'),
          SizedBox(height: 12),
          _PreviewLine(label: 'BPM', value: '112'),
          SizedBox(height: 12),
          _PreviewLine(label: 'Temp', value: '37.3°'),
        ],
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
