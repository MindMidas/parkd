import 'message_delivery_status.dart';

// mirrors public.messages
class ChatMessageRow {
  const ChatMessageRow({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.message,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String message;
  final MessageDeliveryStatus status;
  final DateTime? createdAt;

  static ChatMessageRow fromJson(Map<String, dynamic> json) {
    return ChatMessageRow(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      message: json['message'] as String,
      status: MessageDeliveryStatus.fromWire(json['status'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}
