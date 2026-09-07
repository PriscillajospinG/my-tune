import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../providers/player_provider.dart';
import '../utils/constants.dart';
import 'mini_player.dart';

/// Navigation destinations definition
const _navItems = [
  _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home', route: '/home'),
  _NavItem(icon: Icons.library_music_outlined, activeIcon: Icons.library_music_rounded, label: 'Library', route: '/library'),
  _NavItem(icon: Icons.search_outlined, activeIcon: Icons.search_rounded, label: 'Search', route: '/search'),
  _NavItem(icon: Icons.queue_music_outlined, activeIcon: Icons.queue_music_rounded, label: 'Playlists', route: '/playlists'),
  _NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: 'Settings', route: '/settings'),
];

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}

/// The main shell that wraps all tab screens with a bottom nav + mini-player.
class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final player = ref.watch(playerProvider);
    final hasSong = player.currentSong != null;

    int _selectedIndex = _navItems.indexWhere((item) => location.startsWith(item.route));
    if (_selectedIndex < 0) _selectedIndex = 0;

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgModal,
          border: Border(
            top: BorderSide(color: AppTheme.divider, width: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasSong) ...[
              const SizedBox(height: 8),
              const MiniPlayer(),
              const SizedBox(height: 4),
            ],
            NavigationBar(
              backgroundColor: Colors.transparent,
              indicatorColor: AppTheme.primary.withValues(alpha: 0.15),
              selectedIndex: _selectedIndex,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              height: AppConstants.bottomNavHeight + 10,
              onDestinationSelected: (i) {
                context.go(_navItems[i].route);
              },
              destinations: _navItems.map((item) {
                final isSelected = _navItems.indexOf(item) == _selectedIndex;
                return NavigationDestination(
                  icon: Icon(item.icon,
                      color: AppTheme.iconInactive, size: 22),
                  selectedIcon: Icon(item.activeIcon,
                      color: AppTheme.primary, size: 22),
                  label: item.label,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
