class Message {
  const Message({
    required this.from,
    required this.to,
    required this.body,
    required this.timestamp,
    this.isNudge = false,
    this.isTyping = false,
  });

  final String from;
  final String to;
  final String body;
  final DateTime timestamp;
  final bool isNudge;
  final bool isTyping;
}
