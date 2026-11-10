part of '../main.dart';

// ─────────────────────────────────────────────────────────────
// COMBATE: Joint Drill (raids), Boss Blitz y Jefe mundial
// ─────────────────────────────────────────────────────────────

String _difficultyName(String v) {
  switch (v.toLowerCase()) {
    case 'normal':
      return 'Normal';
    case 'hard':
      return 'Difícil';
    case 'very hard':
      return 'Muy difícil';
    case 'nightmare':
      return 'Pesadilla';
    case 'hell':
      return 'Infierno';
    case 'abyss':
      return 'Abismo';
    default:
      return v;
  }
}

String _seasonStatus(DateTime? start, DateTime? end) {
  final now = DateTime.now();
  if (start != null && now.isBefore(start)) return 'EMPIEZA EN ${_remaining(start)}';
  if (end != null && now.isBefore(end)) return 'TERMINA EN ${_remaining(end)}';
  return 'FINALIZADO';
}

bool _isLive(dynamic start, dynamic end) {
  final s = _parseDate(start);
  final e = _parseDate(end);
  final now = DateTime.now();
  return s != null && e != null && !now.isBefore(s) && now.isBefore(e);
}

/// Selector horizontal de temporadas/rotaciones.
class _SeasonPicker extends StatelessWidget {
  const _SeasonPicker({required this.labels, required this.index, required this.onChanged, this.live = const {}});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final Set<int> live;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 38,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      itemCount: labels.length,
      separatorBuilder: (_, _) => const SizedBox(width: 6),
      itemBuilder: (_, i) => InkWell(
        onTap: () => onChanged(i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: i == index ? kTextPrimary : Colors.transparent,
            border: Border.all(color: i == index ? kTextPrimary : kBorderColor, width: 2),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (live.contains(i)) ...[
              Container(width: 6, height: 6, color: kAccentGreen),
              const SizedBox(width: 6),
            ],
            Text(labels[i],
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: i == index ? kInk : kTextPrimary)),
          ]),
        ),
      ),
    ),
  );
}

/// Cabecera grande con imagen de fondo, estilo cartel de la web.
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.image, required this.title, required this.status, this.subtitle, this.dates});
  final String image;
  final String title;
  final String status;
  final String? subtitle;
  final String? dates;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(border: Border.all(color: kBorderHighlight, width: 2)),
    child: Stack(
      children: [
        Positioned.fill(child: _NetImage(image)),
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x330e0c0a), Color(0xf00e0c0a)],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 60, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                _Tag(status, filled: !status.startsWith('FIN')),
                if (dates != null) _Tag(dates!, color: kTextPrimary),
              ]),
              const SizedBox(height: 10),
              Text(title.toUpperCase(), style: kDisplay(30)),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(subtitle!, style: const TextStyle(fontSize: 12.5, height: 1.4, color: kTextPrimary)),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _itemChip(Map<String, dynamic> item, {String? qty, String? sub}) => Container(
  padding: const EdgeInsets.all(8),
  decoration: BoxDecoration(color: kSurface, border: Border.all(color: kBorderColor)),
  child: Row(children: [
    _itemThumb(item['itemId'] ?? item['id'], size: 34),
    const SizedBox(width: 10),
    Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_string(item['name']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
        if (sub != null && sub.isNotEmpty)
          Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: kTextMuted)),
      ]),
    ),
    if (qty != null) Text(qty, style: kDisplay(16)),
  ]),
);

