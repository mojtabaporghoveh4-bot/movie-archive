import 'package:flutter/material.dart';

import '../archive.dart';
import '../models.dart';
import '../tmdb.dart';
import '../widgets.dart';
import 'detail.dart';
import 'edit.dart';

/// Search TMDB by title or IMDb ID. Adds a new movie, or (with [forMovie]) fixes its match.
class LookupPage extends StatefulWidget {
  final Movie? forMovie;
  const LookupPage({super.key, this.forMovie});
  @override
  State<LookupPage> createState() => _LookupPageState();
}

class _LookupPageState extends State<LookupPage> {
  late final _text = TextEditingController(text: widget.forMovie?.imdbId ?? widget.forMovie?.title ?? '');
  late final _year = TextEditingController(text: widget.forMovie?.year?.toString() ?? '');
  List<SearchResult>? results;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.forMovie != null) _search();
  }

  Future<void> _search() async {
    final t = archive.tmdb;
    if (t == null) return toast(context, 'Add your free TMDB key in Settings to search online.');
    if (_text.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      final r = await t.lookup(_text.text, year: int.tryParse(_year.text.trim()));
      setState(() => results = r);
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _pick(SearchResult r) async {
    final target = widget.forMovie ?? Movie(title: r.title);
    final ok = await withProgress(context, 'Getting movie info', (_) async {
      await archive.fetchInfo(target, tmdbId: r.id);
      widget.forMovie == null ? await archive.add(target) : await archive.save();
      return true;
    });
    if (ok != true || !mounted) return;
    if (widget.forMovie != null) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DetailPage(target)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final owned = {for (final m in archive.movies) m.tmdbId};
    return Scaffold(
      appBar: AppBar(title: Text(widget.forMovie == null ? 'Add movie' : 'Change match')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    autofocus: widget.forMovie == null,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Movie title or IMDb ID (tt0111161)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _year,
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(hintText: 'Year'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: busy ? null : _search, child: const Text('Search')),
              ]),
            ),
            if (busy) const LinearProgressIndicator(),
            Expanded(
              child: results == null
                  ? EmptyState(
                      Icons.travel_explore,
                      'Find a movie',
                      'Type a title or an IMDb ID. Info and posters come from TMDB.',
                      action: widget.forMovie == null
                          ? OutlinedButton.icon(
                              icon: const Icon(Icons.edit_note),
                              label: const Text('Add by hand instead'),
                              onPressed: () => Navigator.pushReplacement(context,
                                  MaterialPageRoute(builder: (_) => EditPage(Movie(title: _text.text.trim())))),
                            )
                          : null,
                    )
                  : results!.isEmpty
                      ? const EmptyState(Icons.search_off, 'No results', 'Check the spelling, or remove the year.')
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: results!.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final r = results![i];
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => _pick(r),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    SizedBox(
                                      width: 60,
                                      child: Poster(Movie(title: r.title, posterPath: r.posterPath), radius: 6),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Row(children: [
                                          Flexible(
                                            child: Text('${r.title}${r.year != null ? ' (${r.year})' : ''}',
                                                style: Theme.of(context).textTheme.titleMedium),
                                          ),
                                          if (owned.contains(r.id)) ...[
                                            const SizedBox(width: 8),
                                            const Chip(label: Text('In archive'), visualDensity: VisualDensity.compact),
                                          ],
                                        ]),
                                        const SizedBox(height: 4),
                                        Text(r.overview, maxLines: 3, overflow: TextOverflow.ellipsis),
                                      ]),
                                    ),
                                  ]),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ]),
        ),
      ),
    );
  }
}
