import 'package:flutter/material.dart';

import '../archive.dart';
import '../models.dart';
import '../tmdb.dart';
import '../widgets.dart';

/// Edit any field by hand. Also used to add a movie that is not on TMDB.
class EditPage extends StatefulWidget {
  final Movie movie;
  const EditPage(this.movie, {super.key});
  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  late final Movie m = widget.movie;
  late final bool isNew = !archive.movies.contains(m);
  late final Map<String, TextEditingController> c = {
    'Title': TextEditingController(text: m.title),
    'Year': TextEditingController(text: m.year?.toString() ?? ''),
    'Original title': TextEditingController(text: m.originalTitle ?? ''),
    'Director': TextEditingController(text: m.directors.join(', ')),
    'Cast': TextEditingController(text: m.cast.join(', ')),
    'Genre': TextEditingController(text: m.genres.join(', ')),
    'Sub-genre': TextEditingController(text: m.subGenre ?? ''),
    'Collection / franchise': TextEditingController(text: m.collection ?? ''),
    'Language': TextEditingController(text: m.language ?? ''),
    'Country': TextEditingController(text: m.countries.join(', ')),
    'IMDb ID': TextEditingController(text: m.imdbId ?? ''),
    'My tags': TextEditingController(text: m.tags.join(', ')),
    'Notes': TextEditingController(text: m.notes ?? ''),
  };
  static const _lists = {'Director', 'Cast', 'Genre', 'Country', 'My tags'};

  Future<void> _save() async {
    String? s(String k) => c[k]!.text.trim().isEmpty ? null : c[k]!.text.trim();
    List<String> l(String k) => [for (final x in c[k]!.text.split(',')) if (x.trim().isNotEmpty) x.trim()];
    if (s('Title') == null) return;
    final oldImdb = m.imdbId;
    m
      ..title = s('Title')!
      ..year = int.tryParse(c['Year']!.text.trim())
      ..originalTitle = s('Original title')
      ..directors = l('Director')
      ..cast = l('Cast')
      ..genres = l('Genre')
      ..subGenre = s('Sub-genre')
      ..collection = s('Collection / franchise')
      ..language = s('Language')
      ..countries = l('Country')
      ..imdbId = s('IMDb ID') == null ? null : imdbIdIn(s('IMDb ID')!) ?? s('IMDb ID')
      ..tags = l('My tags')
      ..notes = s('Notes');
    isNew ? await archive.add(m) : await archive.save();
    if (!mounted) return;
    // A new IMDb ID: fetch everything for that movie.
    final imdb = m.imdbId;
    if (imdb != null && imdb != oldImdb && archive.canLookup) await lookupImdb(context, m, imdb);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(isNew ? 'Add movie' : 'Edit movie'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(onPressed: _save, child: const Text('Save')),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView(padding: const EdgeInsets.all(24), children: [
              for (final e in c.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextField(
                    controller: e.value,
                    autofocus: e.key == 'Title' && isNew,
                    keyboardType: e.key == 'Year' ? TextInputType.number : null,
                    maxLines: e.key == 'Notes' ? 4 : 1,
                    decoration: InputDecoration(
                      labelText: e.key,
                      helperText: _lists.contains(e.key)
                          ? 'Separate with commas'
                          : e.key == 'IMDb ID'
                              ? 'Paste an IMDb ID or link: all info is fetched when you save'
                              : null,
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );
}
