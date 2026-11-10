part of '../main.dart';

// ─────────────────────────────────────────────────────────────
// BIBLIOTECA EXTRA: Enemigos, Monolito, Emblemas,
// Builds de la comunidad y Registro de cambios
// ─────────────────────────────────────────────────────────────

/// Campo de búsqueda con el borde grueso de la web.
Widget _searchField(String hint, ValueChanged<String> onChanged) => TextField(
  onChanged: onChanged,
  style: const TextStyle(fontSize: 13),
  decoration: InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 12, color: kTextMuted),
    prefixIcon: const Icon(Icons.search, size: 18, color: kTextMuted),
    isDense: true,
    filled: true,
    fillColor: kPanelBg,
    enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero, borderSide: BorderSide(color: kBorderHighlight, width: 2)),
    focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero, borderSide: BorderSide(color: kBorderHighlight, width: 2)),
  ),
);

Widget _chipRow(List<String> labels, String selected, ValueChanged<String> onTap) => SizedBox(
  height: 30,
  child: ListView.separated(
    scrollDirection: Axis.horizontal,
    itemCount: labels.length,
    separatorBuilder: (_, _) => const SizedBox(width: 6),
    itemBuilder: (_, i) => InkWell(onTap: () => onTap(labels[i]), child: _Tag(labels[i], filled: labels[i] == selected)),
  ),
);

// ─────────────────────────────────────────────────────────────
// ENEMIGOS (bestiario)
// ─────────────────────────────────────────────────────────────

class EnemiesPage extends StatefulWidget {
  const EnemiesPage({super.key});

  @override
  State<EnemiesPage> createState() => _EnemiesPageState();
}

class _EnemiesPageState extends State<EnemiesPage> {
  String query = '';
  String type = 'TODOS';
  String element = 'TODOS';

  static const _types = {'TODOS': '', 'COMÚN': 'common', 'NORMAL': 'normal', 'ÉLITE': 'elite', 'JEFE': 'boss'};
  static const _elements = ['TODOS', 'ignis', 'aqua', 'ventus', 'terra', 'lux', 'umbra'];

