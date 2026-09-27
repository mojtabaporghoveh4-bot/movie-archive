import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class TmdbException implements Exception {
  final String message;
  TmdbException(this.message);
  @override
  String toString() => message;
}

class SearchResult {
  final int id;
  final String title;
  final int? year;
  final String? posterPath;
  final String overview;
  SearchResult(this.id, this.title, this.year, this.posterPath, this.overview);
}

// TMDB has no sub-genre field; these keywords are used to fill one in.
const _subGenres = [
  'neo-noir', 'film noir', 'slasher', 'found footage', 'cyberpunk', 'space opera', 'heist', 'spaghetti western',
  'mockumentary', 'body horror', 'psychological thriller', 'erotic thriller', 'giallo', 'dystopia', 'post-apocalyptic future',
  'time travel', 'coming of age', 'road movie', 'buddy cop', 'martial arts', 'kaiju', 'zombie', 'vampire', 'superhero',
  'survival', 'courtroom drama', 'biography', 'sports', 'musical', 'period drama', 'war', 'disaster', 'mystery',
  'whodunit', 'revenge', 'satire', 'parody', 'romantic comedy', 'black comedy', 'dark comedy', 'noir', 'epic',
];

class Tmdb {
  final String key;
  Tmdb(this.key);

  static String image(String path, {String size = 'w342'}) => 'https://image.tmdb.org/t/p/$size$path';

  Future<Map<String, dynamic>> _get(String path, [Map<String, String> query = const {}]) async {
    // A v4 "read access token" is long; a v3 "API key" is 32 characters.
    final bearer = key.length > 40;
    final uri = Uri.https('api.themoviedb.org', '/3$path', {...query, if (!bearer) 'api_key': key});
    for (var attempt = 0;; attempt++) {
      final http.Response r;
      try {
        r = await http.get(uri, headers: {
          'accept': 'application/json',
          if (bearer) 'Authorization': 'Bearer $key',
        }).timeout(const Duration(seconds: 20));
      } catch (_) {
        throw TmdbException('No internet connection (or TMDB is not reachable).');
      }
      if (r.statusCode == 200) return jsonDecode(utf8.decode(r.bodyBytes));
      if (r.statusCode == 401) throw TmdbException('Your TMDB key is not valid. Check it in Settings.');
      if (r.statusCode == 404) throw TmdbException('Not found on TMDB.');
      if (r.statusCode == 429 && attempt < 3) {
        await Future.delayed(Duration(seconds: 2 << attempt));
        continue;
      }
      throw TmdbException('TMDB error ${r.statusCode}.');
    }
  }

  static int? _year(dynamic date) => date is String && date.length >= 4 ? int.tryParse(date.substring(0, 4)) : null;

  Future<List<SearchResult>> search(String title, {int? year}) async {
    final d = await _get('/search/movie', {'query': title, if (year != null) 'year': '$year'});
    return [
      for (final r in d['results'] as List)
        SearchResult(r['id'], r['title'] ?? '', _year(r['release_date']), r['poster_path'], r['overview'] ?? ''),
    ];
  }

  /// Search by title, or by IMDb ID when the text looks like tt1234567.
  Future<List<SearchResult>> lookup(String text, {int? year}) async {
    final imdb = RegExp(r'tt\d{5,}').firstMatch(text)?[0];
    if (imdb == null) return search(text.trim(), year: year);
    final d = await _get('/find/$imdb', {'external_source': 'imdb_id'});
    return [
      for (final r in d['movie_results'] as List)
        SearchResult(r['id'], r['title'] ?? '', _year(r['release_date']), r['poster_path'], r['overview'] ?? ''),
    ];
  }

  Future<Map<String, dynamic>> details(int id) => _get('/movie/$id', {'append_to_response': 'credits,keywords'});

  /// Copies TMDB details into [m]. Keeps the user's own tags, notes and sub-genre.
  static void apply(Movie m, Map<String, dynamic> d) {
    List<String> names(dynamic list) => [for (final x in (list as List? ?? [])) x['name'].toString()];
    m.tmdbId = d['id'];
    m.imdbId = d['imdb_id'] ?? m.imdbId;
    m.title = d['title'] ?? m.title;
    m.originalTitle = d['original_title'];
    m.year = _year(d['release_date']) ?? m.year;
    m.overview = d['overview'];
    m.runtime = d['runtime'];
    m.rating = (d['vote_average'] as num?)?.toDouble();
    m.posterPath = d['poster_path'] ?? m.posterPath;
    m.collection = d['belongs_to_collection']?['name'];
    m.genres = names(d['genres']);
    m.countries = names(d['production_countries']);
    m.keywords = names(d['keywords']?['keywords']);
    m.directors = [
      for (final c in (d['credits']?['crew'] as List? ?? []))
        if (c['job'] == 'Director') c['name'].toString(),
    ];
    m.cast = [for (final c in (d['credits']?['cast'] as List? ?? []).take(8)) c['name'].toString()];
    final code = d['original_language'];
    final spoken = (d['spoken_languages'] as List? ?? []).cast<Map>();
    m.language = spoken.where((l) => l['iso_639_1'] == code).map((l) => l['english_name'] as String?).firstOrNull ??
        (code is String ? code.toUpperCase() : null);
    if (m.subGenre == null || m.subGenre!.isEmpty) {
      m.subGenre = _subGenres.where((s) => m.keywords.any((k) => k.toLowerCase() == s)).firstOrNull;
      if (m.subGenre != null) m.subGenre = m.subGenre![0].toUpperCase() + m.subGenre!.substring(1);
    }
  }
}
