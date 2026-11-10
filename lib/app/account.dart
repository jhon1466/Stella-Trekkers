part of '../main.dart';

// ─────────────────────────────────────────────────────────────
// 7. DOSSIER & ACCOUNT PAGE (OFFICIAL PROFILE & ENERGY MONITOR)
// ─────────────────────────────────────────────────────────────

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> with WidgetsBindingObserver {
  YostarAccount? account;
  OfficialGameStats? officialStats;
  bool syncingOfficial = false;
  bool sendingCode = false;
  bool verifyingCode = false;
  bool codeSent = false;
  String? authMessage;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  int? energy;
  int maximum = 240;
  int fullMinutes = 0;
  bool loading = true;
  String? error;
  String? widgetBgPath;
  String? widgetCharName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedAccount = await YostarAuthService.getStoredAccount();
    final cachedStats = await StellaGatewayClient.getCachedStats();

    if (!mounted) return;
    setState(() {
      account = storedAccount;
      officialStats = cachedStats;
      energy = prefs.getInt('account_energy') ?? cachedStats?.currentEnergy ?? 400;
      maximum = prefs.getInt('account_energy_max') ?? cachedStats?.maxEnergy ?? 240;
      fullMinutes = prefs.getInt('account_energy_full_minutes') ?? (cachedStats != null ? cachedStats.secondsToFull ~/ 60 : 0);
      widgetBgPath = prefs.getString('widget_character_path');
      widgetCharName = prefs.getString('widget_character_name');
      loading = false;
    });

    if (storedAccount != null && cachedStats == null) {
      _syncOfficial(silent: true);
    }
  }

  Future<void> _sendVerificationCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => error = 'Ingresa un correo electrónico válido.');
      return;
    }
    setState(() {
      sendingCode = true;
      error = null;
      authMessage = null;
    });

    try {
      await YostarAuthService.sendVerificationCode(email);
      if (!mounted) return;
      setState(() {
        codeSent = true;
        authMessage = 'Código oficial de 6 dígitos enviado a $email. Revisa tu bandeja de entrada.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => sendingCode = false);
    }
  }

  Future<void> _verifyCodeAndLogin() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => error = 'El código debe tener 6 dígitos.');
      return;
    }
    setState(() {
      verifyingCode = true;
      error = null;
    });

    try {
      final acc = await YostarAuthService.verifyCodeAndLogin(email, code);
      if (!mounted) return;
      setState(() {
        account = acc;
        codeSent = false;
        authMessage = null;
        _codeController.clear();
      });
      await _syncOfficial();
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => verifyingCode = false);
    }
  }

  Future<void> _syncOfficial({bool silent = false}) async {
    if (account == null) return;
    if (!silent) {
      setState(() {
        syncingOfficial = true;
        error = null;
      });
    }

    try {
      final stats = await StellaGatewayClient.syncOfficialAccount(account!);
      if (!mounted) return;
      final updatedAcc = await YostarAuthService.getStoredAccount();
      setState(() {
        if (updatedAcc != null) account = updatedAcc;
        officialStats = stats;
        energy = stats.currentEnergy;
        maximum = stats.maxEnergy;
        fullMinutes = stats.secondsToFull ~/ 60;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() => error = 'Error al sincronizar con el servidor: ${e.toString().replaceFirst("Exception: ", "")}');
      }
    } finally {
      if (mounted && !silent) setState(() => syncingOfficial = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kPanelBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: kBorderColor, width: 1.5),
        ),
        title: const Text('CERRAR SESIÓN', style: TextStyle(fontFamily: 'Geist', fontSize: 14)),
        content: const Text(
          '¿Deseas desvincular tu cuenta oficial de Stella Sora en este dispositivo?',
          style: TextStyle(fontFamily: 'Geist', fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: kDestructive,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DESVINCULAR'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await YostarAuthService.logout();
    await StellaGatewayClient.clearWidget();
    if (!mounted) return;
    setState(() {
      account = null;
      officialStats = null;
      widgetBgPath = null;
      widgetCharName = null;
      codeSent = false;
      _codeController.clear();
    });
  }

  void _copyUid(String uid) {
    Clipboard.setData(ClipboardData(text: uid));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: kPanelBg,
        content: Text('UID $uid copiado al portapapeles.', style: const TextStyle(fontFamily: 'Geist')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickWidgetCharacter() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CharacterWidgetPickerSheet(
        currentCharacterName: widgetCharName,
      ),
    );

    if (selected != null) {
      await _load();
    }
  }

  Future<void> _clearWidgetCharacter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('widget_character_path');
    await prefs.remove('widget_character_name');
    await prefs.remove('widget_character_id');

    try {
      await const MethodChannel('stella/account_widget').invokeMethod('updateWidgetBackground', {
        'imagePath': null,
        'characterName': null,
      });
    } catch (_) {}

    setState(() {
      widgetBgPath = null;
      widgetCharName = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: kPanelBg,
          content: Text('Fondo del widget restablecido.', style: TextStyle(fontFamily: 'Geist')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, size: 20),
          tooltip: 'Menú',
          onPressed: CompanionShell.openDrawer,
        ),
        title: const Row(
          children: [
            Icon(Icons.badge_outlined, size: 16, color: kAccentPurple),
            SizedBox(width: 8),
            Text('MI CUENTA'),
          ],
        ),
        actions: [
          if (account != null) ...[
            IconButton(
              icon: const Icon(Icons.palette_outlined, size: 18),
              tooltip: 'Personalizar fondo del widget',
              onPressed: _pickWidgetCharacter,
            ),
            IconButton(
              icon: syncingOfficial
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync, size: 18),
              tooltip: 'Sincronizar cuenta oficial',
              onPressed: syncingOfficial ? null : () => _syncOfficial(),
            ),
            IconButton(
              icon: const Icon(Icons.logout, size: 18, color: Color(0xffd9d6d0)),
              tooltip: 'Cerrar sesión',
              onPressed: _logout,
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (account != null) ...[
            _buildOfficialProfileCard(),
            const SizedBox(height: 14),
            _buildOfficialEnergyCard(),
            const SizedBox(height: 14),
            _buildWidgetCustomizationCard(),
          ] else ...[
            _buildOfficialLoginCard(),
          ],

          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xff2a1114),
                  border: Border.all(color: kDestructive),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: kDestructive, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(error!, style: const TextStyle(color: kDestructive, fontSize: 12, fontFamily: 'Geist')),
                    ),
                  ],
                ),
              ),
            ),

          if (authMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xff0d2818),
                  border: Border.all(color: Colors.greenAccent),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(authMessage!, style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontFamily: 'Geist')),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // OFFICIAL PROFILE CARD (SPACIOUS / GAME-ACCURATE TERMINAL)
  // ─────────────────────────────────────────────────────────
  Widget _buildOfficialProfileCard() {
    final stats = officialStats;
    final displayUid = (stats != null && stats.uid.isNotEmpty && stats.uid != '0')
        ? stats.uid
        : '700494272';
    final nickname = stats?.nickname.isNotEmpty == true ? stats!.nickname : 'etesech';
    final level = stats?.level ?? 25;
    final title = stats?.title ?? 'Calma Steward';
    final signature = stats?.signature ?? 'eso tiln';
    final avatar = stats?.avatar ?? '/stella/assets/head_11001_XL.png';
    final badge = stats?.badge ?? 'Crackling Hint of Spring';
    final exhibitionTrekkers = stats?.exhibitionTrekkers ?? const [
      ExhibitionTrekker(name: 'Firenze', level: 60, element: 'Umbra', icon: '/stella/assets/head_11001_XL.png', grade: 5),
      ExhibitionTrekker(name: 'Nanoha', level: 20, element: 'Ventus', icon: '/stella/assets/head_11901_XL.png', grade: 4),
      ExhibitionTrekker(name: 'Mistique', level: 1, element: 'Umbra', icon: '/stella/assets/head_13501_XL.png', grade: 4),
    ];

    return Container(
      decoration: BoxDecoration(
        color: kPanelBg,
        border: Border.all(color: kBorderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Bar: Clean Title & UID Copy
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: kPanelHeaderBg,
              border: Border(bottom: BorderSide(color: kBorderColor, width: 1.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 14, color: kAccentPurple),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'PERFIL DE JUGADOR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      fontFamily: 'Geist',
                      color: kTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => _copyUid(displayUid),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xff272522),
                      border: Border.all(color: kBorderHighlight),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'UID: $displayUid',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Geist',
                            color: kTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(Icons.copy_rounded, size: 12, color: Color(0xffd9d6d0)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Identity row (Avatar + Name + Title + Badge)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Square avatar box with Level badge cleanly embedded INSIDE
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xff1d1b18),
                        border: Border.all(color: kBorderHighlight, width: 1.2),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: _RemoteThumb(path: avatar, size: 64),
                          ),
                          Positioned(
                            top: 2,
                            left: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              color: kInk.withValues(alpha: 0.85),
                              child: Text(
                                '$level Lv.',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Geist',
                                  color: kTextPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Player Nickname, Title, and Seasonal Badge
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  nickname.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                    fontFamily: 'Geist',
                                    color: kTextPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, size: 14, color: Colors.greenAccent),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xffaba9a5),
                              fontFamily: 'Geist',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xff2b1a14),
                              border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.6)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, size: 10, color: Colors.amberAccent),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    badge.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amberAccent,
                                      fontFamily: 'Geist',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                const SizedBox(height: 12),

                // Signature Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xff141210),
                    border: Border.all(color: kBorderColor),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'FIRMA // ',
                        style: TextStyle(
                          color: kTextMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Geist',
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '"$signature"',
                          style: const TextStyle(
                            color: kTextPrimary,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            fontFamily: 'Geist',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Exhibition Trekkers Header
                const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 12, color: kAccentPurple),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'MIEMBROS DE GUILD CORE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Geist',
                          color: kTextPrimary,
                          letterSpacing: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 3 Exhibition Trekkers Cards (Firenze, Nanoha, Mistique)
                Row(
                  children: exhibitionTrekkers.map((t) {
                    final elemColor = _elementColor(t.element);
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xff1d1b18),
                          border: Border.all(color: kBorderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Stack(
                              children: [
                                Container(
                                  height: 72,
                                  width: double.infinity,
                                  color: const Color(0xff141210),
                                  child: _RemoteThumb(path: t.icon, size: 72),
                                ),
                                Positioned(
                                  top: 3,
                                  left: 3,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    color: kInk.withValues(alpha: 0.8),
                                    child: Text(
                                      _elementLabel(t.element),
                                      style: TextStyle(
                                        fontSize: 7,
                                        fontWeight: FontWeight.bold,
                                        color: elemColor,
                                        fontFamily: 'Geist',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                              color: const Color(0xff272522),
                              child: Column(
                                children: [
                                  Text(
                                    'LV. ${t.level}',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amberAccent,
                                      fontFamily: 'Geist',
                                    ),
                                  ),
                                  Text(
                                    t.name.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: kTextPrimary,
                                      fontFamily: 'Geist',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                // Sync Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xff1d1b18),
                    border: Border(top: BorderSide(color: kBorderColor)),
                  ),
                  child: Row(
                    children: [
                      Container(width: 6, height: 6, color: Colors.greenAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          stats != null
                              ? 'SINCRONIZADO: ${_date(stats.syncTime.toIso8601String())}'
                              : 'SIN SINCRONIZAR',
                          style: const TextStyle(fontSize: 9, color: kTextMuted, fontFamily: 'Geist'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: syncingOfficial ? null : () => _syncOfficial(),
                        child: Text(
                          syncingOfficial ? '[ SINCRONIZANDO... ]' : '[ ACTUALIZAR ]',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kTextPrimary, fontFamily: 'Geist'),
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
    );
  }

  // ─────────────────────────────────────────────────────────
  // REAL-TIME STAMINA MONITOR (TECHNICAL TERMINAL BOX)
  // ─────────────────────────────────────────────────────────
  Widget _buildOfficialEnergyCard() {
    final cur = energy ?? 0;
    final cap = maximum > 0 ? maximum : 240;
    final ratio = (cur / cap).clamp(0.0, 1.0);
    final hours = fullMinutes ~/ 60;
    final mins = fullMinutes % 60;

    final String statusDescription = cur > cap
        ? 'ESTADO: +${cur - cap} SOBRE EL LÍMITE'
        : (cur == cap ? 'ESTADO: ENERGÍA AL MÁXIMO' : 'ESTADO: RECARGANDO (1 / 6min)');

    return Container(
      decoration: BoxDecoration(
        color: kPanelBg,
        border: Border.all(color: kBorderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: kPanelHeaderBg,
              border: Border(bottom: BorderSide(color: kBorderColor, width: 1.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt, size: 14, color: Colors.amberAccent),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'ENERGÍA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      fontFamily: 'Geist',
                      color: kTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$cur / $cap',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Geist',
                    color: Colors.amberAccent,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sharp technical progress bar
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xff1d1b18),
                    border: Border.all(color: kBorderHighlight),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: ratio,
                    child: Container(
                      color: cur > cap ? Colors.amberAccent : kAccentPurple,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Status breakdown
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xff272522),
                          border: Border.all(color: kBorderHighlight),
                        ),
                        child: Text(
                          statusDescription,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: cur >= cap ? Colors.amberAccent : const Color(0xffd9d6d0),
                            fontFamily: 'Geist',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      cur >= cap ? 'COMPLETO' : 'LLENO EN: ${hours > 0 ? "${hours}h " : ""}${mins}m',
                      style: const TextStyle(fontSize: 10, color: kTextMuted, fontFamily: 'Geist'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Widget sync status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xff1d1b18),
                    border: Border.all(color: kBorderColor),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 12, color: Colors.greenAccent),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'WIDGET DE INICIO ACTUALIZADO',
                          style: TextStyle(fontSize: 9, color: Colors.greenAccent, fontFamily: 'Geist'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
    );
  }

  // ─────────────────────────────────────────────────────────
  // ANDROID WIDGET ARTWORK SELECTOR
  // ─────────────────────────────────────────────────────────
  Widget _buildWidgetCustomizationCard() {
    final hasCustomBg = widgetBgPath != null && File(widgetBgPath!).existsSync();

    return Container(
      decoration: BoxDecoration(
        color: kPanelBg,
        border: Border.all(color: kBorderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: kPanelHeaderBg,
              border: Border(bottom: BorderSide(color: kBorderColor, width: 1.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.palette_outlined, size: 14, color: Color(0xffd9d6d0)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'FONDO DEL WIDGET',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontFamily: 'Geist',
                      color: kTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widgetCharName != null)
                  Text(
                    '[ $widgetCharName ]',
                    style: const TextStyle(fontSize: 10, color: Colors.amberAccent, fontFamily: 'Geist'),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live preview in technical frame
                Container(
                  width: double.infinity,
                  height: 140,
                  decoration: BoxDecoration(
                    color: const Color(0xff141210),
                    border: Border.all(color: kBorderHighlight, width: 1.2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasCustomBg)
                        Image.file(File(widgetBgPath!), fit: BoxFit.cover, alignment: Alignment.topCenter)
                      else
                        const Center(
                          child: Icon(Icons.image_outlined, color: Colors.white24, size: 40),
                        ),
                      // Bottom gradient
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 70,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0xe605030c)],
                            ),
                          ),
                        ),
                      ),
                      // Top chip
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          color: kInk.withValues(alpha: 0.75),
                          child: Text(
                            widgetCharName ?? 'STELLA TREKKERS',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Geist'),
                          ),
                        ),
                      ),
                      // Bottom stamina
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 8,
                        child: Row(
                          children: [
                            const Icon(Icons.nightlight_round, size: 20, color: Color(0xff80c8ff)),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${energy ?? 400} / $maximum',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Geist'),
                                ),
                                Text(
                                  energy != null && energy! >= maximum ? 'ENERGÍA LLENA' : 'RECARGANDO...',
                                  style: const TextStyle(fontSize: 9, color: Color(0xffd9d6d0), fontFamily: 'Geist'),
                                ),
                              ],
                            ),
                            const Spacer(),
                            const Icon(Icons.refresh, size: 16, color: Color(0xffd9d6d0)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Button row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: kTextPrimary,
                          side: const BorderSide(color: kTextPrimary),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        ),
                        onPressed: _pickWidgetCharacter,
                        child: Text(
                          widgetCharName != null ? 'CAMBIAR PERSONAJE' : 'ELEGIR PERSONAJE',
                          style: const TextStyle(
                            color: kInk,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Geist',
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (hasCustomBg) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kBorderHighlight),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        ),
                        onPressed: _clearWidgetCharacter,
                        child: const Text('QUITAR', style: TextStyle(fontFamily: 'Geist', fontSize: 10)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialLoginCard() {
    return Container(
      decoration: BoxDecoration(
        color: kPanelBg,
        border: Border.all(color: kBorderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: kPanelHeaderBg,
              border: Border(bottom: BorderSide(color: kBorderColor, width: 1.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 14, color: kAccentPurple),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'INICIAR SESIÓN CON YOSTAR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontFamily: 'Geist',
                      color: kTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ingresa el correo electrónico oficial asociado a tu cuenta de Stella Sora para recibir tu código OTP de 6 dígitos:',
                  style: TextStyle(color: kTextMuted, fontSize: 11, fontFamily: 'Geist', height: 1.4),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontFamily: 'Geist', fontSize: 12),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.email_outlined, size: 18),
                    hintText: 'correo@ejemplo.com',
                    filled: true,
                    fillColor: Color(0xff1d1b18),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: kBorderColor, width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: kTextPrimary, width: 1.2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                if (!codeSent)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: kTextPrimary,
                        side: const BorderSide(color: kTextPrimary),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                      onPressed: sendingCode ? null : _sendVerificationCode,
                      child: Text(
                        sendingCode ? 'ENVIANDO CÓDIGO...' : 'ENVIAR CÓDIGO',
                        style: const TextStyle(
                          color: kInk,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Geist',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),

                if (codeSent) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontFamily: 'Geist', fontSize: 16, letterSpacing: 3, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.pin_outlined, size: 18),
                      hintText: '000000',
                      filled: true,
                      fillColor: Color(0xff1d1b18),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: kBorderColor, width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: kTextPrimary, width: 1.2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: kTextPrimary,
                            side: const BorderSide(color: kTextPrimary),
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          ),
                          onPressed: verifyingCode ? null : _verifyCodeAndLogin,
                          child: Text(
                            verifyingCode ? 'VERIFICANDO...' : 'INICIAR SESIÓN',
                            style: const TextStyle(
                              color: kInk,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Geist',
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kBorderHighlight),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        ),
                        onPressed: sendingCode ? null : _sendVerificationCode,
                        child: const Text('REPETIR', style: TextStyle(fontFamily: 'Geist', fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 8. TECHNICAL CHARACTER PICKER MODAL (FOR WIDGET)
// ─────────────────────────────────────────────────────────────

class _CharacterWidgetPickerSheet extends StatefulWidget {
  const _CharacterWidgetPickerSheet({this.currentCharacterName});
  final String? currentCharacterName;

  @override
  State<_CharacterWidgetPickerSheet> createState() => _CharacterWidgetPickerSheetState();
}

class _CharacterWidgetPickerSheetState extends State<_CharacterWidgetPickerSheet> {
  String selectedElement = 'TODOS';
  String searchQuery = '';
  int? downloadingCharId;

  static const elements = [
    'TODOS',
    'IGNIS',
    'AQUA',
    'VENTUS',
    'LUX',
    'UMBRA',
    'TERRA',
  ];

  Future<void> _selectCharacter(Map<String, dynamic> char) async {
    final charId = char['id'];
    final charName = _string(char['name'], 'Personaje');
    final iconPath = _string(char['icon'], '');
    final portraitPath = _string(char['portrait'], '');

    final targetUrl = portraitPath.isNotEmpty
        ? Api.asset(portraitPath)
        : Api.asset(iconPath);

    if (targetUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: kPanelBg,
          content: Text('Este personaje no cuenta con imagen de alta resolución.', style: TextStyle(fontFamily: 'Geist')),
        ),
      );
      return;
    }

    setState(() => downloadingCharId = charId is int ? charId : 1);

    try {
      final response = await http.get(Uri.parse(targetUrl)).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw Exception('Código de respuesta: ${response.statusCode}');
      }

      final dir = await getApplicationDocumentsDirectory();
      final targetFile = File('${dir.path}/widget_bg_$charId.png');
      await targetFile.writeAsBytes(response.bodyBytes);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('widget_character_path', targetFile.path);
      await prefs.setString('widget_character_name', charName);
      if (charId is int) await prefs.setInt('widget_character_id', charId);

      try {
        await const MethodChannel('stella/account_widget').invokeMethod('updateWidgetBackground', {
          'imagePath': targetFile.path,
          'characterName': charName,
        });
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pop(char);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: kPanelBg,
          content: Text('$charName configurado como fondo del widget.', style: const TextStyle(fontFamily: 'Geist')),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xff2a1114),
          content: Text('Error al descargar ilustración: $e', style: const TextStyle(fontFamily: 'Geist')),
        ),
      );
    } finally {
      if (mounted) setState(() => downloadingCharId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: kBgDark,
        border: Border(
          top: BorderSide(color: kBorderColor, width: 2),
        ),
      ),
      child: Column(
        children: [
          // Drag handle & title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: kPanelHeaderBg,
              border: Border(bottom: BorderSide(color: kBorderColor)),
            ),
            child: Row(
              children: [
                const Icon(Icons.photo_library_outlined, size: 16, color: kAccentPurple),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'ELIGE UN PERSONAJE',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1.1,
                      color: kTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: TextField(
              style: const TextStyle(fontFamily: 'Geist', fontSize: 13),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 18, color: kTextMuted),
                hintText: 'Buscar por nombre...',
                hintStyle: const TextStyle(color: kTextMuted, fontFamily: 'Geist', fontSize: 12),
                filled: true,
                fillColor: kPanelBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: kBorderColor, width: 1.2),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: kTextPrimary, width: 1.2),
                ),
              ),
              onChanged: (val) => setState(() => searchQuery = val.trim().toLowerCase()),
            ),
          ),

          // Element horizontal pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: elements.map((elem) {
                final isSelected = selectedElement == elem;
                final col = elem == 'TODOS' ? kTextPrimary : _elementColor(elem);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => setState(() => selectedElement = elem),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xff272522) : kPanelBg,
                        border: Border.all(
                          color: isSelected ? col : kBorderColor,
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        _elementLabel(elem),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? col : kTextMuted,
                          fontFamily: 'Geist',
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Grid of Characters
          Expanded(
            child: FutureBuilder<dynamic>(
              future: Api.get('characters'),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ErrorView(error: snapshot.error.toString());
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allChars = _asList(snapshot.data).map(_asMap).toList();
                final filtered = allChars.where((c) {
                  final name = _string(c['name'], '').toLowerCase();
                  final elem = _string(c['element'], '').toUpperCase();

                  if (searchQuery.isNotEmpty && !name.contains(searchQuery)) {
                    return false;
                  }
                  if (selectedElement != 'TODOS' && elem != selectedElement) {
                    return false;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const _EmptyNote('No se encontraron personajes con los filtros aplicados.');
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(14),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final char = filtered[index];
                    final charId = char['id'];
                    final name = _string(char['name'], 'Personaje');
                    final element = _string(char['element'], '');
                    final grade = char['grade'] ?? 5;
                    final icon = _string(char['icon'], '');
                    final portrait = _string(char['portrait'], '');
                    final previewPath = portrait.isNotEmpty ? portrait : icon;
                    final isCurrent = widget.currentCharacterName == name;
                    final isDownloading = downloadingCharId == charId;

                    return InkWell(
                      onTap: isDownloading ? null : () => _selectCharacter(char),
                      child: Container(
                        decoration: BoxDecoration(
                          color: kPanelBg,
                          border: Border.all(
                            color: isCurrent
                                ? Colors.amberAccent
                                : _elementColor(element).withValues(alpha: 0.7),
                            width: isCurrent ? 2 : 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _RemoteThumb(path: previewPath),
                                  if (isCurrent)
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        color: kInk,
                                        child: const Text(
                                          'ACTUAL',
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amberAccent,
                                            fontFamily: 'Geist',
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (isDownloading)
                                    Container(
                                      color: Colors.black54,
                                      child: const Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(color: kTextPrimary, strokeWidth: 2),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                              color: const Color(0xff1d1b18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: kTextPrimary,
                                      fontFamily: 'Geist',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        '$grade★',
                                        style: const TextStyle(fontSize: 9, color: Colors.amberAccent, fontFamily: 'Geist'),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _elementLabel(element),
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: _elementColor(element),
                                            fontFamily: 'Geist',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
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
  }
}

