import 'package:flutter/material.dart';

String formatMessageTime(String timeStr) {
  try {
    final dt = DateTime.parse(timeStr).toLocal();
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $ampm';
  } catch (_) {
    return '';
  }
}

LinearGradient parseHtmlGradient(String css) {
  // basic mock for gradient parsing
  return const LinearGradient(colors: [Colors.purple, Colors.blue]);
}

const List<String> emojiList = [
  '😀', '😂', '🥺', '😭', '😍', '🥰', '😊', '🙏', '✨', '🔥', '👍', '❤️'
];

const List<String> storyGradients = [
  'linear-gradient(45deg, #FF6B6B, #FFE66D)',
  'linear-gradient(45deg, #845EC2, #D65DB1, #FF9671)',
  'linear-gradient(45deg, #00C9FF, #92FE9D)',
  'linear-gradient(45deg, #F37335, #FDC830)',
];
