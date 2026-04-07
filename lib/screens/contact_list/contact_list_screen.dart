import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/contacts_provider.dart';
import '../../screens/chat/chat_screen.dart';
import '../../utils/presence_status.dart';
import '../../utils/wlm_color_tags.dart';
import '../../widgets/avatar_widget.dart';

class ContactListScreen extends ConsumerWidget {
  const ContactListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('reLive Messenger'),
        backgroundColor: const Color(0xFF5BAFE3),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF7FF), Color(0xFFCAEAFA)],
          ),
        ),
        child: contacts.isEmpty
            ? const Center(child: Text('No contacts yet. Waiting for SYN/NLN updates...'))
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: contacts.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  return Material(
                    color: const Color(0xC9FFFFFF),
                    borderRadius: BorderRadius.circular(14),
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(contactEmail: contact.email),
                          ),
                        );
                      },
                      leading: AvatarWidget(
                        imagePath: contact.ddpLocalPath ?? contact.avatarLocalPath,
                        status: contact.status,
                      ),
                      title: Text.rich(
                        TextSpan(
                          children: parseWlmColorTags(contact.displayName)
                              .map((s) => TextSpan(
                                    text: s.text,
                                    style: TextStyle(color: s.color),
                                  ))
                              .toList(),
                        ),
                      ),
                      subtitle: Text(
                        contact.personalMessage ?? _statusLabel(contact.status),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  String _statusLabel(PresenceStatus status) {
    switch (status) {
      case PresenceStatus.online:
        return 'Online';
      case PresenceStatus.busy:
        return 'Busy';
      case PresenceStatus.away:
        return 'Away';
      case PresenceStatus.appearOffline:
        return 'Appear Offline';
    }
  }
}
