import 'package:flutter/material.dart';

// ─── Format Time Utility ───
class MediaLightbox extends StatelessWidget {
  final String url;
  final String sender;
  final String time;
  final String mediaType;

  const MediaLightbox({super.key, 
    required this.url,
    required this.sender,
    required this.time,
    required this.mediaType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sender, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            Text(time, style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'forward') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Forward coming soon!')),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'forward', child: Text('Forward')),
              const PopupMenuItem(value: 'download', child: Text('Download')),
            ],
          ),
        ],
      ),
      body: Center(
        child: mediaType == 'image'
            ? InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_circle_outline, color: Colors.white, size: 80),
                  const SizedBox(height: 16),
                  const Text('Video playback requires video_player package', style: TextStyle(color: Colors.white54)),
                ],
              ),
      ),
    );
  }
}

// ════════════════════════════════════════════
//  STORY CREATION SHEET
// ════════════════════════════════════════════

