import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spillcity/core/theme/theme_provider.dart';
import 'settings_screen.dart';

// ════════════════════════════════════════════
//  MAIN SETTINGS SCREEN — Matches page.tsx
// ════════════════════════════════════════════
class ThemePage extends ConsumerWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeSettings = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    return SettingsSubPage(
      title: 'Theme Customization',
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Appearance Mode
          _buildGroupTitle('Appearance Mode', theme),
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.12),
                  width: 1.5),
            ),
            child: Column(
              children: [
                _buildModeItem(
                  label: 'Light Mode',
                  isSelected: themeSettings.themeMode == ThemeMode.light,
                  onTap: () => themeNotifier.setThemeMode(ThemeMode.light),
                  theme: theme,
                ),
                _buildModeItem(
                  label: 'Dark Mode',
                  isSelected: themeSettings.themeMode == ThemeMode.dark,
                  onTap: () => themeNotifier.setThemeMode(ThemeMode.dark),
                  theme: theme,
                ),
                _buildModeItem(
                  label: 'System Mode',
                  isSelected: themeSettings.themeMode == ThemeMode.system,
                  onTap: () => themeNotifier.setThemeMode(ThemeMode.system),
                  theme: theme,
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Premium Presets
          _buildGroupTitle('Premium Presets', theme),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.0,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              _buildPresetCard(
                title: 'Default Light',
                bgColor: const Color(0xFFF8FAFC),
                dotColor: const Color(0xFF2563EB),
                preset: ThemePreset.defaultLight,
                activePreset: themeSettings.themePreset,
                onTap: () =>
                    themeNotifier.setThemePreset(ThemePreset.defaultLight),
                theme: theme,
              ),
              _buildPresetCard(
                title: 'Default Dark',
                bgColor: const Color(0xFF0F172A),
                dotColor: const Color(0xFF3B82F6),
                preset: ThemePreset.defaultDark,
                activePreset: themeSettings.themePreset,
                onTap: () =>
                    themeNotifier.setThemePreset(ThemePreset.defaultDark),
                theme: theme,
              ),
              _buildPresetCard(
                title: 'OLED Black',
                bgColor: Colors.black,
                dotColor: const Color(0xFF3B82F6),
                preset: ThemePreset.oledBlack,
                activePreset: themeSettings.themePreset,
                onTap: () =>
                    themeNotifier.setThemePreset(ThemePreset.oledBlack),
                theme: theme,
              ),
              _buildPresetCard(
                title: 'Midnight',
                bgColor: const Color(0xFF020617),
                dotColor: const Color(0xFF818CF8),
                preset: ThemePreset.midnight,
                activePreset: themeSettings.themePreset,
                onTap: () =>
                    themeNotifier.setThemePreset(ThemePreset.midnight),
                theme: theme,
              ),
              _buildPresetCard(
                title: 'Rose Light',
                bgColor: const Color(0xFFFFF1F2),
                dotColor: const Color(0xFFE11D48),
                preset: ThemePreset.roseLight,
                activePreset: themeSettings.themePreset,
                onTap: () =>
                    themeNotifier.setThemePreset(ThemePreset.roseLight),
                theme: theme,
              ),
              _buildPresetCard(
                title: 'Rose Dark',
                bgColor: const Color(0xFF1E0B11),
                dotColor: const Color(0xFFF43F5E),
                preset: ThemePreset.roseDark,
                activePreset: themeSettings.themePreset,
                onTap: () =>
                    themeNotifier.setThemePreset(ThemePreset.roseDark),
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Footer note
          Center(
            child: Text(
              'Customizations are saved locally to your device.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildGroupTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildModeItem({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: theme.colorScheme.outline
                            .withValues(alpha: 0.08)))),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            if (isSelected)
              Icon(Icons.check,
                  color: theme.colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetCard({
    required String title,
    required Color bgColor,
    required Color dotColor,
    required ThemePreset preset,
    required ThemePreset activePreset,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    final isSelected = preset == activePreset;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.12),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 30,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2)),
              ),
              child: Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                )),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
//  ABOUT PAGE — Matches about/page.tsx
// ════════════════════════════════════════════
