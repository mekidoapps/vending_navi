import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  int _currentPage = 0;

  static const List<_OnboardingPageData> _pages = <_OnboardingPageData>[
    _OnboardingPageData(
      icon: Icons.search_rounded,
      title: '飲みたいドリンクから探せます',
      description:
      '「綾鷹」「BOSS」など、今飲みたいドリンク名から近くの自販機を探せます。',
      accentColor: Color(0xFF3E7BFA),
    ),
    _OnboardingPageData(
      icon: Icons.favorite_rounded,
      title: 'お気に入りで探しやすくなります',
      description:
      'よく飲むドリンクをお気に入りに入れると、近くにある自販機を見つけやすくなります。',
      accentColor: Color(0xFFB56B00),
    ),
    _OnboardingPageData(
      icon: Icons.shield_outlined,
      title: '安全に使ってください',
      description:
      '私有地への立ち入りや危険な場所での利用は避け、周囲に配慮して使ってください。',
      accentColor: Color(0xFF2F7D5B),
    ),
  ];

  bool get _isLastPage => _currentPage == _pages.length - 1;

  void _handlePageChanged(int index) {
    if (!mounted) return;
    setState(() {
      _currentPage = index;
    });
  }

  Future<void> _next() async {
    if (_isLastPage) {
      _finish();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _finish() {
    Navigator.of(context).pop(true);
  }

  void _skip() {
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];

    return Scaffold(
      backgroundColor: const Color(0xFFD6ECFF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            children: [
              Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: _skip,
                    child: const Text('スキップ'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _handlePageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final item = _pages[index];
                    return _OnboardingCard(
                      data: item,
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(
                  _pages.length,
                      (index) => _PageIndicator(
                    isActive: index == _currentPage,
                    color: _pages[index].accentColor,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFFE3E7EB),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _currentPage == 0
                            ? null
                            : () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          );
                        },
                        child: const Text('戻る'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: page.accentColor,
                        ),
                        child: Text(_isLastPage ? 'はじめる' : '次へ'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({
    required this.data,
  });

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFE3E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: data.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              data.icon,
              size: 46,
              color: data.accentColor,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334148),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF60707A),
              height: 1.6,
            ),
          ),
          const Spacer(),
          if (data.icon == Icons.shield_outlined)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FBFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFE3E7EB),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SafetyBullet(text: '私有地には入らない'),
                  SizedBox(height: 8),
                  _SafetyBullet(text: '危険な場所で操作しない'),
                  SizedBox(height: 8),
                  _SafetyBullet(text: '周囲の迷惑にならないように使う'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SafetyBullet extends StatelessWidget {
  const _SafetyBullet({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Icon(
            Icons.circle,
            size: 8,
            color: Color(0xFF60707A),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334148),
            ),
          ),
        ),
      ],
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.isActive,
    required this.color,
  });

  final bool isActive;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 26 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? color : const Color(0xFFD5DDE3),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;
}