import 'package:flutter/material.dart';
import '../../models/message_model.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Fetch chats from API /chat

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: ListView.builder(
        itemCount: 10, // TODO: real chats
        itemBuilder: (context, index) => ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text('User \$index'),
          subtitle: const Text('Last message...'),
          trailing: const Text('14:30'),
          onTap: () {
            // Open chat room
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // New chat
        },
        child: const Icon(Icons.chat),
      ),
    );
  }
}