  String _typeLabel(String t) =>
      _types.entries.firstWhere((e) => e.value == t, orElse: () => MapEntry(t.toUpperCase(), t)).key;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _subAppBar('Enemigos'),
    body: _Loader<dynamic>(
      load: (r) => Api.site('enemies', refresh: r),
      builder: (context, data, refresh) {
        final all = _asList(_asMap(data)['enemies']).map(_asMap).toList();
        final q = query.toLowerCase();
        final list = all.where((e) {
          if (q.isNotEmpty && !_string(e['name']).toLowerCase().contains(q)) return false;
          if (_types[type]!.isNotEmpty && _string(e['type']) != _types[type]) return false;
          if (element != 'TODOS' &&
              !_asList(e['element']).any((x) => '$x'.toLowerCase() == element)) {
            return false;
          }
          return true;
        }).toList();
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Column(children: [
              _searchField('Buscar enemigo…', (v) => setState(() => query = v.trim())),
              const SizedBox(height: 8),
              _chipRow(_types.keys.toList(), type, (v) => setState(() => type = v)),
              const SizedBox(height: 6),
              _chipRow([for (final e in _elements) e == 'TODOS' ? e : _elementLabel(e)],
                  element == 'TODOS' ? 'TODOS' : _elementLabel(element),
                  (v) => setState(() => element = v == 'TODOS' ? v : _elements.firstWhere((e) => _elementLabel(e) == v))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              Text('${list.length} DE ${all.length} ENEMIGOS',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: kTextMuted)),
            ]),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              color: kInk,
              backgroundColor: kPaper,
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.78,
                ),
                itemCount: list.length,
                itemBuilder: (_, i) => _card(list[i]),
              ),
            ),
          ),
        ]);
      },
    ),
  );

  Widget _card(Map<String, dynamic> e) {
    final elements = _asList(e['element']).map((x) => '$x').toList();
    final main = elements.isEmpty ? '' : elements.first;
    return InkWell(
      onTap: () => _detail(e),
      child: Container(
        decoration: BoxDecoration(color: kPanelBg, border: Border.all(color: kBorderColor, width: 2)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(height: 4, color: main.isEmpty ? kBorderColor : _elementColor(main)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _NetImage(_string(e['icon']), fit: BoxFit.contain, fallbackIcon: Icons.pest_control_outlined),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_string(e['name']),
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 4),
              Text(_typeLabel(_string(e['type'])),
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: kTextMuted)),
            ]),
          ),
        ]),
      ),
    );
  }

  void _detail(Map<String, dynamic> e) {
    Widget rating(String label, dynamic v) {
      final n = (v as num?)?.toInt() ?? 0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: kTextMuted))),
          for (var i = 0; i < 5; i++)
            Container(
              width: 22,
              height: 10,
              margin: const EdgeInsets.only(right: 3),
              color: i < n ? kTextPrimary : kMuted,
            ),
        ]),
      );
    }

    _showSheet(context, title: _string(e['name']), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Thumb(_string(e['icon']), size: 96, fit: BoxFit.contain, fallbackIcon: Icons.pest_control_outlined),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Tag(_typeLabel(_string(e['type'])), filled: true),
            const SizedBox(height: 10),
            rating('VIDA', e['hpRating']),
            rating('ATAQUE', e['atkRating']),
            rating('DEFENSA', e['defRating']),
          ]),
        ),
      ]),
      const SizedBox(height: 14),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final x in _asList(e['element'])) _Tag('Elemento: ${_elementLabel('$x')}', color: _elementColor('$x')),
        for (final x in _asList(e['weakness'])) _Tag('Débil a: ${_elementLabel('$x')}', color: _elementColor('$x'), filled: true),
      ]),
      const SizedBox(height: 14),
      Text(_cleanGameText(_string(e['description'])), style: const TextStyle(fontSize: 13, height: 1.5)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// MONOLITO (respuestas de los diálogos)
// ─────────────────────────────────────────────────────────────

class MonolithPage extends StatefulWidget {
  const MonolithPage({super.key});

  @override
  State<MonolithPage> createState() => _MonolithPageState();
}

class _MonolithPageState extends State<MonolithPage> {
  String query = '';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _subAppBar('Monolito'),
    body: _Loader<dynamic>(
      load: (r) => Api.site('monolith', refresh: r),
      builder: (context, data, refresh) {
        final all = _asList(_asMap(data)['questions']).map(_asMap).toList();
        final q = query.toLowerCase();
        final list = all
            .where((x) =>
                q.isEmpty ||
                _string(x['npcName']).toLowerCase().contains(q) ||
                _string(x['question']).toLowerCase().contains(q))
            .toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            const Text(
                'Respuestas correctas a las preguntas de los PNJ en el Monolito. '
                'Elegir la opción marcada da la mejor recompensa.',
                style: TextStyle(fontSize: 12.5, height: 1.45, color: kTextMuted)),
            const SizedBox(height: 12),
            _searchField('Buscar por personaje o pregunta…', (v) => setState(() => query = v.trim())),
            const SizedBox(height: 12),
            if (list.isEmpty) const _EmptyNote('Sin resultados'),
            for (final x in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _Panel(
                  title: _string(x['npcName']),
                  badge: 'Evento ${_string(x['eventId'])}',
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('«${_string(x['question'])}»', style: const TextStyle(fontSize: 13.5, height: 1.4, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    for (final o in _asList(x['options']).map(_asMap))
                      Container(
                        margin: const EdgeInsets.only(bottom: 5),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: o['isCorrect'] == true ? kAccentGreen : Colors.transparent,
                          border: Border.all(color: o['isCorrect'] == true ? kAccentGreen : kBorderColor, width: 1.5),
                        ),
                        child: Row(children: [
                          Icon(o['isCorrect'] == true ? Icons.check : Icons.close,
                              size: 15, color: o['isCorrect'] == true ? kInk : kTextMuted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_string(o['text']),
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: o['isCorrect'] == true ? FontWeight.w700 : FontWeight.w400,
                                    color: o['isCorrect'] == true ? kInk : kTextMuted)),
                          ),
                        ]),
                      ),
                  ]),
                ),
              ),
          ],
        );
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// EMBLEMAS
// ─────────────────────────────────────────────────────────────

