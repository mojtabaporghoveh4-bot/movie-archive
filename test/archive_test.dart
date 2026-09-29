import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movie_archive/archive.dart';
import 'package:movie_archive/models.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('archive');
    archive = Archive.at(File(p.join(tmp.path, 'library.json')), Directory(p.join(tmp.path, 'posters')));
  });
  tearDown(() => tmp.delete(recursive: true));

  test('scan, search, filter, CSV and JSON round trips', () async {
    final root = Directory(p.join(tmp.path, 'drive'));
    for (final rel in ['Heat (1995)/heat.mkv', 'Alien (1979)/alien.mkv']) {
      await File(p.join(root.path, rel)).create(recursive: true);
    }
    final (added, removed) = await archive.scan(root.path, name: 'WD 2TB');
    expect((added, removed), (2, 0));

    final heat = archive.movies.firstWhere((m) => m.title == 'Heat')
      ..directors = ['Michael Mann']
      ..cast = ['Al Pacino', 'Robert De Niro']
      ..language = 'English';
    await archive.add(Movie(title: 'Taxi Driver', year: 1976, cast: ['Robert De Niro']));

    expect(archive.query(MovieQuery()..text = 'de niro').length, 2);
    expect(archive.query(MovieQuery(Facet.director, 'Michael Mann')).single, heat);
    expect(archive.query(MovieQuery(Facet.drive, 'WD 2TB')).length, 2);
    expect(archive.query(MovieQuery(Facet.decade, '1970s')).map((m) => m.title), ['Alien', 'Taxi Driver']);

    // Rescan keeps edits and drops movies that are gone.
    await Directory(p.join(root.path, 'Alien (1979)')).delete(recursive: true);
    expect(await archive.scan(root.path, drive: archive.drives.single), (0, 1));
    expect(heat.directors, ['Michael Mann']);

    // Spreadsheet round trip.
    final csvText = archive.toCsv(archive.movies);
    final json = archive.toJson();
    archive.movies.clear();
    expect(await archive.importCsv(csvText), 2);
    final back = archive.movies.firstWhere((m) => m.title == 'Heat');
    expect([back.year, ...back.cast, back.language], [1995, 'Al Pacino', 'Robert De Niro', 'English']);

    // Archive file: merge keeps both, replace makes an exact copy.
    final jsonText = jsonEncode(json);
    await archive.importJson(jsonText, replace: false);
    expect(archive.movies.length, 4);
    await archive.importJson(jsonText, replace: true);
    expect(archive.movies.length, 2);
    expect(archive.query(MovieQuery()..onlyDuplicates = true), isEmpty);
  });

  test('settings survive a restart and are not lost by a second window', () async {
    final other = Archive.at(File(p.join(tmp.path, 'library.json')), Directory(p.join(tmp.path, 'posters')));
    archive.tmdbKey = ' abc123 ';
    other.setSetting('grid', false); // the other window never saw the key
    final reopened = Archive.at(File(p.join(tmp.path, 'library.json')), Directory(p.join(tmp.path, 'posters')));
    expect([reopened.tmdbKey, reopened.setting<bool>('grid')], ['abc123', false]);
    expect(jsonEncode(archive.toJson()).contains('abc123'), isFalse, reason: 'keys must not go into the synced file');
  });

  test('organize with links keeps files in place', () async {
    if (!Platform.isWindows) return;
    final root = Directory(p.join(tmp.path, 'drive'));
    await File(p.join(root.path, 'Heat (1995)', 'heat.mkv')).create(recursive: true);
    await archive.scan(root.path, name: 'D');
    archive.movies.single.directors = ['Michael Mann'];
    final out = p.join(tmp.path, 'by director & more');
    expect(await archive.organize(archive.drives.single, Facet.director, out, move: false), (1, 0));
    expect(File(p.join(out, 'Michael Mann', 'Heat (1995)', 'heat.mkv')).existsSync(), isTrue);
    expect(File(p.join(root.path, 'Heat (1995)', 'heat.mkv')).existsSync(), isTrue);
  });
}