Widget _shopList(Map<String, dynamic> shop) {
  final goods = _asList(shop['goods']).map(_asMap).toList()
    ..sort((a, b) => ((a['order'] as num?) ?? 0).compareTo((b['order'] as num?) ?? 0));
  if (goods.isEmpty) return const SizedBox.shrink();
  final currency = _asMap(shop['currency']);
  var clear = 0;
  for (final g in goods) {
    clear += ((g['price'] as num?)?.toInt() ?? 0) * (((g['limit'] as num?)?.toInt() ?? 0) == 0 ? 1 : (g['limit'] as num).toInt());
  }
  return _Panel(
    title: 'Tienda',
    badge: 'ショップ',
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          _itemThumb(currency['itemId'], size: 26, fallbackIcon: Icons.toll_outlined),
          const SizedBox(width: 8),
          Expanded(child: Text(_string(currency['name']).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('VACIARLA CUESTA', style: TextStyle(fontSize: 8.5, color: kTextMuted, fontWeight: FontWeight.w700)),
            Text(_formatNumber('$clear'), style: kDisplay(17)),
          ]),
        ]),
        const SizedBox(height: 10),
        for (final g in goods)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _itemChip(
              g,
              qty: '×${_formatNumber(_string(g['quantity']))}',
              sub: '${_formatNumber(_string(g['price']))} ${_string(currency['name'])}'
                  '${(g['limit'] as num?) != null && (g['limit'] as num) > 0 ? ' · LÍMITE ${g['limit']}' : ' · SIN LÍMITE'}',
            ),
          ),
        const SizedBox(height: 4),
        const Text('El precio para vaciarla compra cada artículo hasta su límite; los ilimitados se cuentan una vez.',
            style: TextStyle(fontSize: 10.5, color: kTextMuted, height: 1.4)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// JOINT DRILL
// ─────────────────────────────────────────────────────────────

class RaidsPage extends StatefulWidget {
  const RaidsPage({super.key});

  @override
  State<RaidsPage> createState() => _RaidsPageState();
}

class _RaidsPageState extends State<RaidsPage> {
  int? season;
  int level = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _subAppBar('Joint Drill'),
    body: _Loader<List<dynamic>>(
      load: (r) => Future.wait([Api.site('raids', refresh: r), Api.site('enemies')]),
      builder: (context, data, refresh) {
        final raids = _asList(_asMap(data[0])['raids']).map(_asMap).toList();
        final enemies = {
          for (final e in _asList(_asMap(data[1])['enemies']).map(_asMap)) _string(e['id']): e,
        };
        if (raids.isEmpty) return const _EmptyNote('Sin temporadas');
        final liveIdx = raids.indexWhere((r) => _isLive(r['startTime'], r['endTime']));
        season ??= liveIdx >= 0 ? liveIdx : raids.length - 1;
        final r = raids[season!];
        final levels = _asList(r['levels']).map(_asMap).toList();
        if (level >= levels.length) level = 0;
        final lv = levels.isEmpty ? <String, dynamic>{} : levels[level];
        final affixes = {for (final a in _asList(r['affixes']).map(_asMap)) _string(a['id']): a};
        final tex = _asMap(r['textures']);
        final start = _parseDate(r['startTime']);
        final end = _parseDate(r['endTime']);

        return RefreshIndicator(
          onRefresh: refresh,
          color: kInk,
          backgroundColor: kPaper,
          child: ListView(
            padding: const EdgeInsets.only(top: 14, bottom: 24),
            children: [
              _SeasonPicker(
                labels: [for (final x in raids) 'T${_string(x['season'])}'],
                index: season!,
                live: {if (liveIdx >= 0) liveIdx},
                onChanged: (i) => setState(() {
                  season = i;
                  level = 0;
                }),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroHeader(
                      image: _string(tex['background']),
                      title: _string(r['title']),
                      status: _seasonStatus(start, end),
                      dates: '${_shortDate(start)} – ${_shortDate(end)}',
                      subtitle: _cleanGameText(_string(r['shortDescription'])),
                    ),
                    const SizedBox(height: 14),
                    _Panel(
                      title: 'Cómo funciona',
                      badge: 'Temporada ${_string(r['season'])}',
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_cleanGameText(_string(r['detailDescription'])),
                            style: const TextStyle(fontSize: 12.5, height: 1.45)),
                        if (_string(r['unlockText']).isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _Tag(_string(r['unlockText']).replaceAll('Reach Authorization Lv.', 'Desbloqueo: Nv. de autorización').replaceAll('to unlock', '')),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 14),
                    if (levels.isNotEmpty)
                      _Panel(
                        title: 'Dificultades',
                        badge: '難易度',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                              child: Wrap(spacing: 6, runSpacing: 6, children: [
                                for (var i = 0; i < levels.length; i++)
                                  InkWell(
                                    onTap: () => setState(() => level = i),
                                    child: _Tag(_difficultyName(_string(levels[i]['difficultyName'])), filled: i == level),
                                  ),
                              ]),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(_string(lv['subtitle']).toUpperCase(), style: kDisplay(22)),
                                const SizedBox(height: 8),
                                for (final bid in _asList(lv['bossIds']))
                                  if (enemies[_string(bid)] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _enemyRow(enemies[_string(bid)]!),
                                    ),
                                _InfoRow('Nivel recom.', _string(lv['recommendedLevel'])),
                                _InfoRow('Rango de build', _string(lv['recommendedBuildRank'])),
                                _InfoRow('Combates', _string(lv['maxBattleNum'])),
                                _InfoRow('Tiempo', '${_string(lv['battleTimeSeconds'])} s'),
                                _InfoRow('Barras de vida', _string(lv['hpBarCount'])),
                                if (_asMap(lv['score']).isNotEmpty) ...[
                                  _InfoRow('Puntos por nivel', _formatNumber(_string(_asMap(lv['score'])['levelScore']))),
                                  _InfoRow('Puntos por tiempo', _formatNumber(_string(_asMap(lv['score'])['timeScore']))),
                                  _InfoRow('Puntos / segundo', _formatNumber(_string(_asMap(lv['score'])['scorePerSecond']))),
                                ],
                              ]),
                            ),
                            for (final aid in _asList(lv['affixIds']))
                              if (affixes[_string(aid)] != null) _affix(affixes[_string(aid)]!),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),
                    if (_asList(r['quests']).isNotEmpty)
                      _Panel(
                        title: 'Misiones',
                        badge: 'Recompensas de puntos',
                        padding: const EdgeInsets.all(12),
                        child: Column(children: [
                          for (final q in _asList(r['quests']).map(_asMap))
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorderColor))),
                              child: Row(children: [
                                Expanded(
                                  child: Text(
                                      _string(q['title']).replaceFirst('Reach a total score of', 'Alcanza una puntuación total de').replaceFirst('in this season', 'en esta temporada'),
                                      style: const TextStyle(fontSize: 12, height: 1.35)),
                                ),
                                const SizedBox(width: 8),
                                for (final rw in _asList(q['rewards']).map(_asMap))
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Column(children: [
                                      _itemThumb(rw['id'], size: 30),
                                      Text('×${_formatNumber(_string(rw['quantity']))}', style: const TextStyle(fontSize: 9.5)),
                                    ]),
                                  ),
                              ]),
                            ),
                        ]),
                      ),
                    const SizedBox(height: 14),
                    if (_asList(r['seasonTitles']).isNotEmpty)
                      _Panel(
                        title: 'Títulos',
                        badge: 'De temporada',
                        padding: const EdgeInsets.all(12),
                        child: Column(children: [
                          for (final t in _asList(r['seasonTitles']).map(_asMap))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: _itemChip(t, sub: _cleanGameText(_string(t['description']))),
                            ),
                        ]),
                      ),
                    const SizedBox(height: 14),
                    _shopList(_asMap(r['shop'])),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: kTextPrimary, width: 2),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => const RankingListPage(kind: RankingKind.jointDrill))),
                      child: const Text('VER RANKING DE JOINT DRILL →',
                          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2, color: kTextPrimary)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _affix(Map<String, dynamic> a) => Container(
    padding: const EdgeInsets.all(12),
    decoration: const BoxDecoration(border: Border(top: BorderSide(color: kBorderColor))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Thumb(_string(a['icon']), size: 36, fallbackIcon: Icons.auto_fix_high),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_string(a['name']).toUpperCase(), style: kDisplay(15)),
          const SizedBox(height: 3),
          Text(_cleanGameText(_string(a['description'])), style: const TextStyle(fontSize: 12, height: 1.4, color: kTextMuted)),
        ]),
      ),
    ]),
  );
}

