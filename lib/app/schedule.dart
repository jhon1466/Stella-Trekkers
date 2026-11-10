part of '../main.dart';

// ─────────────────────────────────────────────────────────────
// CALENDARIO, GACHAS, EVENTOS Y NOTICIAS OFICIALES
// ─────────────────────────────────────────────────────────────

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  int _tab = 0; // 0: Gachas, 1: Eventos, 2: Noticias

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header Brutalista
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: kPanelHeaderBg,
                border: Border(bottom: BorderSide(color: kBorderColor, width: 1.2)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: kTextPrimary),
                    onPressed: () => CompanionShell.openDrawer(),
                    tooltip: 'Menú principal',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CALENDARIO Y NOVEDADES',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'GACHAS ACTIVOS, EVENTOS DE TEMPORADA Y AVISOS',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: kTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Selector de pestaña
            Container(
              decoration: const BoxDecoration(
                color: kPanelBg,
                border: Border(bottom: BorderSide(color: kBorderColor, width: 1.2)),
              ),
              child: Row(
                children: [
                  _tabBtn(0, 'GACHAS', Icons.auto_awesome_outlined),
                  _tabBtn(1, 'EVENTOS', Icons.event_outlined),
                  _tabBtn(2, 'NOTICIAS', Icons.campaign_outlined),
                ],
              ),
            ),

            // Contenido dinámico
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: const [
                  _BannersView(),
                  _EventsView(),
                  _NewsView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBtn(int idx, String label, IconData icon) {
    final sel = _tab == idx;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: sel ? kTextPrimary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: sel ? kTextPrimary : kTextMuted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0.8,
                    color: sel ? kTextPrimary : kTextMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PÁGINAS INDIVIDUALES PARA ACCESO DIRECTO DESDE EL DRAWER
// ─────────────────────────────────────────────────────────────

class BannersPage extends StatelessWidget {
  const BannersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _subAppBar('Gachas'),
      body: const SafeArea(child: _BannersView()),
    );
  }
}

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _subAppBar('Eventos'),
      body: const SafeArea(child: _EventsView()),
    );
  }
}

class NewsPage extends StatelessWidget {
  const NewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _subAppBar('Noticias'),
      body: const SafeArea(child: _NewsView()),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// VISTA: GACHAS (BANNERS)
// ─────────────────────────────────────────────────────────────

class _BannersView extends StatefulWidget {
  const _BannersView();

  @override
  State<_BannersView> createState() => _BannersViewState();
}

class _BannersViewState extends State<_BannersView> {
  int _subFilter = 0; // 0: Actuales, 1: Permanentes, 2: Finalizados

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: Api.get('banners'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Spinner();
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: _ErrorView(
              msg: 'No se pudo cargar la lista de banners.',
              onRetry: () => setState(() {}),
            ),
          );
        }

