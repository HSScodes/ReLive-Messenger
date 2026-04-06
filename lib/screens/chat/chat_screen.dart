import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.contactEmail,
  });

  final String contactEmail;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(chatProvider);
    final messages = ref.read(chatProvider.notifier).threadForContact(widget.contactEmail);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contactEmail),
        backgroundColor: const Color(0xFF4CA5DC),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFFF7FCFF),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return Align(
                    alignment: message.from == widget.contactEmail
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: message.from == widget.contactEmail
                            ? const Color(0xFFE1F5FF)
                            : const Color(0xFFD7F8D8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(message.body),
                    ),
                  );
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFEAF5FC),
              border: Border(top: BorderSide(color: Color(0xFFA5CEE8))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onChanged: (_) => ref.read(chatProvider.notifier).sendTyping(widget.contactEmail),
                    onSubmitted: (_) => _sendText(),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Emoticons',
                  onPressed: () {},
                  icon: const Icon(Icons.emoji_emotions_outlined),
                ),
                TextButton(
                  onPressed: () => ref.read(chatProvider.notifier).sendNudge(widget.contactEmail),
                  child: const Text('Nudge'),
                ),
                const SizedBox(width: 6),
                ElevatedButton(
                  onPressed: _sendText,
                  child: const Text('Send'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendText() async {
    final body = _messageController.text.trim();
    if (body.isEmpty) {
      return;
    }

    await ref.read(chatProvider.notifier).sendMessage(
          to: widget.contactEmail,
          body: body,
        );
    if (!mounted) {
      return;
    }
    _messageController.clear();
  }
}
