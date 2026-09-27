import 'package:flutter/material.dart';

import '../archive.dart';
import 'library.dart';

class BrowsePage extends StatelessWidget {
  const BrowsePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Browse')),
      body: ListenableBuilder(
        listenable: archive,
        builder: (context, _) => GridView.extent(
          maxCrossAxisExtent: 260,
          childAspectRatio: 1.6,
          padding: const EdgeInsets.all(16),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final f in Facet.values)
              Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FacetPage(f))),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(f.icon, color: scheme.primary, size: 28),
                      const Spacer(),
                      Text(f.plural, style: Theme.of(context).textTheme.titleMedium),
                      Text('${archive.counts(f).length}', style: TextStyle(color: scheme.outline)),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// All values of one category (e.g. every director) with movie counts.
class FacetPage extends StatefulWidget {
  final Facet facet;
  const FacetPage(this.facet, {super.key});
  @override
  State<FacetPage> createState() => _FacetPageState();
}

class _FacetPageState extends State<FacetPage> {
  String find = '';

  @override
  Widget build(BuildContext context) {
    final f = widget.facet;
    final values = archive.counts(f).where((e) => e.key.toLowerCase().contains(find.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: Text(f.plural)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Find a ${f.label.toLowerCase()}'),
            onChanged: (v) => setState(() => find = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: values.length,
            itemBuilder: (_, i) => ListTile(
              leading: Icon(f.icon),
              title: Text(values[i].key),
              trailing: Text('${values[i].value}'),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => LibraryPage(facet: f, value: values[i].key))),
            ),
          ),
        ),
      ]),
    );
  }
}
