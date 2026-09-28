import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'archive.dart';
import 'models.dart';
import 'screens/detail.dart';
import 'tmdb.dart';

void toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));

String formatSize(int bytes) =>
    bytes >= 1e12 ? '${(bytes / 1e12).toStringAsFixed(2)} TB' : '${(bytes / 1e9).toStringAsFixed(1)} GB';

/// Lets the user pick a file (on Android this includes Google Drive, Dropbox, email...) and reads it as text.
Future<(String name, String text)?> pickTextFile() async {
  final f = await FilePicker.pickFile(type: FileType.any);
  if (f == null) return null;
  final bytes = await f.xFile.readAsBytes();
  return (f.name, utf8.decode(bytes, allowMalformed: true));
}

Future<bool> saveTextFile(String fileName, String text) async {
  final uri = await FilePicker.saveFile(fileName: fileName, bytes: Uint8List.fromList(utf8.encode(text)));
  return uri != null;
}

Future<bool> confirm(BuildContext context, String title, String body, {String ok = 'OK'}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
        ],
      ),
    ) ??
    false;

Future<String?> askText(BuildContext context, String title, {String initial = '', String? hint}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('OK')),
      ],
    ),
  );
}

/// Shows the local poster copy if there is one, otherwise loads it from TMDB.
class Poster extends StatelessWidget {
  final Movie movie;
  final double radius;
  const Poster(this.movie, {super.key, this.radius = 10});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.movie_outlined, size: 36, color: scheme.outline),
        const SizedBox(height: 6),
        Text(movie.title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.outline, fontSize: 12)),
      ]),
    );
    final local = isDesktop ? archive.posterFile(movie) : null;
    Widget img;
    if (local != null && local.existsSync()) {
      img = Image.file(local, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder);
    } else if (movie.posterPath != null || movie.posterUrl != null) {
      img = Image.network(movie.posterPath != null ? Tmdb.image(movie.posterPath!) : movie.posterUrl!,
          fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder);
    } else {
      img = placeholder;
    }
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: AspectRatio(aspectRatio: 2 / 3, child: img));
  }
}

class MovieCard extends StatelessWidget {
  final Movie movie;
  const MovieCard(this.movie, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(movie))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          Poster(movie),
          if (movie.score != null)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                  const SizedBox(width: 2),
                  Text(movie.score!.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 11)),
                ]),
              ),
            ),
          if (!movie.matched)
            Positioned(
              top: 6,
              left: 6,
              child: Tooltip(
                message: 'No info yet',
                child: CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.black.withValues(alpha: 0.7),
                    child: const Icon(Icons.help_outline, size: 14, color: Colors.white)),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall),
        Text([if (movie.year != null) '${movie.year}', ...movie.directors.take(1)].join(' · '),
            maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
      ]),
    );
  }
}

class MovieTile extends StatelessWidget {
  final Movie movie;
  const MovieTile(this.movie, {super.key});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: SizedBox(width: 40, child: Poster(movie, radius: 4)),
        title: Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [if (movie.year != null) '${movie.year}', movie.directors.join(', '), archive.driveName(movie)]
              .where((s) => s.isNotEmpty)
              .join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: movie.score != null
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                Text(' ${movie.score!.toStringAsFixed(1)}'),
              ])
            : null,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(movie))),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  const EmptyState(this.icon, this.title, this.body, {super.key, this.action});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: scheme.outline),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: TextStyle(color: scheme.outline)),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ]),
      ),
    );
  }
}

/// Sets a typed IMDb ID on [m] and fetches all its info, with progress and messages.
Future<void> lookupImdb(BuildContext context, Movie m, String input) async {
  final ok = await withProgress(context, 'Getting movie info', (_) => archive.setImdbId(m, input));
  if (!context.mounted || ok == null) return;
  toast(context, ok ? 'Info updated for "${m.title}".' : 'No movie found with that IMDb ID.');
}

/// Runs [task] behind a small progress dialog. [task] gets a function to update the text.
Future<T?> withProgress<T>(BuildContext context, String title, Future<T> Function(void Function(String) update) task) async {
  final status = ValueNotifier('Starting…');
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(title),
        content: Row(children: [
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(width: 20),
          Expanded(child: ValueListenableBuilder(valueListenable: status, builder: (_, s, _) => Text(s))),
        ]),
      ),
    ),
  );
  try {
    return await task((s) => status.value = s);
  } catch (e) {
    if (context.mounted) toast(context, '$e');
    return null;
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}
