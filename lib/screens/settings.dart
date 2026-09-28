import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../archive.dart';
import '../widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _importArchive() async {
    final f = await pickTextFile();
    if (f == null || !mounted) return;
    final replace = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Import archive'),
        content: const Text(
            'Replace: your list becomes exactly the imported one (best for updating your phone from your computer).\n\n'
            'Merge: adds the imported movies to your current list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          OutlinedButton(onPressed: () => Navigator.pop(c, false), child: const Text('Merge')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Replace')),
        ],
      ),
    );
    if (replace == null) return;
    try {
      final n = await archive.importJson(f.$2, replace: replace);
      if (mounted) toast(context, 'Imported $n movies.');
    } catch (e) {
      if (mounted) toast(context, 'Could not read this file. Pick a file exported from Movie Archive (.json).');
    }
  }

  Future<void> _importCsv() async {
    final f = await pickTextFile();
    if (f == null) return;
    try {
      final n = await archive.importCsv(f.$2);
      if (mounted) toast(context, 'Added $n movies. Use "Find info & posters" in the Library to complete them.');
    } catch (e) {
      if (mounted) toast(context, e is FormatException ? e.message : 'Could not read this spreadsheet.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget header(String s) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
          child: Text(s, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: scheme.primary)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: archive,
        builder: (context, _) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
              header('Movie info'),
              _KeyCard(
                title: 'TMDB (info and posters)',
                about: 'Titles, directors, cast, genres, collections and posters come from The Movie Database (TMDB).',
                link: 'https://www.themoviedb.org/settings/api',
                label: 'API key or read access token',
                initial: archive.tmdbKey,
                onChanged: (v) => archive.tmdbKey = v,
                test: () => archive.tmdb!.search('The Matrix'),
              ),
              const SizedBox(height: 12),
              _KeyCard(
                title: 'OMDb (IMDb rating)',
                about: 'Adds the IMDb rating and votes. Works alone too: without a TMDB key, all info comes from IMDb '
                    'through OMDb. Free key: 1,000 movies per day.',
                link: 'https://www.omdbapi.com/apikey.aspx',
                label: 'OMDb API key',
                initial: archive.omdbKey,
                onChanged: (v) => archive.omdbKey = v,
                test: () => archive.omdb!.movie(imdbId: 'tt0133093'),
              ),
              header('Sync between computer and phone'),
              Card(
                child: Column(children: [
                  if (isDesktop)
                    ListTile(
                      leading: const Icon(Icons.cloud_sync_outlined),
                      title: const Text('Cloud sync folder'),
                      subtitle: Text(archive.syncFolder ??
                          'Pick a folder from Google Drive, OneDrive or Dropbox. The app saves "movie-archive.json" there after every change.'),
                      trailing: archive.syncFolder == null
                          ? FilledButton.tonal(
                              child: const Text('Choose'),
                              onPressed: () async {
                                final d = await FilePicker.getDirectoryPath(dialogTitle: 'Pick your cloud sync folder');
                                if (d != null) archive.syncFolder = d;
                              },
                            )
                          : IconButton(
                              tooltip: 'Stop syncing',
                              icon: const Icon(Icons.close),
                              onPressed: () => archive.syncFolder = null,
                            ),
                    ),
                  ListTile(
                    leading: const Icon(Icons.file_download_outlined),
                    title: const Text('Import archive'),
                    subtitle: Text(isDesktop
                        ? 'Open a movie-archive.json file.'
                        : 'Open movie-archive.json from Google Drive, Dropbox, OneDrive, email or your phone.'),
                    onTap: _importArchive,
                  ),
                  ListTile(
                    leading: const Icon(Icons.file_upload_outlined),
                    title: const Text('Export archive'),
                    subtitle: const Text('Save the whole archive as one file to open on another device.'),
                    onTap: () async {
                      final text = const JsonEncoder.withIndent(' ').convert(archive.toJson());
                      if (await saveTextFile('movie-archive.json', text) && context.mounted) toast(context, 'Archive saved.');
                    },
                  ),
                ]),
              ),
              header('Spreadsheet'),
              Card(
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.table_view_outlined),
                    title: const Text('Export spreadsheet (CSV)'),
                    subtitle: const Text('Opens in Excel or Google Sheets.'),
                    onTap: () async {
                      if (await saveTextFile('movies.csv', archive.toCsv(archive.query(MovieQuery()))) && context.mounted) {
                        toast(context, 'Spreadsheet saved.');
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.playlist_add),
                    title: const Text('Import spreadsheet (CSV)'),
                    subtitle: const Text('Add movies from a list. Needs a "Title" column; "Year", "Director", "IMDb ID"… are optional.'),
                    onTap: _importCsv,
                  ),
                ]),
              ),
              header('Appearance'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
                      ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
                      ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('System')),
                    ],
                    selected: {archive.themeMode},
                    onSelectionChanged: (s) => archive.themeMode = s.first,
                  ),
                ),
              ),
              header('About'),
              Card(
                child: ListTile(
                  leading: Icon(Icons.movie_filter_rounded, color: scheme.primary, size: 32),
                  title: const Text('Movie Archive 1.1.2'),
                  subtitle: const Text('Created by ArMo · Telegram @mocntrl\n'
                      'Info and posters by TMDB, IMDb ratings via OMDb. Not endorsed by TMDB or IMDb.'),
                  isThreeLine: true,
                  onTap: () => launchUrl(Uri.parse('https://t.me/mocntrl')),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A card to enter, show/hide, and test one API key.
class _KeyCard extends StatefulWidget {
  final String title, about, link, label, initial;
  final void Function(String) onChanged;
  final Future<Object?> Function() test;
  const _KeyCard({
    required this.title,
    required this.about,
    required this.link,
    required this.label,
    required this.initial,
    required this.onChanged,
    required this.test,
  });
  @override
  State<_KeyCard> createState() => _KeyCardState();
}

class _KeyCardState extends State<_KeyCard> {
  late final _key = TextEditingController(text: widget.initial);
  bool _show = false;

  Future<void> _test() async {
    if (_key.text.trim().isEmpty) return toast(context, 'Paste your key first.');
    widget.onChanged(_key.text);
    final ok = await withProgress(context, 'Checking key', (_) async {
      await widget.test();
      return true;
    });
    if (ok == true && mounted) toast(context, 'Key works.');
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(widget.about),
            TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Get a free key'),
              onPressed: () => launchUrl(Uri.parse(widget.link)),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _key,
              obscureText: !_show,
              decoration: InputDecoration(
                labelText: widget.label,
                suffixIcon: IconButton(
                  icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _show = !_show),
                ),
              ),
              onChanged: widget.onChanged,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: _test, child: const Text('Test key')),
          ]),
        ),
      );
}
