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
  late final _key = TextEditingController(text: archive.tmdbKey);
  bool _showKey = false;

  Future<void> _testKey() async {
    archive.tmdbKey = _key.text;
    final ok = await withProgress(context, 'Checking key', (_) async {
      await archive.tmdb!.search('The Matrix');
      return true;
    });
    if (ok == true && mounted) toast(context, 'Key works. You are connected to TMDB.');
  }

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
              header('Movie info (TMDB)'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Titles, directors, cast, genres and posters come from The Movie Database (TMDB). '
                        'Get a free API key and paste it here.'),
                    TextButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Get a free TMDB key'),
                      onPressed: () => launchUrl(Uri.parse('https://www.themoviedb.org/settings/api')),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _key,
                      obscureText: !_showKey,
                      decoration: InputDecoration(
                        labelText: 'API key or read access token',
                        suffixIcon: IconButton(
                          icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _showKey = !_showKey),
                        ),
                      ),
                      onChanged: (v) => archive.tmdbKey = v,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(onPressed: _testKey, child: const Text('Test key')),
                  ]),
                ),
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
                  title: const Text('Movie Archive 1.0.1'),
                  subtitle: const Text('Created by ArMo · Telegram @mocntrl\n'
                      'Movie info and posters by TMDB. This app is not endorsed by TMDB.'),
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
