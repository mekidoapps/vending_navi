import 'package:flutter/material.dart';

import '../../models/feedback_category.dart';
import '../../services/feedback_service.dart';

class FeedbackFormScreen extends StatefulWidget {
  const FeedbackFormScreen({
    super.key,
    this.initialScreenName,
  });

  final String? initialScreenName;

  @override
  State<FeedbackFormScreen> createState() => _FeedbackFormScreenState();
}

class _FeedbackFormScreenState extends State<FeedbackFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _screenController = TextEditingController();
  final _stepsController = TextEditingController();

  late final FeedbackService _feedbackService;

  FeedbackCategory _selectedCategory = FeedbackCategory.bug;
  bool _replyRequested = false;
  bool _isSubmitting = false;

  static const int _minLength = 10;
  static const int _maxLength = 2000;

  @override
  void initState() {
    super.initState();
    _feedbackService = FeedbackService();
    _screenController.text = widget.initialScreenName ?? '';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _screenController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messageLength = _messageController.text.trim().length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('フィードバック送信'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ご意見を送る',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '不具合・要望・使いにくかった点を送れます。メールアドレスは公開せず、アプリ内フォームから受け付けます。',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '種別',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<FeedbackCategory>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: FeedbackCategory.values
                          .map(
                            (category) => DropdownMenuItem<FeedbackCategory>(
                          value: category,
                          child: Text(category.label),
                        ),
                      )
                          .toList(),
                      onChanged: _isSubmitting
                          ? null
                          : (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedCategory = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '内容',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'できるだけ具体的に書いてください。',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _messageController,
                      enabled: !_isSubmitting,
                      maxLines: 8,
                      minLines: 6,
                      maxLength: _maxLength,
                      decoration: const InputDecoration(
                        hintText: '例）詳細画面から戻ると下カードが重なることがあります。',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) {
                          return '内容を入力してください。';
                        }
                        if (text.length < _minLength) {
                          return '内容は$_minLength文字以上で入力してください。';
                        }
                        if (text.length > _maxLength) {
                          return '内容は$_maxLength文字以下で入力してください。';
                        }
                        return null;
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$messageLength / $_maxLength',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '発生画面（任意）',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _screenController,
                      enabled: !_isSubmitting,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        hintText: '例）main_shell / machine_detail',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '再現手順（任意）',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _stepsController,
                      enabled: !_isSubmitting,
                      maxLines: 4,
                      minLines: 3,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        hintText: '例）ピンを開く → 詳細を見る → 戻る を繰り返す',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('送信する'),
              ),
              const SizedBox(height: 12),
              Text(
                '送信内容は、サービス改善・不具合調査・不正利用対策のために利用します。',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final locale = Localizations.localeOf(context).toLanguageTag();

      final result = await _feedbackService.submitFeedback(
        category: _selectedCategory,
        message: _messageController.text,
        screen: _screenController.text,
        stepsToReproduce: _stepsController.text,
        replyRequested: _replyRequested,
        locale: locale,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message.isEmpty ? 'フィードバックを受け付けました。' : result.message,
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } on FeedbackValidationException catch (e) {
      if (!mounted) return;
      _showErrorDialog(e.message);
    } on FeedbackSubmitException catch (e) {
      if (!mounted) return;
      _showErrorDialog(e.message);
    } catch (_) {
      if (!mounted) return;
      _showErrorDialog(
        '送信に失敗しました。通信状況を確認して、少し時間をおいて再度お試しください。',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _showErrorDialog(String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('送信できませんでした'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).dividerColor.withOpacity(0.25);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}