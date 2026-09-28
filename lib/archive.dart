import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'omdb.dart';
import 'scanner.dart';
import 'tmdb.dart';

late Archive archive;

bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

/// Ways to group and filter the archive.
enum Facet {
  genre('Genre', 'Genres', Icons.theater_comedy_outlined),
  subGenre('Sub-genre', 'Sub-genres', Icons.category_outlined),
  director('Director', 'Directors', Icons.movie_creation_outlined),
  actor('Actor', 'Actors', Icons.person_outline),
  year('Year', 'Years', Icons.event_outlined),
  decade('Decade', 'Decades', Icons.date_range_outlined),
  language('Language', 'Languages', Icons.translate),
  country('Country', 'Countries', Icons.public),
  collection('Collection', 'Collections & franchises', Icons.collections_bookmark_outlined),
  tag('Tag', 'My tags', Icons.label_outline),
  drive('Drive', 'Drives', Icons.storage_outlined);

  final String label;
  final String plural;
  final IconData icon;
  const Facet(this.label, this.plural, this.icon);

  List<String> of(Movie m) => switch (this) {
        Facet.genre => m.genres,
        Facet.subGenre => [if (m.subGenre?.isNotEmpty ?? false) m.subGenre!],
        Facet.director => m.directors,
        Facet.actor => m.cast,
        Facet.year => [if (m.year != null) '${m.year}'],
        Facet.decade => [if (m.year != null) '${m.year! ~/ 10 * 10}s'],
        Facet.language => [if (m.language?.isNotEmpty ?? false) m.language!],
        Facet.country => m.countries,
        Facet.collection => [if (m.collection?.isNotEmpty ?? false) m.collection!],
        Facet.tag => m.tags,
        Facet.drive => [archive.driveName(m)],
      };
}

enum SortBy {
  title('Title'),
  yearNew('Year (newest)'),
  yearOld('Year (oldest)'),
  rating('Rating'),
  added('Recently added');

  final String label;
  const SortBy(this.label);
}

/// Search text plus filters. Values in one facet are OR-ed, facets are AND-ed.
class MovieQuery {
  String text = '';
  final Map<Facet, Set<String>> filters = {};
  SortBy sort = SortBy.title;
  bool onlyUnmatched = false;
  bool onlyDuplicates = false;

  MovieQuery([Facet? facet, String? value]) {
    if (facet != null && value != null) filters[facet] = {value};
  }

  bool get isEmpty => text.isEmpty && filters.isEmpty && !onlyUnmatched && !onlyDuplicates;
}

class Archive extends ChangeNotifier {
  final File _file;
  final Directory posterDir;
  final SharedPreferences prefs;
  List<Drive> drives = [];
  List<Movie> movies = [];

  Archive.at(this._file, this.posterDir, this.prefs);

  static Future<Archive> open() async {
    final dir = await getApplicationSupportDirectory();
    final a = Archive.at(File(p.join(dir.path, 'library.json')), Directory(p.join(dir.path, 'posters')),
        await SharedPreferences.getInstance());
    if (await a._file.exists()) a._load(jsonDecode(await a._file.readAsString()));
    return a;
  }

  // ---------- settings ----------

  String get tmdbKey => prefs.getString('tmdbKey') ?? '';
  set tmdbKey(String v) => prefs.setString('tmdbKey', v.trim()).then((_) => notifyListeners());
  Tmdb? get tmdb => tmdbKey.isEmpty ? null : Tmdb(tmdbKey);

  String get omdbKey => prefs.getString('omdbKey') ?? '';
  set omdbKey(String v) => prefs.setString('omdbKey', v.trim()).then((_) => notifyListeners());
  Omdb? get omdb => omdbKey.isEmpty ? null : Omdb(omdbKey);

  bool get canLookup => tmdb != null || omdb != null;

