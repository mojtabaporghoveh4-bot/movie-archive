import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../archive.dart';
import '../models.dart';
import '../widgets.dart';
import 'edit.dart';
import 'library.dart';
import 'lookup.dart';

class DetailPage extends StatelessWidget {
  final Movie movie;
  const DetailPage(this.movie, {super.key});

  Future<void> _refresh(BuildContext context) async {
    final ok = await withProgress(context, 'Updating info', (_) async {
      final ok = await archive.fetchInfo(movie);
      await archive.save();
      return ok;
    });
    if (ok == false && context.mounted) toast(context, 'No match found. Try "Change match".');
  }

  Future<void> _delete(BuildContext context) async {
    final onDisk = movie.driveId != null;
    if (!await confirm(
        context,
        'Remove from archive?',
        onDisk
            ? '"${movie.title}" will be removed from the list. The file on the drive is NOT deleted, and it comes back if you scan the drive again.'
            : '"${movie.title}" will be removed from the list.',
        ok: 'Remove')) {
      return;
    }
    await archive.remove(movie);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: archive,
        builder: (context, _) {
          final m = movie;
          final t = Theme.of(context).textTheme;
          final scheme = Theme.of(context).colorScheme;
          final wide = MediaQuery.sizeOf(context).width >= 700;
          final full = archive.fullPath(m);

          Widget section(String label, Facet facet, List<String> values) => values.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: t.labelLarge?.copyWith(color: scheme.outline)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final v in values)
                        ActionChip(
                          label: Text(v),
                          onPressed: () => Navigator.push(
                              context, MaterialPageRoute(builder: (_) => LibraryPage(facet: facet, value: v))),
                        ),
                    ]),
                  ]),
                );

          final facts = [
            if (m.year != null) '${m.year}',
            if (m.runtime != null && m.runtime! > 0) '${m.runtime! ~/ 60}h ${m.runtime! % 60}m',
            if (m.language != null) m.language!,
            if (m.rating != null && m.rating! > 0) '★ ${m.rating!.toStringAsFixed(1)}',
          ];

          final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.title, style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
            if (m.originalTitle != null && m.originalTitle != m.title)
              Text(m.originalTitle!, style: t.titleMedium?.copyWith(color: scheme.outline)),
            const SizedBox(height: 8),
            Text(facts.join('   ·   '), style: t.titleSmall),
            if (m.overview?.isNotEmpty ?? false) ...[
              const SizedBox(height: 16),
              Text(m.overview!, style: t.bodyLarge),
            ],
            section('Director', Facet.director, m.directors),
            section('Cast', Facet.actor, m.cast),
            section('Genre', Facet.genre, m.genres),
            section('Sub-genre', Facet.subGenre, [if (m.subGenre != null) m.subGenre!]),
            section('Collection', Facet.collection, [if (m.collection != null) m.collection!]),
            section('Country', Facet.country, m.countries),
            section('My tags', Facet.tag, m.tags),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _row(context, Icons.storage_outlined, 'Drive', archive.driveName(m)),
                  if (m.path != null) _row(context, Icons.insert_drive_file_outlined, 'File', m.path!),
                  if (m.sizeBytes != null) _row(context, Icons.data_usage, 'Size', formatSize(m.sizeBytes!)),
                  if (m.imdbId != null) _row(context, Icons.tag, 'IMDb ID', m.imdbId!),
                  if (m.notes?.isNotEmpty ?? false) _row(context, Icons.notes, 'Notes', m.notes!),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilterChip(
                label: const Text('Watched'),
                selected: m.watched,
                onSelected: (v) {
                  m.watched = v;
                  archive.save();
                },
              ),
              if (m.imdbId != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('IMDb'),
                  onPressed: () => launchUrl(Uri.parse('https://www.imdb.com/title/${m.imdbId}/')),
                ),
              if (isDesktop && full != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.folder_open_outlined, size: 18),
                  label: const Text('Open folder'),
                  onPressed: () async {
                    if (!await File(full).exists()) {
                      if (context.mounted) toast(context, 'Drive "${archive.driveName(m)}" is not connected.');
                      return;
                    }
                    Process.run('explorer', ['/select,', p.normalize(full)]);
                  },
                ),
            ]),
          ]);

          return Scaffold(
            appBar: AppBar(actions: [
              IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditPage(m)))),
              PopupMenuButton<String>(
                onSelected: (v) => switch (v) {
                  'refresh' => _refresh(context),
                  'match' => Navigator.push(context, MaterialPageRoute(builder: (_) => LookupPage(forMovie: m))),
                  _ => _delete(context),
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'refresh', child: ListTile(leading: Icon(Icons.refresh), title: Text('Update info'))),
                  PopupMenuItem(
                      value: 'match', child: ListTile(leading: Icon(Icons.find_replace), title: Text('Change match'))),
                  PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Remove'))),
                ],
              ),
              const SizedBox(width: 8),
            ]),
            body: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: wide
                      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(width: 300, child: Poster(m, radius: 14)),
                          const SizedBox(width: 32),
                          Expanded(child: info),
                        ])
                      : Column(children: [
                          Center(child: SizedBox(width: 220, child: Poster(m, radius: 14))),
                          const SizedBox(height: 20),
                          info,
                        ]),
                ),
              ),
            ),
          );
        },
      );

  Widget _row(BuildContext context, IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 10),
          SizedBox(width: 70, child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.outline))),
          Expanded(child: SelectableText(value)),
        ]),
      );
}
