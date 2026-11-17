part of '../main.dart';

// ─────────────────────────────────────────────────────────────
// CREADOR DE EQUIPOS, SIMULADOR DE RESONANCIA Y BUILDS META
// ─────────────────────────────────────────────────────────────

class TeamBuilderPage extends StatefulWidget {
  const TeamBuilderPage({super.key});

  @override
  State<TeamBuilderPage> createState() => _TeamBuilderPageState();
}

class _TeamBuilderPageState extends State<TeamBuilderPage> {
  int _viewTab = 0; // 0: Simulador de Escuadrón, 1: Builds de la Comunidad

  // Los 3 puestos del escuadrón
  Map<String, dynamic>? _leader;
  Map<String, dynamic>? _sub1;
  Map<String, dynamic>? _sub2;
  List<Map<String, dynamic>?> _mainDiscs = List<Map<String, dynamic>?>.filled(3, null);
  List<Map<String, dynamic>?> _subDiscs = List<Map<String, dynamic>?>.filled(6, null);
  final Map<int, List<Map<String, dynamic>>> _potentials = {0: [], 1: [], 2: []};

  // Equipos guardados en memoria / SharedPreferences
  List<Map<String, dynamic>> _savedTeams = [];

  @override
  void initState() {
    super.initState();
    _loadSavedTeams();
  }

