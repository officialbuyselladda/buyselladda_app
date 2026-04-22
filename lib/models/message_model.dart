class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  
  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
  });
  
  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['_id'] ?? '',
    chatId: json['chatId'] ?? '',
    senderId: json['senderId'] ?? '',
    text: json['text'] ?? '',
    timestamp: DateTime.parse(json['timestamp']),
  );
}

