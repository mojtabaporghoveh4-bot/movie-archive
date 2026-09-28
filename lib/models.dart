import 'dart:math';

String newId() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

List<String> _list(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];

/// A hard drive (or any folder) that was scanned into the archive.
class Drive {
  final String id;
  String name;
  String root; // folder that was scanned; movie paths are relative to it
  DateTime? scannedAt;

  Drive({required this.id, required this.name, required this.root, this.scannedAt});

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'root': root, 'scannedAt': scannedAt?.toIso8601String()};

  factory Drive.fromJson(Map<String, dynamic> j) => Drive(
        id: j['id'],
        name: j['name'] ?? '',
        root: j['root'] ?? '',
        scannedAt: DateTime.tryParse(j['scannedAt'] ?? ''),
      );
}

class Movie {
  final String id;
  String? driveId; // null = added by hand (not on a drive)
  String? path; // relative to the drive root
  int? sizeBytes;
  String title;
  String? originalTitle;
  int? year;
  int? tmdbId;
  String? imdbId;
  String? overview;
  int? runtime; // minutes
  double? rating; // TMDB user score
  double? imdbRating;
  int? imdbVotes;
  String? posterPath; // TMDB image path, e.g. /abc.jpg
  String? posterUrl; // full poster URL when info came from OMDb
  String? language;
  String? collection;
  String? subGenre;
  List<String> genres;
  List<String> directors;
  List<String> cast;
  List<String> countries;
  List<String> keywords;
  List<String> tags;
  bool watched;
  String? notes;
  DateTime added;

  Movie({
    String? id,
    required this.title,
    this.driveId,
    this.path,
    this.sizeBytes,
    this.originalTitle,
    this.year,
    this.tmdbId,
    this.imdbId,
    this.overview,
    this.runtime,
    this.rating,
    this.imdbRating,
    this.imdbVotes,
    this.posterPath,
    this.posterUrl,
    this.language,
    this.collection,
    this.subGenre,
    List<String>? genres,
    List<String>? directors,
    List<String>? cast,
    List<String>? countries,
    List<String>? keywords,
    List<String>? tags,
    this.watched = false,
    this.notes,
    DateTime? added,
  })  : id = id ?? newId(),
        genres = genres ?? [],
        directors = directors ?? [],
        cast = cast ?? [],
        countries = countries ?? [],
        keywords = keywords ?? [],
        tags = tags ?? [],
        added = added ?? DateTime.now();

  bool get matched => tmdbId != null || (imdbId != null && (overview?.isNotEmpty ?? false));

  /// IMDb rating when known, otherwise the TMDB score.
  double? get score => imdbRating ?? ((rating ?? 0) > 0 ? rating : null);

  Map<String, dynamic> toJson() => {
        'id': id,
        'driveId': driveId,
        'path': path,
        'sizeBytes': sizeBytes,
        'title': title,
        'originalTitle': originalTitle,
        'year': year,
        'tmdbId': tmdbId,
        'imdbId': imdbId,
        'overview': overview,
        'runtime': runtime,
        'rating': rating,
        'imdbRating': imdbRating,
        'imdbVotes': imdbVotes,
        'posterPath': posterPath,
        'posterUrl': posterUrl,
        'language': language,
        'collection': collection,
        'subGenre': subGenre,
        'genres': genres,
        'directors': directors,
        'cast': cast,
        'countries': countries,
        'keywords': keywords,
        'tags': tags,
        'watched': watched,
        'notes': notes,
        'added': added.toIso8601String(),
      };

  factory Movie.fromJson(Map<String, dynamic> j) => Movie(
        id: j['id'],
        title: j['title'] ?? '',
        driveId: j['driveId'],
        path: j['path'],
        sizeBytes: (j['sizeBytes'] as num?)?.toInt(),
        originalTitle: j['originalTitle'],
        year: (j['year'] as num?)?.toInt(),
        tmdbId: (j['tmdbId'] as num?)?.toInt(),
        imdbId: j['imdbId'],
        overview: j['overview'],
        runtime: (j['runtime'] as num?)?.toInt(),
        rating: (j['rating'] as num?)?.toDouble(),
        imdbRating: (j['imdbRating'] as num?)?.toDouble(),
        imdbVotes: (j['imdbVotes'] as num?)?.toInt(),
        posterPath: j['posterPath'],
        posterUrl: j['posterUrl'],
        language: j['language'],
        collection: j['collection'],
        subGenre: j['subGenre'],
        genres: _list(j['genres']),
        directors: _list(j['directors']),
        cast: _list(j['cast']),
        countries: _list(j['countries']),
        keywords: _list(j['keywords']),
        tags: _list(j['tags']),
        watched: j['watched'] == true,
        notes: j['notes'],
        added: DateTime.tryParse(j['added'] ?? ''),
      );
}
