part of '../main.dart';

// ─────────────────────────────────────────────────────────────
// PANTALLA DE BASE DE DATOS (TREKKERS Y DISCOS)
// ─────────────────────────────────────────────────────────────

class DatabasePage extends StatefulWidget {
  const DatabasePage({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<DatabasePage> createState() => _DatabasePageState();
}

class _DatabasePageState extends State<DatabasePage> {
  late int tab;
  String selectedElement = 'TODOS';
  int? selectedGrade;
  String search = '';

  static const elements = ['TODOS', 'IGNIS', 'AQUA', 'VENTUS', 'LUX', 'UMBRA', 'TERRA'];
  static const grades = [null, 5, 4, 3];

  @override
  void initState() {
    super.initState();
    tab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Navigator.canPop(context)
          ? _subAppBar(tab == 0 ? 'Trekkers' : 'Discos')
          : _rootAppBar(tab == 0 ? 'Trekkers' : 'Discos'),
      body: Column(
        children: [
          // Conmutador de pestaña (Trekkers / Discos)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: _tabButton(0, 'PERSONAJES'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _tabButton(1, 'DISCOS RÚNICOS'),
                ),
              ],
            ),
          ),

          // Filtros por Elemento (sólo para Trekkers)
          if (tab == 0)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
              child: Row(
                children: elements.map((elem) {
                  final isSel = selectedElement == elem;
                  final col = elem == 'TODOS' ? kTextPrimary : _elementColor(elem);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => setState(() => selectedElement = elem),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xff272522) : kPanelBg,
                          border: Border.all(
                            color: isSel ? col : kBorderColor,
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          _elementLabel(elem),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSel ? col : kTextMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Filtros por Rareza (Estrellas)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: grades.map((g) {
                final isSel = selectedGrade == g;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => setState(() => selectedGrade = g),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xff272522) : kPanelBg,
                        border: Border.all(
                          color: isSel ? kAccentAmber : kBorderColor,
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        g == null ? 'TODAS' : '$g★',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSel ? kAccentAmber : kTextMuted,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Campo de Búsqueda
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 18, color: kTextMuted),
                hintText: tab == 0 ? 'Buscar trekker por nombre...' : 'Buscar disco por nombre...',
                hintStyle: const TextStyle(color: kTextMuted, fontSize: 11),
                filled: true,
                fillColor: kPanelBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: kBorderColor, width: 1.2),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: kTextPrimary, width: 1.2),
                ),
              ),
              onChanged: (val) => setState(() => search = val.trim().toLowerCase()),
            ),
          ),

          // Lista de resultados
          Expanded(
            child: tab == 0
                ? _buildCharactersList()
                : _buildDiscsList(),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(int index, String label) {
    final isSelected = tab == index;
    return InkWell(
      onTap: () => setState(() {
        tab = index;
        selectedElement = 'TODOS';
        selectedGrade = null;
        search = '';
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kTextPrimary : kPanelBg,
          border: Border.all(
            color: isSelected ? kTextPrimary : kBorderColor,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: isSelected ? kInk : kTextMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildCharactersList() {
    return _Loader<dynamic>(
      load: (refresh) => Api.get('characters', refresh: refresh),
      builder: (context, data, refresh) {
        final list = _asList(data).map(_asMap).where((c) {
          final name = _string(c['name']).toLowerCase();
          final elem = _string(c['element']).toUpperCase();
          final grade = c['grade'] is int ? c['grade'] as int : int.tryParse('${c['grade']}');

          if (selectedElement != 'TODOS' && elem != selectedElement) return false;
          if (selectedGrade != null && grade != selectedGrade) return false;
          if (search.isNotEmpty && !name.contains(search)) return false;
          return true;
        }).toList();

        if (list.isEmpty) {
          return const _EmptyNote('No se encontraron personajes con los filtros seleccionados.');
        }

        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final c = list[i];
              return _buildCharacterCard(c);
            },
          ),
        );
      },
    );
  }

  Widget _buildCharacterCard(Map<String, dynamic> c) {
    final name = _string(c['name'], 'Trekker');
    final icon = _string(c['icon'], _string(c['portrait']));
    final elem = _string(c['element']);
    final grade = c['grade'] ?? 5;
    final pos = _term(_string(c['position']));
    final faction = _string(c['faction']);
    final elemCol = _elementColor(elem);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: kPanelBg,
        border: Border.all(color: kBorderColor, width: 1.2),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => TrekkerDetailPage(character: c)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _Thumb(icon, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kTextPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        if (elem.isNotEmpty)
                          _Tag(_elementLabel(elem), color: elemCol),
                        _Tag('$grade★', color: kAccentAmber),
                        if (pos.isNotEmpty)
                          _Tag(pos, color: const Color(0xffd9d6d0)),
                        if (faction.isNotEmpty)
                          _Tag(faction, color: kTextMuted),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 12, color: kTextMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscsList() {
    return _Loader<dynamic>(
      load: (refresh) => Api.get('discs', refresh: refresh),
      builder: (context, data, refresh) {
        final list = _asList(data).map(_asMap).where((d) {
          final name = _string(d['name']).toLowerCase();
          final star = d['star'] is int ? d['star'] as int : int.tryParse('${d['star']}');

          if (selectedGrade != null && star != selectedGrade) return false;
          if (search.isNotEmpty && !name.contains(search)) return false;
          return true;
        }).toList();

        if (list.isEmpty) {
          return const _EmptyNote('No se encontraron discos con los filtros seleccionados.');
        }

        return Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 6), child: Row(children: [
            Text('${list.length} DE ${_asList(data).length} DISCS',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: kTextMuted)),
          ])),
          Expanded(child: RefreshIndicator(
            onRefresh: refresh,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              itemCount: list.length,
              itemBuilder: (ctx, i) => _buildDiscCard(list[i]),
            ),
          )),
        ]);
      },
    );
  }

  Widget _buildDiscCard(Map<String, dynamic> d) {
    final name = _string(d['name'], 'Disco Rúnico');
    final icon = _string(d['icon'], _string(d['base']));
    final star = d['star'] ?? 3;
    final story = _asMap(d['story']);
    final desc = _cleanGameText(_string(story['description']));
    final elem = _string(d['element']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: kPanelBg,
        border: Border.all(color: kBorderColor, width: 1.2),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => DiscDetailPage(disc: d)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _Thumb(icon, size: 52, fallbackIcon: Icons.album_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kTextPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Tag('$star★', color: star >= 5 ? kAccentAmber : (star == 4 ? kAccentPurple : const Color(0xffd9d6d0))),
                        if (elem.isNotEmpty && elem != 'None') ...[
                          const SizedBox(width: 6),
                          _Tag(_elementLabel(elem), color: _elementColor(elem)),
                        ],
                      ],
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: kTextMuted),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 12, color: kTextMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PÁGINAS INDIVIDUALES (ACCESIBLES DESDE EL MENÚ LATERAL)
// ─────────────────────────────────────────────────────────────

class CharactersPage extends StatelessWidget {
  const CharactersPage({super.key});

  @override
  Widget build(BuildContext context) => const DatabasePage(initialTab: 0);
}

class DiscsPage extends StatelessWidget {
  const DiscsPage({super.key});

  @override
  Widget build(BuildContext context) => const DatabasePage(initialTab: 1);
}

// ─────────────────────────────────────────────────────────────
// DETALLE DE TREKKER (COMPLETO: HABILIDADES, SKINS, CITAS, CV)
// ─────────────────────────────────────────────────────────────

class TrekkerDetailPage extends StatelessWidget {
  const TrekkerDetailPage({super.key, required this.character});
  final Map<String, dynamic> character;

  @override
  Widget build(BuildContext context) {
    final id = character['id'];
    final initialName = _string(character['name'], 'Trekker');

    return Scaffold(
      appBar: _subAppBar(initialName.toUpperCase()),
      body: _Loader<dynamic>(
        load: (refresh) => Api.get('character/$id', refresh: refresh).catchError((_) => character),
        builder: (context, data, refresh) {
          final c = _asMap(data);
          final portrait = _string(c['portrait'], _string(c['background'], _string(c['icon'])));
          final elem = _string(c['element']);
          final elemCol = _elementColor(elem);
          final grade = c['grade'] ?? 5;
          final pos = _term(_string(c['position']));
          final atkType = _term(_string(c['attackType']));
          final style = _term(_string(c['style']));
          final faction = _string(c['faction']);
          final birthday = _string(c['birthday']);
          final desc = _string(c['description']);
          final voiceActor = _asMap(c['voiceActor']);
          final skins = _asList(c['skins']).map(_asMap).toList();
          final dateEvents = _asList(c['dateEvents']).map(_asMap).toList();
          final giftPrefs = _asMap(c['giftPreferences']);
          final normalAttack = _asMap(c['normalAttack']);
          final skill = _asMap(c['skill']);
          final supportSkill = _asMap(c['supportSkill']);
          final ultimate = _asMap(c['ultimate']);
          final combatSkills = <(String, Map<String, dynamic>)>[
            if (normalAttack.isNotEmpty) ('ATAQUE BÁSICO', normalAttack),
            if (skill.isNotEmpty) ('HABILIDAD PRINCIPAL', skill),
            if (supportSkill.isNotEmpty) ('HABILIDAD DE APOYO', supportSkill),
            if (ultimate.isNotEmpty) ('HABILIDAD DEFINITIVA', ultimate),
          ];

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Ilustración Principal
              if (portrait.isNotEmpty)
                Container(
                  height: 460,
                  decoration: BoxDecoration(
                    color: kPanelBg,
                    border: Border.all(color: kBorderHighlight, width: 2),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_string(c['background']).isNotEmpty)
                        Opacity(opacity: 0.55, child: _NetImage(_string(c['background']))),
                      Image.network(
                        Api.asset(portrait),
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomCenter,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: Text(_string(c['name']).toUpperCase(), style: kDisplay(34)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // Cabecera Técnica
              _Panel(
                title: 'Ficha',
                badge: '$grade★',
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (elem.isNotEmpty)
                          _Tag(_elementLabel(elem), color: elemCol, filled: true),
                        _Tag('$grade★', color: kAccentAmber),
                        if (pos.isNotEmpty) _Tag(pos, color: const Color(0xffd9d6d0)),
                        if (atkType.isNotEmpty) _Tag(atkType, color: const Color(0xff0abec5)),
                        if (style.isNotEmpty) _Tag(style, color: const Color(0xffec6d21)),
                        if (faction.isNotEmpty) _Tag(faction, color: kTextMuted),
                      ],
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(desc, style: const TextStyle(color: Color(0xffd9d6d0), fontSize: 12, height: 1.4)),
                    ],
                    const SizedBox(height: 12),
                    if (birthday.isNotEmpty) _InfoRow('CUMPLEAÑOS', birthday),
                    if (voiceActor['jp'] != null)
                      _InfoRow('CV (JAPONÉS)', '${voiceActor['jp']} (${voiceActor['jpLocalized'] ?? ''})'),
                    if (voiceActor['cn'] != null)
                      _InfoRow('CV (CHINO)', '${voiceActor['cn']} (${voiceActor['cnLocalized'] ?? ''})'),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Habilidades de Combate
              _Panel(
                title: 'Habilidades',
                badge: 'Combate',
                padding: const EdgeInsets.all(12),
                child: _TrekkerSkillsPanel(skills: combatSkills),
              ),
              const SizedBox(height: 14),

              ..._extraTrekkerPanels(c),

              // Galería de Trajes y Skins
              if (skins.isNotEmpty) ...[
                _Panel(
                  title: 'Trajes y Apariencias',
                  badge: '${skins.length} TRAJES',
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: skins.map((sk) {
                      final sName = _string(sk['name']);
                      final sDesc = _string(sk['description']);
                      final textures = _asMap(sk['textures']);
                      final sIcon = _string(textures['icon'], _string(textures['portrait'], _string(textures['banner'], _string(sk['icon']))));
                      final sPortrait = _string(textures['portrait'], sIcon);
                      final sBackground = _string(textures['background']);
                      final skinArt = _skinArtCandidates(sk['id'], sPortrait);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xff1d1b18),
                          border: Border.all(color: kBorderColor),
                        ),
                        child: InkWell(
                          onTap: () => _showSkinViewer(context, sk, skinArt, sBackground),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AspectRatio(aspectRatio: 24 / 17,
                                child: _NetImage(skinArt.first, fit: BoxFit.contain, alt: skinArt.skip(1).toList())),
                              Row(children: [
                                _Thumb(sIcon, size: 50, fit: BoxFit.contain, alt: [sPortrait, _string(textures['background'])]),
                                const SizedBox(width: 10),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(sName.toUpperCase(),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                    if (sDesc.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(sDesc,
                                        style: const TextStyle(fontSize: 10, color: kTextMuted, height: 1.3),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                    ],
                                  ],
                                )),
                              ]),
                              const SizedBox(height: 5),
                              const Text('TOCA PARA VER LA APARIENCIA COMPLETA', textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 9, color: kTextMuted, letterSpacing: .5)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Citas y Encuentros
              if (dateEvents.isNotEmpty) ...[
                _Panel(
                  title: 'Encuentros y Citas',
                  badge: 'ROMANCE',
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: dateEvents.map((ev) {
                      final evName = _string(ev['name']);
                      final evClue = _string(ev['clue']);
                      final evChoice = _string(ev['secondChoice']);
                      final evIcon = _string(ev['icon']);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xff1d1b18),
                          border: Border.all(color: kSkillOrange.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            _Thumb(evIcon, size: 52, fallbackIcon: Icons.favorite_border),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(evName.toUpperCase(),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  if (evClue.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text('PISTA: $evClue', style: const TextStyle(fontSize: 9, color: kTextMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                  if (evChoice.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text('RESPUESTA: "$evChoice"', style: const TextStyle(fontSize: 9, color: kSkillOrange), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Preferencias de Regalos
              if (giftPrefs.isNotEmpty) ...[
                _Panel(
                  title: 'Preferencias de Regalos',
                  badge: 'AFINIDAD',
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (giftPrefs['loves'] is List) ...[
                        const Text('LE ENCANTA (AFINIDAD MÁXIMA):', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kSkillOrange)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _asList(giftPrefs['loves']).map((g) => _giftTile('$g', loved: true)).toList(),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (giftPrefs['likes'] is List) ...[
                        const Text('LE GUSTA (AFINIDAD NORMAL):', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kAccentAmber)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _asList(giftPrefs['likes']).map((g) => _giftTile('$g')).toList(),
                        ),
                      ],
                      if (giftPrefs['hates'] is List && _asList(giftPrefs['hates']).isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text('NO LE GUSTA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kDestructive)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 6, children: _asList(giftPrefs['hates']).map((g) => _giftTile('$g', disliked: true)).toList()),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  List<String> _skinArtCandidates(dynamic id, String fallback) {
    final skinId = _string(id);
    const cdn = 'https://k2b1c5ab57ed98e51.gachawiki.info/stella-sora/charart';
    return [
      // StellaBase tries the full CG and full skin artwork before portrait files.
      if (skinId.isNotEmpty) '${skinId}_CG.png',
      if (skinId.isNotEmpty) '$skinId.png',
      if (skinId.isNotEmpty) '$cdn/${skinId}_adv.png',
      if (skinId.isNotEmpty) '$cdn/${skinId}_SK.png',
      if (fallback.isNotEmpty) fallback,
    ];
  }

  Widget _giftTile(String name, {bool loved = false, bool disliked = false}) {
    const aliases = {
      'Card Capturer': 'card-photo-capturer',
      'Chill Crushed Ice': 'summer-chill-crushed-ice',
      'Porcelain Cup': 'blossom-porcelain-cup',
      'Star Eclipse': 'stellanite-enchantment',
      'Sweet Ice Furry': 'sweet-icefurry',
    };
    final slug = aliases[name] ?? name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
    final color = disliked ? kDestructive : loved ? kSkillOrange : kAccentAmber;
    const cdn = 'https://k2b1c5ab57ed98e51.gachawiki.info/stella-sora/items';
    return Container(
      width: 86,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: kSurface, border: Border.all(color: color.withValues(alpha: .65))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 58, height: 58, child: _NetImage('$cdn/$slug.png', fit: BoxFit.contain,
          alt: ['$cdn/${name.toLowerCase().replaceAll(' ', '_')}.png'],
          fallbackIcon: Icons.card_giftcard_outlined)),
        const SizedBox(height: 4),
        Text(name, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9, height: 1.15)),
      ]),
    );
  }

  void _showSkinViewer(BuildContext context, Map<String, dynamic> skin, List<String> art, String background) {
    showDialog<void>(context: context, barrierColor: Colors.black, builder: (ctx) => Dialog.fullscreen(
      backgroundColor: kBgDark,
      child: SafeArea(child: Column(children: [
        Row(children: [
          IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close), tooltip: 'Cerrar'),
          Expanded(child: Text(_string(skin['name']).toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center, style: kDisplay(18))),
          const SizedBox(width: 48),
        ]),
        Expanded(child: Center(child: InteractiveViewer(
          minScale: 0.7, maxScale: 6, panEnabled: true, scaleEnabled: true,
          boundaryMargin: const EdgeInsets.all(100), clipBehavior: Clip.none,
          child: AspectRatio(aspectRatio: 24 / 17, child: Stack(fit: StackFit.expand, children: [
            if (background.isNotEmpty) _NetImage(background, fit: BoxFit.cover),
            _NetImage(art.first, fit: BoxFit.contain, alt: art.skip(1).toList()),
          ])),
        ))),
        if (_string(skin['description']).isNotEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 18), child: Text(
            _cleanGameText(_string(skin['description'])), textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, height: 1.4, color: kTextMuted))),
      ])),
    ));
  }
}

// ─────────────────────────────────────────────────────────────
// DETALLE DE DISCO (HABILIDADES, HISTORIA, ATRIBUTOS)
// ─────────────────────────────────────────────────────────────

class DiscDetailPage extends StatelessWidget {
  const DiscDetailPage({super.key, required this.disc});
  final Map<String, dynamic> disc;

  @override
  Widget build(BuildContext context) {
    final id = disc['id'];
    final initialName = _string(disc['name'], 'Disco Rúnico');

    return Scaffold(
      appBar: _subAppBar(initialName.toUpperCase()),
      body: _Loader<dynamic>(
        load: (refresh) => Api.get('disc/$id', refresh: refresh).catchError((_) => disc),
        builder: (context, data, refresh) {
          final d = _asMap(data);
          final star = d['star'] ?? 3;
          final elem = _string(d['element']);
          final tags = _asList(d['tag']);
          final icon = _string(d['icon'], _string(d['base']));
          final bg = _string(d['background']);
          final heroImg = bg.isNotEmpty ? bg : icon;
          final story = _asMap(d['story']);
          final storyDesc = _cleanGameText(_string(story['description']));
          final mainSkill = _asMap(d['mainSkill']);
          final secondarySkills = _asList(d['secondarySkills']).map(_asMap).toList();

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Imagen del Disco
              if (heroImg.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: kPanelBg,
                    border: Border.all(color: kBorderColor, width: 1.2),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _NetImage(
                      _string(_asMap(d['variants'])['gacha']),
                      fit: BoxFit.contain,
                      fallbackIcon: Icons.album_outlined,
                      alt: [_string(_asMap(d['variants'])['base']), heroImg, icon],
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              // Ficha Técnica
              _Panel(
                title: 'Ficha del Disco',
                badge: '$star★',
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Tag('$star★', color: star >= 5 ? kAccentAmber : (star == 4 ? kAccentPurple : const Color(0xffd9d6d0))),
                        if (elem.isNotEmpty && elem != 'None')
                          _Tag(_elementLabel(elem), color: _elementColor(elem)),
                        for (final t in tags)
                          _Tag(_term('$t'), color: const Color(0xffd9d6d0)),
                      ],
                    ),
                    if (storyDesc.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('HISTORIA / LORE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kTextMuted)),
                      const SizedBox(height: 4),
                      Text(storyDesc, style: const TextStyle(fontSize: 11, color: Color(0xffd9d6d0), height: 1.5)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Habilidad Principal
              if (mainSkill.isNotEmpty) ...[
                _Panel(
                  title: 'Efecto Principal',
                  badge: 'HABILIDAD',
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Thumb(_string(mainSkill['icon']), size: 44, fallbackIcon: Icons.auto_awesome),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_string(mainSkill['name']).toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(_cleanGameText(_string(mainSkill['description'])),
                                style: const TextStyle(fontSize: 11, color: Color(0xffd9d6d0), height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Habilidades Secundarias
              if (secondarySkills.isNotEmpty) ...[
                _Panel(
                  title: 'Efectos Secundarios',
                  badge: '${secondarySkills.length} EFECTOS',
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: secondarySkills.map((sk) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Thumb(_string(sk['icon']), size: 38, fallbackIcon: Icons.auto_awesome),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_string(sk['name']).toUpperCase(),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 3),
                                  Text(_cleanGameText(_string(sk['description'])),
                                      style: const TextStyle(fontSize: 11, color: Color(0xffd9d6d0), height: 1.3)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CALENDARIO COMPLETO DE CUMPLEAÑOS
// ─────────────────────────────────────────────────────────────

class BirthdaysPage extends StatelessWidget {
  const BirthdaysPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _subAppBar('CALENDARIO DE CUMPLEAÑOS'),
      body: _Loader<dynamic>(
        load: (refresh) => Api.get('characters', refresh: refresh),
        builder: (context, data, refresh) {
          final now = DateTime.now();
          final characters = _asList(data).map(_asMap).toList();
          final sorted = <Map<String, dynamic>>[];

          for (final c in characters) {
            final bStr = _string(c['birthday']);
            if (bStr.isEmpty || !bStr.contains('.')) continue;
            final parts = bStr.split('.');
            final month = int.tryParse(parts[0]);
            final day = int.tryParse(parts[1]);
            if (month == null || day == null) continue;

            var bDate = DateTime(now.year, month, day);
            if (bDate.isBefore(DateTime(now.year, now.month, now.day))) {
              bDate = DateTime(now.year + 1, month, day);
            }
            final daysDiff = bDate.difference(DateTime(now.year, now.month, now.day)).inDays;

            sorted.add({
              'character': c,
              'name': _string(c['name']),
              'element': _string(c['element']),
              'dateStr': '${day.toString().padLeft(2, '0')} ${_months[month - 1]}',
              'daysLeft': daysDiff,
              'icon': _string(c['icon'], _string(c['portrait'])),
            });
          }

          sorted.sort((a, b) => (a['daysLeft'] as int).compareTo(b['daysLeft'] as int));

          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: sorted.length,
              itemBuilder: (ctx, i) {
                final b = sorted[i];
                final elem = _string(b['element']);
                final col = _elementColor(elem);
                final days = b['daysLeft'] as int;

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kPanelBg,
                    border: Border.all(color: days <= 7 ? kAccentPurple : kBorderColor),
                  ),
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => TrekkerDetailPage(character: b['character'])),
                    ),
                    child: Row(
                      children: [
                        _Thumb(b['icon'], size: 40),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b['name'].toString().toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text('${b['dateStr']} · ${_elementLabel(elem)}',
                                  style: TextStyle(fontSize: 10, color: col, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: days <= 7 ? kAccentPurple.withValues(alpha: 0.2) : const Color(0xff1d1b18),
                            border: Border.all(color: days <= 7 ? kAccentPurple : kBorderHighlight),
                          ),
                          child: Text(
                            days == 0 ? '¡HOY!' : 'EN $days DÍAS',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: days <= 7 ? kTextPrimary : kTextMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SECCIONES COMPLETAS DE LA FICHA (potenciales, talentos, stats, mejoras)
// ─────────────────────────────────────────────────────────────

List<Widget> _extraTrekkerPanels(Map<String, dynamic> c) {
  final out = <Widget>[];
  final pots = _asMap(c['potentials']);
  const potLabels = {
    'mainCore': 'Núcleo (principal)',
    'mainNormal': 'Principal',
    'supportCore': 'Núcleo (apoyo)',
    'supportNormal': 'Apoyo',
    'common': 'Comunes',
  };
  if (pots.isNotEmpty) {
    out.add(_TrekkerPotentialsPanel(potentials: pots, labels: potLabels));
    out.add(const SizedBox(height: 14));
  }

  final talents = _asList(c['talents']).map(_asMap).toList();
  if (talents.isNotEmpty) {
    out.add(_Panel(
      title: 'Talentos',
      badge: '${talents.length} ramas',
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final g in talents) ...[
          Text(_string(g['name']).toUpperCase(), style: kDisplay(16)),
          const SizedBox(height: 6),
          for (final (i, t) in _asList(g['talents']).map(_asMap).indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 24, child: Text('${i + 1}', style: kDisplay(14, color: kTextMuted))),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_string(t['name']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    Text(_cleanGameText(_string(t['description']), params: _asList(t['params'])),
                        style: const TextStyle(fontSize: 11.5, height: 1.4, color: kTextMuted)),
                  ]),
                ),
              ]),
            ),
          const SizedBox(height: 8),
        ],
      ]),
    ));
    out.add(const SizedBox(height: 14));
  }

  final stats = _asList(c['stats']).map(_asMap).toList();
  if (stats.isNotEmpty) {
    out.add(_TrekkerStatsPanel(stats: stats));
    out.add(const SizedBox(height: 14));
  }

  for (final (key, title) in [('upgrades', 'Ascensión'), ('skillUpgrades', 'Mejora de habilidades')]) {
    final ups = _asList(c[key]).map(_asMap).toList();
    if (ups.isEmpty) continue;
    out.add(_Panel(
      title: title,
      badge: 'Materiales',
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        for (final (i, u) in ups.indexed)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorderColor))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              SizedBox(width: 30, child: Text('${i + 1}', style: kDisplay(16))),
              Expanded(
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final it in _asList(u['items']).map(_asMap))
                    Tooltip(
                      message: _string(it['name']),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        _itemThumb(it['id'], size: 36),
                        Text('×${it['quantity']}', style: const TextStyle(fontSize: 10)),
                      ]),
                    ),
                ]),
              ),
              Row(mainAxisSize: MainAxisSize.min, children: [
                _Thumb('https://k2b1c5ab57ed98e51.gachawiki.info/stella-sora/upgrades/dorra.png',
                  size: 22, fallbackIcon: Icons.toll_outlined),
                const SizedBox(width: 4),
                Text('${_formatNumber(_string(_asMap(u['currency'])['dorra']))} Dorra',
                    style: const TextStyle(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
      ]),
    ));
    out.add(const SizedBox(height: 14));
  }
  return out;
}

class _TrekkerStatsPanel extends StatefulWidget {
  const _TrekkerStatsPanel({required this.stats});
  final List<Map<String, dynamic>> stats;

  @override
  State<_TrekkerStatsPanel> createState() => _TrekkerStatsPanelState();
}

class _TrekkerSkillsPanel extends StatefulWidget {
  const _TrekkerSkillsPanel({required this.skills});
  final List<(String, Map<String, dynamic>)> skills;

  @override
  State<_TrekkerSkillsPanel> createState() => _TrekkerSkillsPanelState();
}

class _TrekkerSkillsPanelState extends State<_TrekkerSkillsPanel> {
  int _level = 13;

  @override
  Widget build(BuildContext context) {
    final maxLevel = widget.skills
        .map((entry) => _asList(entry.$2['params']).fold<int>(1, (max, param) {
          final count = '$param'.split('/').length;
          return count > max ? count : max;
        }))
        .fold<int>(1, (max, count) => count > max ? count : max);
    final level = _level.clamp(1, maxLevel);
    return Column(children: [
      Row(children: [
        const Expanded(child: Text('NIVEL DE HABILIDAD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kTextMuted))),
        Text('$level / $maxLevel', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
      if (maxLevel > 1)
        Slider(value: level.toDouble(), min: 1, max: maxLevel.toDouble(), divisions: maxLevel - 1,
          activeColor: kTextPrimary, onChanged: (value) => setState(() => _level = value.round())),
      for (final (label, skill) in widget.skills) _skillTile(label, skill, level),
    ]);
  }

  Widget _skillTile(String label, Map<String, dynamic> skill, int level) {
    final params = _asList(skill['params']).map((param) {
      final values = '$param'.split('/');
      return values.length > 1 ? values[(level - 1).clamp(0, values.length - 1)] : param;
    }).toList();
    final description = _cleanGameText(_string(skill['description']), params: params);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xff1d1b18), border: Border.all(color: kBorderHighlight)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Thumb(_string(skill['icon']), size: 44, fallbackIcon: Icons.bolt),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(_string(skill['name'], 'Habilidad').toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
            _Tag(label, color: kAccentPurple),
          ]),
          if (skill['cooldown'] != null) ...[
            const SizedBox(height: 2),
            Text('ENFRIAMIENTO: ${skill['cooldown']}', style: const TextStyle(fontSize: 9, color: kAccentAmber)),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(description, style: const TextStyle(fontSize: 11, color: Color(0xffd9d6d0), height: 1.4)),
          ],
        ])),
      ]),
    );
  }
}

class _TrekkerPotentialsPanel extends StatefulWidget {
  const _TrekkerPotentialsPanel({required this.potentials, required this.labels});
  final Map<String, dynamic> potentials;
  final Map<String, String> labels;

  @override
  State<_TrekkerPotentialsPanel> createState() => _TrekkerPotentialsPanelState();
}

class _TrekkerPotentialsPanelState extends State<_TrekkerPotentialsPanel> {
  int _level = 13;

  int get _maxLevel {
    var result = 1;
    for (final group in widget.labels.keys) {
      for (final potential in _asList(widget.potentials[group]).map(_asMap)) {
        for (final param in _asList(potential['params'])) {
          final count = '$param'.split('/').length;
          if (count > result) result = count;
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final level = _level.clamp(1, _maxLevel);
    return _Panel(
      title: 'Potenciales',
      badge: '$_maxLevel niveles',
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Text('NIVEL DE POTENCIALES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kTextMuted))),
          Text('$level / $_maxLevel', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
        if (_maxLevel > 1)
          Slider(value: level.toDouble(), min: 1, max: _maxLevel.toDouble(), divisions: _maxLevel - 1,
            activeColor: kTextPrimary, onChanged: (value) => setState(() => _level = value.round())),
        for (final group in widget.labels.keys)
          if (_asList(widget.potentials[group]).isNotEmpty) ...[
            Text(widget.labels[group]!.toUpperCase(), style: kDisplay(16)),
            const SizedBox(height: 6),
            for (final p in _asList(widget.potentials[group]).map(_asMap))
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(border: Border.all(color: kBorderColor)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _PotentialPlate(p, size: 48),
                  const SizedBox(width: 9),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(_string(p['name']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                      if (p['rarity'] != null) _Tag('R${p['rarity']}', color: kTextMuted),
                    ]),
                    const SizedBox(height: 4),
                    Text(_cleanGameText(_string(p['description']), params: _paramsAtLevel(_asList(p['params']), level)),
                      style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xffd9d6d0))),
                  ])),
                ]),
              ),
          ],
      ]),
    );
  }
}

List<dynamic> _paramsAtLevel(List<dynamic> params, int level) => params.map((param) {
  final values = '$param'.split('/');
  return values.length > 1 ? values[(level - 1).clamp(0, values.length - 1)] : param;
}).toList();

class _TrekkerStatsPanelState extends State<_TrekkerStatsPanel> {
  int get _maxLevel => widget.stats.length < 90 ? widget.stats.length : 90;
  late int _level = _maxLevel;

  @override
  Widget build(BuildContext context) {
    final stat = widget.stats[_level - 1];
    return _Panel(
      title: 'Estadísticas',
      badge: '1–$_maxLevel',
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Text('TREKKER LEVEL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kTextMuted))),
          Text('$_level / $_maxLevel', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
        Slider(value: _level.toDouble(), min: 1, max: _maxLevel.toDouble(), divisions: _maxLevel - 1,
          activeColor: kTextPrimary, onChanged: (value) => setState(() => _level = value.round())),
        Row(children: [
          Expanded(child: _value('HP', stat['hp'])),
          const SizedBox(width: 10),
          Expanded(child: _value('ATK', stat['atk'])),
        ]),
      ]),
    );
  }

  Widget _value(String label, dynamic value) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: kSurface, border: Border.all(color: kBorderColor)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 9, color: kTextMuted, fontWeight: FontWeight.w700)),
      const SizedBox(height: 3),
      Text(_formatNumber(_string(value)), style: kDisplay(20)),
    ]),
  );
}
