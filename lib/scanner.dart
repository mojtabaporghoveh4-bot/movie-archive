import 'dart:io';

import 'package:path/path.dart' as p;

const videoExtensions = {
  '.mkv', '.mp4', '.avi', '.m4v', '.mov', '.wmv', '.mpg', '.mpeg', '.ts', '.webm', '.flv', '.iso', '.divx',
};

class ParsedName {
  final String title;
  final int? year;
  const ParsedName(this.title, this.year);
  @override
  String toString() => '$title ($year)';
}

final _year = RegExp(r'(?<!\d)(19\d\d|20\d\d)(?!\d)');
final _junk = RegExp(
  r'\b(2160p|1080p|720p|576p|480p|4k|uhd|hdr|hdr10|dv|bluray|blu ray|bdrip|brrip|webrip|web dl|webdl|web|hdtv|dvdrip|dvd|hdrip|'
  r'x264|x265|h264|h265|hevc|avc|aac|ac3|dts|ddp?5 1|remux|proper|repack|extended|unrated|remastered|imax|'
  r'directors cut|criterion|multi|dual audio|subbed|yts|yify|rarbg)\b',
  caseSensitive: false,
);
final _part = RegExp(r'\b(cd|disc|disk|part|pt)\s?\d\b', caseSensitive: false);

/// Turns a file or folder name like "Blade.Runner.2049.2017.1080p.BluRay.x264.mkv"
/// into a title and year.
ParsedName parseName(String raw) {
  var s = raw.trim();
  final ext = p.extension(s).toLowerCase();
  if (videoExtensions.contains(ext)) s = s.substring(0, s.length - ext.length);

  // Drop bracket tags like [YTS] but keep ones holding a year like [1999].
  s = s.replaceAllMapped(RegExp(r'\[([^\]]*)\]'), (m) => _year.hasMatch(m[1]!) ? ' ${m[1]} ' : ' ');
  s = s.replaceAll(_imdbTag, ' ').replaceAll(RegExp(r'[._]'), ' ').replaceAll(_part, ' ');

  // The year is the last 19xx/20xx that is not at the very start (so "1917 (2019)" works)
  // and not in the future (so "Blade Runner 2049" without a year is not read as 2049).
  final maxYear = DateTime.now().year + 2;
  RegExpMatch? year;
  for (final m in _year.allMatches(s)) {
    if (m.start > 0 && int.parse(m[1]!) <= maxYear) year = m;
  }

  var title = year != null ? s.substring(0, year.start) : s;
  final junk = _junk.firstMatch(title);
  if (junk != null && junk.start > 0) title = title.substring(0, junk.start);
  title = title
      .replaceAll(RegExp(r'[\[\]\(\){}]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[\s\-–,]+$'), '')
      .trim();
  if (title.isEmpty) title = s.trim();
  return ParsedName(title, year == null ? null : int.parse(year[1]!));
}

class ScannedMovie {
  final String relPath; // relative to the scanned root
  final int size;
  final ParsedName name;
  final String? imdbId; // when the file or folder name has one, e.g. "Heat (1995) {imdb-tt0113277}"
  ScannedMovie(this.relPath, this.size, this.name, [this.imdbId]);
}

final _imdbTag = RegExp(r'[\[\({]?\b(imdb(id)?[-_ =]?)?(tt\d{7,8})\b[\]\)}]?', caseSensitive: false);

bool _skip(String path) {
  final l = path.toLowerCase();
  return l.contains(r'$recycle.bin') ||
      l.contains('system volume information') ||
      RegExp(r'\b(sample|trailer)\b').hasMatch(p.basenameWithoutExtension(l));
}

/// Finds all movies under [root]. A folder with a single movie is named after the
/// folder; split files (CD1/CD2) are joined into one movie.
Future<List<ScannedMovie>> scanFolder(String root, {void Function(int found)? onProgress}) async {
  final byDir = <String, List<File>>{};
  var found = 0;
  final stream = Directory(root).list(recursive: true, followLinks: false).handleError((_) {});
  await for (final e in stream) {
    if (e is! File || !videoExtensions.contains(p.extension(e.path).toLowerCase()) || _skip(e.path)) continue;
    byDir.putIfAbsent(p.dirname(e.path), () => []).add(e);
    onProgress?.call(++found);
  }

  final result = <ScannedMovie>[];
  for (final entry in byDir.entries) {
    final dir = entry.key;
    final files = entry.value;
    final ownFolder = files.length == 1 || files.every((f) => _part.hasMatch(p.basename(f.path).replaceAll(RegExp(r'[._]'), ' ')));
    final folder = ownFolder && !p.equals(dir, root) ? parseName(p.basename(dir)) : null;
    final groups = <String, (ParsedName, List<File>)>{};
    for (final f in files) {
      var name = parseName(p.basename(f.path));
      if (folder != null && (folder.year != null || name.year == null)) name = folder;
      groups.putIfAbsent('${name.title.toLowerCase()}|${name.year}', () => (name, [])).$2.add(f);
    }
    for (final (name, g) in groups.values) {
      g.sort((a, b) => a.path.compareTo(b.path));
      var size = 0;
      for (final f in g) {
        try {
          size += f.lengthSync();
        } catch (_) {}
      }
      final rel = p.relative(g.first.path, from: root);
      result.add(ScannedMovie(rel, size, name, _imdbTag.allMatches(rel).lastOrNull?[3]?.toLowerCase()));
    }
  }
  result.sort((a, b) => a.name.title.toLowerCase().compareTo(b.name.title.toLowerCase()));
  return result;
}
