class GroupConversation {
  GroupConversation({
    required this.id,
    required this.participants,
    this.unreadCount = 0,
    DateTime? lastActivity,
  }) : lastActivity = lastActivity ?? DateTime.now();

  /// Sorted participant emails joined by '+'.
  final String id;

  /// Set of all remote participant emails.
  final Set<String> participants;

  int unreadCount;
  DateTime lastActivity;

  /// Build a canonical conversation id from a set of email addresses.
  static String buildId(Iterable<String> emails) {
    final sorted = emails.map((e) => e.toLowerCase()).toList()..sort();
    return sorted.join('+');
  }

  GroupConversation copyWith({
    Set<String>? participants,
    int? unreadCount,
    DateTime? lastActivity,
  }) {
    return GroupConversation(
      id: id,
      participants: participants ?? this.participants,
      unreadCount: unreadCount ?? this.unreadCount,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }
}
