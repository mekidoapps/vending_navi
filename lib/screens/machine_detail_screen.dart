import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/vending_machine.dart';
import '../utils/distance_util.dart';
import '../widgets/machine_freshness_badge.dart';

class MachineDetailScreen extends StatelessWidget {
  const MachineDetailScreen({
    super.key,
    required this.machine,
    this.currentLat,
    this.currentLng,
  });

  final VendingMachine machine;
  final double? currentLat;
  final double? currentLng;

  static const Map<String, List<Map<String, dynamic>>> _manufacturerPresets =
  <String, List<Map<String, dynamic>>>{
    'コカ・コーラ': <Map<String, dynamic>>[
      {'name': 'コカ・コーラ', 'tags': <String>['炭酸', 'ジュース', '加糖']},
      {'name': '綾鷹', 'tags': <String>['お茶', '無糖']},
      {'name': 'い・ろ・は・す', 'tags': <String>['水']},
      {'name': 'ジョージア', 'tags': <String>['コーヒー', 'カフェイン']},
      {'name': 'ファンタ', 'tags': <String>['炭酸', 'ジュース', '加糖']},
      {'name': 'アクエリアス', 'tags': <String>['スポーツ', 'スッキリ']},
    ],
    'サントリー': <Map<String, dynamic>>[
      {'name': 'BOSS', 'tags': <String>['コーヒー', 'カフェイン']},
      {'name': '伊右衛門', 'tags': <String>['お茶', '無糖']},
      {'name': 'C.C.レモン', 'tags': <String>['炭酸', 'ジュース', '加糖']},
      {'name': '天然水', 'tags': <String>['水']},
      {'name': 'GREEN DA・KA・RA', 'tags': <String>['スポーツ', 'スッキリ']},
    ],
    '伊藤園': <Map<String, dynamic>>[
      {'name': 'お〜いお茶', 'tags': <String>['お茶', '無糖']},
      {'name': '健康ミネラルむぎ茶', 'tags': <String>['お茶', 'スッキリ']},
      {'name': 'TULLY\'S COFFEE', 'tags': <String>['コーヒー', 'カフェイン']},
      {'name': '天然水', 'tags': <String>['水']},
      {'name': '充実野菜', 'tags': <String>['ジュース']},
    ],
    'キリン': <Map<String, dynamic>>[
      {'name': '午後の紅茶', 'tags': <String>['紅茶', '加糖']},
      {'name': '生茶', 'tags': <String>['お茶', '無糖']},
      {'name': 'FIRE', 'tags': <String>['コーヒー', 'カフェイン']},
      {'name': 'キリンレモン', 'tags': <String>['炭酸', 'ジュース', '加糖']},
      {'name': 'アルカリイオンの水', 'tags': <String>['水']},
    ],
    'アサヒ': <Map<String, dynamic>>[
      {'name': 'WONDA', 'tags': <String>['コーヒー', 'カフェイン']},
      {'name': '十六茶', 'tags': <String>['お茶', '無糖']},
      {'name': '三ツ矢サイダー', 'tags': <String>['炭酸', 'ジュース', '加糖']},
      {'name': 'おいしい水', 'tags': <String>['水']},
      {'name': 'カルピス', 'tags': <String>['ジュース', '加糖']},
    ],
    'ダイドー': <Map<String, dynamic>>[
      {'name': 'ダイドーブレンド', 'tags': <String>['コーヒー', 'カフェイン']},
      {'name': 'miu', 'tags': <String>['水']},
      {'name': '葉の茶', 'tags': <String>['お茶', '無糖']},
    ],
    '大塚製薬': <Map<String, dynamic>>[
      {'name': 'ポカリスエット', 'tags': <String>['スポーツ', 'スッキリ']},
      {'name': 'MATCH', 'tags': <String>['炭酸', 'ジュース', '加糖']},
      {'name': 'オロナミンC', 'tags': <String>['炭酸', 'ジュース', 'カフェイン']},
    ],
    'AQUO': <Map<String, dynamic>>[
      {'name': '天然水', 'tags': <String>['水']},
      {'name': 'お茶', 'tags': <String>['お茶', '無糖']},
      {'name': 'コーヒー', 'tags': <String>['コーヒー', 'カフェイン']},
    ],
    'その他': <Map<String, dynamic>>[
      {'name': 'お茶', 'tags': <String>['お茶']},
      {'name': 'コーヒー', 'tags': <String>['コーヒー']},
      {'name': '水', 'tags': <String>['水']},
      {'name': '炭酸飲料', 'tags': <String>['炭酸']},
      {'name': 'ジュース', 'tags': <String>['ジュース']},
    ],
  };

