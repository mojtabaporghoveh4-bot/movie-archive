import 'package:flutter/material.dart';

import '../archive.dart';
import '../widgets.dart';
import 'library.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Stats')),
        body: ListenableBuilder(
          listenable: archive,
          builder: (context, _) {
            final all = archive.movies;
            if (all.isEmpty) {
              return const EmptyState(Icons.insights_outlined, 'Nothing to show yet', 'Add movies to see stats about your archive.');
            }
            final size = all.fold<int>(0, (s, m) => s + (m.sizeBytes ?? 0));
            final minutes = all.fold<int>(0, (s, m) => s + (m.runtime ?? 0));
            final rated = all.where((m) => m.score != null);
            final avg = rated.isEmpty ? 0 : rated.fold<double>(0, (s, m) => s + m.score!) / rated.length;
            final watched = all.where((m) => m.watched).length;
            final tiles = [
              ('Movies', '${all.length}', Icons.movie_outlined),
              ('Storage', formatSize(size), Icons.storage_outlined),
              ('Watch time', '${minutes ~/ 60} h', Icons.schedule),
              ('Avg. rating', avg.toStringAsFixed(1), Icons.star_outline),
              ('Watched', '$watched', Icons.visibility_outlined),
              ('Drives', '${archive.drives.length}', Icons.storage),
            ];
            return ListView(padding: const EdgeInsets.all(16), children: [
              Wrap(spacing: 12, runSpacing: 12, children: [
                for (final (label, value, icon) in tiles)
                  SizedBox(
                    width: 160,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(icon, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 10),
                          Text(value, style: Theme.of(context).textTheme.headlineSmall),
                          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                        ]),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 8),
              LayoutBuilder(builder: (context, box) {
                final cols = box.maxWidth >= 900 ? 2 : 1;
                final w = (box.maxWidth - (cols - 1) * 12) / cols;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  for (final (f, n) in [
                    (Facet.decade, 12),
                    (Facet.genre, 12),
                    (Facet.language, 10),
                    (Facet.director, 10),
                    (Facet.actor, 10),
                    (Facet.country, 10),
                    (Facet.collection, 10),
                    (Facet.drive, 10),
                  ])
                    SizedBox(width: w, child: _Bars(f, n)),
                ]);
              }),
            ]);
          },
        ),
      );
}

/// Horizontal bar chart of the top values of a category. Tap a bar to see those movies.
class _Bars extends StatelessWidget {
  final Facet facet;
  final int top;
  const _Bars(this.facet, this.top);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    var data = archive.counts(facet);
    if (facet != Facet.decade) data = data.take(top).toList();
    if (data.isEmpty) return const SizedBox.shrink();
    final max = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(facet == Facet.decade ? 'By decade' : 'Top ${facet.plural.toLowerCase()}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final e in data)
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => LibraryPage(facet: facet, value: e.key))),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(width: 130, child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: e.value / max,
                        minHeight: 14,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  SizedBox(width: 44, child: Text('${e.value}', textAlign: TextAlign.right)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