  String? get syncFolder => prefs.getString('syncFolder');
  set syncFolder(String? v) =>
      (v == null ? prefs.remove('syncFolder') : prefs.setString('syncFolder', v)).then((_) => save());

  ThemeMode get themeMode => ThemeMode.values.byName(prefs.getString('theme') ?? 'dark');
  set themeMode(ThemeMode v) => prefs.setString('theme', v.name).then((_) => notifyListeners());

  // ---------- storage ----------

  // ponytail: whole archive is one JSON file kept in memory; fine for tens of thousands of movies.
  // Move to SQLite if it ever gets slow.
  Map<String, dynamic> toJson() => {
        'app': 'Movie Archive by ArMo',
        'version': 1,
        'exported': DateTime.now().toIso8601String(),
        'drives': [for (final d in drives) d.toJson()],
        'movies': [for (final m in movies) m.toJson()],
      };

  void _load(Map<String, dynamic> j) {
    drives = [for (final d in j['drives'] as List? ?? []) Drive.fromJson(d)];
    movies = [for (final m in j['movies'] as List? ?? []) Movie.fromJson(m)];
  }

  Future<void> save() async {
    notifyListeners();
    final text = const JsonEncoder.withIndent(' ').convert(toJson());
    final tmp = File('${_file.path}.tmp');
    await tmp.parent.create(recursive: true);
    await tmp.writeAsString(text, flush: true);
    await tmp.rename(_file.path);
    final sync = syncFolder;
    if (sync != null && await Directory(sync).exists()) {
      await File(p.join(sync, 'movie-archive.json')).writeAsString(text);
    }
  }

  /// Merges (or replaces with) an exported archive file. Returns how many movies came in.
  Future<int> importJson(String text, {required bool replace}) async {
    final j = jsonDecode(text);
    if (j is! Map<String, dynamic> || j['movies'] is! List) throw const FormatException('Not a Movie Archive file.');
    final incoming = Archive.at(_file, posterDir, prefs).._load(j);
    if (replace) {
      drives = incoming.drives;
      movies = incoming.movies;
    } else {
      final d = {for (final x in drives) x.id: x}..addAll({for (final x in incoming.drives) x.id: x});
      final m = {for (final x in movies) x.id: x}..addAll({for (final x in incoming.movies) x.id: x});
      drives = d.values.toList();
      movies = m.values.toList();
    }
    await save();
    return incoming.movies.length;
  }

  static const csvColumns = [
    'Title', 'Year', 'Original title', 'Director', 'Cast', 'Genre', 'Sub-genre', 'Collection', 'Language', 'Country',
    'IMDb rating', 'TMDB rating', 'Runtime', 'IMDb ID', 'TMDB ID', 'Tags', 'Watched', 'Drive', 'Path', 'Size (GB)', 'Notes',
  ];

  /// A spreadsheet of [list] that opens in Excel or Google Sheets.
  String toCsv(List<Movie> list) {
    final rows = <List<Object?>>[
      csvColumns,
      for (final m in list)
        [
          m.title, m.year, m.originalTitle, m.directors.join(', '), m.cast.join(', '), m.genres.join(', '), m.subGenre,
          m.collection, m.language, m.countries.join(', '), m.imdbRating, m.rating?.toStringAsFixed(1), m.runtime, m.imdbId, m.tmdbId,
          m.tags.join(', '), m.watched ? 'Yes' : 'No', driveName(m), m.path,
          m.sizeBytes == null ? null : (m.sizeBytes! / 1e9).toStringAsFixed(2), m.notes,
        ].map((v) => v ?? '').toList(),
    ];
    return '﻿${Csv(lineDelimiter: '\n').encode(rows)}';
  }

