part of '../main.dart';

// ─────────────────────────────────────────────────────────────
// RANKINGS (Boss Blitz y Joint Drill) — mismos datos que StellaBase
// ─────────────────────────────────────────────────────────────

enum RankingKind {
  scoreBoss, // Boss Blitz
  jointDrill,
}

class RankingsPage extends StatefulWidget {
  const RankingsPage({super.key});

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

class _RankingsPageState extends State<RankingsPage> {
  RankingKind _kind = RankingKind.scoreBoss;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _rootAppBar('Rankings'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: _Segmented(
              labels: const ['BOSS BLITZ', 'JOINT DRILL'],
              index: _kind.index,
              onChanged: (i) => setState(() => _kind = RankingKind.values[i]),
            ),
          ),
          Expanded(child: _RankingBody(key: ValueKey(_kind), kind: _kind)),
        ],
      ),
    );
  }
}

class RankingListPage extends StatelessWidget {
  const RankingListPage({super.key, required this.kind});
  final RankingKind kind;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _subAppBar(kind == RankingKind.scoreBoss ? 'Ranking de Boss Blitz' : 'Ranking de Joint Drill'),
    body: _RankingBody(kind: kind),
  );
}

class _RankingBody extends StatefulWidget {
  const _RankingBody({super.key, required this.kind});
  final RankingKind kind;

  @override
  State<_RankingBody> createState() => _RankingBodyState();
}

class _RankingBodyState extends State<_RankingBody> {
  static const _regions = ['EN', 'JP', 'KR', 'TW'];
  String region = 'EN';
  String search = '';
  int? expanded;

  String get _endpoint =>
      '${widget.kind == RankingKind.scoreBoss ? 'boss-blitz-ranking' : 'joint-drill-ranking'}?region=$region';

  /// Todos los equipos de una entrada (Boss Blitz tiene dos, Joint Drill uno).
  List<Map<String, dynamic>> _teams(Map<String, dynamic> e) {
    final teams = _asList(e['teams']).map(_asMap).toList();
    if (teams.isNotEmpty) return teams;
    final t = _asMap(e['team']);
    return t.isEmpty ? [] : [t];
  }

