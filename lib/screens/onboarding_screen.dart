import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_gate.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const String _seenKey = 'has_seen_onboarding_v1';

  static Future<bool> hasSeen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  static Future<void> markSeen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  int _currentPage = 0;
  bool _isFinishing = false;

  static const List<_OnboardingPageData> _pages = <_OnboardingPageData>[
    _OnboardingPageData(
      icon: Icons.search_rounded,
      title: '飲みたいドリンクから探せます',
      description: '「綾鷹」「BOSS」「お〜いお茶」など、今飲みたいドリンク名から近くの自販機を探せます。',
      accentColor: Color(0xFF3E7BFA),
    ),
    _OnboardingPageData(
      icon: Icons.add_location_alt_rounded,
      title: '見かけた自販機やドリンクを登録できます',
      description: '見かけたものだけで大丈夫です。メーカーを選んで、あとからドリンク情報を追加することもできます。',
      accentColor: Color(0xFF2F7D5B),
    ),
    _OnboardingPageData(
      icon: Icons.favorite_rounded,
      title: 'お気に入りで探しやすくなります',
      description: 'よく飲むドリンクをお気に入りに入れると、近くにある自販機を見つけやすくなります。',
      accentColor: Color(0xFFB56B00),
    ),
    _OnboardingPageData(
      icon: Icons.shield_outlined,
      title: '安全に使ってください',
      description: '私有地に入らない、危険な場所で操作しない、周囲の迷惑にならないように使ってください。',
      accentColor: Color(0xFFFFB74D),
      isSafetyPage: true,
    ),
  ];

  bool get _isLastPage => _currentPage == _pages.length - 1;

  void _handlePageChanged(int index) {
    if (!mounted) return;
    setState(() {
      _currentPage = index;
    });
  }

  Future<void> _complete() async {
    if (_isFinishing) return;

    setState(() {
      _isFinishing = true;
    });

    try {
      await OnboardingScreen.markSeen();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const AuthGate(),
        ),
            (Route<dynamic> route) => false,
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isFinishing = false;
      });
    }
  }

  Future<void> _next() async {
    if (_isFinishing) return;

    if (_isLastPage) {
      await _complete();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _previous() async {
    if (_currentPage == 0 || _isFinishing) return;

    await _pageController.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _skip() async {
    await _complete();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final _OnboardingPageData page = _pages[_currentPage];

    return Scaffold(
      backgroundColor: const Color(0xFFD6ECFF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Text(
                    '自販機ナビ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF334148),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isFinishing ? null : _skip,
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
                  itemBuilder: (BuildContext context, int index) {
                    return _OnboardingPage(
                      data: _pages[index],
                      theme: theme,
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(
                  _pages.length,
                      (int index) => _PageIndicator(
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
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _currentPage == 0 || _isFinishing ? null : _previous,
                        child: const Text('戻る'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isFinishing ? null : _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: page.accentColor,
                        ),
                        child: _isFinishing
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : Text(_isLastPage ? 'はじめる' : '次へ'),
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

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.data,
    required this.theme,
  });

  final _OnboardingPageData data;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE3E7EB)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: <Widget>[
            _HeroIllustration(data: data),
            const SizedBox(height: 24),
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF334148),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              data.description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF60707A),
                height: 1.65,
              ),
            ),
            const Spacer(),
            if (data.isSafetyPage)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E8),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFFE0A3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _SafetyRow(
                      icon: Icons.block_rounded,
                      text: '私有地や立ち入り禁止の場所には入らない',
                    ),
                    SizedBox(height: 10),
                    _SafetyRow(
                      icon: Icons.warning_amber_rounded,
                      text: '歩きながらや車道付近での操作を避ける',
                    ),
                    SizedBox(height: 10),
                    _SafetyRow(
                      icon: Icons.people_alt_outlined,
                      text: '通行や施設利用の迷惑にならないようにする',
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

class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration({
    required this.data,
  });

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: <Color>[
            data.accentColor.withOpacity(0.18),
            data.accentColor.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: data.accentColor.withOpacity(0.22),
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: 18,
            right: 18,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: data.accentColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 18,
            bottom: 18,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: data.accentColor.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: data.isSafetyPage
                ? const _SafetyMiniScene()
                : _SearchMiniScene(
              accentColor: data.accentColor,
              icon: data.icon,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchMiniScene extends StatelessWidget {
  const _SearchMiniScene({
    required this.accentColor,
    required this.icon,
  });

  final Color accentColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE3E7EB)),
            ),
            child: const Row(
              children: <Widget>[
                Icon(
                  Icons.search_rounded,
                  color: Color(0xFF60707A),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '綾鷹 / BOSS / お〜いお茶',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF60707A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: 210,
            height: 128,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE3E7EB)),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      icon,
                      size: 36,
                      color: accentColor,
                    ),
                  ),
                ),
                const Positioned(
                  right: 16,
                  top: 22,
                  child: Column(
                    children: <Widget>[
                      _MiniDrinkPill(label: '近くで買える'),
                      SizedBox(height: 10),
                      _MiniDrinkPill(label: 'メーカー確認'),
                      SizedBox(height: 10),
                      _MiniDrinkPill(label: 'あとで登録'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyMiniScene extends StatelessWidget {
  const _SafetyMiniScene();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 210,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE3E7EB)),
            ),
            child: const Column(
              children: <Widget>[
                Icon(
                  Icons.shield_outlined,
                  size: 52,
                  color: Color(0xFFFFB74D),
                ),
                SizedBox(height: 14),
                _MiniNoticePill(text: '私有地NG'),
                SizedBox(height: 10),
                _MiniNoticePill(text: '危険場所で操作しない'),
                SizedBox(height: 10),
                _MiniNoticePill(text: '周囲に配慮'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniDrinkPill extends StatelessWidget {
  const _MiniDrinkPill({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF4B6472),
        ),
      ),
    );
  }
}

class _MiniNoticePill extends StatelessWidget {
  const _MiniNoticePill({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFFE0A3)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(0xFF8A5B00),
        ),
      ),
    );
  }
}

class _SafetyRow extends StatelessWidget {
  const _SafetyRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            icon,
            size: 18,
            color: const Color(0xFF8A5B00),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7A6642),
              height: 1.55,
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
    this.isSafetyPage = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;
  final bool isSafetyPage;
}