Widget _enemyRow(Map<String, dynamic> e) {
  final weak = _asList(e['weakness']).map((x) => '$x').toList();
  return Row(children: [
    _Thumb(_string(e['icon']), size: 48, fallbackIcon: Icons.pest_control_outlined),
    const SizedBox(width: 10),
    Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_string(e['name']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        const SizedBox(height: 4),
        Wrap(spacing: 4, runSpacing: 4, children: [
          for (final w in weak) _Tag('Débil: ${_elementLabel(w)}', color: _elementColor(w)),
        ]),
      ]),
    ),
  ]);
}

// ─────────────────────────────────────────────────────────────
// BOSS BLITZ
// ─────────────────────────────────────────────────────────────

class BossBlitzPage extends StatefulWidget {
  const BossBlitzPage({super.key});

  @override
  State<BossBlitzPage> createState() => _BossBlitzPageState();
}

class _BossBlitzPageState extends State<BossBlitzPage> {
  int? rotation;
  final Set<int> openStats = {};

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _subAppBar('Boss Blitz'),
    body: _Loader<dynamic>(
      load: (r) => Api.site('boss-blitz', refresh: r),
      builder: (context, data, refresh) {
        final blitz = _asMap(_asMap(data)['blitz']);
        final rotations = _asList(blitz['rotations']).map(_asMap).where((r) => r['placeholder'] != true).toList();
        if (rotations.isEmpty) return const _EmptyNote('Sin rotaciones');
        final liveIdx = rotations.indexWhere((r) => _isLive(r['startTime'], r['endTime']));
        rotation ??= liveIdx >= 0 ? liveIdx : rotations.length - 1;
        final rot = rotations[rotation!];
        final start = _parseDate(rot['startTime']);
        final end = _parseDate(rot['endTime']);
        final missions = _asList(rot['missions']).map(_asMap).toList();

        return RefreshIndicator(
          onRefresh: refresh,
          color: kInk,
          backgroundColor: kPaper,
          child: ListView(
            padding: const EdgeInsets.only(top: 14, bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Text('Inflige todo el daño posible dentro del tiempo límite. Cada rotación trae dos jefes; '
                    'la puntuación total de ambos combates decide tu puesto.',
                    style: TextStyle(fontSize: 12.5, height: 1.45, color: kTextMuted)),
              ),
              _SeasonPicker(
                labels: [for (final r in rotations) 'R${_string(r['rotation'])}'],
                index: rotation!,
                live: {if (liveIdx >= 0) liveIdx},
                onChanged: (i) => setState(() {
                  rotation = i;
                  openStats.clear();
                }),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  _Tag(_seasonStatus(start, end), filled: _isLive(rot['startTime'], rot['endTime'])),
                  _Tag('${_shortDate(start)} – ${_shortDate(end)}'),
                ]),
              ),
              const SizedBox(height: 14),
              for (final m in missions)
                Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), child: _mission(m)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: kTextPrimary, width: 2),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => const RankingListPage(kind: RankingKind.scoreBoss))),
                  child: const Text('VER RANKING DE BOSS BLITZ →',
                      style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2, color: kTextPrimary)),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _mission(Map<String, dynamic> m) {
    final tex = _asMap(m['textures']);
    final el = _asMap(m['elements']);
    final weak = _asList(el['weak']).map((x) => '$x').toList();
    final resist = _string(el['resist']);
    final cons = _asMap(m['constants']);
    final ability = _asMap(m['ability']);
    final tech = _asMap(m['technique']);
    final stats = _asList(m['stats']).map(_asMap).toList();
    final id = (m['id'] as num?)?.toInt() ?? 0;
    final open = openStats.contains(id);

    return Container(
      decoration: BoxDecoration(color: kPanelBg, border: Border.all(color: kBorderHighlight, width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 200,
            child: Stack(children: [
              Positioned.fill(child: _NetImage(_string(tex['background']))),
              Positioned.fill(child: Container(color: const Color(0x660e0c0a))),
              Positioned(right: 0, top: 0, bottom: 0, width: 200, child: _NetImage(_string(tex['image']), fit: BoxFit.contain)),
              Positioned(
                left: 12,
                bottom: 12,
                right: 140,
                child: Text(_string(m['name']).toUpperCase(), style: kDisplay(26)),
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: kBorderHighlight, width: 2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final w in weak) _Tag('Débil: ${_elementLabel(w)}', color: _elementColor(w), filled: true),
                if (resist.isNotEmpty) _Tag('Resiste: ${_elementLabel(resist)}', color: _elementColor(resist)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _miniStat('ATQ', _formatNumber(_string(cons['atk'])))),
                const SizedBox(width: 6),
                Expanded(child: _miniStat('DEF', _formatNumber(_string(cons['def'])))),
                const SizedBox(width: 6),
                Expanded(child: _miniStat('DAÑO/PUNTO', _formatNumber(_string(cons['damagePerScore'])))),
              ]),
            ]),
          ),
          if (ability.isNotEmpty) _skillBlock('Mecánica especial', ability),
          if (tech.isNotEmpty) _skillBlock('Técnica', tech, extra: 'Máx. ${_formatNumber(_string(tech['maxLimit']))} pts'),
          InkWell(
            onTap: () => setState(() => open ? openStats.remove(id) : openStats.add(id)),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: kBorderColor))),
              child: Row(children: [
                Text('VIDA POR NIVEL · ${stats.length}', style: kDisplay(15)),
                const Spacer(),
                Icon(open ? Icons.expand_less : Icons.expand_more, color: kTextMuted),
              ]),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(children: [
                const Row(children: [
                  SizedBox(width: 40, child: Text('NV.', style: TextStyle(fontSize: 9.5, color: kTextMuted, fontWeight: FontWeight.w700))),
                  Expanded(child: Text('VIDA', style: TextStyle(fontSize: 9.5, color: kTextMuted, fontWeight: FontWeight.w700))),
                  Expanded(child: Text('PUNTOS', textAlign: TextAlign.right, style: TextStyle(fontSize: 9.5, color: kTextMuted, fontWeight: FontWeight.w700))),
                ]),
                for (final s in stats)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorderColor))),
                    child: Row(children: [
                      SizedBox(width: 40, child: Text(_string(s['level']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      Expanded(child: Text(_formatNumber(_string(s['hp'])), style: const TextStyle(fontSize: 12))),
                      Expanded(child: Text(_string(s['scoreBand']).replaceAll(',', '.'), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                    ]),
                  ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _miniStat(String l, String v) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(border: Border.all(color: kBorderColor)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: kTextMuted, letterSpacing: 1)),
      FittedBox(child: Text(v, style: kDisplay(16))),
    ]),
  );

  Widget _skillBlock(String label, Map<String, dynamic> s, {String? extra}) => Container(
    padding: const EdgeInsets.all(12),
    decoration: const BoxDecoration(border: Border(top: BorderSide(color: kBorderColor))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Thumb(_string(s['icon']), size: 38, fallbackIcon: Icons.flash_on),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.3, color: kTextMuted)),
          Text(_string(s['name']).toUpperCase(), style: kDisplay(15)),
          const SizedBox(height: 3),
          Text(_cleanGameText(_string(s['description'])), style: const TextStyle(fontSize: 12, height: 1.4)),
          if (extra != null) ...[const SizedBox(height: 6), _Tag(extra)],
        ]),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────
