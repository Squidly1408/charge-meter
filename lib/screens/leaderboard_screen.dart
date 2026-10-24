import 'package:flutter/material.dart';

import '../services/rating.dart';
import '../services/results_store.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, required this.store, required this.revision});
  final ResultsStore store;

  /// Bumped by the parent whenever a new result is saved.
  final int revision;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<List<CableResult>> _future = widget.store.load();

  @override
  void didUpdateWidget(covariant LeaderboardScreen old) {
    super.didUpdateWidget(old);
    if (old.revision != widget.revision) _reload();
  }

  void _reload() => setState(() => _future = widget.store.load());

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear leaderboard?'),
        content: const Text('All saved cable results will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.clear();
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<CableResult>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data!;
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.emoji_events_outlined,
                    size: 64, color: theme.colorScheme.outline),
                const SizedBox(height: 12),
                Text('No cables tested yet',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('Run "Test this cable" to start comparing.',
                    style: theme.textTheme.bodyMedium),
              ]),
            ),
          );
        }
        final best = items.first.score;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(children: [
              Text('Leaderboard', style: theme.textTheme.headlineSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: _confirmClear,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Clear'),
              ),
            ]),
            const SizedBox(height: 8),
            for (final (i, r) in items.indexed)
              Dismissible(
                key: ValueKey(r.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  color: theme.colorScheme.errorContainer,
                  child: const Icon(Icons.delete_outline),
                ),
                onDismissed: (_) async {
                  await widget.store.remove(r.id);
                  _reload();
                },
                child: _Row(rank: i + 1, result: r, best: best),
              ),
            const SizedBox(height: 8),
            Text('Swipe left to delete. Ranked by average watts '
                '(or %/min on iOS).',
                textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          ],
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.rank, required this.result, required this.best});
  final int rank;
  final CableResult result;
  final double best;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strength = result.isElectrical
        ? strengthFromWatts(result.avgWatts)
        : strengthFromPercentPerMin(result.percentPerMin);
    final value = result.isElectrical
        ? '${result.avgWatts!.toStringAsFixed(1)} W'
        : result.percentPerMin == null
            ? '--'
            : '${result.percentPerMin!.toStringAsFixed(2)} %/min';
    final sub = result.isElectrical
        ? '${result.avgCurrentMa?.toStringAsFixed(0) ?? '--'} mA - '
            '${result.avgVoltageV?.toStringAsFixed(2) ?? '--'} V - ${result.plug}'
        : '${result.durationSec ~/ 60} min test - estimate';
    final d = result.date;
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: rank == 1
                  ? const Color(0xFFFFC53D)
                  : theme.colorScheme.secondaryContainer,
              child: Text('$rank',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: rank == 1
                          ? Colors.black
                          : theme.colorScheme.onSecondaryContainer)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.name,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis),
                  Text('$sub - ${d.day}/${d.month}/${d.year}',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(value,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(strength.label,
                  style: TextStyle(color: strength.color, fontSize: 12)),
            ]),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: best <= 0 ? 0 : (result.score / best).clamp(0.0, 1.0),
              minHeight: 6,
              color: strength.color,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ]),
      ),
    );
  }
}