  /// Adds movies from a spreadsheet. Only a "Title" column is required; other columns
  /// are matched by name (same names as the export).
  Future<int> importCsv(String text) async {
    final rows = csv.decode(text.replaceFirst('﻿', ''));
    if (rows.isEmpty) return 0;
    final head = [for (final h in rows.first) h.toString().trim().toLowerCase()];
    final ti = head.indexOf('title');
    if (ti < 0) throw const FormatException('The first row must have a "Title" column.');
    List<String> split(String v) => [for (final s in v.split(RegExp(r'[,;]'))) if (s.trim().isNotEmpty) s.trim()];
    var added = 0;
    for (final r in rows.skip(1)) {
      String cell(String name) {
        final i = head.indexOf(name.toLowerCase());
        return i >= 0 && i < r.length ? r[i].toString().trim() : '';
      }

      if (cell('title').isEmpty) continue;
      final driveName = cell('drive');
      movies.add(Movie(
        title: cell('title'),
        year: int.tryParse(cell('year')),
        originalTitle: cell('original title').isEmpty ? null : cell('original title'),
        directors: split(cell('director')),
        cast: split(cell('cast')),
        genres: split(cell('genre')),
        subGenre: cell('sub-genre').isEmpty ? null : cell('sub-genre'),
        collection: cell('collection').isEmpty ? null : cell('collection'),
        language: cell('language').isEmpty ? null : cell('language'),
        countries: split(cell('country')),
        imdbRating: double.tryParse(cell('imdb rating')),
        rating: double.tryParse(cell('tmdb rating')),
        runtime: int.tryParse(cell('runtime')),
        imdbId: cell('imdb id').isEmpty ? null : cell('imdb id'),
        tmdbId: int.tryParse(cell('tmdb id')),
        tags: split(cell('tags')),
        watched: cell('watched').toLowerCase() == 'yes',
        driveId: drives.where((d) => d.name == driveName).firstOrNull?.id,
        path: cell('path').isEmpty ? null : cell('path'),
        notes: cell('notes').isEmpty ? null : cell('notes'),
      ));
      added++;
    }
    await save();
    return added;
  }

  // ---------- queries ----------

  Drive? driveOf(Movie m) => drives.where((d) => d.id == m.driveId).firstOrNull;
  String driveName(Movie m) => driveOf(m)?.name ?? 'Added by hand';

  String? fullPath(Movie m) {
    final d = driveOf(m);
    return d == null || m.path == null ? null : p.join(d.root, m.path);
  }

  String _dupKey(Movie m) => m.tmdbId != null ? '#${m.tmdbId}' : '${m.title.toLowerCase()}|${m.year}';