class EmblemsPage extends StatelessWidget {
  const EmblemsPage({super.key});

  static String _faction(String f) {
    switch (f) {
      case 'Grace Imperium':
        return 'Imperio de la Gracia';
      case 'Trekker Association':
        return 'Asociación de Trekkers';
      case 'Imperial Guard':
        return 'Guardia Imperial';
      default:
        return f;
    }
  }

  static String _shape(String s) =>
      const {'spike': 'Púa', 'rhombus': 'Rombo', 'starlight': 'Luz estelar'}[s] ?? s;

  static String _tag(String t) => const {
    'Stats': 'Atributos',
    'Skill Level': 'Nivel de habilidad',
    'Generic Potential': 'Potencial genérico',
    'Main Trekker Potential': 'Potencial del principal',
    'Support Trekker Potential': 'Potencial de apoyo',
  }[t] ?? t;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _subAppBar('Emblemas'),
    body: _Loader<dynamic>(
      load: (r) => Api.site('emblems', refresh: r),
      builder: (context, data, refresh) {
        final list = _asList(_asMap(data)['emblems']).map(_asMap).toList();
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.8,
          ),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final e = list[i];
            return InkWell(
              onTap: () => _detail(context, e),
              child: Container(
                decoration: BoxDecoration(color: kPanelBg, border: Border.all(color: kBorderColor, width: 2)),
                padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: _NetImage(_string(e['background']), fit: BoxFit.contain, fallbackIcon: Icons.shield_outlined)),
                  const SizedBox(height: 8),
                  Text(_string(e['name']),
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 3),
                  Text('${_shape(_string(e['shape'])).toUpperCase()} · ${_faction(_string(e['factionName'])).toUpperCase()}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: kTextMuted)),
                ]),
              ),
            );
          },
        );
      },
    ),
  );

  void _detail(BuildContext context, Map<String, dynamic> e) {
    final affixes = _asList(e['affixes']).map(_asMap).toList();
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final a in affixes) {
      groups.putIfAbsent(_string(a['tagName']), () => []).add(a);
    }
    String fmt(Map<String, dynamic> a, dynamic v) {
      final mode = _string(a['mode']);
      if (mode == 'percent') return '$v%';
      if (mode == 'level') return '+$v';
      return _formatNumber('$v');
    }

    _showSheet(context, title: _string(e['name']), children: [
      Row(children: [
        _Thumb(_string(e['background']), size: 84, fit: BoxFit.contain, fallbackIcon: Icons.shield_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            _Tag(_shape(_string(e['shape'])), filled: true),
            _Tag(_faction(_string(e['factionName']))),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      Text(_cleanGameText(_string(e['description'])), style: const TextStyle(fontSize: 12.5, height: 1.45, color: kTextMuted)),
      const SizedBox(height: 14),
      const Text('Valores por rareza: R1 · R2 · R3 · R4',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: kTextMuted)),
      for (final g in groups.entries) ...[
        const SizedBox(height: 14),
        Text(_tag(g.key).toUpperCase(), style: kDisplay(17)),
        const SizedBox(height: 6),
        for (final a in g.value)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorderColor))),
            child: Row(children: [
              Expanded(child: Text(_string(a['name']), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
              Text(
                  _asList(a['values']).map(_asMap).map((v) => fmt(a, v['value'])).join(' · '),
                  style: const TextStyle(fontSize: 11.5, color: kTextMuted)),
            ]),
          ),
      ],
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// BUILDS DE LA COMUNIDAD
// ─────────────────────────────────────────────────────────────

class CommunityBuildsPage extends StatefulWidget {
  const CommunityBuildsPage({super.key});

  @override
  State<CommunityBuildsPage> createState() => _CommunityBuildsPageState();
}

class _CommunityBuildsPageState extends State<CommunityBuildsPage> {
  String query = '';
  int sort = 0; // 0 recientes, 1 mejor valoradas, 2 más vistas

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _subAppBar('Builds de la comunidad'),
    body: _Loader<List<dynamic>>(
      load: (r) => Future.wait([Api.site('builds', refresh: r), Api.get('characters'), Api.get('discs')]),
      builder: (context, data, refresh) {
        final chars = {for (final c in _asList(data[1]).map(_asMap)) _string(c['id']): c};
        final discs = {for (final d in _asList(data[2]).map(_asMap)) _string(d['id']): d};
        final q = query.toLowerCase();
        final list = _asList(_asMap(data[0])['builds']).map(_asMap).where((b) {
          if (q.isEmpty) return true;
          if (_string(b['name']).toLowerCase().contains(q)) return true;
          return _asList(b['trekkerIds']).any((id) => _string(chars['$id']?['name']).toLowerCase().contains(q));
        }).toList();
        if (sort == 1) {
          list.sort((a, b) => ((b['ratingScore'] as num?) ?? 0).compareTo((a['ratingScore'] as num?) ?? 0));
        } else if (sort == 2) {
          list.sort((a, b) => ((b['viewCount'] as num?) ?? 0).compareTo((a['viewCount'] as num?) ?? 0));
        }
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Column(children: [
              _searchField('Buscar build o trekker…', (v) => setState(() => query = v.trim())),
              const SizedBox(height: 8),
              _Segmented(
                labels: const ['RECIENTES', 'VALORADAS', 'MÁS VISTAS'],
                index: sort,
                onChanged: (i) => setState(() => sort = i),
              ),
            ]),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              color: kInk,
              backgroundColor: kPaper,
              child: list.isEmpty
                  ? ListView(children: const [_EmptyNote('Sin builds')])
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _card(list[i], chars, discs),
                    ),
            ),
          ),
        ]);
      },
    ),
  );

  Widget _card(Map<String, dynamic> b, Map<String, Map<String, dynamic>> chars, Map<String, Map<String, dynamic>> discs) {
    final mainId = _string(b['mainTrekkerId']);
    final trekkers = _asList(b['trekkerIds']).map((x) => '$x').toList();
    final discIds = _asList(b['discIds']).map((x) => '$x').toList();
    final updated = _parseDate(b['updatedAt']);
    return InkWell(
      onTap: () => _detail(_string(b['shortId']), chars, discs),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: kPanelBg, border: Border.all(color: kBorderColor, width: 2)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_string(b['name'], 'Sin nombre').toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis, style: kDisplay(18)),
          const SizedBox(height: 8),
          Row(children: [
            for (final t in trekkers)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: t == mainId ? kTextPrimary : Colors.transparent, width: 2)),
                  child: _Thumb(_charHead(t), size: 42),
                ),
              ),
            const SizedBox(width: 6),
            for (final d in discIds.take(3))
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _Thumb(_string(discs[d]?['icon']), size: 34, fallbackIcon: Icons.album_outlined),
              ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.visibility_outlined, size: 13, color: kTextMuted),
            const SizedBox(width: 3),
            Text(_string(b['viewCount'], '0'), style: const TextStyle(fontSize: 11, color: kTextMuted)),
            const SizedBox(width: 10),
            const Icon(Icons.thumb_up_alt_outlined, size: 13, color: kTextMuted),
            const SizedBox(width: 3),
            Text(_string(b['ratingScore'], '0'), style: const TextStyle(fontSize: 11, color: kTextMuted)),
            const Spacer(),
            if (updated != null) Text(_ago(updated), style: const TextStyle(fontSize: 10, color: kTextMuted, fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
    );
  }

  void _detail(String id, Map<String, Map<String, dynamic>> chars, Map<String, Map<String, dynamic>> discs) {
    _showSheet(context, title: 'Build', children: [
      FutureBuilder<dynamic>(
        future: Api.site('builds/$id'),
        builder: (context, snap) {
          if (snap.hasError) return const _EmptyNote('No se pudo cargar la build');
          if (!snap.hasData) return const Padding(padding: EdgeInsets.all(30), child: _Spinner());
          final b = _asMap(_asMap(snap.data)['build']);
          final slots = _asMap(b['slots']);
          final main = _asList(b['discsMain']).map((x) => '$x').toList();
          final subs = _asList(b['discsSubs']).map((x) => '$x').toList();
          Widget slot(String label, Map<String, dynamic> s) {
            final c = chars[_string(s['trekkerId'])];
            final pots = _asList(s['potentials']).map(_asMap).toList();
            final core = pots.where((p) => p['priority'] == 'core').length;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: kBorderColor, width: 1.5)),
              child: Row(children: [
                _Thumb(_charHead(s['trekkerId']), size: 52),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.3, color: kTextMuted)),
                    Text(_string(c?['name'], '—').toUpperCase(), style: kDisplay(18)),
                    Text('${pots.length} potenciales · $core clave',
                        style: const TextStyle(fontSize: 11, color: kTextMuted)),
                  ]),
                ),
                if (c != null) _Tag(_elementLabel(_string(c['element'])), color: _elementColor(_string(c['element']))),
              ]),
            );
          }

          Widget discRow(String label, List<String> ids) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: kDisplay(16)),
            const SizedBox(height: 6),
            for (final d in ids)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  _Thumb(_string(discs[d]?['icon']), size: 40, fallbackIcon: Icons.album_outlined),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_string(discs[d]?['name'], d), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                ]),
              ),
          ]);

          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(_string(b['name']).toUpperCase(), style: kDisplay(24)),
            const SizedBox(height: 12),
            if (slots['main'] != null) slot('PRINCIPAL', _asMap(slots['main'])),
            if (slots['support1'] != null) slot('APOYO 1', _asMap(slots['support1'])),
            if (slots['support2'] != null) slot('APOYO 2', _asMap(slots['support2'])),
            const SizedBox(height: 8),
            if (main.isNotEmpty) discRow('DISCOS PRINCIPALES', main),
            if (subs.isNotEmpty) ...[const SizedBox(height: 8), discRow('DISCOS SECUNDARIOS', subs)],
            if (_string(b['notes']).isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('NOTAS DEL AUTOR', style: kDisplay(16)),
              const SizedBox(height: 6),
              Text(_string(b['notes']), style: const TextStyle(fontSize: 12.5, height: 1.45)),
            ],
            if (_asMap(b['forkedFrom']).isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Basada en: ${_string(_asMap(b['forkedFrom'])['name'])}',
                  style: const TextStyle(fontSize: 11, color: kTextMuted)),
            ],
          ]);
        },
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// REGISTRO DE CAMBIOS (versiones de datos)
// ─────────────────────────────────────────────────────────────

