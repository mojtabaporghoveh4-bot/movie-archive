import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movie_archive/scanner.dart';
import 'package:path/path.dart' as p;

void main() {
  test('parseName', () {
    final cases = {
      'Blade.Runner.2049.2017.1080p.BluRay.x264.mkv': ('Blade Runner 2049', 2017),
      'Blade Runner 2049.mkv': ('Blade Runner 2049', null),
      '1917 (2019)': ('1917', 2019),
      '1917.mkv': ('1917', null),
      'The Godfather (1972) [1080p]': ('The Godfather', 1972),
      '[YTS] Heat [1995] BRRip': ('Heat', 1995),
      'Amelie_2001_720p_WEB-DL.mp4': ('Amelie', 2001),
      'Alien.Directors.Cut.1979.mkv': ('Alien', 1979),
      'Seven Samurai CD1.avi': ('Seven Samurai', null),
      'Pulp Fiction - 1994': ('Pulp Fiction', 1994),
    };
    cases.forEach((raw, want) {
      final got = parseName(raw);
      expect((got.title, got.year), want, reason: raw);
    });
  });

  test('scanFolder uses folder names and joins split files', () async {
    final root = await Directory.systemTemp.createTemp('scan');
    Future<void> touch(String rel) async {
      final f = File(p.join(root.path, rel));
      await f.create(recursive: true);
      await f.writeAsString('x');
    }

    await touch('Heat (1995)/heat.1080p.mkv');
    await touch('Heat (1995)/heat-sample.mkv');
    await touch('Seven Samurai (1954)/Seven Samurai CD1.avi');
    await touch('Seven Samurai (1954)/Seven Samurai CD2.avi');
    await touch('Loose/Alien.1979.mkv');
    await touch('Loose/Aliens.1986.mkv');
    await touch('notes.txt');

    final found = await scanFolder(root.path);
    expect(found.map((m) => m.name.toString()).toList(),
        ['Alien (1979)', 'Aliens (1986)', 'Heat (1995)', 'Seven Samurai (1954)']);
    expect(found.last.size, 2);
    await root.delete(recursive: true);
  });
}