  @override
  Widget build(BuildContext context) {
    return _Loader<dynamic>(
      key: ValueKey(_endpoint),
      load: (refresh) => Api.site(_endpoint, refresh: refresh),
      builder: (context, data, refresh) {
        final ranking = _asMap(_asMap(data)['ranking']);
        final entries = _asList(ranking['entries']).map(_asMap).toList();
        final total = _string(ranking['total'], '0');
        final refreshed = _parseDate(ranking['refreshedAt']);
        final scores = entries.map((e) => (e['score'] as num?)?.toInt() ?? 0).toList();
        final sorted = [...scores]..sort();
        final median = sorted.isEmpty ? 0 : sorted[sorted.length ~/ 2];

        // Trekkers y discos más usados en el top 100
        final charCount = <String, (Map<String, dynamic>, int)>{};
        final discCount = <String, (Map<String, dynamic>, int)>{};
        var runs = 0;
        for (final e in entries) {
          for (final t in _teams(e)) {
            runs++;
            for (final c in _asList(t['chars']).map(_asMap)) {
              final k = _string(c['id']);
              charCount[k] = (c, (charCount[k]?.$2 ?? 0) + 1);
            }
            for (final d in _asList(t['discs']).map(_asMap)) {
              final k = _string(d['id']);
              discCount[k] = (d, (discCount[k]?.$2 ?? 0) + 1);
            }
          }
        }
        final topChars = charCount.values.toList()..sort((a, b) => b.$2.compareTo(a.$2));
        final topDiscs = discCount.values.toList()..sort((a, b) => b.$2.compareTo(a.$2));

        final q = search.toLowerCase();
        final filtered = q.isEmpty
            ? entries
            : entries.where((e) {
                if (_string(e['nickname']).toLowerCase().contains(q)) return true;
                return _teams(e).any((t) =>
                    _asList(t['chars']).map(_asMap).any((c) => _string(c['name']).toLowerCase().contains(q)));
              }).toList();

        return RefreshIndicator(
          color: kInk,
          backgroundColor: kPaper,
          onRefresh: refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              Row(children: [
                for (final r in _regions)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => setState(() {
                        region = r;
                        expanded = null;
                      }),
                      child: _Tag(r, filled: r == region),
                    ),
                  ),
                const Spacer(),
                if (refreshed != null)
                  Text('ACTUALIZADO ${_ago(refreshed)}',
                      style: const TextStyle(fontSize: 9.5, color: kTextMuted, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.3,
                children: [
                  _stat('Clasificados', _formatNumber(total)),
                  _stat('Primero', _formatNumber('${sorted.isEmpty ? 0 : sorted.last}')),
                  _stat('Puesto 100', _formatNumber('${sorted.isEmpty ? 0 : sorted.first}')),
                  _stat('Mediana top 100', _formatNumber('$median')),
                ],
              ),
              const SizedBox(height: 14),
              if (topChars.isNotEmpty)
                _Panel(
                  title: 'Más usados',
                  badge: '$runs partidas del top 100',
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TREKKERS · ${topChars.length}', style: kDisplay(15)),
                      const SizedBox(height: 8),
                      for (final c in topChars.take(5)) _usageRow(_string(c.$1['icon']), _string(c.$1['name']), c.$2 / runs),
                      if (topDiscs.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('DISCOS · ${topDiscs.length}', style: kDisplay(15)),
                        const SizedBox(height: 8),
                        for (final d in topDiscs.take(5))
                          _usageRow(_string(d.$1['icon']), _string(d.$1['name']), d.$2 / runs, disc: true),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              TextField(
                onChanged: (v) => setState(() => search = v.trim()),
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Buscar jugador o trekker…',
                  hintStyle: TextStyle(fontSize: 12, color: kTextMuted),
                  prefixIcon: Icon(Icons.search, size: 18, color: kTextMuted),
                  isDense: true,
                  filled: true,
                  fillColor: kPanelBg,
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero, borderSide: BorderSide(color: kBorderHighlight, width: 2)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero, borderSide: BorderSide(color: kBorderHighlight, width: 2)),
                ),
              ),
              const SizedBox(height: 10),
              if (filtered.isEmpty) const _EmptyNote('Sin resultados'),
              for (var i = 0; i < filtered.length; i++) _entry(filtered[i], i),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String label, String value) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: kPanelBg, border: Border.all(color: kBorderHighlight, width: 2)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.3, color: kTextMuted)),
        FittedBox(child: Text(value, style: kDisplay(22))),
      ],
    ),
  );

  Widget _usageRow(String icon, String name, double pct, {bool disc = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      _Thumb(icon, size: 30, fallbackIcon: disc ? Icons.album_outlined : Icons.person_outline),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Container(
            height: 5,
            color: kMuted,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(widthFactor: pct.clamp(0, 1), child: Container(color: kTextPrimary)),
          ),
        ]),
      ),
      const SizedBox(width: 8),
      SizedBox(width: 38, child: Text('${(pct * 100).round()}%', textAlign: TextAlign.right, style: kDisplay(15))),
    ]),
  );

  Widget _entry(Map<String, dynamic> e, int i) {
    final rank = (e['rank'] as num?)?.toInt() ?? i + 1;
    final avatar = _string(e['avatar']);
    final avatarPath = avatar.length > 5 ? 'item_$avatar.png' : 'head_${avatar}_XL.png';
    final teams = _teams(e);
    final open = expanded == rank;
    final medal = rank == 1
        ? const Color(0xffeacb3e)
        : rank == 2
        ? const Color(0xffc9c6c0)
        : rank == 3
        ? const Color(0xffc8803e)
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: kPanelBg, border: Border.all(color: open ? kBorderHighlight : kBorderColor, width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => expanded = open ? null : rank),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  color: medal ?? kMuted,
                  child: Text('$rank', style: kDisplay(18, color: medal != null ? kInk : kTextPrimary)),
                ),
                const SizedBox(width: 10),
                _Thumb(avatarPath, size: 38, alt: ['head_${avatar}_XL.png', 'item_$avatar.png']),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_string(e['nickname'], '—'),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 4),
                    Row(children: [
                      for (final c in teams.isEmpty ? const <Map<String, dynamic>>[] : _asList(teams.first['chars']).map(_asMap))
                        Padding(padding: const EdgeInsets.only(right: 4), child: _Thumb(_string(c['icon']), size: 24)),
                    ]),
                  ]),
                ),
                Text(_formatNumber(_string(e['score'])), style: kDisplay(18)),
                Icon(open ? Icons.expand_less : Icons.expand_more, color: kTextMuted, size: 20),
              ]),
            ),
          ),
          if (open)
            for (var t = 0; t < teams.length; t++) _team(teams[t], t, teams.length > 1),
        ],
      ),
    );
  }

  Widget _team(Map<String, dynamic> t, int index, bool numbered) {
    final chars = _asList(t['chars']).map(_asMap).toList();
    final discs = _asList(t['discs']).map(_asMap).toList();
    final notes = _asList(t['notes']).map(_asMap).toList();
    final score = _string(t['score']);
    final buildScore = _string(t['buildScore']);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: kBorderColor))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(numbered ? 'EQUIPO ${index + 1}' : 'EQUIPO', style: kDisplay(15)),
            const Spacer(),
            if (score.isNotEmpty) Text(_formatNumber(score), style: kDisplay(15)),
            if (buildScore.isNotEmpty) _Tag('Build $buildScore'),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in chars)
              SizedBox(
                width: 64,
                child: Column(children: [
                  _Thumb(_string(c['icon']), size: 52),
                  const SizedBox(height: 3),
                  Text(_string(c['name']),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                  Text('NV. ${_string(c['level'])}', style: const TextStyle(fontSize: 9, color: kTextMuted)),
                ]),
              ),
          ]),
          if (discs.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('DISCOS', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 1.3, color: kTextMuted)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final d in discs)
                Tooltip(
                  message: _string(d['name']),
                  child: _Thumb(_string(d['icon']), size: 44, fallbackIcon: Icons.album_outlined),
                ),
            ]),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('MELODÍAS', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 1.3, color: kTextMuted)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final n in notes) _Tag('${_string(n['name']).replaceFirst('Melody of ', '')} ×${_string(n['qty'])}', color: kTextMuted),
            ]),
          ],
        ],
      ),
    );
  }
}

String _formatNumber(String raw) {
  final n = int.tryParse(raw.replaceAll(RegExp(r'[^0-9-]'), ''));
  if (n == null) return raw;
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${n < 0 ? '-' : ''}$buf';
}
