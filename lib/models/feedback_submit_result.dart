class FeedbackSubmitResult {
  const FeedbackSubmitResult({
    required this.ok,
    required this.feedbackId,
    required this.status,
    required this.message,
  });

  final bool ok;
  final String feedbackId;
  final String status;
  final String message;

  factory FeedbackSubmitResult.fromMap(Map<dynamic, dynamic> map) {
    return FeedbackSubmitResult(
      ok: map['ok'] == true,
      feedbackId: (map['feedbackId'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
    );
  }
}