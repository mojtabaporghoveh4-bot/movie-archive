import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'tmdb.dart';

/// OMDb (omdbapi.com) serves IMDb data: rating, votes, and full info when TMDB has no match.
class Omdb {
  final String key;
  Omdb(this.key);

  Future<Map<String, dynamic>?> _get(Map<String, String> query) async {
    final uri = Uri.https('www.omdbapi.com', '/', {...query, 'apikey': key});
    final http.Response r;
    try {
      r = await http.get(uri).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw LookupException('No internet connection (or OMDb is not reachable).');
    }
    final d = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    final error = '${d['Error'] ?? ''}';
    if (r.statusCode == 401 || error.contains('API key')) throw LookupException('Your OMDb key is not valid. Check it in Settings.');
    if (error.contains('limit')) throw LookupException('OMDb daily limit reached (1,000 per day on the free key). Try again tomorrow.');
    return d['Response'] == 'True' ? d : null;
  }

  /// One movie, by IMDb ID or by title (+ year).
  Future<Map<String, dynamic>?> movie({String? imdbId, String? title, int? year}) => _get({
        if (imdbId != null) 'i': imdbId else 't': title ?? '',
        if (imdbId == null && year != null) 'y': '$year',
        'type': 'movie',
        'plot': 'full',
      });

  Future<List<SearchResult>> search(String text, {int? year}) async {
    final imdb = imdbIdIn(text);
    if (imdb != null) {
      final d = await movie(imdbId: imdb);
      return d == null ? [] : [_result(d)];
    }
    final d = await _get({'s': text.trim(), 'type': 'movie', if (year != null) 'y': '$year'});
    return [for (final r in (d?['Search'] as List? ?? [])) _result(r)];
  }

  static SearchResult _result(Map r) => SearchResult(null, r['Title'] ?? '', int.tryParse('${r['Year']}'.split(RegExp(r'\D')).first),
      null, _na(r['Plot']) ?? '', imdbId: r['imdbID'], posterUrl: _na(r['Poster']));

  static String? _na(dynamic v) => v == null || v == 'N/A' || v == '' ? null : '$v';

  /// Always copies the IMDb rating and votes. With [full], also fills in everything else
  /// (used when TMDB is not set up or did not find the movie).
  static void apply(Movie m, Map<String, dynamic> d, {required bool full}) {
    List<String> list(dynamic v) => [for (final s in (_na(v) ?? '').split(',')) if (s.trim().isNotEmpty) s.trim()];
    m.imdbId = _na(d['imdbID']) ?? m.imdbId;
    m.imdbRating = double.tryParse(_na(d['imdbRating']) ?? '');
    m.imdbVotes = int.tryParse((_na(d['imdbVotes']) ?? '').replaceAll(',', ''));
    if (!full) return;
    m.title = _na(d['Title']) ?? m.title;
    m.year = int.tryParse('${d['Year']}'.split(RegExp(r'\D')).first) ?? m.year;
    m.overview = _na(d['Plot']);
    m.runtime = int.tryParse((_na(d['Runtime']) ?? '').split(' ').first);
    m.directors = list(d['Director']);
    m.cast = list(d['Actors']);
    m.genres = list(d['Genre']);
    m.language = list(d['Language']).firstOrNull;
    m.countries = list(d['Country']);
    m.posterUrl = _na(d['Poster']);
  }
}
