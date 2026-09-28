import 'package:flutter/material.dart';

import '../archive.dart';
import '../models.dart';
import '../widgets.dart';
import 'lookup.dart';

class LibraryPage extends StatefulWidget {
  final Facet? facet;
  final String? value;
  const LibraryPage({super.key, this.facet, this.value});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late final MovieQuery q = MovieQuery(widget.facet, widget.value);
  final _search = TextEditingController();

  bool get _grid => archive.prefs.getBool('grid') ?? true;
  set _grid(bool v) => archive.prefs.setBool('grid', v).then((_) => setState(() {}));

  Future<void> _fetchMissing() async {
    final todo = archive.movies.where((m) => !m.matched).toList();
    if (todo.isEmpty) return toast(context, 'All movies already have info.');
    if (!archive.canLookup) return toast(context, 'Add a free TMDB or OMDb key in Settings first.');
    final found = await withProgress(context, 'Finding movie info', (update) => archive.fetchMany(todo, update));
    if (found == null) return;
    if (mounted) toast(context, 'Found info for $found of ${todo.length} movies.');
  }

  Future<void> _export(List<Movie> list) async {
    if (await saveTextFile('movies.csv', archive.toCsv(list)) && mounted) {
      toast(context, 'Saved ${list.length} movies as a spreadsheet.');
    }
  }

  Future<void> _addFilter() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(heightFactor: 0.8, child: FilterSheet(q)),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: archive,
        builder: (context, _) {
          final list = archive.query(q);
          final unmatched = archive.movies.where((m) => !m.matched).length;
          final title = widget.facet == null ? 'Library' : widget.value!;
          return Scaffold(
            appBar: AppBar(
              title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title),
                Text('${list.length} movies', style: Theme.of(context).textTheme.bodySmall),
              ]),
              actions: [
                IconButton(
                  tooltip: _grid ? 'List view' : 'Poster view',
                  icon: Icon(_grid ? Icons.view_list_outlined : Icons.grid_view_outlined),
                  onPressed: () => _grid = !_grid,
                ),
                PopupMenuButton<SortBy>(
                  tooltip: 'Sort',
                  icon: const Icon(Icons.sort),
                  initialValue: q.sort,
                  onSelected: (s) => setState(() => q.sort = s),
                  itemBuilder: (_) => [for (final s in SortBy.values) PopupMenuItem(value: s, child: Text(s.label))],
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => switch (v) {
                    'fetch' => _fetchMissing(),
                    'unmatched' => setState(() => q.onlyUnmatched = !q.onlyUnmatched),
                    'dups' => setState(() => q.onlyDuplicates = !q.onlyDuplicates),
                    _ => _export(list),
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'fetch',
                      enabled: unmatched > 0,
                      child: ListTile(
                          leading: const Icon(Icons.cloud_download_outlined),
                          title: Text('Find info & posters ($unmatched)')),
                    ),
                    CheckedPopupMenuItem(value: 'unmatched', checked: q.onlyUnmatched, child: const Text('Only movies without info')),
                    CheckedPopupMenuItem(value: 'dups', checked: q.onlyDuplicates, child: const Text('Only duplicates')),
                    const PopupMenuItem(
                        value: 'csv',
                        child: ListTile(leading: Icon(Icons.table_view_outlined), title: Text('Export this list (CSV)'))),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),
            floatingActionButton: widget.facet == null
                ? FloatingActionButton.extended(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LookupPage())),
                    icon: const Icon(Icons.add),
                    label: const Text('Add movie'),
                  )
                : null,
            body: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: SearchBar(
                  controller: _search,
                  hintText: 'Search title, director, actor, year, genre…',
                  leading: const Icon(Icons.search),
                  elevation: const WidgetStatePropertyAll(0),
                  trailing: [
                    if (q.text.isNotEmpty)
                      IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                                _search.clear();
                                q.text = '';
                              })),
                  ],
                  onChanged: (v) => setState(() => q.text = v),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                  ActionChip(avatar: const Icon(Icons.tune, size: 18), label: const Text('Filter'), onPressed: _addFilter),
                  for (final e in q.filters.entries)
                    for (final v in e.value)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: InputChip(
                          avatar: Icon(e.key.icon, size: 18),
                          label: Text(v),
                          onDeleted: () => setState(() {
                            e.value.remove(v);
                            q.filters.removeWhere((_, s) => s.isEmpty);
                          }),
                        ),
                      ),
                  if (q.onlyUnmatched)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: InputChip(label: const Text('Without info'), onDeleted: () => setState(() => q.onlyUnmatched = false)),
                    ),
                  if (q.onlyDuplicates)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: InputChip(label: const Text('Duplicates'), onDeleted: () => setState(() => q.onlyDuplicates = false)),
                    ),
                ]),
              ),
              const SizedBox(height: 4),
              Expanded(child: _results(list)),
            ]),
          );
        },
      );

  Widget _results(List<Movie> list) {
    if (archive.movies.isEmpty) {
      return EmptyState(
        Icons.video_library_outlined,
        'Your archive is empty',
        isDesktop
            ? 'Go to Drives and scan a folder or hard drive, or add a movie by hand.'
            : 'Import the archive file from your computer in Settings, or add a movie by hand.',
      );
    }
    if (list.isEmpty) return const EmptyState(Icons.search_off, 'No movies found', 'Try a different search or remove a filter.');
    if (!_grid) {
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: list.length,
        itemBuilder: (_, i) => MovieTile(list[i]),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        childAspectRatio: 0.52,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: list.length,
      itemBuilder: (_, i) => MovieCard(list[i]),
    );
  }
}

class FilterSheet extends StatefulWidget {
  final MovieQuery q;
  const FilterSheet(this.q, {super.key});
  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  Facet facet = Facet.genre;
  String find = '';

  @override
  Widget build(BuildContext context) {
    final values = archive.counts(facet).where((e) => e.key.toLowerCase().contains(find.toLowerCase())).toList();
    final chosen = widget.q.filters[facet] ?? {};
    return Column(children: [
      SizedBox(
        height: 44,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          for (final f in Facet.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(f.icon, size: 18),
                label: Text(f.label),
                selected: f == facet,
                onSelected: (_) => setState(() => facet = f),
              ),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Find a ${facet.label.toLowerCase()}'),
          onChanged: (v) => setState(() => find = v),
        ),
      ),
      Expanded(
        child: values.isEmpty
            ? Center(child: Text('Nothing here yet', style: TextStyle(color: Theme.of(context).colorScheme.outline)))
            : ListView.builder(
                itemCount: values.length,
                itemBuilder: (_, i) {
                  final e = values[i];
                  return CheckboxListTile(
                    value: chosen.contains(e.key),
                    title: Text(e.key),
                    secondary: Text('${e.value}'),
                    onChanged: (on) => setState(() {
                      final set = widget.q.filters.putIfAbsent(facet, () => {});
                      on! ? set.add(e.key) : set.remove(e.key);
                      widget.q.filters.removeWhere((_, s) => s.isEmpty);
                    }),
                  );
                },
              ),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Show movies')),
        ),
      ),
    ]);
  }
}
