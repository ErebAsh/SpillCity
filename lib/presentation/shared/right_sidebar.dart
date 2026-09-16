import 'package:flutter/material.dart';

class RightSidebar extends StatelessWidget {
  const RightSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Mock Trending topics
    final trendingList = [
      {'tag': '#CollegeFest2026', 'posts': '1,240'},
      {'tag': '#ExamScheduleOut', 'posts': '850'},
      {'tag': '#HackathonResults', 'posts': '532'},
      {'tag': '#PlacementsReport', 'posts': '418'},
    ];

    // Mock Announcements with dynamic styles
    final announcementsList = [
      {
        'text': 'Library timings extended up to 10 PM for the upcoming exams.',
        'timeAgo': '2h ago',
        'type': 'info',
        'color': Colors.blue
      },
      {
        'text': 'Urgent: Maintenance downtime scheduled for college Wi-Fi tonight at 12 AM.',
        'timeAgo': '5h ago',
        'type': 'alert',
        'color': Colors.red
      },
      {
        'text': 'Submit academic registration forms before Friday to avoid late fees.',
        'timeAgo': '1d ago',
        'type': 'warning',
        'color': Colors.amber
      },
    ];

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          left: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Trending section
            const Row(
              children: [
                Text(
                  '🔥 Trending',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                Text(
                  'See all',
                  style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...trendingList.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final topic = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '$idx',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topic['tag']!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${topic['posts']} posts',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            // 2. Announcements Section
            const Text(
              '📣 Announcements',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...announcementsList.map((ann) {
              final color = ann['color'] as Color;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border(
                      left: BorderSide(color: color, width: 3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ann['text'] as String,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ann['timeAgo'] as String,
                        style: const TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            // 3. Footer Section
            Wrap(
              spacing: 12,
              children: ['About', 'Help', 'Privacy', 'Terms', 'Contact']
                  .map((link) => Text(
                        link,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            const Text(
              '© 2026 SpillCity',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
