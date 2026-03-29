class ChatMessage {
  final int userId;
  final String userName;
  final String message;
  final DateTime time;

  ChatMessage({required this.userId, required this.userName, required this.message, required this.time});
}