        final data = snapshot.data as Map<String, dynamic>;
        final current = (data['current'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final permanent = (data['permanent'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final ended = (data['ended'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        List<Map<String, dynamic>> activeList;
        if (_subFilter == 0) {
          activeList = current;
        } else if (_subFilter == 1) {
          activeList = permanent;
        } else {
          activeList = ended;
        }

        return Column(
          children: [
            // Sub-filtros
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: kPanelBg,
                border: Border(bottom: BorderSide(color: kBorderColor)),
              ),
              child: Row(
                children: [
                  _subChip(0, 'ACTUALES (${current.length})'),
                  const SizedBox(width: 8),
                  _subChip(1, 'PERMANENTES (${permanent.length})'),
                  const SizedBox(width: 8),
                  _subChip(2, 'FINALIZADOS (${ended.length})'),
                ],
              ),
            ),

            // Lista de banners
            Expanded(
              child: activeList.isEmpty
                  ? const Center(child: _EmptyNote('No hay banners en esta categoría.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: activeList.length,
                      itemBuilder: (context, i) => _buildBannerCard(context, activeList[i], isCurrent: _subFilter == 0),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _subChip(int idx, String text) {
    final sel = _subFilter == idx;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _subFilter = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? kTextPrimary : Colors.transparent,
            border: Border.all(color: sel ? kTextPrimary : kBorderColor),
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: sel ? kInk : kTextMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBannerCard(BuildContext context, Map<String, dynamic> b, {required bool isCurrent}) {
    final name = (b['name'] ?? b['title'] ?? 'Banner').toString();
    final rateUpChars = [..._rateUpEntries(b, disc: false), ..._rateUpEntries(b, disc: true)];
    final textures = _asMap(b['textures'] ?? b['assets']);
    final bannerImgAlt = _imageChain(textures, ['banner', 'tabBackground', 'tabIcon', 'background', 'cover']);
    final bannerImg = bannerImgAlt.isEmpty ? null : bannerImgAlt.first;
    final startTime = b['startTime']?.toString() ?? '';
    final endTime = b['endTime']?.toString() ?? '';
    final type = (b['type'] ?? 'Promocional').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: kPanelBg,
        border: Border.all(color: isCurrent ? kBorderHighlight : kBorderColor, width: 1.2),
      ),
      child: InkWell(
        onTap: () => _showBannerDetails(context, b),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera de estado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: kPanelHeaderBg,
                border: Border(bottom: BorderSide(color: kBorderColor)),
              ),
              child: Row(
                children: [
                  _Tag(
                    isCurrent ? 'ACTIVO' : (_subFilter == 1 ? 'PERMANENTE' : 'FINALIZADO'),
                    color: isCurrent ? kTextPrimary : (_subFilter == 1 ? kAccentAmber : kTextMuted),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _translateBannerType(type),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kTextMuted),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 12, color: kTextMuted),
                ],
              ),
            ),

            // Imagen / Banner preview
            if (bannerImg != null)
              SizedBox(
                height: 120,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _NetImage(bannerImg.toString(), fit: BoxFit.cover, alt: bannerImgAlt.skip(1).toList()),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, kInk.withValues(alpha: 0.85)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 8,
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: kTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),

            // Personajes destacados
            if (rateUpChars.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TASA MEJORADA (RATE-UP):',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: kTextMuted),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: rateUpChars.map((rc) {
                        final charName = rc['name']?.toString() ?? '';
                        final icon = rc['icon']?.toString() ?? '';
                        final rarity = rc['rarity']?.toString() ?? '5';
                        final is5Star = rarity.contains('5');
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xff1d1b18),
                            border: Border.all(color: is5Star ? kAccentAmber : kBorderColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (icon.isNotEmpty) ...[
                                _Thumb(icon, size: 20),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                charName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: is5Star ? kAccentAmber : kTextPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                is5Star ? '5★' : '4★',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: is5Star ? kAccentAmber : kTextMuted,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

            // Período
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 13, color: kTextMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _formatDateRange(startTime, endTime),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: kTextMuted),
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

  void _showBannerDetails(BuildContext context, Map<String, dynamic> b) {
    final name = (b['name'] ?? b['title'] ?? 'Banner').toString();
    final rateUpChars = _rateUpEntries(b, disc: false);
    final rateUpDiscs = _rateUpEntries(b, disc: true);
    final textures = _asMap(b['textures'] ?? b['assets']);
    final bannerImgAlt = _imageChain(textures, ['banner', 'tabBackground', 'tabIcon', 'background', 'cover']);
    final bannerImg = bannerImgAlt.isEmpty ? null : bannerImgAlt.first;
    final startTime = b['startTime']?.toString() ?? '';
    final endTime = b['endTime']?.toString() ?? '';
    final type = (b['type'] ?? 'Promocional').toString();
    final description = b['description']?.toString() ?? '';

    _showSheet(
      context,
      title: 'Detalles del Gacha',
      children: [
        if (bannerImg != null)
          Container(
            height: 140,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(border: Border.all(color: kBorderColor)),
            child: _NetImage(bannerImg.toString(), fit: BoxFit.cover, alt: bannerImgAlt.skip(1).toList()),
          ),
        Text(
          name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.8),
        ),
        const SizedBox(height: 6),
        _InfoRow('TIPO', _translateBannerType(type)),
        _InfoRow('PERÍODO', _formatDateRange(startTime, endTime)),
        const Divider(color: kBorderColor, height: 24),
        if (description.isNotEmpty) ...[
          const Text('DESCRIPCIÓN Y REGLAS',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: kTextMuted)),
          const SizedBox(height: 6),
          Text(
            _cleanGameText(description),
            style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xffd9d6d0)),
          ),
          const SizedBox(height: 14),
        ],
        if (rateUpChars.isNotEmpty) ...[
          const Text('TREKKERS DESTACADOS',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: kTextMuted)),
          const SizedBox(height: 8),
          for (final rc in rateUpChars)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kPanelBg,
                border: Border.all(color: kBorderColor),
              ),
              child: Row(
                children: [
                  _Thumb(rc['icon']?.toString() ?? '', size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rc['name']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Probabilidad aumentada (${rc['rarity'] ?? 5}★)',
                          style: const TextStyle(fontSize: 10, color: kAccentAmber),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
        ],
        if (rateUpDiscs.isNotEmpty) ...[
          const Text('DISCOS DESTACADOS',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: kTextMuted)),
          const SizedBox(height: 8),
          for (final rd in rateUpDiscs)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kPanelBg,
                border: Border.all(color: kBorderColor),
              ),
              child: Row(
                children: [
                  _Thumb(rd['icon']?.toString() ?? '', size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rd['name']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Probabilidad aumentada (${rd['rarity'] ?? 5}★)',
                          style: const TextStyle(fontSize: 10, color: kAccentPurple),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// VISTA: EVENTOS (EVENTS)
// ─────────────────────────────────────────────────────────────

class _EventsView extends StatefulWidget {
  const _EventsView();

  @override
  State<_EventsView> createState() => _EventsViewState();
}

class _EventsViewState extends State<_EventsView> {
  int _subFilter = 0; // 0: Actuales, 1: Finalizados

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: Api.get('events'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Spinner();
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: _ErrorView(
              msg: 'No se pudieron cargar los eventos.',
              onRetry: () => setState(() {}),
            ),
          );
        }

        final data = snapshot.data as Map<String, dynamic>;
        final current = (data['current'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final ended = (data['ended'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        final activeList = _subFilter == 0 ? current : ended;

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: kPanelBg,
                border: Border(bottom: BorderSide(color: kBorderColor)),
              ),
              child: Row(
                children: [
                  _subChip(0, 'EN CURSO (${current.length})'),
                  const SizedBox(width: 8),
                  _subChip(1, 'FINALIZADOS (${ended.length})'),
                ],
              ),
            ),
            Expanded(
              child: activeList.isEmpty
                  ? const Center(child: _EmptyNote('No hay eventos en esta sección.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: activeList.length,
                      itemBuilder: (context, i) => _buildEventCard(context, activeList[i], isCurrent: _subFilter == 0),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _subChip(int idx, String text) {
    final sel = _subFilter == idx;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _subFilter = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? kTextPrimary : Colors.transparent,
            border: Border.all(color: sel ? kTextPrimary : kBorderColor),
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: sel ? kInk : kTextMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, Map<String, dynamic> ev, {required bool isCurrent}) {
    final title = (ev['title'] ?? 'Evento').toString();
    final textures = ev['textures'] as Map<String, dynamic>? ?? {};
    final coverAlt = _imageChain(textures, ['banner', 'tabBackground', 'tabIcon', 'background', 'cover']);
    final cover = coverAlt.isEmpty ? null : coverAlt.first;
    final startTime = ev['startTime']?.toString() ?? '';
    final endTime = ev['endTime']?.toString() ?? '';
    final rewards = (ev['rewards'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: kPanelBg,
        border: Border.all(color: isCurrent ? kBorderHighlight : kBorderColor, width: 1.2),
      ),
      child: InkWell(
        onTap: () => _openPage(context, EventDetailPage(event: ev)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: kPanelHeaderBg,
                border: Border(bottom: BorderSide(color: kBorderColor)),
              ),
              child: Row(
                children: [
                  _Tag(
                    isCurrent ? 'ACTIVO' : 'CONCLUIDO',
                    color: isCurrent ? kAccentGreen : kTextMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatDateRange(startTime, endTime),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: kTextMuted),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 12, color: kTextMuted),
                ],
              ),
            ),

            if (cover != null)
              SizedBox(
                height: 110,
                width: double.infinity,
                child: _NetImage(cover.toString(), fit: BoxFit.cover, alt: coverAlt.skip(1).toList()),
              ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  if (rewards.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'RECOMPENSAS CLAVE:',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: kTextMuted),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: rewards.take(4).map((rw) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xff1d1b18),
                            border: Border.all(color: kBorderColor),
                          ),
                          child: Text(
                            rw['name']?.toString() ?? '',
                            style: const TextStyle(fontSize: 10, color: Color(0xffd9d6d0)),
                          ),
                        );
                      }).toList(),
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


}

// ─────────────────────────────────────────────────────────────
// VISTA: NOTICIAS (NEWS / NOTICES)
// ─────────────────────────────────────────────────────────────

class _NewsView extends StatefulWidget {
  const _NewsView();

  @override
  State<_NewsView> createState() => _NewsViewState();
}

class _NewsViewState extends State<_NewsView> {
  int _category = 0; // 0: Todas, 1: Avisos, 2: Eventos

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: Api.get('news/notices'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Spinner();
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: _ErrorView(
              msg: 'No se pudieron cargar las noticias.',
              onRetry: () => setState(() {}),
            ),
          );
        }

        final data = snapshot.data as Map<String, dynamic>;
        final inner = data['data'] as Map<String, dynamic>? ?? {};
        final rows = (inner['rows'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        List<Map<String, dynamic>> filtered = rows;
        if (_category == 1) {
          filtered = rows.where((n) {
            final t = (n['typeLabel'] ?? n['type'] ?? '').toString().toLowerCase();
            return t.contains('notice') || t.contains('aviso') || t.contains('mantenimiento');
          }).toList();
        } else if (_category == 2) {
          filtered = rows.where((n) {
            final t = (n['typeLabel'] ?? n['type'] ?? '').toString().toLowerCase();
            return t.contains('event') || t.contains('evento') || t.contains('update');
          }).toList();
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: kPanelBg,
                border: Border(bottom: BorderSide(color: kBorderColor)),
              ),
              child: Row(
                children: [
                  _subChip(0, 'TODAS (${rows.length})'),
                  const SizedBox(width: 8),
                  _subChip(1, 'AVISOS'),
                  const SizedBox(width: 8),
                  _subChip(2, 'EVENTOS'),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: _EmptyNote('No hay noticias en esta sección.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => _buildNewsCard(context, filtered[i]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _subChip(int idx, String text) {
    final sel = _category == idx;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _category = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? kTextPrimary : Colors.transparent,
            border: Border.all(color: sel ? kTextPrimary : kBorderColor),
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: sel ? kInk : kTextMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewsCard(BuildContext context, Map<String, dynamic> n) {
    final title = (n['title'] ?? 'Aviso Oficial').toString();
    final thumb = n['thumbnail']?.toString() ?? '';
    final publishTime = n['publishTime']?.toString() ?? '';
    final typeLabel = (n['typeLabel'] ?? n['type'] ?? 'Aviso').toString();
    final desc = _cleanHtml(n['description']?.toString() ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kPanelBg,
        border: Border.all(color: kBorderColor, width: 1.2),
      ),
      child: InkWell(
        onTap: () => _openPage(context, NewsDetailPage(news: n)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (thumb.isNotEmpty) ...[
                _Thumb(thumb, size: 54, radius: 0),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Tag(_translateNoticeType(typeLabel), color: kAccentPurple),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _formatSimpleDate(publishTime),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, color: kTextMuted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: kTextMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


}

// ─────────────────────────────────────────────────────────────
// TRADUCCIONES Y FORMATEO EN ESPAÑOL
// ─────────────────────────────────────────────────────────────

String _translateBannerType(String type) {
  final lower = type.toLowerCase();
  if (lower.contains('rateup') || lower.contains('featured') || lower.contains('limited')) {
    return 'PROMOCIONAL LIMITADO';
  }
  if (lower.contains('permanent') || lower.contains('standard')) {
    return 'CONVOCATORIA ESTÁNDAR';
  }
  if (lower.contains('disc')) {
    return 'DISCOS DESTACADOS';
  }
  return 'CONVOCATORIA ESPECIAL';
}

String _translateNoticeType(String type) {
  final lower = type.toLowerCase();
  if (lower.contains('notice')) return 'AVISO';
  if (lower.contains('update')) return 'ACTUALIZACIÓN';
  if (lower.contains('event')) return 'EVENTO';
  if (lower.contains('maint')) return 'MANTENIMIENTO';
  return 'COMUNICADO';
}

String _formatDateRange(String start, String end) {
  if (start.isEmpty && end.isEmpty) return 'Período permanente';
  final s = _formatSimpleDate(start);
  final e = _formatSimpleDate(end);
  if (s.isEmpty) return 'Hasta el $e';
  if (e.isEmpty) return 'Desde el $s';
  return '$s – $e';
}

String _formatSimpleDate(String raw) {
  if (raw.isEmpty) return '';
  try {
    final dt = DateTime.parse(raw).toLocal();
    final months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    final m = months[dt.month - 1];
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} $m ${dt.year} $h:$min';
  } catch (_) {
    return raw;
  }
}


/// Rutas de imagen disponibles en [m] según el orden de [keys] (la primera que exista se muestra).
List<String> _imageChain(Map<String, dynamic> m, List<String> keys) =>
    [for (final k in keys) if (_string(m[k]).isNotEmpty) _string(m[k])];

/// Destacados de un gacha con nombre, icono y rareza, desde el formato real de la API (rateUp).
List<Map<String, dynamic>> _rateUpEntries(Map<String, dynamic> b, {required bool disc}) {
  final isDiscBanner = _string(b['bannerType']).toLowerCase().contains('disc');
  if (isDiscBanner != disc) return const [];
  final rateUp = _asMap(b['rateUp']);
  final out = <Map<String, dynamic>>[];
  for (final (key, rarity) in [('fiveStar', 5), ('fourStar', 4)]) {
    for (final e in _asList(_asMap(rateUp[key])['entries']).map(_asMap)) {
      final id = _string(e['id']);
      out.add({
        'name': e['name'],
        'rarity': rarity,
        'element': e['element'],
        'icon': disc ? 'outfit_${id.length > 4 ? id.substring(id.length - 4) : id}_b.png' : _charHead(id),
      });
    }
  }
  return out;
}