// JEFE MUNDIAL (Operación: Asedio de las Sombras)
// ─────────────────────────────────────────────────────────────

class WorldBossPage extends StatefulWidget {
  const WorldBossPage({super.key});

  @override
  State<WorldBossPage> createState() => _WorldBossPageState();
}

class _WorldBossPageState extends State<WorldBossPage> {
  int? period;
  bool allLevels = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _subAppBar('Jefe mundial'),
    body: _Loader<dynamic>(
      load: (r) => Api.site('trace-hunts', refresh: r),
      builder: (context, data, refresh) {
        final periods = _asList(_asMap(data)['periods']).map(_asMap).toList();
        if (periods.isEmpty) return const _EmptyNote('Sin periodos');
        final liveIdx = periods.indexWhere((p) => _isLive(p['startTime'], p['endTime']));
        period ??= liveIdx >= 0 ? liveIdx : periods.length - 1;
        final p = periods[period!];
        final start = _parseDate(p['startTime']);
        final end = _parseDate(p['endTime']);
        final bosses = _asList(p['bosses']).map(_asMap).toList();
        final stars = _asList(p['starRatings']).map(_asMap).toList();
        final levels = _asList(p['levels']).map(_asMap).toList();
        final costs = _asMap(p['costs']);

        return RefreshIndicator(
          onRefresh: refresh,
          color: kInk,
          backgroundColor: kPaper,
          child: ListView(
            padding: const EdgeInsets.only(top: 14, bottom: 24),
            children: [
              _SeasonPicker(
                labels: [for (final x in periods) _shortDate(_parseDate(x['startTime'])).substring(3)],
                index: period!,
                live: {if (liveIdx >= 0) liveIdx},
                onChanged: (i) => setState(() => period = i),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _HeroHeader(
                    image: bosses.isNotEmpty ? _string(_asMap(bosses.first['icons'])['image']) : '',
                    title: _string(p['title']).replaceFirst('Operation: Shadow Siege', 'Operación: Asedio de las Sombras'),
                    status: _seasonStatus(start, end),
                    dates: '${_shortDate(start)} – ${_shortDate(end)}',
                    subtitle: _cleanGameText(_string(p['description'])),
                  ),
                  const SizedBox(height: 14),
                  _Panel(
                    title: 'Recursos',
                    badge: 'Gana · Cuesta',
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      if (_asMap(p['currency']).isNotEmpty)
                        _itemChip(_asMap(p['currency']), sub: 'SE GANA', qty: ''),
                      const SizedBox(height: 6),
                      for (final c in [_asMap(costs['tracking']), _asMap(costs['hunt'])])
                        if (c.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _itemChip(_asMap(c['item']), sub: 'CUESTA', qty: '×${_string(c['quantity'])}'),
                          ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  _Panel(
                    title: 'Objetivos',
                    badge: '標的',
                    child: Column(children: [
                      for (var i = 0; i < bosses.length; i++)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: kBorderColor))),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Container(
                              height: 150,
                              decoration: BoxDecoration(border: Border.all(color: kBorderColor)),
                              child: _NetImage(_string(_asMap(bosses[i]['icons'])['image']), fit: BoxFit.cover),
                            ),
                            const SizedBox(height: 10),
                            Row(children: [
                              _Thumb(_string(bosses[i]['icon']), size: 40, fallbackIcon: Icons.pest_control_outlined),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(_string(bosses[i]['name']).toUpperCase(), style: kDisplay(18)),
                                  Text('OBJETIVO ${i + 1}',
                                      style: const TextStyle(fontSize: 9.5, color: kTextMuted, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                                ]),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            Text(_cleanGameText(_string(bosses[i]['description'])),
                                style: const TextStyle(fontSize: 12, height: 1.4, color: kTextMuted)),
                          ]),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  if (stars.isNotEmpty)
                    _Panel(
                      title: 'Estrellas',
                      badge: '評価',
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final s in stars)
                            Container(
                              width: 70,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(border: Border.all(color: kBorderColor)),
                              child: Column(children: [
                                Text('${_string(s['star'])}★', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                                Text(_formatNumber(_string(s['scoreRequired'])), style: kDisplay(15)),
                              ]),
                            ),
                        ]),
                        const SizedBox(height: 8),
                        const Text('Puntuación necesaria en una sola caza para cada estrella. La caza termina al llegar al límite de estrellas, que depende de tu nivel de asedio.',
                            style: TextStyle(fontSize: 10.5, color: kTextMuted, height: 1.4)),
                      ]),
                    ),
                  const SizedBox(height: 14),
                  if (levels.isNotEmpty)
                    _Panel(
                      title: 'Niveles de asedio',
                      badge: 'レベル',
                      onMore: levels.length > 10 && !allLevels ? () => setState(() => allLevels = true) : null,
                      padding: const EdgeInsets.all(12),
                      child: Column(children: [
                        const Row(children: [
                          SizedBox(width: 30, child: Text('NV', style: TextStyle(fontSize: 9, color: kTextMuted, fontWeight: FontWeight.w700))),
                          SizedBox(width: 44, child: Text('EXP', style: TextStyle(fontSize: 9, color: kTextMuted, fontWeight: FontWeight.w700))),
                          SizedBox(width: 44, child: Text('MUNDO', style: TextStyle(fontSize: 9, color: kTextMuted, fontWeight: FontWeight.w700))),
                          SizedBox(width: 36, child: Text('MÁX', style: TextStyle(fontSize: 9, color: kTextMuted, fontWeight: FontWeight.w700))),
                          SizedBox(width: 48, child: Text('MEDALLAS', style: TextStyle(fontSize: 9, color: kTextMuted, fontWeight: FontWeight.w700))),
                          Expanded(child: Text('DESBLOQUEA', style: TextStyle(fontSize: 9, color: kTextMuted, fontWeight: FontWeight.w700))),
                        ]),
                        for (final l in levels.take(allLevels ? levels.length : 10))
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorderColor))),
                            child: Row(children: [
                              SizedBox(width: 30, child: Text(_string(l['level']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                              SizedBox(width: 44, child: Text(_string(l['exp']), style: const TextStyle(fontSize: 11.5))),
                              SizedBox(width: 44, child: Text(_string(l['requiredWorldClass']), style: const TextStyle(fontSize: 11.5))),
                              SizedBox(width: 36, child: Text('${_string(l['maxStar'])}★', style: const TextStyle(fontSize: 11.5))),
                              SizedBox(width: 48, child: Text('${_string(l['medalRate'])}%', style: const TextStyle(fontSize: 11.5))),
                              Expanded(child: Text(_siegeUnlock(l), style: const TextStyle(fontSize: 11, color: kTextMuted))),
                            ]),
                          ),
                      ]),
                    ),
                  const SizedBox(height: 14),
                  _shopList(_asMap(p['shop'])),
                  const SizedBox(height: 14),
                  if (_asList(p['guide']).isNotEmpty)
                    _Panel(
                      title: 'Cómo se juega',
                      badge: '遊び方',
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        for (final (i, g) in _asList(p['guide']).map(_asMap).indexed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${(i + 1).toString().padLeft(2, '0')} ${_string(g['title']).toUpperCase()}', style: kDisplay(15)),
                              const SizedBox(height: 4),
                              Text(_cleanGameText(_string(g['text'])), style: const TextStyle(fontSize: 12, height: 1.45)),
                            ]),
                          ),
                      ]),
                    ),
                ]),
              ),
            ],
          ),
        );
      },
    ),
  );

  String _siegeUnlock(Map<String, dynamic> l) {
    final parts = <String>[];
    if (l['medalRateBonus'] != null) parts.add('+${l['medalRateBonus']}% medallas');
    if (l['trackingEffectBonus'] != null) parts.add('+${l['trackingEffectBonus']}% rastreo');
    if (l['permitRefundChance'] != null) parts.add('${l['permitRefundChance']}% reembolso de permiso');
    if (l['greatTrackingChance'] != null) parts.add('${l['greatTrackingChance']}% gran rastreo');
    return parts.isEmpty ? '—' : parts.join(' · ');
  }
}
