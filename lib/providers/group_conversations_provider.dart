import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_conversation.dart';

class GroupConversationsNotifier extends Notifier<List<GroupConversation>> {
  @override
  List<GroupConversation> build() => <GroupConversation>[];

  /// Add or update a group conversation entry.
  void addOrUpdate(Set<String> participants) {
    final id = GroupConversation.buildId(participants);
    final idx = state.indexWhere((g) => g.id == id);
    if (idx >= 0) {
      final updated = state[idx].copyWith(
        participants: participants,
        lastActivity: DateTime.now(),
      );
      state = [...state]..[idx] = updated;
    } else {
      state = [GroupConversation(id: id, participants: participants), ...state];
    }
  }

  void incrementUnread(String conversationId) {
    final idx = state.indexWhere((g) => g.id == conversationId);
    if (idx >= 0) {
      final g = state[idx];
      state = [...state]..[idx] = g.copyWith(unreadCount: g.unreadCount + 1);
    }
  }

  void clearUnread(String conversationId) {
    final idx = state.indexWhere((g) => g.id == conversationId);
    if (idx >= 0) {
      state = [...state]..[idx] = state[idx].copyWith(unreadCount: 0);
    }
  }

  void remove(String conversationId) {
    state = state.where((g) => g.id != conversationId).toList();
  }
}

final groupConversationsProvider =
    NotifierProvider<GroupConversationsNotifier, List<GroupConversation>>(
      GroupConversationsNotifier.new,
    );
