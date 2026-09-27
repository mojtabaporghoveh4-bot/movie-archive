import 'package:flutter_test/flutter_test.dart';
import 'package:movie_archive/models.dart';
import 'package:movie_archive/tmdb.dart';

void main() {
  test('apply copies TMDB details into a movie', () {
    final m = Movie(title: 'heat', tags: ['favorite']);
    Tmdb.apply(m, {
      'id': 949,
      'imdb_id': 'tt0113277',
      'title': 'Heat',
      'release_date': '1995-12-15',
      'original_language': 'en',
      'spoken_languages': [
        {'iso_639_1': 'es', 'english_name': 'Spanish'},
        {'iso_639_1': 'en', 'english_name': 'English'},
      ],
      'belongs_to_collection': null,
      'genres': [{'name': 'Crime'}, {'name': 'Drama'}],
      'keywords': {'keywords': [{'name': 'Heist'}, {'name': 'los angeles'}]},
      'credits': {
        'crew': [{'job': 'Producer', 'name': 'Art Linson'}, {'job': 'Director', 'name': 'Michael Mann'}],
        'cast': [{'name': 'Al Pacino'}, {'name': 'Robert De Niro'}],
      },
    });
    expect([m.title, m.year, m.imdbId, m.language, m.subGenre], ['Heat', 1995, 'tt0113277', 'English', 'Heist']);
    expect([...m.directors, ...m.cast, ...m.genres, ...m.tags],
        ['Michael Mann', 'Al Pacino', 'Robert De Niro', 'Crime', 'Drama', 'favorite']);
  });
}
