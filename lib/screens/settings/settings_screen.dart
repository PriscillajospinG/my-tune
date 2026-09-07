import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _dbSize = 'Calculating…';
  final String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  Future<void> _loadStorageInfo() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbFile = File('${dir.path}/mytune_db.isar');
      if (await dbFile.exists()) {
        final bytes = await dbFile.length();
        final kb = bytes / 1024;
        setState(() =>
            _dbSize = kb < 1024 ? '${kb.toStringAsFixed(1)} KB' : '${(kb / 1024).toStringAsFixed(2)} MB');
      } else {
        setState(() => _dbSize = '< 1 KB');
      }
    } catch (_) {
      setState(() => _dbSize = 'Unknown');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: AppTheme.bgDeep,
              title: const Text(
                'Settings',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate([
                // ── Appearance ──────────────────────────────────────
                _sectionHeader('Appearance'),
                _SettingsTile(
                  icon: Icons.dark_mode_rounded,
                  iconColor: AppTheme.primary,
                  title: 'Theme',
                  subtitle: 'Dark (default)',
                  trailing: const Icon(Icons.chevron_right,
                      color: AppTheme.textMuted),
                  onTap: () => _showThemeDialog(context),
                ),
                _SettingsTile(
                  icon: Icons.color_lens_rounded,
                  iconColor: AppTheme.accent,
                  title: 'Accent Color',
                  subtitle: 'Violet',
                  trailing: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primary,
                    ),
                  ),
                  onTap: () {},
                ),

                // ── Audio ────────────────────────────────────────────
                _sectionHeader('Audio'),
                _SettingsTile(
                  icon: Icons.equalizer_rounded,
                  iconColor: AppTheme.accentWarm,
                  title: 'Equalizer',
                  subtitle: 'Coming soon',
                  trailing:
                      const Icon(Icons.lock_outline, color: AppTheme.textMuted, size: 18),
                  onTap: () => _showComingSoon(context, 'Equalizer'),
                ),
                _SettingsTile(
                  icon: Icons.speed_rounded,
                  iconColor: Color(0xFF4CAF50),
                  title: 'Playback Speed',
                  subtitle: '1.0× (default)',
                  trailing:
                      const Icon(Icons.lock_outline, color: AppTheme.textMuted, size: 18),
                  onTap: () => _showComingSoon(context, 'Playback Speed'),
                ),
                _SettingsTile(
                  icon: Icons.bluetooth_audio_rounded,
                  iconColor: Color(0xFF2196F3),
                  title: 'Bluetooth Controls',
                  subtitle: 'Enabled via system',
                  trailing: const Icon(Icons.check_circle,
                      color: Color(0xFF4CAF50), size: 20),
                  onTap: null,
                ),

                // ── Storage ──────────────────────────────────────────
                _sectionHeader('Storage'),
                _SettingsTile(
                  icon: Icons.storage_rounded,
                  iconColor: Color(0xFF9C27B0),
                  title: 'Database Size',
                  subtitle: _dbSize,
                  onTap: _loadStorageInfo,
                ),
                _SettingsTile(
                  icon: Icons.folder_open_rounded,
                  iconColor: Color(0xFFFF9800),
                  title: 'Import Music',
                  subtitle: 'Add files from your device',
                  trailing: const Icon(Icons.add, color: AppTheme.primary),
                  onTap: () {},
                ),

                // ── About ────────────────────────────────────────────
                _sectionHeader('About'),
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  iconColor: AppTheme.textSecondary,
                  title: 'Version',
                  subtitle: _appVersion,
                  onTap: null,
                ),
                _SettingsTile(
                  icon: Icons.music_note_rounded,
                  iconColor: AppTheme.primary,
                  title: 'MyTune',
                  subtitle: 'A clean, local music player. No ads. No accounts.',
                  onTap: null,
                ),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  iconColor: AppTheme.textSecondary,
                  title: 'Privacy',
                  subtitle: 'All data stays on your device',
                  onTap: null,
                ),

                const SizedBox(height: 120),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgModal,
        title: const Text('Choose Theme',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _themeOption('Dark', true),
            _themeOption('AMOLED Black', false),
            _themeOption('Dark + Blue Accent', false),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close',
                style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _themeOption(String name, bool selected) {
    return ListTile(
      title: Text(name,
          style: const TextStyle(color: AppTheme.textPrimary)),
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppTheme.primary)
          : null,
      onTap: () {},
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$feature coming in a future update'),
      backgroundColor: AppTheme.bgCard,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ─── Settings Tile ────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
