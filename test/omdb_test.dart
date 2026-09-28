import 'package:flutter_test/flutter_test.dart';
import 'package:movie_archive/models.dart';
import 'package:movie_archive/omdb.dart';

void main() {
  final heat = {
    'Title': 'Heat',
    'Year': '1995',
    'Runtime': '170 min',
    'Genre': 'Action, Crime, Drama',
    'Director': 'Michael Mann',
    'Actors': 'Al Pacino, Robert De Niro, Val Kilmer',
    'Plot': 'A group of high-end professional thieves...',
    'Language': 'English, Spanish',
    'Country': 'United States',
    'Poster': 'https://m.media-amazon.com/images/M/heat.jpg',
    'imdbRating': '8.3',
    'imdbVotes': '733,213',
    'imdbID': 'tt0113277',
    'Response': 'True',
  };

  test('rating only keeps TMDB info', () {
    final m = Movie(title: 'Heat', directors: ['From TMDB']);
    Omdb.apply(m, heat, full: false);
    expect([m.imdbRating, m.imdbVotes, m.imdbId, m.score, ...m.directors], [8.3, 733213, 'tt0113277', 8.3, 'From TMDB']);
  });

  test('full fills everything and counts as matched', () {
    final m = Movie(title: 'heat');
    expect(m.matched, isFalse);
    Omdb.apply(m, heat, full: true);
    expect([m.title, m.year, m.runtime, m.language, m.posterUrl, m.matched],
        ['Heat', 1995, 170, 'English', 'https://m.media-amazon.com/images/M/heat.jpg', true]);
    expect([...m.genres, ...m.cast], ['Action', 'Crime', 'Drama', 'Al Pacino', 'Robert De Niro', 'Val Kilmer']);
  });
}