class ChangelogPage extends StatelessWidget {
  const ChangelogPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _subAppBar('Registro de cambios'),
    body: _Loader<dynamic>(
      load: (r) => Api.site('changelog', refresh: r),
      builder: (context, data, refresh) {
        final versions = _asList(_asMap(data)['versions']).map(_asMap).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            const Text('Cada entrada es una actualización de los datos del juego que usa la base de datos.',
                style: TextStyle(fontSize: 12.5, height: 1.45, color: kTextMuted)),
            const SizedBox(height: 12),
            for (final (i, v) in versions.indexed)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: i == 0 ? kPaper : kPanelBg,
                  border: Border.all(color: i == 0 ? kPaper : kBorderColor, width: 2),
                ),
                child: Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_shortDate(_parseDate(v['date'])), style: kDisplay(18, color: i == 0 ? kInk : kTextPrimary)),
                    Text(_string(v['short']).toUpperCase(),
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: i == 0 ? kInk : kTextMuted)),
                  ]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        _string(v['label']).isEmpty ? 'Actualización de datos del juego' : _string(v['label']),
                        style: TextStyle(fontSize: 12.5, color: i == 0 ? kInk : kTextPrimary)),
                  ),
                  if (i == 0) const _Tag('Última', color: kInk, filled: true),
                ]),
              ),
          ],
        );
      },
    ),
  );
}
