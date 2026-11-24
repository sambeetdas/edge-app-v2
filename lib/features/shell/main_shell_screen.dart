import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../chat/chat_list_screen.dart';
import '../document_qa/document_qa_screen.dart';
import '../image_qa/image_qa_screen.dart';
import '../settings/settings_screen.dart';
import '../skills/skills_screen.dart';

class _ShellTab {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;

  const _ShellTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });
}

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final modelAsync = ref.watch(downloadedModelProvider);
    final tier = ref.watch(activeModelTierProvider);
    final hasModel = modelAsync.value != null && tier != null;

    final tabs = <_ShellTab>[
      if (hasModel) ...[
        const _ShellTab(
          label: 'Chats',
          icon: Icons.chat_bubble_outline_rounded,
          selectedIcon: Icons.chat_bubble_rounded,
          page: ChatListScreen(),
        ),
        if (tier.supportsDocumentQa)
          const _ShellTab(
            label: 'Knowledge',
            icon: Icons.library_books_outlined,
            selectedIcon: Icons.library_books_rounded,
            page: DocumentQaScreen(),
          ),
        const _ShellTab(
          label: 'Scan',
          icon: Icons.document_scanner_outlined,
          selectedIcon: Icons.document_scanner_rounded,
          page: ImageQaScreen(),
        ),
        const _ShellTab(
          label: 'Skills',
          icon: Icons.auto_awesome_outlined,
          selectedIcon: Icons.auto_awesome_rounded,
          page: SkillsScreen(),
        ),
      ],
      const _ShellTab(
        label: 'Settings',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings_rounded,
        page: SettingsScreen(),
      ),
    ];

    final safeIndex = _selectedIndex.clamp(0, tabs.length - 1);

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: tabs.map((t) => t.page).toList(),
      ),
      bottomNavigationBar: tabs.length <= 1
          ? null
          : NavigationBar(
              selectedIndex: safeIndex,
              onDestinationSelected: (idx) {
                setState(() => _selectedIndex = idx);
              },
              destinations: tabs
                  .map(
                    (t) => NavigationDestination(
                      icon: Icon(t.icon),
                      selectedIcon: Icon(t.selectedIcon),
                      label: t.label,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}