  @override
  Widget build(BuildContext context) {
    final confirmedProducts = _productNamesOf(machine);
    final confirmedTags = _productTagsOf(machine);
    final estimatedProducts = _estimatedProductNamesOf(machine);
    final estimatedTags = _estimatedProductTagsOf(machine);
    final isEstimated =
        confirmedProducts.isEmpty && estimatedProducts.isNotEmpty;
    final displayProducts =
    confirmedProducts.isNotEmpty ? confirmedProducts : estimatedProducts;
    final displayTags =
    confirmedTags.isNotEmpty ? confirmedTags : estimatedTags;
    final distanceText = _buildDistanceText();

    return Scaffold(
      appBar: AppBar(
        title: const Text('自販機詳細'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          machine.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF334148),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _DrinkStateBadge(isEstimated: isEstimated),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _InfoPill(
                        icon: Icons.local_drink_rounded,
                        label: machine.manufacturer,
                      ),
                      MachineFreshnessBadge(
                        updatedAt: machine.lastCheckedAt ?? machine.updatedAt,
                        compact: true,
                      ),
                      if (distanceText != null)
                        _InfoPill(
                          icon: Icons.near_me_rounded,
                          label: distanceText,
                        ),
                    ],
                  ),
                  if ((machine.locationName ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _LabeledText(
                      label: '場所',
                      value: machine.locationName!,
                    ),
                  ],
                  if ((machine.address ?? '').trim().isNotEmpty &&
                      machine.address != machine.locationName) ...[
                    const SizedBox(height: 10),
                    _LabeledText(
                      label: '住所',
                      value: machine.address!,
                    ),
                  ],
                  if ((machine.note ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _LabeledText(
                      label: 'メモ',
                      value: machine.note!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEstimated ? 'このメーカーで見かけることがあるドリンク' : '確認されているドリンク',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF334148),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isEstimated
                        ? 'まだドリンク登録がないため、メーカー情報から候補を表示しています。'
                        : 'この自販機で登録されているドリンクです。',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF60707A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (displayProducts.isEmpty)
                    const Text(
                      'ドリンク未登録',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF60707A),
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: displayProducts.map((product) {
                        return _ProductChip(
                          label: product,
                          isEstimated: isEstimated,
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            if (displayTags.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'タグ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334148),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: displayTags.map((tag) {
                        return _TagChip(
                          label: tag,
                          subtle: isEstimated,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
            if (machine.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '自販機メモタグ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334148),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: machine.tags.map((tag) {
                        return _TagChip(
                          label: tag,
                          subtle: false,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }

  String _normalize(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll('　', '')
        .replaceAll(' ', '')
        .replaceAll('〜', 'ー')
        .replaceAll('～', 'ー')
        .replaceAll('-', 'ー');
  }

  List<String> _productNamesOf(VendingMachine machine) {
    final result = <String>[];
    final used = <String>{};

    for (final product in machine.products) {
      final name = (product['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      final key = _normalize(name);
      if (used.contains(key)) continue;
      used.add(key);
      result.add(name);
    }

    return result;
  }

  List<String> _productTagsOf(VendingMachine machine) {
    final result = <String>[];
    final used = <String>{};

    for (final product in machine.products) {
      final tags = List<String>.from(product['tags'] ?? const <String>[]);
      for (final tag in tags) {
        final trimmed = tag.trim();
        if (trimmed.isEmpty) continue;

        final key = _normalize(trimmed);
        if (used.contains(key)) continue;
        used.add(key);
        result.add(trimmed);
      }
    }

    return result;
  }

  List<Map<String, dynamic>> _estimatedProductsOf(VendingMachine machine) {
    if (_productNamesOf(machine).isNotEmpty) {
      return const <Map<String, dynamic>>[];
    }

    return _manufacturerPresets[machine.manufacturer] ??
        _manufacturerPresets['その他'] ??
        const <Map<String, dynamic>>[];
  }

  List<String> _estimatedProductNamesOf(VendingMachine machine) {
    final result = <String>[];
    final used = <String>{};

    for (final product in _estimatedProductsOf(machine)) {
      final name = (product['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      final key = _normalize(name);
      if (used.contains(key)) continue;
      used.add(key);
      result.add(name);
    }

    return result;
  }

  List<String> _estimatedProductTagsOf(VendingMachine machine) {
    final result = <String>[];
    final used = <String>{};

    for (final product in _estimatedProductsOf(machine)) {
      final tags = List<String>.from(product['tags'] ?? const <String>[]);
      for (final tag in tags) {
        final trimmed = tag.trim();
        if (trimmed.isEmpty) continue;

        final key = _normalize(trimmed);
        if (used.contains(key)) continue;
        used.add(key);
        result.add(trimmed);
      }
    }

    return result;
  }

  String? _buildDistanceText() {
    if (currentLat == null || currentLng == null) return null;

    final meters = _distanceMeters(
      currentLat!,
      currentLng!,
      machine.lat,
      machine.lng,
    );

    return DistanceUtil.formatDistance(meters);
  }

  double _distanceMeters(
      double lat1,
      double lng1,
      double lat2,
      double lng2,
      ) {
    const earthRadius = 6371000.0;

    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);

    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.pow(math.sin(dLng / 2), 2);

    final c =
        2 * math.atan2(math.sqrt(a.toDouble()), math.sqrt(1 - a.toDouble()));
    return earthRadius * c;
  }

  double _degToRad(double degrees) => degrees * math.pi / 180.0;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LabeledText extends StatelessWidget {
  const _LabeledText({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 54,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF60707A),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334148),
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: const Color(0xFF60707A),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF60707A),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrinkStateBadge extends StatelessWidget {
  const _DrinkStateBadge({
    required this.isEstimated,
  });

  final bool isEstimated;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
    isEstimated ? const Color(0xFFF1F3F5) : const Color(0xFFEAF6FF);
    final borderColor =
    isEstimated ? const Color(0xFFD8E0E5) : const Color(0xFFBEDDF4);
    final textColor =
    isEstimated ? const Color(0xFF60707A) : const Color(0xFF245A84);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        isEstimated ? '候補' : '確認済み',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}

class _ProductChip extends StatelessWidget {
  const _ProductChip({
    required this.label,
    required this.isEstimated,
  });

  final String label;
  final bool isEstimated;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isEstimated ? const Color(0xFFF7FBFC) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color:
          isEstimated ? const Color(0xFFD8E7EA) : const Color(0xFFE3E7EB),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isEstimated) ...[
            const Icon(
              Icons.help_outline_rounded,
              size: 13,
              color: Color(0xFF60707A),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color:
              isEstimated ? const Color(0xFF60707A) : const Color(0xFF334148),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.subtle,
  });

  final String label;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: subtle ? const Color(0xFFF7FBFC) : const Color(0xFFEAF6FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: subtle ? const Color(0xFFE3E7EB) : const Color(0xFFBEDDF4),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: subtle ? const Color(0xFF60707A) : const Color(0xFF245A84),
        ),
      ),
    );
  }
}