  List<Movie> query(MovieQuery q) {
    final text = q.text.trim().toLowerCase();
    Set<String>? dups;
    if (q.onlyDuplicates) {
      final count = <String, int>{};
      for (final m in movies) {
        count.update(_dupKey(m), (c) => c + 1, ifAbsent: () => 1);
      }
      dups = {for (final e in count.entries) if (e.value > 1) e.key};
    }
    final list = movies.where((m) {
      if (q.onlyUnmatched && m.matched) return false;
      if (dups != null && !dups.contains(_dupKey(m))) return false;
      for (final f in q.filters.entries) {
        if (!f.key.of(m).any(f.value.contains)) return false;
      }
      if (text.isEmpty) return true;
      return [
        m.title, m.originalTitle, m.imdbId, m.collection, m.subGenre, m.language, m.notes,
        ...m.directors, ...m.cast, ...m.genres, ...m.keywords, ...m.tags, ...m.countries,
        if (m.year != null) '${m.year}',
      ].any((s) => s != null && s.toLowerCase().contains(text));
    }).toList();
    int cmp<T extends Comparable>(T? a, T? b) => a == null ? (b == null ? 0 : 1) : (b == null ? -1 : a.compareTo(b));
    list.sort(switch (q.sort) {
      SortBy.title => (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      SortBy.yearNew => (a, b) => cmp(b.year, a.year),
      SortBy.yearOld => (a, b) => cmp(a.year, b.year),
      SortBy.rating => (a, b) => cmp(b.score, a.score),
      SortBy.added => (a, b) => b.added.compareTo(a.added),
    });
    return list;
  }

  /// Every value of [facet] with its movie count, biggest first.
  List<MapEntry<String, int>> counts(Facet facet, [Iterable<Movie>? from]) {
    final c = <String, int>{};
    for (final m in from ?? movies) {
      for (final v in facet.of(m).toSet()) {
        c.update(v, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final list = c.entries.toList();
    if (facet == Facet.year || facet == Facet.decade) {
      list.sort((a, b) => b.key.compareTo(a.key));
    } else {
      list.sort((a, b) => b.value != a.value ? b.value - a.value : a.key.compareTo(b.key));
    }
    return list;
  }

  // ---------- editing ----------

  Future<void> add(Movie m) async {
    movies.add(m);
    await save();
  }

  Future<void> remove(Movie m) async {
    movies.remove(m);
    await save();
  }

  Future<void> removeDrive(Drive d) async {
    drives.remove(d);
    movies.removeWhere((m) => m.driveId == d.id);
    await save();
  }

  /// Scans [root] into [drive] (a new drive if null). Keeps info for movies already
  /// known, adds new ones, drops ones no longer there. Returns (added, removed).
  Future<(int, int)> scan(String root, {Drive? drive, String? name, void Function(int)? onProgress}) async {
    final found = await scanFolder(root, onProgress: onProgress);
    if (drive == null) {
      drive = Drive(id: newId(), name: name ?? p.basename(root), root: root);
      drives.add(drive);
    }
    drive
      ..root = root
      ..scannedAt = DateTime.now();
    final known = {for (final m in movies.where((m) => m.driveId == drive!.id)) m.path?.toLowerCase(): m};
    var added = 0;
    for (final f in found) {
      final existing = known.remove(f.relPath.toLowerCase());
      if (existing != null) {
        existing.sizeBytes = f.size;
        existing.imdbId ??= f.imdbId;
      } else {
        movies.add(Movie(
            title: f.name.title, year: f.name.year, imdbId: f.imdbId, driveId: drive.id, path: f.relPath, sizeBytes: f.size));
        added++;
      }
    }
    movies.removeWhere((m) => known.values.contains(m));
    await save();
    return (added, known.length);
  }

  /// Finds the movie online (by [tmdbId], IMDb ID, or title + year) and fills in its info.
  /// TMDB gives the full info and poster; OMDb adds the IMDb rating, and fills in
  /// everything when TMDB is not set up or has no match.
  Future<bool> fetchInfo(Movie m, {int? tmdbId}) async {
    final t = tmdb, o = omdb;
    if (t == null && o == null) throw LookupException('Add a free TMDB or OMDb key in Settings first.');
    var found = false;
    if (t != null) {
      tmdbId ??= m.tmdbId;
      if (tmdbId == null) {
        var hits = await t.lookup(m.imdbId ?? m.title, year: m.year);
        if (hits.isEmpty && m.year != null && m.imdbId == null) hits = await t.search(m.title);
        tmdbId = hits.firstOrNull?.id;
      }
      if (tmdbId != null) {
        Tmdb.apply(m, await t.details(tmdbId));
        found = true;
      }
    }
    if (o != null) {
      final d = await o.movie(imdbId: m.imdbId, title: m.title, year: m.year);
      if (d != null) {
        Omdb.apply(m, d, full: !found);
        found = true;
      }
    }
    if (found && isDesktop) await downloadPoster(m);
    return found;
  }

  /// Sets the IMDb ID the user typed (or pasted as a link) and fetches that movie's info.
  Future<bool> setImdbId(Movie m, String input) async {
    final id = imdbIdIn(input);
    if (id == null) throw LookupException('That is not an IMDb ID. It looks like tt0111161.');
    m
      ..imdbId = id
      ..tmdbId = null
      ..posterPath = null
      ..posterUrl = null;
    final ok = await fetchInfo(m);
    await save();
    return ok;
  }

  /// Looks up many movies. Skips ones that fail, but stops on a bad key or no internet.
  Future<int> fetchMany(List<Movie> todo, void Function(String) update) async {
    var found = 0;
    try {
      for (var i = 0; i < todo.length; i++) {
        update('${i + 1} of ${todo.length}\n${todo[i].title}');
        try {
          if (await fetchInfo(todo[i])) found++;
        } on LookupException catch (e) {
          if (e.message.contains('key') || e.message.contains('internet') || e.message.contains('limit')) rethrow;
        }
      }
    } finally {
      await save();
    }
    return found;
  }

  File? posterFile(Movie m) {
    final id = m.tmdbId?.toString() ?? m.imdbId;
    return id == null ? null : File(p.join(posterDir.path, '$id.jpg'));
  }

  String? posterUrl(Movie m) => m.posterPath != null ? Tmdb.image(m.posterPath!, size: 'w500') : m.posterUrl;

  /// Keeps a local copy of the poster so the desktop app works offline.
  Future<void> downloadPoster(Movie m) async {
    final f = posterFile(m);
    final url = posterUrl(m);
    if (f == null || url == null || await f.exists()) return;
    try {
      final r = await http.get(Uri.parse(url));
      if (r.statusCode != 200) return;
      await f.parent.create(recursive: true);
      await f.writeAsBytes(r.bodyBytes);
    } catch (_) {}
  }

  // ---------- organizing folders (desktop) ----------

  static String safeName(String s) => s.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '').trim().replaceAll(RegExp(r'[. ]+$'), '');

  /// Builds `target/<value>/<movie folder>` for every movie on [drive].
  /// With [move] false, folders are links (Windows junctions) that use no extra space.
  /// Moving only works inside the same drive. Returns (done, skipped).
  Future<(int, int)> organize(Drive drive, Facet facet, String target, {required bool move}) async {
    if (move && !p.isWithin(drive.root, target)) {
      throw const FileSystemException('To move files, the target folder must be on the same drive.');
    }
    var done = 0, skipped = 0;
    for (final m in movies.where((m) => m.driveId == drive.id).toList()) {
      final src = fullPath(m);
      final values = facet.of(m);
      if (src == null || values.isEmpty || !await File(src).exists()) {
        skipped++;
        continue;
      }
      final ownFolder = !p.equals(p.dirname(src), drive.root);
      final item = ownFolder ? p.dirname(src) : src;
      try {
        if (move) {
          final dest = p.join(target, safeName(values.first), p.basename(item));
          if (await FileSystemEntity.type(dest) != FileSystemEntityType.notFound) {
            skipped++;
            continue;
          }
          await Directory(p.dirname(dest)).create(recursive: true);
          ownFolder ? await Directory(item).rename(dest) : await File(item).rename(dest);
          m.path = p.relative(ownFolder ? p.join(dest, p.basename(src)) : dest, from: drive.root);
        } else {
          if (!ownFolder) {
            skipped++; // junctions can only point at folders
            continue;
          }
          for (final v in values.take(facet == Facet.actor ? 5 : values.length)) {
            final link = Link(p.join(target, safeName(v), p.basename(item)));
            if (await FileSystemEntity.type(link.path, followLinks: false) != FileSystemEntityType.notFound) continue;
            await Directory(p.dirname(link.path)).create(recursive: true);
            await _junction(link.path, item);
          }
        }
        done++;
      } catch (_) {
        skipped++;
      }
    }
    await save();
    return (done, skipped);
  }

  /// A folder link. On Windows a junction, which (unlike a symlink) needs no admin rights.
  static Future<void> _junction(String link, String target) async {
    if (!Platform.isWindows) {
      await Link(link).create(target);
      return;
    }
    final r = await Process.run('cmd', ['/c', 'mklink', '/J', link, target]);
    if (r.exitCode != 0) throw FileSystemException('${r.stdout}${r.stderr}'.trim(), link);
  }
}
