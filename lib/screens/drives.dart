import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../archive.dart';
import '../models.dart';
import '../widgets.dart';
import 'library.dart';

class DrivesPage extends StatelessWidget {
  const DrivesPage({super.key});

  Future<void> _scan(BuildContext context, {Drive? drive, bool newFolder = false}) async {
    var root = drive?.root;
    if (drive == null || newFolder || !await Directory(root!).exists()) {
      if (drive != null && !newFolder && context.mounted) {
        toast(context, 'The old folder is not connected. Pick where "${drive.name}" is now.');
      }
      root = await FilePicker.getDirectoryPath(dialogTitle: 'Pick the drive or folder with your movies');
      if (root == null) return;
    }
    if (!context.mounted) return;
    String? name;
    if (drive == null) {
      name = await askText(context, 'Name this drive', initial: '', hint: 'e.g. WD Blue 2TB');
      if (name == null || name.isEmpty) return;
    }
    if (!context.mounted) return;
    final r = await withProgress(context, 'Scanning ${drive?.name ?? name}',
        (update) => archive.scan(root!, drive: drive, name: name, onProgress: (n) => update('Found $n video files…')));
    if (r == null || !context.mounted) return;
    final (added, removed) = r;
    toast(context, 'Done: $added new, $removed no longer there.');
    if (added > 0 && archive.tmdb != null && await confirm(context, 'Find info and posters?',
        'Look up the $added new movies online (title, director, cast, genre, poster…)?', ok: 'Find info')) {
      if (!context.mounted) return;
      final todo = archive.movies.where((m) => !m.matched && m.driveId == (drive?.id ?? archive.drives.last.id)).toList();
      await withProgress(context, 'Finding movie info', (update) => archive.fetchMany(todo, update));
    }
  }

  Future<void> _rename(BuildContext context, Drive d) async {
    final name = await askText(context, 'Rename drive', initial: d.name);
    if (name == null || name.isEmpty) return;
    d.name = name;
    await archive.save();
  }

  Future<void> _remove(BuildContext context, Drive d) async {
    if (await confirm(context, 'Remove "${d.name}"?',
        'Its movies are removed from the archive. Nothing on the drive is deleted.', ok: 'Remove')) {
      await archive.removeDrive(d);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: archive,
        builder: (context, _) {
          final scheme = Theme.of(context).colorScheme;
          final manual = archive.movies.where((m) => m.driveId == null).length;
          return Scaffold(
            appBar: AppBar(title: const Text('Drives')),
            floatingActionButton: isDesktop
                ? FloatingActionButton.extended(
                    onPressed: () => _scan(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Scan a drive'),
                  )
                : null,
            body: archive.drives.isEmpty && manual == 0
                ? EmptyState(
                    Icons.storage_outlined,
                    'No drives yet',
                    isDesktop
                        ? 'Scan a hard drive or folder. Each drive gets its own list, and the Library shows them all together.'
                        : 'Drives are scanned on your computer. Import the archive file in Settings to see them here.',
                  )
                : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 88), children: [
                    for (final d in archive.drives) _card(context, d, scheme),
                    if (manual > 0)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.edit_note),
                          title: const Text('Added by hand'),
                          subtitle: Text('$manual movies'),
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const LibraryPage(facet: Facet.drive, value: 'Added by hand'))),
                        ),
                      ),
                  ]),
          );
        },
      );

  Widget _card(BuildContext context, Drive d, ColorScheme scheme) {
    final list = archive.movies.where((m) => m.driveId == d.id);
    final size = list.fold<int>(0, (s, m) => s + (m.sizeBytes ?? 0));
    final online = isDesktop && Directory(d.root).existsSync();
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        leading: CircleAvatar(
          backgroundColor: online ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          child: Icon(Icons.storage, color: online ? scheme.onPrimaryContainer : scheme.outline),
        ),
        title: Text(d.name),
        subtitle: Text([
          '${list.length} movies · ${formatSize(size)}',
          if (isDesktop) online ? 'Connected · ${d.root}' : 'Not connected',
          if (d.scannedAt != null) 'Scanned ${d.scannedAt!.toLocal().toString().substring(0, 16)}',
        ].join('\n')),
        isThreeLine: true,
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => LibraryPage(facet: Facet.drive, value: d.name))),
        trailing: PopupMenuButton<String>(
          onSelected: (v) => switch (v) {
            'rescan' => _scan(context, drive: d),
            'move' => _scan(context, drive: d, newFolder: true),
            'rename' => _rename(context, d),
            'organize' => showDialog(context: context, builder: (_) => OrganizeDialog(d)),
            _ => _remove(context, d),
          },
          itemBuilder: (_) => [
            if (isDesktop) ...const [
              PopupMenuItem(value: 'rescan', child: ListTile(leading: Icon(Icons.refresh), title: Text('Scan again'))),
              PopupMenuItem(
                  value: 'move', child: ListTile(leading: Icon(Icons.drive_file_move_outline), title: Text('Scan from another folder'))),
              PopupMenuItem(
                  value: 'organize', child: ListTile(leading: Icon(Icons.account_tree_outlined), title: Text('Organize folders'))),
            ],
            const PopupMenuItem(value: 'rename', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Rename'))),
            const PopupMenuItem(value: 'remove', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Remove'))),
          ],
        ),
      ),
    );
  }
}

class OrganizeDialog extends StatefulWidget {
  final Drive drive;
  const OrganizeDialog(this.drive, {super.key});
  @override
  State<OrganizeDialog> createState() => _OrganizeDialogState();
}

class _OrganizeDialogState extends State<OrganizeDialog> {
  Facet facet = Facet.director;
  String? target;
  bool move = false;

  static const _facets = [
    Facet.director, Facet.actor, Facet.year, Facet.decade, Facet.genre, Facet.subGenre, Facet.collection, Facet.language,
    Facet.country,
  ];

  Future<void> _run() async {
    final r = await withProgress(context, 'Organizing', (update) {
      update(move ? 'Moving folders…' : 'Creating links…');
      return archive.organize(widget.drive, facet, target!, move: move);
    });
    if (!mounted) return;
    Navigator.pop(context);
    if (r != null) toast(context, 'Done: ${r.$1} movies organized, ${r.$2} skipped.');
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Organize folders'),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            DropdownButtonFormField<Facet>(
              initialValue: facet,
              decoration: const InputDecoration(labelText: 'Group by'),
              items: [for (final f in _facets) DropdownMenuItem(value: f, child: Text(f.label))],
              onChanged: (f) => setState(() => facet = f!),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_outlined),
              title: Text(target ?? 'Choose where to create the folders'),
              trailing: TextButton(
                child: const Text('Choose'),
                onPressed: () async {
                  final t = await FilePicker.getDirectoryPath(dialogTitle: 'Where should the folders go?');
                  if (t != null) setState(() => target = t);
                },
              ),
            ),
            RadioGroup<bool>(
              groupValue: move,
              onChanged: (v) => setState(() => move = v!),
              child: const Column(children: [
                RadioListTile(
                  value: false,
                  title: Text('Links (recommended)'),
                  subtitle: Text('Folders point to your movies. Uses no extra space. Movie files stay where they are.'),
                ),
                RadioListTile(
                  value: true,
                  title: Text('Move movies'),
                  subtitle: Text('Really moves each movie into its folder. Only on the same drive.'),
                ),
              ]),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: target == null ? null : _run, child: const Text('Start')),
        ],
      );
}
