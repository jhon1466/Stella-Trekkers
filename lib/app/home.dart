part of '../main.dart';

// ─────────────────────────────────────────────────────────────
// PANEL PRINCIPAL — misma estructura que el dashboard de StellaBase:
// gachas destacados · eventos · tablón · modos · cumpleaños · calendario
// ─────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onGoTab});
  final void Function(int tab) onGoTab;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int bannerIndex = 0;
  int eventTab = 0; // 0 en curso, 1 próximos, 2 archivo
  int newsTab = 0;
  int scheduleTab = 0;
  Timer? _ticker;

  static const _newsKinds = [
    (label: 'NOTICIAS', path: 'news/news'),
    (label: 'ACTUALIZ.', path: 'news/updates'),
    (label: 'EVENTOS', path: 'news/events'),
    (label: 'AVISOS', path: 'news/notices'),
  ];

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _rootAppBar('Panel'),
      body: _Loader<List<dynamic>>(
        load: (refresh) => Future.wait([
          Api.get('banners', refresh: refresh),
          Api.get('events', refresh: refresh),
          Api.get('characters', refresh: refresh),
          Api.site(
            'challenges',
            refresh: refresh,
          ).catchError((_) => <String, dynamic>{}),
          Api.site(
            'raids',
            refresh: refresh,
          ).catchError((_) => <String, dynamic>{}),
          Api.site(
            'boss-blitz',
            refresh: refresh,
          ).catchError((_) => <String, dynamic>{}),
        ]),
        builder: (context, data, refresh) {
          final banners = _asMap(data[0]);
          final events = _asMap(data[1]);
          final characters = _asList(data[2]).map(_asMap).toList();
          final challenges = _asList(
            _asMap(data[3])['challenges'],
          ).map(_asMap).toList();
          final raids = _asList(_asMap(data[4])['raids']).map(_asMap).toList();
          final blitz = _asList(
            _asMap(_asMap(data[5])['blitz'])['rotations'],
          ).map(_asMap).toList();
          final current = _asList(banners['current']).map(_asMap).toList();

          return RefreshIndicator(
            color: kInk,
            backgroundColor: kPaper,
            onRefresh: refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
              children: [
                if (current.isNotEmpty) ...[
                  _hero(current),
                  const SizedBox(height: 18),
                ],
                _eventsPanel(events, challenges),
                const SizedBox(height: 18),
                _noticeBoard(),
                const SizedBox(height: 18),
                _modesPanel(raids, blitz),
                const SizedBox(height: 18),
                _birthdaysPanel(characters),
                const SizedBox(height: 18),
                _schedulePanel(banners),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // 1. GACHAS DESTACADOS (tarjeta crema como en la web)
  // ─────────────────────────────────────────────────────────
  Widget _hero(List<Map<String, dynamic>> banners) {
    if (bannerIndex >= banners.length) bannerIndex = 0;
    final b = banners[bannerIndex];
    final title = _string(b['name']);
    final type = _string(b['bannerType']).toLowerCase();
    final isDisc = type.contains('disc');
    final end = _parseDate(b['endTime']);
    final start = _parseDate(b['startTime']);
    final rateUp = _asMap(b['rateUp']);
    final five = _asList(
      _asMap(rateUp['fiveStar'])['entries'],
    ).map(_asMap).toList();
    final four = _asList(
      _asMap(rateUp['fourStar'])['entries'],
    ).map(_asMap).toList();
    final element = five.isNotEmpty
        ? _string(five.first['element'])
        : _string(b['element']);
    final assets = _asMap(b['assets']);
    final artChain = _imageChain(assets, ['banner', 'tabIcon', 'cover']);
    final art = artChain.isEmpty ? '' : artChain.first;
    const ink = TextStyle(
      color: kInk,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      fontSize: 10.5,
    );

    return Container(
      decoration: BoxDecoration(
        color: kPaper,
        border: Border.all(color: kBorderHighlight, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _bannerSheet(b),
            child: _Dotted(
              color: const Color(0x22130e0a),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        const _Tag('● En curso', color: kInk, filled: true),
                        _Tag(
                          type.contains('permanent')
                              ? 'Permanente'
                              : '期間限定 · Limitado',
                          color: kInk,
                        ),
                        _Tag(
                          '${isDisc ? 'Disco' : 'Trekker'} · ${element.isEmpty ? '—' : _elementLabel(element)}',
                          color: kInk,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(title.toUpperCase(), style: kDisplay(30, color: kInk)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(_shortDate(start), style: ink),
                        const SizedBox(width: 10),
                        Expanded(child: Container(height: 1.5, color: kInk)),
                        const SizedBox(width: 10),
                        Text(_shortDate(end), style: ink),
                      ],
                    ),
                    if (five.isNotEmpty || four.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      if (five.isNotEmpty)
                        _rateUpRow('★5 Destacado', five, isDisc),
                      if (four.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _rateUpRow('★4 Destacados', four, isDisc),
                      ],
                    ],
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: _countdown(end, onPaper: true)),
                        if (art.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Container(
                            width: 110,
                            height: 70,
                            decoration: BoxDecoration(
                              border: Border.all(color: kInk, width: 2),
                            ),
                            child: _NetImage(
                              art,
                              alt: artChain.skip(1).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: kPanelHeaderBg,
              border: Border(
                top: BorderSide(color: kBorderHighlight, width: 2),
              ),
            ),
            height: 64,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: banners.length,
              itemBuilder: (_, i) {
                final x = banners[i];
                final sel = i == bannerIndex;
                final xType =
                    _string(x['bannerType']).toLowerCase().contains('disc')
                    ? 'DISCO'
                    : 'TREKKER';
                return InkWell(
                  onTap: () => setState(() => bannerIndex = i),
                  child: Container(
                    width: 170,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: sel ? kPaper : Colors.transparent,
                      border: const Border(
                        right: BorderSide(color: kBorderColor),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: sel ? kInk : Colors.transparent,
                            border: Border.all(
                              color: sel ? kInk : kTextPrimary,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: sel ? kPaper : kTextPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _string(x['name']),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sel ? kInk : kTextPrimary,
                                ),
                              ),
                              Text(
                                'EN CURSO · $xType',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  color: sel
                                      ? const Color(0xff58514b)
                                      : kTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _rateUpRow(
    String label,
    List<Map<String, dynamic>> entries,
    bool isDisc,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Color(0xff58514b),
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in entries)
                Container(
                  padding: const EdgeInsets.fromLTRB(2, 2, 8, 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: kInk, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isDisc)
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: _NetImage(_charHead(e['id'])),
                        ),
                      if (isDisc)
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: _NetImage(
                            'outfit_${_string(e['id']).substring(_string(e['id']).length > 4 ? _string(e['id']).length - 4 : 0)}.png',
                            fallbackIcon: Icons.album_outlined,
                          ),
                        ),
                      const SizedBox(width: 6),
                      Text(
                        _string(e['name']).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: kInk,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Cuenta atrás en cajas, como la web ("TERMINA EN 03 HRS 36 MIN 45 SEG").
  Widget _countdown(
    DateTime? end, {
    bool onPaper = false,
    String label = 'Termina en',
  }) {
    final fg = onPaper ? kInk : kTextPrimary;
    final diff = end == null ? Duration.zero : end.difference(DateTime.now());
    final parts = <(String, String)>[];
    if (diff.isNegative || end == null) {
      parts.add(('—', 'FIN'));
    } else if (diff.inDays > 0) {
      parts.addAll([
        (diff.inDays.toString().padLeft(2, '0'), 'DÍAS'),
        ((diff.inHours % 24).toString().padLeft(2, '0'), 'HRS'),
        ((diff.inMinutes % 60).toString().padLeft(2, '0'), 'MIN'),
      ]);
    } else {
      parts.addAll([
        (diff.inHours.toString().padLeft(2, '0'), 'HRS'),
        ((diff.inMinutes % 60).toString().padLeft(2, '0'), 'MIN'),
        ((diff.inSeconds % 60).toString().padLeft(2, '0'), 'SEG'),
      ]);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(border: Border.all(color: fg, width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: fg,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                for (final p in parts) ...[
                  Text(p.$1, style: kDisplay(28, color: fg)),
                  const SizedBox(width: 3),
                  Text(
                    p.$2,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _bannerSheet(Map<String, dynamic> b) {
    final rateUp = _asMap(b['rateUp']);
    final five = _asList(
      _asMap(rateUp['fiveStar'])['entries'],
    ).map(_asMap).toList();
    final four = _asList(
      _asMap(rateUp['fourStar'])['entries'],
    ).map(_asMap).toList();
    final assets = _asMap(b['assets']);
    final artChain = _imageChain(assets, ['banner', 'tabIcon', 'cover']);
    final art = artChain.isEmpty ? '' : artChain.first;
    _showSheet(
      context,
      title: _string(b['name']),
      children: [
        if (art.isNotEmpty)
          Container(
            height: 170,
            decoration: BoxDecoration(
              border: Border.all(color: kBorderHighlight, width: 2),
            ),
            child: _NetImage(art, alt: artChain.skip(1).toList()),
          ),
        const SizedBox(height: 14),
        _InfoRow('Tipo', _term(_string(b['bannerType']))),
        _InfoRow('Inicio', _shortDate(_parseDate(b['startTime']))),
        _InfoRow('Fin', _shortDate(_parseDate(b['endTime']))),
        _InfoRow('Restante', _remaining(_parseDate(b['endTime']))),
        for (final group in [('★5 DESTACADO', five), ('★4 DESTACADOS', four)])
          if (group.$2.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(group.$1, style: kDisplay(16)),
            const SizedBox(height: 8),
            for (final e in group.$2)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    _Thumb(_charHead(e['id']), size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _string(e['name']),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (_string(e['element']).isNotEmpty)
                      _Tag(
                        _elementLabel(_string(e['element'])),
                        color: _elementColor(_string(e['element'])),
                      ),
                  ],
                ),
              ),
          ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 2. EVENTOS (en curso · próximos · archivo)
  // ─────────────────────────────────────────────────────────
  Widget _eventsPanel(
    Map<String, dynamic> events,
    List<Map<String, dynamic>> challenges,
  ) {
    final now = DateTime.now();
    final all = <Map<String, dynamic>>[
      ..._asList(events['current']).map(_asMap),
      ..._asList(events['upcoming']).map(_asMap),
      ..._asList(events['ended']).map(_asMap),
      ...challenges.map((c) => {...c, '_challenge': true}),
    ];
    final seen = <String>{};
    all.removeWhere((e) => !seen.add('${e['id']}'));
    bool isOn(Map<String, dynamic> e) {
      final s = _parseDate(e['startTime']);
      final claim = _parseDate(e['claimEndTime']) ?? _parseDate(e['endTime']);
      return s != null &&
          claim != null &&
          !now.isBefore(s) &&
          now.isBefore(claim);
    }

    bool isNext(Map<String, dynamic> e) {
      final s = _parseDate(e['startTime']);
      return s != null && now.isBefore(s);
    }

    final on = all.where(isOn).toList()
      ..sort(
        (a, b) => (_parseDate(a['endTime']) ?? now).compareTo(
          _parseDate(b['endTime']) ?? now,
        ),
      );
    final next = all.where(isNext).toList()
      ..sort(
        (a, b) => (_parseDate(a['startTime']) ?? now).compareTo(
          _parseDate(b['startTime']) ?? now,
        ),
      );
    final past = all.where((e) => !isOn(e) && !isNext(e)).toList()
      ..sort(
        (a, b) => (_parseDate(b['endTime']) ?? now).compareTo(
          _parseDate(a['endTime']) ?? now,
        ),
      );
    final lists = [on, next, past];
    final shown = lists[eventTab].take(eventTab == 2 ? 6 : 20).toList();

    return _Panel(
      title: 'Eventos',
      badge: '時限イベント',
      onMore: () => _push(const EventsPage()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: _Segmented(
              labels: [
                'EN CURSO ${on.length}',
                'PRÓXIMOS ${next.length}',
                'ARCHIVO ${past.length}',
              ],
              index: eventTab,
              onChanged: (i) => setState(() => eventTab = i),
            ),
          ),
          if (shown.isEmpty) const _EmptyNote('Nada por aquí todavía'),
          for (final e in shown) _eventCard(e, ended: eventTab == 2),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _eventCard(Map<String, dynamic> e, {bool ended = false}) {
    final tex = _asMap(e['textures']);
    final artChain = _imageChain(tex, [
      'banner',
      'tabBackground',
      'background',
    ]);
    final art = artChain.isEmpty ? '' : artChain.first;
    final start = _parseDate(e['startTime']);
    final end = _parseDate(e['endTime']);
    final claim = _parseDate(e['claimEndTime']);
    final now = DateTime.now();
    final claimOnly =
        end != null && claim != null && now.isAfter(end) && now.isBefore(claim);
    final shops = _asList(e['shops']).map(_asMap).toList();
    final currency = shops.isNotEmpty
        ? _asMap(shops.first['currency'])
        : <String, dynamic>{};
    final isChallenge = e['_challenge'] == true;

    return InkWell(
      onTap: () => _push(EventDetailPage(event: e)),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        decoration: BoxDecoration(
          border: Border.all(color: kBorderHighlight, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (art.isNotEmpty)
              AspectRatio(
                aspectRatio: 2.4,
                child: _NetImage(
                  art,
                  fallbackIcon: Icons.event_outlined,
                  alt: artChain.skip(1).toList(),
                ),
              )
            else
              Container(
                height: 70,
                color: kMuted,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.calendar_today_outlined,
                  color: kTextMuted,
                  size: 20,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (claimOnly)
                        const _Tag(
                          'Sólo reclamar',
                          color: kAccentAmber,
                          filled: true,
                        )
                      else if (ended)
                        const _Tag('Finalizado', color: kTextMuted)
                      else if (start != null && now.isBefore(start))
                        const _Tag('Próximamente')
                      else
                        const _Tag('En curso', filled: true),
                      if (isChallenge) const _Tag('Desafío'),
                      Text(
                        '${_shortDate(start)} – ${_shortDate(end)}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: kTextMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_string(e['title']).toUpperCase(), style: kDisplay(20)),
                  if (currency.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _itemThumb(
                          currency['itemId'],
                          size: 22,
                          fallbackIcon: Icons.toll_outlined,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _string(currency['name']).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (!ended) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: kBorderHighlight, width: 2),
                      ),
                      child: Column(
                        children: [
                          Text(
                            claimOnly
                                ? 'EL CANJE CIERRA EN'
                                : (start != null && now.isBefore(start)
                                      ? 'EMPIEZA EN'
                                      : 'TERMINA EN'),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _remaining(
                              claimOnly
                                  ? claim
                                  : (start != null && now.isBefore(start)
                                        ? start
                                        : end),
                            ),
                            style: kDisplay(20),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // 3. TABLÓN DE ANUNCIOS (noticias oficiales)
  // ─────────────────────────────────────────────────────────
  Widget _noticeBoard() {
    final kind = _newsKinds[newsTab];
    return _Panel(
      title: 'Tablón',
      badge: 'Del operador',
      onMore: () => _push(const NewsPage()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: _Segmented(
              labels: [for (final k in _newsKinds) k.label],
              index: newsTab,
              onChanged: (i) => setState(() => newsTab = i),
            ),
          ),
          FutureBuilder<dynamic>(
            key: ValueKey(kind.path),
            future: Api.get(kind.path),
            builder: (context, snap) {
              if (snap.hasError) {
                return const _EmptyNote('No se pudieron cargar las noticias');
              }
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: _Spinner(),
                );
              }
              final rows = _asList(
                _asMap(_asMap(snap.data)['data'])['rows'],
              ).map(_asMap).take(5).toList();
              if (rows.isEmpty) return const _EmptyNote('Sin publicaciones');
              return Column(children: [for (final n in rows) _newsRow(n)]);
            },
          ),
        ],
      ),
    );
  }

  Widget _newsRow(Map<String, dynamic> n) {
    final published = _parseDate(int.tryParse(_string(n['publishTime'])));
    final ago = published == null ? '' : _ago(published);
    final summary = _cleanHtml(
      _string(n['description']),
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
    return InkWell(
      onTap: () => _push(NewsDetailPage(news: n)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kBorderColor)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 92,
              height: 56,
              decoration: BoxDecoration(
                border: Border.all(color: kBorderColor),
              ),
              child: _NetImage(
                _string(n['thumbnail']),
                fallbackIcon: Icons.campaign_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Tag(_newsTypeLabel(_string(n['type'])), filled: true),
                      const SizedBox(width: 8),
                      Text(
                        ago,
                        style: const TextStyle(
                          fontSize: 10,
                          color: kTextMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _string(n['title']).toUpperCase(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: kDisplay(16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: kTextMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // 4. MODOS (Joint Drill · Boss Blitz)
  // ─────────────────────────────────────────────────────────
  Widget _modesPanel(
    List<Map<String, dynamic>> raids,
    List<Map<String, dynamic>> blitz,
  ) {
    Widget row(
      String name,
      List<Map<String, dynamic>> seasons,
      String titleKey,
      VoidCallback onTap,
    ) {
      final now = DateTime.now();
      Map<String, dynamic>? active;
      Map<String, dynamic>? upcoming;
      for (final s in seasons) {
        if (s['placeholder'] == true) continue;
        final st = _parseDate(s['startTime']);
        final en = _parseDate(s['endTime']);
        if (st == null || en == null) continue;
        if (!now.isBefore(st) && now.isBefore(en)) active = s;
        if (now.isBefore(st) &&
            (upcoming == null ||
                st.isBefore(_parseDate(upcoming['startTime'])!))) {
          upcoming = s;
        }
      }
      String status;
      String? detail;
      if (active != null) {
        status =
            'EN CURSO · TERMINA EN ${_remaining(_parseDate(active['endTime']))}';
        detail = _string(active[titleKey]);
        if (detail.isEmpty) {
          final m = _asList(active['missions']).map(_asMap).toList();
          detail = m.map((x) => _string(x['name'])).join(' · ');
        }
      } else if (upcoming != null) {
        status =
            'PRÓXIMO · EMPIEZA EN ${_remaining(_parseDate(upcoming['startTime']))}';
        detail = _string(upcoming[titleKey]);
      } else {
        status = 'ENTRE TEMPORADAS — NADA ANUNCIADO';
      }
      return InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: kBorderColor)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name.toUpperCase(), style: kDisplay(19)),
              if (detail != null && detail.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: active != null ? kAccentGreen : kTextMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _Panel(
      title: 'Modos',
      badge: '常設モード',
      child: Column(
        children: [
          row('Joint Drill', raids, 'title', () => _push(const RaidsPage())),
          row('Boss Blitz', blitz, 'title', () => _push(const BossBlitzPage())),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // 5. CUMPLEAÑOS
  // ─────────────────────────────────────────────────────────
  Widget _birthdaysPanel(List<Map<String, dynamic>> characters) {
    final list = _upcomingBirthdays(characters);
    if (list.isEmpty) return const SizedBox.shrink();
    final first = list.first;
    final firstColor = _elementColor(_string(first.c['element']));
    return _Panel(
      title: 'Cumpleaños',
      badge: '誕生日 · Próximo',
      onMore: () => _push(const BirthdaysPage()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => _push(TrekkerDetailPage(character: first.c)),
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: firstColor,
                border: Border.all(color: kBorderHighlight, width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      border: Border.all(color: kInk, width: 2),
                      color: kPaper,
                    ),
                    child: _NetImage(_string(first.c['icon'])),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          first.days == 0 ? '¡HOY!' : 'PRÓXIMO',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                            color: kInk,
                          ),
                        ),
                        Text(
                          _string(first.c['name']).toUpperCase(),
                          style: kDisplay(24, color: kInk),
                        ),
                        Text(
                          '${first.label} · ${_elementLabel(_string(first.c['element']))}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: kInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 54,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: kPaper,
                      border: Border.all(color: kInk, width: 2),
                    ),
                    child: Column(
                      children: [
                        Text('${first.days}', style: kDisplay(24, color: kInk)),
                        Text(
                          first.days == 1 ? 'DÍA' : 'DÍAS',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: kInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final b in list.skip(1).take(6))
            InkWell(
              onTap: () => _push(TrekkerDetailPage(character: b.c)),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: kBorderColor)),
                ),
                child: Row(
                  children: [
                    _ElementBlock(_string(b.c['element'])),
                    const SizedBox(width: 10),
                    ClipOval(
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: _NetImage(_string(b.c['icon'])),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _string(b.c['name']),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            b.label,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: kTextMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text('${b.days}d', style: kDisplay(18)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // 6. CALENDARIO DE GACHAS
  // ─────────────────────────────────────────────────────────
  Widget _schedulePanel(Map<String, dynamic> banners) {
    final groups = [
      _asList(banners['current']).map(_asMap).toList(),
      _asList(banners['upcoming']).map(_asMap).toList(),
      _asList(banners['permanent']).map(_asMap).toList(),
      _asList(banners['ended']).map(_asMap).toList(),
    ];
    final labels = [
      'EN ${groups[0].length}',
      'PRÓX ${groups[1].length}',
      'PERM ${groups[2].length}',
      'PAS ${groups[3].length}',
    ];
    final rows = groups[scheduleTab].take(scheduleTab == 3 ? 10 : 30).toList();
    return _Panel(
      title: 'Calendario',
      badge: 'Gachas',
      onMore: () => _push(const BannersPage()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: _Segmented(
              labels: labels,
              index: scheduleTab,
              onChanged: (i) => setState(() => scheduleTab = i),
            ),
          ),
          if (rows.isEmpty) const _EmptyNote('Nada anunciado'),
          for (final b in rows) _scheduleRow(b),
        ],
      ),
    );
  }

  Widget _scheduleRow(Map<String, dynamic> b) {
    final rateUp = _asMap(b['rateUp']);
    final five = _asList(
      _asMap(rateUp['fiveStar'])['entries'],
    ).map(_asMap).toList();
    final element = five.isNotEmpty
        ? _string(five.first['element'])
        : _string(b['element']);
    final isDisc = _string(b['bannerType']).toLowerCase().contains('disc');
    final end = _parseDate(b['endTime']);
    final assets = _asMap(b['assets']);
    final ended = end != null && end.isBefore(DateTime.now());
    return InkWell(
      onTap: () => _bannerSheet(b),
      child: Container(
        height: 58,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kBorderColor)),
        ),
        child: Row(
          children: [
            _ElementBlock(element, tall: true),
            const SizedBox(width: 10),
            Container(
              width: 64,
              height: 38,
              decoration: BoxDecoration(
                border: Border.all(color: kBorderColor),
              ),
              child: _NetImage(
                _string(assets['tabIcon']),
                alt: [_string(assets['banner']), _string(assets['cover'])],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _string(b['name']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${isDisc ? 'DISCO' : 'TREKKER'}${five.isNotEmpty ? ' · ${_string(five.first['name']).toUpperCase()}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: kTextMuted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    b['permanent'] == true
                        ? '∞'
                        : (ended ? _shortDate(end) : _remaining(end)),
                    style: kDisplay(ended ? 13 : 18),
                  ),
                  Text(
                    b['permanent'] == true
                        ? 'PERMANENTE'
                        : (ended ? 'TERMINÓ' : 'RESTANTE'),
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: kTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PIEZAS COMPARTIDAS DEL PANEL
// ─────────────────────────────────────────────────────────────

/// Selector segmentado con borde grueso (ON NOW | NEXT UP | ARCHIVE en la web).
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.labels,
    required this.index,
    required this.onChanged,
  });
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: kBorderHighlight, width: 2),
    ),
    child: IntrinsicHeight(
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? kTextPrimary : Colors.transparent,
                    border: i == 0
                        ? null
                        : const Border(
                            left: BorderSide(color: kBorderHighlight, width: 2),
                          ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: i == index ? kInk : kTextMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Bloque de color con la abreviatura del elemento (IG, AQ, VE, TE, LU, UM).
class _ElementBlock extends StatelessWidget {
  const _ElementBlock(this.element, {this.tall = false});
  final String element;
  final bool tall;

  static const _abbr = {
    'ignis': 'IG',
    'aqua': 'AQ',
    'ventus': 'VE',
    'terra': 'TE',
    'lux': 'LU',
    'umbra': 'UM',
  };

  @override
  Widget build(BuildContext context) {
    final e = element.toLowerCase();
    final color = _abbr.containsKey(e) ? _elementColor(e) : kPaper;
    return Container(
      width: 30,
      height: tall ? double.infinity : 30,
      alignment: Alignment.center,
      color: color,
      child: Text(
        _abbr[e] ?? '—',
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: kInk,
        ),
      ),
    );
  }
}

class _Birthday {
  _Birthday(this.c, this.days, this.label);
  final Map<String, dynamic> c;
  final int days;
  final String label;
}

/// Ordena los cumpleaños por cercanía. El formato de la API es "mes.día".
List<_Birthday> _upcomingBirthdays(List<Map<String, dynamic>> characters) {
  final today = DateTime.now();
  final base = DateTime(today.year, today.month, today.day);
  final out = <_Birthday>[];
  for (final c in characters) {
    final parts = _string(c['birthday']).split('.');
    if (parts.length != 2) continue;
    final m = int.tryParse(parts[0]);
    final d = int.tryParse(parts[1]);
    if (m == null || d == null) continue;
    var next = DateTime(base.year, m, d);
    if (next.isBefore(base)) next = DateTime(base.year + 1, m, d);
    out.add(_Birthday(c, next.difference(base).inDays, '$d ${_months[m - 1]}'));
  }
  out.sort((a, b) => a.days.compareTo(b.days));
  return out;
}

String _ago(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inDays >= 60) return 'HACE ${diff.inDays ~/ 30} MESES';
  if (diff.inDays >= 30) return 'HACE 1 MES';
  if (diff.inDays >= 1) return 'HACE ${diff.inDays} D';
  if (diff.inHours >= 1) return 'HACE ${diff.inHours} H';
  return 'RECIENTE';
}

String _newsTypeLabel(String t) {
  switch (t.toLowerCase()) {
    case 'news':
      return 'Noticia';
    case 'updates':
    case 'update':
      return 'Actualización';
    case 'events':
    case 'event':
      return 'Evento';
    case 'notices':
    case 'notice':
      return 'Aviso';
    default:
      return t.isEmpty ? 'Noticia' : t;
  }
}
