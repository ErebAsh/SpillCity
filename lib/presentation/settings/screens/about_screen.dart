import 'package:flutter/material.dart';
import 'settings_screen.dart';

// ════════════════════════════════════════════
//  MAIN SETTINGS SCREEN — Matches page.tsx
// ════════════════════════════════════════════
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final aboutItems = [
      {
        'icon': Icons.info_outline,
        'label': 'App Details',
        'sub': 'Story, features and uniqueness',
        'page': const _AppDetailsPage(),
      },
      {
        'icon': Icons.description_outlined,
        'label': 'Terms of Service',
        'sub': 'Read our usage guidelines',
        'page': const _TermsOfServicePage(),
      },
      {
        'icon': Icons.lock_outline,
        'label': 'Privacy Policy',
        'sub': 'How we handle your data',
        'page': const _PrivacyPolicyPage(),
      },
      {
        'icon': Icons.folder_outlined,
        'label': 'Open Source Licenses',
        'sub': 'Third-party software we use',
        'page': const _LicensesPage(),
      },
    ];

    return SettingsSubPage(
      title: 'About',
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.12),
                  width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: aboutItems.asMap().entries.map((entry) {
                final item = entry.value;
                final isLast = entry.key == aboutItems.length - 1;
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => item['page'] as Widget),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                    decoration: isLast
                        ? null
                        : BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    color: theme.colorScheme.outline
                                        .withValues(alpha: 0.08),
                                    width: 1.5)),
                          ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(item['icon'] as IconData,
                              size: 20,
                              color: theme.colorScheme.primary),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['label'] as String,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(item['sub'] as String,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.4),
                                  )),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            size: 18,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.3)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Text('Version 2.0.0 (Beta)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    )),
                const SizedBox(height: 4),
                Text('© 2026 SpillCity Team',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
//  APP DETAILS PAGE — Matches about/app-details/page.tsx
// ════════════════════════════════════════════
class _AppDetailsPage extends StatelessWidget {
  const _AppDetailsPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final features = [
      {
        'title': 'Real-time Updates',
        'desc': 'Instant notifications for college news and events.',
        'icon': Icons.notifications_active_outlined,
      },
      {
        'title': 'Vanish Mode',
        'desc': 'Keep your private conversations truly private.',
        'icon': Icons.visibility_off_outlined,
      },
      {
        'title': 'Community Driven',
        'desc': 'Built by students, for students, to keep everyone connected.',
        'icon': Icons.people_outline,
      },
      {
        'title': 'Premium UI',
        'desc': 'A modern, mobile-native experience designed for speed.',
        'icon': Icons.layers_outlined,
      },
    ];

    return SettingsSubPage(
      title: 'App Details',
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              'Discover the story of SpillCity, a platform developed during my college life, built to bridge the communication gap on campus.',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildStorySection(
            title: 'My Story',
            icon: Icons.book_outlined,
            theme: theme,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'In my college, I noticed a persistent problem: many students were failing to receive timely notifications about important news and events. Information was fragmented and often arrived too late.',
                  style: TextStyle(fontSize: 14.5, height: 1.5, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 14.5, height: 1.5, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                    children: const [
                      TextSpan(text: 'Recognizing this gap, '),
                      TextSpan(text: 'Himanshu Raj', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: ' decided to take action. I envisioned a platform that would not just deliver news, but would truly connect people.'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 14.5, height: 1.5, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                    children: const [
                      TextSpan(text: 'SpillCity', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: ' was born from this mission—to create a seamless, community-driven platform where every student stays updated and every voice can be heard.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildStorySection(
            title: 'Uniqueness & Features',
            icon: Icons.star_outline,
            theme: theme,
            content: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: features.map((f) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(f['icon'] as IconData, size: 18, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        f['title'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Expanded(
                        child: Text(
                          f['desc'] as String,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Text(
                  'v1.0.0 (Beta)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'A student-run project developed during college life with ❤️',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorySection({
    required String title,
    required IconData icon,
    required ThemeData theme,
    required Widget content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }
}

// ════════════════════════════════════════════
//  TERMS OF SERVICE PAGE — Matches about/terms/page.tsx
// ════════════════════════════════════════════
class _TermsOfServicePage extends StatelessWidget {
  const _TermsOfServicePage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final sections = [
      {
        'title': '1. Acceptance of Terms',
        'content': 'By accessing or using SpillCity, you agree to be bound by these Terms of Service. If you do not agree to all of these terms, do not use the application.'
      },
      {
        'title': '2. Eligibility',
        'content': 'You must be a student or faculty member of the associated college to use this platform. You are responsible for ensuring that your account information is accurate.'
      },
      {
        'title': '3. Community Guidelines',
        'content': 'SpillCity is built for positive community interaction. Harassment, hate speech, or the distribution of inappropriate content is strictly prohibited. Users found violating these guidelines may be banned permanently.'
      },
      {
        'title': '4. Privacy',
        'content': 'Your privacy is important to us. Please refer to our Privacy Policy for information on how we collect, use, and disclose information from our users.'
      },
      {
        'title': '5. Content Ownership',
        'content': 'You retain all rights to the content you post on SpillCity. By posting content, you grant SpillCity a non-exclusive, royalty-free license to display and distribute your content within the platform.'
      },
      {
        'title': '6. Limitation of Liability',
        'content': 'SpillCity is provided "as is" without any warranties. We are not responsible for any damages or losses resulting from your use of the platform.'
      },
      {
        'title': '7. Prohibited Activities',
        'content': 'You may not attempt to scrape, hack, or interfere with the proper functioning of SpillCity. Automated accounts or bots are strictly prohibited unless explicitly authorized.'
      },
      {
        'title': '8. Termination',
        'content': 'We reserve the right to suspend or terminate your account at our sole discretion, without notice, for conduct that we believe violates these Terms or is harmful to other users.'
      },
      {
        'title': '9. Changes to Terms',
        'content': 'We may update these terms from time to time. Your continued use of the platform after changes are posted constitutes your acceptance of the new terms.'
      }
    ];

    return SettingsSubPage(
      title: 'Terms of Service',
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              'Last updated: April 24, 2026. Please read these terms carefully before using our platform.',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...sections.map((sec) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sec['title']!,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sec['content']!,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Thank you for being a part of SpillCity.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
//  PRIVACY POLICY PAGE — Matches about/privacy/page.tsx
// ════════════════════════════════════════════
class _PrivacyPolicyPage extends StatelessWidget {
  const _PrivacyPolicyPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final sections = [
      {
        'title': '1. Information We Collect',
        'content': 'We collect information you provide directly to us when you create an account, such as your name, email address, and profile information. We also collect the content you post and your interactions with other users.'
      },
      {
        'title': '2. How We Use Your Information',
        'content': 'We use the information to provide, maintain, and improve our services, to communicate with you about updates, and to protect the security of our community.'
      },
      {
        'title': '3. Data Sharing',
        'content': 'We do not sell your personal data. We may share information with service providers who perform services for us, or when required by law.'
      },
      {
        'title': '4. Security',
        'content': 'We take reasonable measures to help protect your information from loss, theft, misuse, and unauthorized access. However, no internet transmission is ever completely secure.'
      },
      {
        'title': '5. Your Choices',
        'content': 'You can update your account information at any time through the settings page. You may also request to delete your account, which will remove your personal information from our active databases.'
      },
      {
        'title': '6. Cookies and Tracking',
        'content': 'We use cookies and similar technologies to remember your preferences, keep you logged in, and understand how you use our app. You can control these through your browser settings.'
      },
      {
        'title': '7. Data Retention',
        'content': 'We retain your personal information for as long as your account is active or as needed to provide you with services. If you delete your account, we will purge your personal data within 30 days.'
      },
      {
        'title': '8. Children\'s Privacy',
        'content': 'SpillCity is intended for college-aged users. We do not knowingly collect personal information from children under the age of 13. If we discover such data, we will delete it immediately.'
      }
    ];

    return SettingsSubPage(
      title: 'Privacy Policy',
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              'Your privacy matters to us. This policy explains how SpillCity handles your personal information.',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...sections.map((sec) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sec['title']!,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sec['content']!,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Last updated: April 24, 2026',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
//  LICENSES PAGE — Matches about/licenses/page.tsx
// ════════════════════════════════════════════
class _LicensesPage extends StatelessWidget {
  const _LicensesPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final licenses = [
      {
        'name': 'Flutter SDK',
        'version': '3.x.x',
        'license': 'BSD-3-Clause',
        'copyright': 'Copyright 2014 The Flutter Authors. All rights reserved.',
        'url': 'https://github.com/flutter/flutter'
      },
      {
        'name': 'Cupertino Icons',
        'version': '1.0.8',
        'license': 'MIT',
        'copyright': 'Copyright (c) 2020 The Flutter Authors. All rights reserved.',
        'url': 'https://github.com/flutter/packages'
      },
      {
        'name': 'Go Router',
        'version': '13.2.0',
        'license': 'BSD-3-Clause',
        'copyright': 'Copyright 2013 The Flutter Authors. All rights reserved.',
        'url': 'https://github.com/flutter/packages'
      },
      {
        'name': 'Flutter Riverpod',
        'version': '2.5.1',
        'license': 'MIT',
        'copyright': 'Copyright (c) 2020 Remi Rousselet',
        'url': 'https://github.com/rrousselGit/river_pod'
      },
      {
        'name': 'Riverpod Annotation',
        'version': '2.3.5',
        'license': 'MIT',
        'copyright': 'Copyright (c) 2020 Remi Rousselet',
        'url': 'https://github.com/rrousselGit/river_pod'
      },
      {
        'name': 'Supabase Flutter',
        'version': '2.6.0',
        'license': 'MIT',
        'copyright': 'Copyright (c) 2024 Supabase, Inc.',
        'url': 'https://github.com/supabase/supabase-flutter'
      },
      {
        'name': 'HTTP',
        'version': '1.2.1',
        'license': 'BSD-3-Clause',
        'copyright': 'Copyright 2014, the Dart project authors. All rights reserved.',
        'url': 'https://github.com/dart-lang/http'
      },
      {
        'name': 'Drift ORM',
        'version': '2.16.0',
        'license': 'MIT',
        'copyright': 'Copyright (c) 2019 Simon Binder',
        'url': 'https://github.com/simolus3/drift'
      },
      {
        'name': 'SQLite3 Flutter Libs',
        'version': '0.5.20',
        'license': 'MIT',
        'copyright': 'Copyright (c) 2020 Simon Binder',
        'url': 'https://github.com/simolus3/sqlite3.dart'
      },
      {
        'name': 'Path Provider',
        'version': '2.1.2',
        'license': 'BSD-3-Clause',
        'copyright': 'Copyright 2013 The Flutter Authors. All rights reserved.',
        'url': 'https://github.com/flutter/packages'
      },
      {
        'name': 'Path',
        'version': '1.9.0',
        'license': 'BSD-3-Clause',
        'copyright': 'Copyright 2014, the Dart project authors. All rights reserved.',
        'url': 'https://github.com/dart-lang/path'
      },
      {
        'name': 'Shared Preferences',
        'version': '2.2.3',
        'license': 'BSD-3-Clause',
        'copyright': 'Copyright 2013 The Flutter Authors. All rights reserved.',
        'url': 'https://github.com/flutter/packages'
      },
      {
        'name': 'Flutter Secure Storage',
        'version': '9.0.0',
        'license': 'BSD-3-Clause',
        'copyright': 'Copyright (c) 2018 Germanus One',
        'url': 'https://github.com/mogol/flutter_secure_storage'
      },
      {
        'name': 'Agora RTC Engine',
        'version': '6.3.0',
        'license': 'MIT',
        'copyright': 'Copyright (c) 2024 Agora.io',
        'url': 'https://github.com/AgoraIO/Flutter-SDK'
      },
      {
        'name': 'Pusher Channels Flutter',
        'version': '2.2.0',
        'license': 'MIT',
        'copyright': 'Copyright (c) 2022 Pusher',
        'url': 'https://github.com/pusher/pusher-channels-flutter'
      },
      {
        'name': 'Permission Handler',
        'version': '11.3.1',
        'license': 'MIT',
        'copyright': 'Copyright (c) 2018 Baseflow',
        'url': 'https://github.com/Baseflow/flutter-permission-handler'
      },
      {
        'name': 'Cached Network Image',
        'version': '3.3.1',
        'license': 'MIT',
        'copyright': 'Copyright (c) 2018 Rene Floor',
        'url': 'https://github.com/Baseflow/flutter_cached_network_image'
      },
      {
        'name': 'Image Picker',
        'version': '1.1.1',
        'license': 'BSD-3-Clause',
        'copyright': 'Copyright 2013 The Flutter Authors. All rights reserved.',
        'url': 'https://github.com/flutter/packages'
      },
      {
        'name': 'Flutter SVG',
        'version': '2.0.10',
        'license': 'MIT',
        'copyright': 'Copyright (c) 2018 Dan Field',
        'url': 'https://github.com/dnfield/flutter_svg'
      },
      {
        'name': 'Record',
        'version': '6.2.1',
        'license': 'MIT',
        'copyright': 'Copyright (c) 2021 Alexandre Roux',
        'url': 'https://github.com/llfbandit/record'
      },
      {
        'name': 'Audioplayers',
        'version': '6.7.1',
        'license': 'MIT',
        'copyright': 'Copyright (c) 2024 Blue Fire',
        'url': 'https://github.com/bluefireteam/audioplayers'
      }
    ];

    return SettingsSubPage(
      title: 'Licenses',
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              'SpillCity is built with the help of several amazing open source projects. Below are the licenses for the major libraries used in this application.',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.12),
                  width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: licenses.asMap().entries.map((entry) {
                final lib = entry.value;
                final isLast = entry.key == licenses.length - 1;

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: isLast
                      ? null
                      : BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                                  color: theme.colorScheme.outline
                                      .withValues(alpha: 0.08)))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              children: [
                                TextSpan(text: lib['name']!),
                                const TextSpan(text: ' '),
                                TextSpan(
                                  text: lib['version']!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.normal,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              lib['license']!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lib['copyright']!,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lib['url']!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Handcrafted with respect for the open source community.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
//  FEEDBACK PAGE — Matches feedback modal in page.tsx
// ════════════════════════════════════════════