  Future<void> _loadSavedTeams() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString('custom_saved_teams');
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        setState(() {
          _savedTeams = list.cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {}
  }

  Future<void> _saveCurrentTeam(String name) async {
    if (_leader == null && _sub1 == null && _sub2 == null) return;
    try {
      final sp = await SharedPreferences.getInstance();
      final newEntry = {
        'name': name.isEmpty ? 'Escuadrón ${_savedTeams.length + 1}' : name,
        'date': DateTime.now().toIso8601String(),
        'leader': _leader,
        'sub1': _sub1,
        'sub2': _sub2,
        'mainDiscs': _mainDiscs,
        'subDiscs': _subDiscs,
        'potentials': _potentials.map((k, v) => MapEntry('$k', v)),
      };
      final updated = List<Map<String, dynamic>>.from(_savedTeams)..insert(0, newEntry);
      await sp.setString('custom_saved_teams', jsonEncode(updated));
      setState(() => _savedTeams = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Escuadrón guardado con éxito!'),
            backgroundColor: kAccentGreen,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _deleteSavedTeam(int index) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final updated = List<Map<String, dynamic>>.from(_savedTeams)..removeAt(index);
      await sp.setString('custom_saved_teams', jsonEncode(updated));
      setState(() => _savedTeams = updated);
    } catch (_) {}
  }

  void _loadSquad(Map<String, dynamic>? l, Map<String, dynamic>? s1, Map<String, dynamic>? s2, [Map<String, dynamic>? saved]) {
    setState(() {
      _leader = l;
      _sub1 = s1;
      _sub2 = s2;
      if (saved != null) {
        _mainDiscs = _nullableMaps(saved['mainDiscs'], 3);
        _subDiscs = _nullableMaps(saved['subDiscs'], 6);
        final raw = _asMap(saved['potentials']);
        for (var i = 0; i < 3; i++) {
          _potentials[i] = _asList(raw['$i']).map(_asMap).toList();
        }
      } else {
        _mainDiscs = List<Map<String, dynamic>?>.filled(3, null);
        _subDiscs = List<Map<String, dynamic>?>.filled(6, null);
        for (var i = 0; i < 3; i++) { _potentials[i] = []; }
      }
      _viewTab = 0;
    });
  }

  List<Map<String, dynamic>?> _nullableMaps(dynamic raw, int size) {
    final values = _asList(raw).map((v) => v == null ? null : _asMap(v)).toList();
    return List<Map<String, dynamic>?>.generate(size, (i) => i < values.length ? values[i] : null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Cabecera Brutalista
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: kPanelHeaderBg,
                border: Border(bottom: BorderSide(color: kBorderColor, width: 1.2)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: kTextPrimary),
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Volver',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TEAM BUILDER',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'TREKKERS · DISCS · POTENTIALS',
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
                  const _MenuButton(),
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
                  _navTab(0, 'SIMULADOR', Icons.group_work_outlined),
                  _navTab(1, 'BUILDS META', Icons.auto_graph_outlined),
                  _navTab(2, 'GUARDADOS (${_savedTeams.length})', Icons.bookmark_border_outlined),
                ],
              ),
            ),

            // Contenido
            Expanded(
              child: IndexedStack(
                index: _viewTab,
                children: [
                  _buildSimulatorTab(),
                  _buildMetaBuildsTab(),
                  _buildSavedTeamsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navTab(int idx, String label, IconData icon) {
    final sel = _viewTab == idx;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _viewTab = idx),
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
              Icon(icon, size: 15, color: sel ? kTextPrimary : kTextMuted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
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

  // ─────────────────────────────────────────────────────────────
  // PESTAÑA 1: SIMULADOR DE ESCUADRÓN
  // ─────────────────────────────────────────────────────────────

  Widget _buildSimulatorTab() {
    final activeCount = [_leader, _sub1, _sub2].where((t) => t != null).length;
    final synergies = _calculateSynergies();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Selector de 3 puestos
        Row(
          children: [
            Expanded(child: _buildSlot('LÍDER', _leader, 0, Icons.star_border)),
            const SizedBox(width: 8),
            Expanded(child: _buildSlot('APOYO 1', _sub1, 1, Icons.shield_outlined)),
            const SizedBox(width: 8),
            Expanded(child: _buildSlot('APOYO 2', _sub2, 2, Icons.flash_on_outlined)),
          ],
        ),
        const SizedBox(height: 14),
        _discSlots('MAIN', _mainDiscs, 3),
        const SizedBox(height: 10),
        _discSlots('SUB', _subDiscs, 6),
        const SizedBox(height: 14),
        for (final entry in <(String, Map<String, dynamic>?, int)>[
          ('MAIN', _leader, 0), ('SUPPORT 1', _sub1, 1), ('SUPPORT 2', _sub2, 2),
        ]) if (entry.$2 != null) _potentialControl(entry.$1, entry.$2!, entry.$3),
        const SizedBox(height: 14),
        const SizedBox(height: 16),

        // Barra de acciones del simulador
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: activeCount == 0 ? null : () => _promptSaveTeam(),
                icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                label: const Text('GUARDAR ESCUADRÓN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kTextPrimary,
                  side: const BorderSide(color: kBorderColor),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: activeCount == 0
                  ? null
                  : () => setState(() {
                        _leader = null;
                        _sub1 = null;
                        _sub2 = null;
                        _mainDiscs = List<Map<String, dynamic>?>.filled(3, null);
                        _subDiscs = List<Map<String, dynamic>?>.filled(6, null);
                        for (var i = 0; i < 3; i++) { _potentials[i] = []; }
                      }),
              style: OutlinedButton.styleFrom(
                foregroundColor: kDestructive,
                side: const BorderSide(color: kBorderColor),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              ),
              child: const Text('LIMPIAR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Cálculo de Poder de Combate y Resonancias
        _Panel(
          title: 'ANÁLISIS TÁCTICO DEL ESCUADRÓN',
          right: _Tag(
            activeCount == 3 ? 'ESCUADRÓN COMPLETO' : '$activeCount/3 ASIGNADOS',
            color: activeCount == 3 ? kAccentGreen : kAccentAmber,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Estimación de Poder de Combate (BP)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xff1d1b18),
                  border: Border(bottom: BorderSide(color: kBorderColor)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, color: kAccentAmber, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PODER DE COMBATE ESTIMADO (BP)',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: kTextMuted),
                          ),
                          Text(
                            '${_formatNumber((activeCount * 7850 + (activeCount == 3 ? 3200 : 0)).toString())} BP',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Lista de Resonancias activadas
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'EFECTOS Y RESONANCIAS ACTIVAS:',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: kTextMuted),
                    ),
                    const SizedBox(height: 8),
                    if (synergies.isEmpty)
                      const Text(
                        'Selecciona al menos 2 Trekkers para activar resonancias de afinidad elemental y sinergias tácticas.',
                        style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.4),
                      )
                    else
                      for (final syn in synergies)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: kPanelBg,
                            border: Border.all(color: syn.color.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(syn.icon, size: 18, color: syn.color),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      syn.title,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: syn.color,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      syn.description,
                                      style: const TextStyle(fontSize: 11, color: Color(0xffd9d6d0), height: 1.3),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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

  Widget _discSlots(String label, List<Map<String, dynamic>?> discs, int capacity) => _Panel(
    title: '$label · ${discs.where((d) => d != null).length}/$capacity',
    padding: const EdgeInsets.all(10),
    child: Wrap(spacing: 8, runSpacing: 8, children: [
      for (var i = 0; i < capacity; i++) InkWell(
        onTap: () => _openDiscPicker(label == 'MAIN' ? _mainDiscs : _subDiscs, i),
        child: Container(width: 76, height: 92, decoration: BoxDecoration(
          border: Border.all(color: discs[i] == null ? kBorderColor : kBorderHighlight)),
          child: Stack(children: [
            Center(child: discs[i] == null
              ? const Icon(Icons.add, color: kTextMuted)
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _Thumb(_string(discs[i]!['icon']), size: 48, fallbackIcon: Icons.album_outlined),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: Text(_string(discs[i]!['name']),
                    maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 8))),
                ])),
            if (discs[i] != null) Positioned(right: 0, top: 0, child: InkWell(
              onTap: () => setState(() => discs[i] = null),
              child: const Icon(Icons.close, size: 16, color: kDestructive))),
          ]),
        ),
      ),
    ]),
  );

  void _openDiscPicker(List<Map<String, dynamic>?> target, int index) {
    showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: kBgDark,
      builder: (ctx) => SafeArea(child: SizedBox(height: MediaQuery.sizeOf(ctx).height * .8,
        child: FutureBuilder<dynamic>(future: Api.get('discs'), builder: (context, snap) {
          if (!snap.hasData) return const Center(child: _Spinner());
          final list = _asList(snap.data).map(_asMap).toList();
          return ListView(children: [
            ListTile(title: const Text('Seleccionar disco'), trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))),
            for (final disc in list) ListTile(
              leading: _Thumb(_string(disc['icon'], _string(disc['base'])), size: 44, fallbackIcon: Icons.album_outlined),
              title: Text(_string(disc['name'])), subtitle: Text('${_string(disc['star'])}★ · ${_string(disc['element'])}'),
              onTap: () { setState(() => target[index] = disc); Navigator.pop(ctx); },
            ),
          ]);
        }))),
    );
  }

  Widget _potentialControl(String label, Map<String, dynamic> trekker, int index) => Container(
    margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: kPanelBg, border: Border.all(color: kBorderColor)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text('$label · ${_potentials[index]?.length ?? 0} potenciales', style: kDisplay(16))),
        TextButton.icon(onPressed: () => _openPotentialPicker(index, trekker), icon: const Icon(Icons.tune, size: 16), label: const Text('EDITAR'))]),
      for (final p in _potentials[index] ?? const <Map<String, dynamic>>[])
        Container(margin: const EdgeInsets.only(bottom: 5), padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: kSurface, border: Border.all(color: kBorderColor)),
          child: Row(children: [
            _PotentialPlate(p, size: 42),
            const SizedBox(width: 7),
            Expanded(child: Text('${_string(p['name'])} · Nv.${_string(p['level'])} · ${_string(p['priority'])}',
              style: const TextStyle(fontSize: 10, color: kTextMuted))),
          ])),
    ]),
  );

  Future<void> _openPotentialPicker(int slot, Map<String, dynamic> trekker) async {
    final detail = _asMap(await Api.get('character/${trekker['id']}'));
    if (!mounted) return;
    final definitions = _asMap(detail['potentials']);
    final categories = slot == 0
      ? ['mainCore', 'mainNormal', 'common']
      : ['supportCore', 'supportNormal', 'common'];
    final optionsByGroup = <String, List<Map<String, dynamic>>>{};
    for (final category in categories) {
      final list = _asList(definitions[category]).map(_asMap).toList();
      optionsByGroup[category] = [
        for (var i = 0; i < list.length; i++) {...list[i], 'ref': '$category:$i'},
      ];
    }
    final selected = <String, Map<String, dynamic>>{
      for (final p in _potentials[slot] ?? []) _string(p['ref']): Map<String, dynamic>.from(p),
    };
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: kBgDark,
      builder: (ctx) => StatefulBuilder(builder: (context, refresh) {
        Widget potentialCard(Map<String, dynamic> p, {required bool disabled}) {
          final ref = _string(p['ref']);
          final chosen = selected[ref];
          return Opacity(opacity: disabled ? .38 : 1, child: Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: kPanelBg, border: Border.all(color: kBorderColor)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _PotentialPlate(p, size: 48),
                Checkbox(value: chosen != null, onChanged: disabled ? null : (v) => refresh(() {
                  if (v == true) {
                    selected[ref] = {...p, 'ref': ref, 'level': 1, 'priority': 'medium'};
                  } else {
                    selected.remove(ref);
                  }
                })),
                const SizedBox(width: 6),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_string(p['name']), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.2)),
                  const SizedBox(height: 4),
                  Text(_cleanGameText(_string(p['description']), params: _asList(p['params'])),
                    style: const TextStyle(fontSize: 11, height: 1.3, color: kTextMuted)),
                ])),
              ]),
              if (chosen != null) ...[
                const SizedBox(height: 7),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  PopupMenuButton<int>(
                    tooltip: 'Cambiar nivel del potencial', padding: EdgeInsets.zero,
                    onSelected: (v) => refresh(() => chosen['level'] = v),
                    itemBuilder: (context) => List.generate(13, (i) => PopupMenuItem(value: i + 1, child: Text('Nivel ${i + 1}'))),
                    child: _potentialSetting('Nivel: ${_string(chosen['level'], '1')}'),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Cambiar prioridad del potencial', padding: EdgeInsets.zero,
                    onSelected: (v) => refresh(() => chosen['priority'] = v),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'core', child: Text('Clave')),
                      PopupMenuItem(value: 'medium', child: Text('Media')),
                      PopupMenuItem(value: 'optional', child: Text('Opcional')),
                    ],
                    child: _potentialSetting('Prioridad: ${switch (_string(chosen['priority'], 'medium')) {
                      'core' => 'Clave', 'optional' => 'Opcional', _ => 'Media',
                    }}'),
                  ),
                ]),
              ],
            ]),
          ));
        }

        return SafeArea(child: SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .85,
        child: Column(children: [
          ListTile(
            title: Text('${_string(trekker['name']).toUpperCase()} · POTENTIALS'),
            subtitle: Text('${selected.length} SELECCIONADOS', style: const TextStyle(fontSize: 10, letterSpacing: 1.1)),
            trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ),
          Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(10, 4, 10, 12), children: [
            for (final category in categories) Builder(builder: (context) {
              final group = optionsByGroup[category] ?? const <Map<String, dynamic>>[];
              final chosenCount = group.where((p) => selected.containsKey(_string(p['ref']))).length;
              final limit = category.endsWith('Core') ? 2 : group.length;
              final label = switch (category) {
                'mainCore' => 'MAIN CORE',
                'mainNormal' => 'MAIN',
                'supportCore' => 'SUPPORT CORE',
                'supportNormal' => 'SUPPORT',
                _ => 'COMMON',
              };
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(padding: const EdgeInsets.fromLTRB(4, 10, 4, 7), child: Row(children: [
                  Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: kTextMuted)),
                  const SizedBox(width: 7),
                  Text('$chosenCount/$limit', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kTextMuted)),
                ])),
                for (final p in group)
                  potentialCard(p, disabled: !selected.containsKey(_string(p['ref'])) && chosenCount >= limit),
              ]);
            }),
          ])),
          Padding(padding: const EdgeInsets.all(10), child: SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () { setState(() => _potentials[slot] = selected.values.toList()); Navigator.pop(ctx); },
            child: Text('GUARDAR ${selected.length} POTENCIALES')))),
        ]),
      ));
      }),
    );
  }

  Widget _potentialSetting(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(color: kSurface, border: Border.all(color: kBorderColor)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, maxLines: 1, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kTextPrimary)),
      const SizedBox(width: 3),
      const Icon(Icons.arrow_drop_down, size: 16, color: kTextMuted),
    ]),
  );

  Widget _buildSlot(String roleTag, Map<String, dynamic>? char, int slotIndex, IconData placeholderIcon) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: kPanelBg,
        border: Border.all(color: char != null ? kBorderHighlight : kBorderColor, width: 1.2),
      ),
      child: InkWell(
        onTap: () => _openPicker(slotIndex),
        child: Column(
          children: [
            // Cabecera del Puesto
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: kPanelHeaderBg,
                border: Border(bottom: BorderSide(color: kBorderColor)),
              ),
              child: Text(
                roleTag,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: kTextMuted),
              ),
            ),

            // Contenido o Placeholder
            Expanded(
              child: char == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(placeholderIcon, size: 32, color: kTextMuted),
                        const SizedBox(height: 8),
                        const Text(
                          '+ ASIGNAR',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kTextMuted),
                        ),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        _NetImage(char['icon']?.toString() ?? '', fit: BoxFit.cover),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, kInk.withValues(alpha: 0.9)],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: InkWell(
                            onTap: () => setState(() {
                              if (slotIndex == 0) _leader = null;
                              if (slotIndex == 1) _sub1 = null;
                              if (slotIndex == 2) _sub2 = null;
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              color: kInk.withValues(alpha: 0.6),
                              child: const Icon(Icons.close, size: 14, color: Color(0xffd9d6d0)),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 6,
                          right: 6,
                          bottom: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _Tag(
                                _elementLabel(char['element']?.toString()),
                                color: _elementColor(char['element']?.toString()),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                char['name']?.toString() ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '${char['grade'] ?? char['rarity'] ?? 5}★ · Nv. 90',
                                style: const TextStyle(fontSize: 9, color: kTextMuted),
                              ),
                            ],
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

  void _openPicker(int slotIndex) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kBgDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => _TrekkerPickerSheet(
        onSelected: (trekker) {
          Navigator.pop(ctx);
          setState(() {
            if (slotIndex == 0) _leader = trekker;
            if (slotIndex == 1) _sub1 = trekker;
            if (slotIndex == 2) _sub2 = trekker;
          });
        },
      ),
    );
  }

  void _promptSaveTeam() {
    final controller = TextEditingController(text: 'Mi Escuadrón ${_savedTeams.length + 1}');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kPanelBg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('GUARDAR ESCUADRÓN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          style: const TextStyle(fontSize: 13, color: kTextPrimary),
          decoration: const InputDecoration(
            labelText: 'Nombre de la composición',
            labelStyle: TextStyle(color: kTextMuted, fontSize: 12),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: kBorderColor)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: kTextPrimary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR', style: TextStyle(color: kTextMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kTextPrimary,
              foregroundColor: kInk,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _saveCurrentTeam(controller.text.trim());
            },
            child: const Text('GUARDAR', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PESTAÑA 2: BUILDS META RECOMENDADAS
  // ─────────────────────────────────────────────────────────────

  Widget _buildMetaBuildsTab() {
    final metaSquads = [
      _MetaSquad(
        name: 'META HIDRO-BURBUJA (DOMINIO AQUA)',
        tier: 'TIER S+',
        color: const Color(0xff0abec5),
        leaderName: 'Allie',
        sub1Name: 'Suntide Willow',
        sub2Name: 'Teresa',
        description:
            'Generación incesante de burbujas sonoras que explotan infligiendo daño continuo en área, respaldadas por el escudo torrencial.',
      ),
      _MetaSquad(
        name: 'META OSCURIDAD PROFUNDA (CORRUPCIÓN UMBRA)',
        tier: 'TIER S+',
        color: const Color(0xffa855f7),
        leaderName: 'Karin',
        sub1Name: 'Otoha',
        sub2Name: 'Cosette',
        description:
            'Vórtice voraz de tiburones combinado con el desgarro de sombras de Otoha y el control de garras de Cosette.',
      ),
      _MetaSquad(
        name: 'META LLAMA PURA (IGNICIÓN CRÍTICA)',
        tier: 'TIER S',
        color: const Color(0xfff87171),
        leaderName: 'Rin',
        sub1Name: 'Nanoha',
        sub2Name: 'Florence',
        description:
            'Multiplicadores masivos de daño por fuego con acumulación de quemaduras y ruptura de barras de guardia enemigas.',
      ),
      _MetaSquad(
        name: 'META LUZ CELESTIAL (RESONANCIA LUX)',
        tier: 'TIER S',
        color: const Color(0xfffbbf24),
        leaderName: 'Cosette',
        sub1Name: 'Stella',
        sub2Name: 'Lyra',
        description:
            'Defensas sagradas impenetrables junto con ráfagas continuas de daño de luz de alta precisión.',
      ),
    ];

    return FutureBuilder<dynamic>(
      future: Api.get('characters'),
      builder: (context, snapshot) {
        final allChars = (snapshot.data as List?)?.cast<Map<String, dynamic>>() ?? [];

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: metaSquads.length,
          itemBuilder: (context, i) {
            final ms = metaSquads[i];
            final lChar = _findByName(allChars, ms.leaderName);
            final s1Char = _findByName(allChars, ms.sub1Name);
            final s2Char = _findByName(allChars, ms.sub2Name);

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: kPanelBg,
                border: Border.all(color: ms.color.withValues(alpha: 0.6), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabecera Meta
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(
                      color: kPanelHeaderBg,
                      border: Border(bottom: BorderSide(color: kBorderColor)),
                    ),
                    child: Row(
                      children: [
                        _Tag(ms.tier, color: ms.color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ms.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Miniaturas de los 3
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _miniChar(lChar, ms.leaderName, 'LÍDER'),
                            const SizedBox(width: 8),
                            _miniChar(s1Char, ms.sub1Name, 'APOYO 1'),
                            const SizedBox(width: 8),
                            _miniChar(s2Char, ms.sub2Name, 'APOYO 2'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          ms.description,
                          style: const TextStyle(fontSize: 11, color: Color(0xffd9d6d0), height: 1.3),
                        ),
                        const SizedBox(height: 12),

                        // Botón para cargar en el simulador
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.flash_on, size: 14),
                            label: const Text(
                              'CARGAR EN EL SIMULADOR',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ms.color,
                              foregroundColor: kInk,
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () {
                              _loadSquad(lChar, s1Char, s2Char);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Composición cargada: ${ms.name}'),
                                  backgroundColor: ms.color,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Map<String, dynamic>? _findByName(List<Map<String, dynamic>> list, String name) {
    try {
      return list.firstWhere((c) => (c['name'] ?? '').toString().toLowerCase() == name.toLowerCase());
    } catch (_) {
      return {'name': name, 'element': 'Aqua', 'rarity': 5};
    }
  }

  Widget _miniChar(Map<String, dynamic>? c, String fallbackName, String roleTag) {
    final name = c?['name']?.toString() ?? fallbackName;
    final icon = c?['icon']?.toString() ?? '';
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xff1d1b18),
          border: Border.all(color: kBorderColor),
        ),
        child: Column(
          children: [
            _Thumb(icon, size: 36),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
            Text(
              roleTag,
              style: const TextStyle(fontSize: 8, color: kTextMuted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PESTAÑA 3: EQUIPOS GUARDADOS POR EL USUARIO
  // ─────────────────────────────────────────────────────────────

  Widget _buildSavedTeamsTab() {
    if (_savedTeams.isEmpty) {
      return const Center(
        child: _EmptyNote('No tienes escuadrones guardados.\nConfigura uno en el simulador y presiona "GUARDAR ESCUADRÓN".'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _savedTeams.length,
      itemBuilder: (context, i) {
        final t = _savedTeams[i];
        final name = t['name']?.toString() ?? 'Escuadrón';
        final l = t['leader'] as Map<String, dynamic>?;
        final s1 = t['sub1'] as Map<String, dynamic>?;
        final s2 = t['sub2'] as Map<String, dynamic>?;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: kPanelBg,
            border: Border.all(color: kBorderColor, width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: kDestructive),
                      onPressed: () => _deleteSavedTeam(i),
                      tooltip: 'Eliminar',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _miniChar(l, 'Vacío', 'LÍDER'),
                    const SizedBox(width: 6),
                    _miniChar(s1, 'Vacío', 'APOYO 1'),
                    const SizedBox(width: 6),
                    _miniChar(s2, 'Vacío', 'APOYO 2'),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _loadSquad(l, s1, s2, t),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kTextPrimary,
                      side: const BorderSide(color: kBorderColor),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    ),
                    child: const Text('CARGAR EN EL SIMULADOR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MOTOR DE CÁLCULO DE RESONANCIAS Y SINERGIAS
  // ─────────────────────────────────────────────────────────────

  List<_SynergyResult> _calculateSynergies() {
    final list = <_SynergyResult>[];
    final active = [_leader, _sub1, _sub2].whereType<Map<String, dynamic>>().toList();
    if (active.length < 2) return list;

    // Conteo elemental
    final elementCounts = <String, int>{};
    for (final c in active) {
      final elem = (c['element'] ?? 'Desconocido').toString();
      elementCounts[elem] = (elementCounts[elem] ?? 0) + 1;
    }

    // Comprobar resonancias de afinidad
    for (final entry in elementCounts.entries) {
      final elem = entry.key;
      final count = entry.value;
      final elemName = _elementLabel(elem);
      final color = _elementColor(elem);

      if (count == 3) {
        list.add(_SynergyResult(
          title: 'TRIPLE RESONANCIA $elemName (MONO-ELEMENTAL)',
          description: '+25% Daño de afinidad elemental para todo el escuadrón, +15% Recarga de Habilidad Definitiva.',
          color: color,
          icon: Icons.whatshot,
        ));
      } else if (count == 2) {
        list.add(_SynergyResult(
          title: 'DOBLE RESONANCIA $elemName (DUO)',
          description: '+12% Daño elemental de afinidad para los aliados correspondientes.',
          color: color,
          icon: Icons.all_inclusive,
        ));
      }
    }

    // Resonancia por diversidad
    if (active.length == 3 && elementCounts.length == 3) {
      list.add(_SynergyResult(
        title: 'RESONANCIA POLICROMÁTICA (TRIPLE ELEMENTO)',
        description: '+8% Daño general y +10% Resistencia a alteraciones de estado para todo el escuadrón.',
        color: const Color(0xffa78bfa),
        icon: Icons.bubble_chart,
      ));
    }

    // Sinergias de rol (Vanguardia, Versátil, Apoyo)
    final roles = active.map((c) => (c['role'] ?? '').toString().toLowerCase()).toList();
    final hasVanguard = roles.any((r) => r.contains('vanguard'));
    final hasVersatile = roles.any((r) => r.contains('versatile'));
    final hasSupport = roles.any((r) => r.contains('support'));

    if (hasVanguard && hasVersatile && hasSupport) {
      list.add(_SynergyResult(
        title: 'TRINIDAD TÁCTICA (VANGUARDIA + VERSÁTIL + APOYO)',
        description: '+15% Generación de Decibeles y +10% Eficacia del Escudo activo.',
        color: kAccentAmber,
        icon: Icons.shield,
      ));
    }

    return list;
  }
}

class _SynergyResult {
  final String title;
  final String description;
  final Color color;
  final IconData icon;

  const _SynergyResult({
    required this.title,
    required this.description,
    required this.color,
    required this.icon,
  });
}

class _MetaSquad {
  final String name;
  final String tier;
  final Color color;
  final String leaderName;
  final String sub1Name;
  final String sub2Name;
  final String description;

  const _MetaSquad({
    required this.name,
    required this.tier,
    required this.color,
    required this.leaderName,
    required this.sub1Name,
    required this.sub2Name,
    required this.description,
  });
}

// ─────────────────────────────────────────────────────────────
// HOJA SELECTORA DE TREKKERS
// ─────────────────────────────────────────────────────────────

class _TrekkerPickerSheet extends StatefulWidget {
  const _TrekkerPickerSheet({required this.onSelected});
  final void Function(Map<String, dynamic> trekker) onSelected;

  @override
  State<_TrekkerPickerSheet> createState() => _TrekkerPickerSheetState();
}

class _TrekkerPickerSheetState extends State<_TrekkerPickerSheet> {
  String _selectedElement = 'TODOS';
  int? _selectedGrade;
  String _search = '';

  static const _elements = ['TODOS', 'IGNIS', 'AQUA', 'VENTUS', 'TERRA', 'LUX', 'UMBRA'];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (ctx, scroll) {
        return Container(
          color: kBgDark,
          child: Column(
            children: [
              // Cabecera del selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: kPanelHeaderBg,
                  border: Border(bottom: BorderSide(color: kBorderColor, width: 1.2)),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'SELECCIONAR TREKKER',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // Buscador
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: TextField(
                  onChanged: (val) => setState(() => _search = val.trim()),
                  style: const TextStyle(fontSize: 13, color: kTextPrimary),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre...',
                    hintStyle: const TextStyle(fontSize: 12, color: kTextMuted),
                    prefixIcon: const Icon(Icons.search, size: 18, color: kTextMuted),
                    filled: true,
                    fillColor: kPanelBg,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: kBorderColor),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: kTextPrimary),
                    ),
                  ),
                ),
              ),

              // Filtro por afinidad elemental
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _elements.length,
                  separatorBuilder: (_, index) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final el = _elements[i];
                    final sel = _selectedElement == el;
                    return InkWell(
                      onTap: () => setState(() => _selectedElement = el),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: sel ? kTextPrimary : kPanelBg,
                          border: Border.all(color: sel ? kTextPrimary : kBorderColor),
                        ),
                        child: Text(
                          el,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: sel ? kInk : kTextMuted,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [null, 5, 4, 3].map((grade) {
                    final selected = _selectedGrade == grade;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => setState(() => _selectedGrade = grade),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: selected ? kTextPrimary : kPanelBg,
                            border: Border.all(color: selected ? kTextPrimary : kBorderColor),
                          ),
                          child: Text(grade == null ? 'TODAS LAS RAREZAS' : '$grade★',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                              color: selected ? kInk : kTextMuted)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),

              // Rejilla de Trekkers
              Expanded(
                child: FutureBuilder<dynamic>(
                  future: Api.get('characters'),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _Spinner();
                    }
                    if (snapshot.hasError || snapshot.data == null) {
                      return const Center(child: _EmptyNote('No se pudieron cargar los personajes.'));
                    }

                    final list = (snapshot.data as List).cast<Map<String, dynamic>>();
                    final filtered = list.where((c) {
                      final name = (c['name'] ?? '').toString().toLowerCase();
                      if (_search.isNotEmpty && !name.contains(_search.toLowerCase())) return false;
                      if (_selectedElement != 'TODOS') {
                        final elem = (c['element']?.toString() ?? '').toUpperCase();
                        if (elem != _selectedElement) return false;
                      }
                      final grade = int.tryParse('${c['grade'] ?? c['rarity'] ?? ''}');
                      if (_selectedGrade != null && grade != _selectedGrade) return false;
                      return true;
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(child: _EmptyNote('No hay personajes que coincidan.'));
                    }

                    return GridView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final c = filtered[i];
                        final name = c['name']?.toString() ?? '';
                        final icon = c['icon']?.toString() ?? '';
                        final elem = c['element']?.toString();
                        final rarity = c['grade']?.toString() ?? c['rarity']?.toString() ?? '5';

                        return InkWell(
                          onTap: () => widget.onSelected(c),
                          child: Container(
                            decoration: BoxDecoration(
                              color: kPanelBg,
                              border: Border.all(color: kBorderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      _NetImage(icon, fit: BoxFit.cover,
                                        alt: [c['portrait']?.toString(), c['background']?.toString()]),
                                      Positioned(
                                        top: 4,
                                        left: 4,
                                        child: _Tag('$rarity★', color: kAccentAmber),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  color: kPanelHeaderBg,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _elementLabel(elem),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: _elementColor(elem),
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
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
