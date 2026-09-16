import 'package:spillcity/data/database/local_db.dart';

class MessageModel {
  final String id;
  final String? conversationId;
  final String? senderId;
  final String text;
  final String? type; // 'text', 'image', 'heart', 'voice', 'video', 'file'
  final String timestamp;
  final String status; // 'sent', 'pending', 'failed'
  final String? tempId;
  final String? attachment;
  final String? localAttachment;

  MessageModel({
    required this.id,
    this.conversationId,
    this.senderId,
    required this.text,
    this.type = 'text',
    required this.timestamp,
    this.status = 'sent',
    this.tempId,
    this.attachment,
    this.localAttachment,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: (json['id'] as String?) ?? (json['tempId'] as String?) ?? '',
      conversationId: json['conversationId'] as String? ?? json['conversation_id'] as String?,
      senderId: json['senderId'] as String? ?? json['sender_id'] as String?,
      text: json['text'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      status: json['status'] as String? ?? 'sent',
      tempId: json['tempId'] as String? ?? json['temp_id'] as String?,
      attachment: json['attachment'] as String?,
      localAttachment: json['localAttachment'] as String? ?? json['local_attachment'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'text': text,
      'type': type,
      'timestamp': timestamp,
      'status': status,
      'tempId': tempId,
      'attachment': attachment,
      'localAttachment': localAttachment,
    };
  }

  // Convert to Drift LocalMessage object
  LocalMessage toDrift() {
    return LocalMessage(
      id: id.isNotEmpty ? id : (tempId ?? ''),
      conversationId: conversationId,
      senderId: senderId,
      textContent: text,
      type: type,
      timestamp: timestamp,
      status: status,
      tempId: tempId,
      attachment: attachment,
      localAttachment: localAttachment,
    );
  }

  // Create from Drift LocalMessage object
  factory MessageModel.fromDrift(LocalMessage msg) {
    return MessageModel(
      id: msg.id,
      conversationId: msg.conversationId,
      senderId: msg.senderId,
      text: msg.textContent,
      type: msg.type,
      timestamp: msg.timestamp ?? '',
      status: msg.status ?? 'sent',
      tempId: msg.tempId,
      attachment: msg.attachment,
      localAttachment: msg.localAttachment,
    );
  }
}
