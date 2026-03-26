import 'dart:collection';

import 'package:flutter/foundation.dart';

class ProgressionPopupData {
  final String title;
  final String? subtitle;

  const ProgressionPopupData({
    required this.title,
    this.subtitle,
  });
}

class ProgressionPopupService extends ChangeNotifier {
  ProgressionPopupService._internal();

  static final ProgressionPopupService _instance =
  ProgressionPopupService._internal();

  factory ProgressionPopupService() => _instance;

  final Queue<ProgressionPopupData> _queue = Queue<ProgressionPopupData>();

  ProgressionPopupData? _current;
  bool _isShowing = false;

  ProgressionPopupData? get current => _current;
  bool get isShowing => _isShowing;
  bool get hasPending => _queue.isNotEmpty || _current != null;

  void enqueue({
    required String title,
    String? subtitle,
  }) {
    _queue.add(
      ProgressionPopupData(
        title: title,
        subtitle: subtitle,
      ),
    );
    _tryShowNext();
  }

  void completeCurrent() {
    _current = null;
    _isShowing = false;
    notifyListeners();
    _tryShowNext();
  }

  void clear() {
    _queue.clear();
    _current = null;
    _isShowing = false;
    notifyListeners();
  }

  void _tryShowNext() {
    if (_isShowing) return;
    if (_queue.isEmpty) return;

    _current = _queue.removeFirst();
    _isShowing = true;
    notifyListeners();
  }
}