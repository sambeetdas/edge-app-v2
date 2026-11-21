import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/games_service.dart';
import '../../providers/app_providers.dart';

class GamesScreen extends ConsumerStatefulWidget {
  const GamesScreen({super.key});

  @override
  ConsumerState<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends ConsumerState<GamesScreen> {
  List<GameDefinition> _customGames = [];
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadCustom();
  }

  Future<void> _loadCustom() async {
    final custom = await ref.read(gamesServiceProvider).getCustomGames();
    if (!mounted) return;
    setState(() => _customGames = custom);
  }

  Future<void> _confirmDelete(GameDefinition game) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${game.name}"?'),
        content: const Text('This custom game will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(gamesServiceProvider).deleteCustomGame(game.id);
      _loadCustom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = [...GamesService.builtInGames, ..._customGames];
    final categories = ['All', ...{for (final g in all) g.category}];
    final filtered = _selectedCategory == 'All'
        ? all
        : all.where((g) => g.category == _selectedCategory).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('AI Games')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = categories[i];
                return ChoiceChip(
                  label: Text(cat),
                  selected: _selectedCategory == cat,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final game = filtered[i];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        game.icon,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            game.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            game.category,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        game.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    onTap: () => context.push('/games/play/${game.id}'),
                    onLongPress:
                        game.isBuiltIn ? null : () => _confirmDelete(game),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_create_game',
        onPressed: () async {
          await context.push('/games/create');
          _loadCustom();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Game'),
      ),
    );
  }
}
