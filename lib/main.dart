import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'services/yostar_auth_service.dart';
import 'services/stella_gateway_client.dart';

part 'app/home.dart';
part 'app/database.dart';
part 'app/schedule.dart';
part 'app/rankings.dart';
part 'app/team.dart';
part 'app/account.dart';
part 'app/library_extra.dart';
part 'app/combat.dart';
part 'app/details.dart';

const _apiRoot = 'https://api.ennead.cc/stella';
const _assetRoot = 'https://api.ennead.cc/stella/assets/';
const _siteApiRoot = 'https://stella.ennead.cc/api';

/// Espejo traducido al español que publica la GitHub Action (GitHub Pages).
/// Ejemplo: 'https://TU-USUARIO.github.io/stella-trekkers/es'. Vacío = usar sólo los datos originales.
const kSpanishMirror = 'https://jhon1466.github.io/Stella-Trekkers/es';

/// Intenta leer primero la versión traducida; si no existe, devuelve null.
Future<dynamic> _fromMirror(String rel) async {
  if (kSpanishMirror.isEmpty || rel.contains('?')) return null;
  try {
    final r = await http.get(Uri.parse('$kSpanishMirror/$rel.json')).timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return jsonDecode(utf8.decode(r.bodyBytes));
  } catch (_) {}
  return null;
}

// Paleta de StellaBase (tema oscuro): negro cálido, tinta crema y bordes marcados.
const kBgDark = Color(0xff0e0c0a); // --background
const kPanelBg = Color(0xff191714); // --card
const kPanelHeaderBg = Color(0xff141210); // --sidebar
const kSurface = Color(0xff1d1b18);
const kMuted = Color(0xff272522); // --muted / --secondary
const kBorderColor = Color(0xff3b3935); // --border (crema al 26 %)
const kBorderHighlight = Color(0xfff2f0ec); // --rule
const kTextPrimary = Color(0xfff2f0ec); // --foreground
const kTextMuted = Color(0xffaba9a5); // --muted-foreground
const kInk = Color(0xff130e0a); // tinta sobre papel crema
const kPaper = Color(0xfff7f4ef); // papel crema (tarjetas destacadas)
const kAccentPurple = kTextPrimary; // la web usa el blanco crema como acento
const kAccentAmber = Color(0xffeacb3e);
const kAccentGreen = Color(0xff22af68);
const kDestructive = Color(0xfffc4a47);
const kSkillCyan = Color(0xff0abec5);
const kSkillOrange = Color(0xffec6d21);

/// Estilo de titular (Anton, mayúsculas condensadas) como en la web.
TextStyle kDisplay(double size, {Color color = kTextPrimary}) =>
    TextStyle(fontFamily: 'Anton', fontSize: size, height: 1.05, letterSpacing: 0.2, color: color);

void main() => runApp(const StellaCompanion());

/// Punto de entrada sin interfaz que lanza el botón de recarga del widget:
/// sincroniza la energía con el servidor oficial sin abrir la app.
@pragma('vm:entry-point')
Future<void> widgetRefreshMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  const done = MethodChannel('stella/widget_refresh');
  var ok = false;
  try {
    final account = await YostarAuthService.getStoredAccount();
    if (account != null) {
      await StellaGatewayClient.syncOfficialAccount(account).timeout(const Duration(seconds: 20));
      ok = true;
    }
  } catch (_) {}
  try {
    await done.invokeMethod('done', {'ok': ok});
  } catch (_) {}
}

class StellaCompanion extends StatelessWidget {
  const StellaCompanion({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Stella Trekkers',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kBgDark,
      canvasColor: kBgDark,
      cardColor: kPanelBg,
      dividerColor: kBorderColor,
      colorScheme: const ColorScheme.dark(
        primary: kTextPrimary,
        onPrimary: kInk,
        surface: kPanelBg,
        onSurface: kTextPrimary,
        outline: kBorderColor,
        secondary: kTextPrimary,
        error: kDestructive,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: kTextPrimary),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: kPaper,
        contentTextStyle: TextStyle(fontFamily: 'Geist', color: kInk, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      fontFamily: 'Geist',
      appBarTheme: const AppBarTheme(
        backgroundColor: kBgDark,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Anton',
          fontSize: 22,
          letterSpacing: 0.3,
          color: kTextPrimary,
        ),
        shape: Border(bottom: BorderSide(color: kBorderHighlight, width: 2)),
      ),
      useMaterial3: true,
    ),
    navigatorKey: CompanionShell.navKey,
    home: CompanionShell(key: CompanionShell.shellKey),
    // Un único menú lateral por encima de todas las pantallas: se abre desde cualquier sitio.
    builder: (context, child) => Scaffold(
      key: CompanionShell.scaffoldKey,
      drawer: const _GlobalDrawer(),
      drawerEdgeDragWidth: 24,
      body: child,
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// API + CACHÉ EN MEMORIA
// ─────────────────────────────────────────────────────────────

class Api {
  static final Map<String, Future<dynamic>> _cache = {};

  static Future<dynamic> get(String path, {bool refresh = false}) {
    final clean = path.startsWith('/') ? path.substring(1) : path;
    if (!refresh && _cache.containsKey(clean)) return _cache[clean]!;
    final future = _fetch(clean);
    _cache[clean] = future;
    future.catchError((_) {
      _cache.remove(clean);
      return null;
    });
    return future;
  }

  static Future<dynamic> _fetch(String clean) async {
    final es = await _fromMirror('stella/$clean');
    if (es != null) return es;
    final uri = Uri.parse('$_apiRoot/$clean').replace(queryParameters: {'lang': 'EN'});
    final response = await http.get(uri).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('El servidor respondió ${response.statusCode}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  /// Endpoints propios de la web StellaBase (enemigos, emblemas, raids, rankings…).
  static Future<dynamic> site(String path, {bool refresh = false}) {
    final clean = path.startsWith('/') ? path.substring(1) : path;
    final key = 'site:$clean';
    if (!refresh && _cache.containsKey(key)) return _cache[key]!;
    final future = () async {
      final es = await _fromMirror('site/$clean');
      if (es != null) return es;
      final response = await http.get(Uri.parse('$_siteApiRoot/$clean')).timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('El servidor respondió ${response.statusCode}');
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    }();
    _cache[key] = future;
    future.catchError((_) {
      _cache.remove(key);
      return null;
    });
    return future;
  }

  static void clearCache() => _cache.clear();

  /// Convierte cualquier referencia de recurso en una URL válida, igual que la web:
  /// conserva las subcarpetas ("Icon/Equipment/chargem_a_01" → …/Icon/Equipment/chargem_a_01.png).
  static String asset(String? path) {
    if (path == null) return '';
    var p = path.trim();
    if (p.isEmpty || p == 'null') return '';
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    if (p.startsWith('/stella/assets/')) {
      p = p.substring('/stella/assets/'.length);
    } else if (p.startsWith('/')) {
      p = p.substring(1);
    }
    if (!p.split('/').last.contains('.')) p = '$p.png';
    return '$_assetRoot$p';
  }
}

// ─────────────────────────────────────────────────────────────
// CONTENEDOR PRINCIPAL CON MENÚ LATERAL Y BARRA INFERIOR
// ─────────────────────────────────────────────────────────────

class CompanionShell extends StatefulWidget {
  const CompanionShell({super.key});

  static final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
  // ignore: library_private_types_in_public_api
  static final GlobalKey<_CompanionShellState> shellKey = GlobalKey<_CompanionShellState>();

  static void openDrawer() => scaffoldKey.currentState?.openDrawer();

  @override
  State<CompanionShell> createState() => _CompanionShellState();
}

class _CompanionShellState extends State<CompanionShell> {
  int tab = 0;

  static const _tabs = [
    (label: 'PANEL', icon: Icons.space_dashboard_outlined, active: Icons.space_dashboard),
    (label: 'DATOS', icon: Icons.storage_outlined, active: Icons.storage),
    (label: 'CALENDARIO', icon: Icons.calendar_month_outlined, active: Icons.calendar_month),
    (label: 'RANKINGS', icon: Icons.emoji_events_outlined, active: Icons.emoji_events),
    (label: 'CUENTA', icon: Icons.person_outline, active: Icons.person),
  ];

  void goTab(int i) => setState(() => tab = i);

  void _openFromDrawer(VoidCallback action) {
    CompanionShell.scaffoldKey.currentState?.closeDrawer();
    CompanionShell.navKey.currentState?.popUntil((r) => r.isFirst);
    action();
  }

  void _push(Widget page) =>
      CompanionShell.navKey.currentState?.push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: [
          HomePage(onGoTab: goTab),
          const DatabasePage(),
          const SchedulePage(),
          const RankingsPage(),
          const AccountPage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: kPanelHeaderBg,
          border: Border(top: BorderSide(color: kBorderHighlight, width: 2)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(children: [for (var i = 0; i < _tabs.length; i++) _navItem(i)]),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i) {
    final t = _tabs[i];
    final sel = tab == i;
    final fg = sel ? kInk : kTextMuted;
    return Expanded(
      child: InkWell(
        onTap: () => goTab(i),
        child: Container(
          margin: const EdgeInsets.all(5),
          color: sel ? kTextPrimary : Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(sel ? t.active : t.icon, size: 19, color: fg),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  t.label,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: kPanelHeaderBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: kBorderHighlight, width: 2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(border: Border.all(color: kBorderHighlight, width: 1.5)),
                    child: Image.network(
                      'https://stella.ennead.cc/icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('STELLA TREKKERS', maxLines: 1, style: kDisplay(20)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _drawerCategory('BIBLIOTECA'),
            _drawerItem('Panel', Icons.space_dashboard_outlined, () => goTab(0), active: tab == 0),
            _drawerItem('Trekkers', Icons.groups_outlined, () => _push(const CharactersPage())),
            _drawerItem('Cumpleaños', Icons.cake_outlined, () => _push(const BirthdaysPage())),
            _drawerItem('Discos', Icons.album_outlined, () => _push(const DiscsPage())),
            _drawerItem('Enemigos', Icons.pest_control_outlined, () => _push(const EnemiesPage())),
            _drawerItem('Monolito', Icons.forum_outlined, () => _push(const MonolithPage())),
            _drawerItem('Emblemas', Icons.shield_outlined, () => _push(const EmblemsPage())),
            _divider(),
            _drawerCategory('EQUIPOS'),
            _drawerItem('Creador de equipos', Icons.handyman_outlined, () => _push(const TeamBuilderPage())),
            _drawerItem('Builds de la comunidad', Icons.people_alt_outlined, () => _push(const CommunityBuildsPage())),
            _divider(),
            _drawerCategory('CALENDARIO'),
            _drawerItem('Gachas', Icons.auto_awesome_outlined, () => _push(const BannersPage())),
            _drawerItem('Eventos', Icons.event_outlined, () => _push(const EventsPage())),
            _drawerItem('Noticias', Icons.campaign_outlined, () => _push(const NewsPage())),
            _divider(),
            _drawerCategory('COMBATE'),
            _drawerItem('Joint Drill', Icons.sports_martial_arts_outlined, () => _push(const RaidsPage())),
            _drawerItem('Ranking de Joint Drill', Icons.military_tech_outlined,
                () => _push(const RankingListPage(kind: RankingKind.jointDrill))),
            _drawerItem('Boss Blitz', Icons.bolt_outlined, () => _push(const BossBlitzPage())),
            _drawerItem('Ranking de Boss Blitz', Icons.emoji_events_outlined,
                () => _push(const RankingListPage(kind: RankingKind.scoreBoss))),
            _drawerItem('Jefe mundial', Icons.public_outlined, () => _push(const WorldBossPage())),
            _divider(),
            _drawerCategory('OTROS'),
            _drawerItem('Registro de cambios', Icons.history_outlined, () => _push(const ChangelogPage())),
            _drawerItem('Mi cuenta', Icons.person_outline, () => goTab(4), active: tab == 4),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Padding(
    padding: EdgeInsets.only(top: 10),
    child: Divider(height: 1, thickness: 1, color: kBorderColor),
  );

  Widget _drawerCategory(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
    child: Text(title,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: kTextMuted)),
  );

  Widget _drawerItem(String title, IconData icon, VoidCallback onTap, {bool active = false}) {
    final fg = active ? kInk : kTextPrimary;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      color: active ? kTextPrimary : Colors.transparent,
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -2),
        leading: Icon(icon, size: 18, color: fg),
        title: Text(title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: fg)),
        onTap: () => _openFromDrawer(onTap),
      ),
    );
  }
}

/// AppBar de las pestañas raíz: botón de menú funcional + título que nunca desborda.
PreferredSizeWidget _rootAppBar(String title, {List<Widget>? actions}) => AppBar(
  leading: Padding(
    padding: const EdgeInsets.all(9),
    child: Container(
      decoration: BoxDecoration(border: Border.all(color: kBorderHighlight, width: 1.5)),
      child: const IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(Icons.view_sidebar_outlined, size: 18),
        tooltip: 'Menú',
        onPressed: CompanionShell.openDrawer,
      ),
    ),
  ),
  title: Text(title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis),
  actions: actions,
);

/// AppBar de páginas secundarias (con flecha atrás automática).
PreferredSizeWidget _subAppBar(String title, {List<Widget>? actions}) => AppBar(
  title: Text(title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis),
  actions: [...?actions, const _MenuButton()],
);

/// Botón de menú para páginas internas (junto a la flecha atrás).
class _MenuButton extends StatelessWidget {
  const _MenuButton();

  @override
  Widget build(BuildContext context) => const IconButton(
    icon: Icon(Icons.menu, size: 22),
    tooltip: 'Menú',
    onPressed: CompanionShell.openDrawer,
  );
}

/// Menú lateral global; su contenido lo construye el contenedor principal.
class _GlobalDrawer extends StatelessWidget {
  const _GlobalDrawer();

  @override
  Widget build(BuildContext context) =>
      CompanionShell.shellKey.currentState?._buildDrawer() ?? const Drawer(backgroundColor: kPanelHeaderBg);
}

// ─────────────────────────────────────────────────────────────
// WIDGETS REUTILIZABLES
// ─────────────────────────────────────────────────────────────

/// Textura de puntos que usa la web en las cabeceras.
class _DotPainter extends CustomPainter {
  const _DotPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double y = 4; y < size.height; y += 8) {
      for (double x = 4; x < size.width; x += 8) {
        canvas.drawCircle(Offset(x, y), 0.7, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotPainter oldDelegate) => oldDelegate.color != color;
}

class _Dotted extends StatelessWidget {
  const _Dotted({required this.child, this.color = const Color(0x18f2f0ec)});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _DotPainter(color), child: child);
}

/// Panel con cabecera: [título] [subtítulo] [acción opcional]. Bordes crema de 2 px como la web.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.badge,
    this.right,
    this.onMore,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final String? badge;
  final Widget? right;
  final VoidCallback? onMore;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: kPanelBg, border: Border.all(color: kBorderHighlight, width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: const BoxDecoration(
              color: kPanelHeaderBg,
              border: Border(bottom: BorderSide(color: kBorderHighlight, width: 2)),
            ),
            child: _Dotted(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(title.toUpperCase(), style: kDisplay(21)),
                          if (badge != null)
                            Text(badge!.toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.3, color: kTextMuted)),
                        ],
                      ),
                    ),
                    if (right != null) ...[const SizedBox(width: 6), right!],
                  ],
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
          if (onMore != null)
            InkWell(
              onTap: onMore,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: kBorderColor))),
                child: const Text('VER TODO →',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.3, color: kTextPrimary)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(
    this.text, {
    this.color = kTextPrimary,
    this.filled = false,
  });

  final String text;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: filled ? color : Colors.transparent,
      border: Border.all(color: color, width: 1.5),
    ),
    child: Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        color: filled ? (color.computeLuminance() > 0.35 ? kInk : kTextPrimary) : color,
        letterSpacing: 1.1,
      ),
    ),
  );
}

/// Imagen remota robusta: prueba la ruta principal y, si falla, cada alternativa
/// de [alt] en orden; si ninguna existe, muestra un recuadro neutro.
class _NetImage extends StatelessWidget {
  const _NetImage(this.path, {this.fit = BoxFit.cover, this.fallbackIcon = Icons.image_outlined, this.alt = const []});
  final String? path;
  final BoxFit fit;
  final IconData fallbackIcon;
  final List<String?> alt;

  @override
  Widget build(BuildContext context) {
    final urls = <String>[];
    for (final p in [path, ...alt]) {
      final u = Api.asset(p);
      if (u.isNotEmpty && !urls.contains(u)) urls.add(u);
    }
    final placeholder = Container(
      color: kMuted,
      alignment: Alignment.center,
      child: Icon(fallbackIcon, color: const Color(0xff4a4743), size: 18),
    );
    Widget at(int i) {
      if (i >= urls.length) return placeholder;
      return Image.network(
        urls[i],
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (context, error, stack) => at(i + 1),
        loadingBuilder: (context, child, progress) => progress == null ? child : Container(color: kMuted),
      );
    }

    return at(0);
  }
}

/// Cuadro de imagen con borde fijo.
class _Thumb extends StatelessWidget {
  const _Thumb(this.path,
      {this.size = 48,
      this.radius = 0,
      this.fallbackIcon = Icons.person_outline,
      this.fit = BoxFit.cover,
      this.alt = const []});
  final String? path;
  final List<String?> alt;
  final double size;
  final double radius;
  final IconData fallbackIcon;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: kMuted,
      borderRadius: radius > 0 ? BorderRadius.circular(radius) : null,
      border: Border.all(color: kBorderColor),
    ),
    clipBehavior: Clip.hardEdge,
    child: _NetImage(path, fallbackIcon: fallbackIcon, fit: fit, alt: alt),
  );
}

class _RemoteThumb extends StatelessWidget {
  const _RemoteThumb({this.path, this.size = 48});
  final String? path;
  final double size;

  @override
  Widget build(BuildContext context) => _Thumb(path, size: size);
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(strokeWidth: 2, color: kTextPrimary),
    ),
  );
}

/// Carga asíncrona estándar con estados de error y reintento.
class _Loader<T> extends StatefulWidget {
  const _Loader({super.key, required this.load, required this.builder});
  final Future<T> Function(bool refresh) load;
  final Widget Function(BuildContext context, T data, Future<void> Function() refresh) builder;

  @override
  State<_Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<_Loader<T>> {
  late Future<T> future;

  @override
  void initState() {
    super.initState();
    future = widget.load(false);
  }

  Future<void> _refresh() async {
    final f = widget.load(true);
    setState(() => future = f);
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snap) {
      if (snap.hasError) return _ErrorView(error: '${snap.error}', onRetry: _refresh);
      if (!snap.hasData) return const _Spinner();
      return widget.builder(context, snap.data as T, _refresh);
    },
  );
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Center(
      child: Text(text.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({String? error, String? msg, this.onRetry})
      : error = error ?? msg ?? 'No se pudieron cargar los datos';
  final String error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: kPanelBg, border: Border.all(color: kDestructive, width: 2)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: kDestructive, size: 26),
            const SizedBox(height: 10),
            Text('NO SE PUDIERON CARGAR LOS DATOS', textAlign: TextAlign.center, style: kDisplay(18, color: kDestructive)),
            const SizedBox(height: 6),
            Text(error.replaceFirst('Exception: ', ''),
                textAlign: TextAlign.center, style: const TextStyle(color: kTextMuted, fontSize: 11)),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kTextPrimary, width: 1.5),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                onPressed: onRetry,
                child: const Text('REINTENTAR',
                    style: TextStyle(color: kTextPrimary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Fila "etiqueta: valor" que nunca desborda.
class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kTextMuted)),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}

/// Abre una hoja inferior desplazable con contenido arbitrario.
Future<void> _showSheet(BuildContext context, {required String title, required List<Widget> children}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: kBgDark,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (ctx, scroll) => Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            decoration: const BoxDecoration(
              color: kPanelHeaderBg,
              border: Border(
                top: BorderSide(color: kBorderHighlight, width: 2),
                bottom: BorderSide(color: kBorderColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(title.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
          ),
          Expanded(
            child: ListView(controller: scroll, padding: const EdgeInsets.all(16), children: children),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// TRADUCCIONES Y UTILIDADES
// ─────────────────────────────────────────────────────────────

const _elementNames = {
  'ignis': 'Fuego',
  'aqua': 'Agua',
  'ventus': 'Viento',
  'terra': 'Tierra',
  'lux': 'Luz',
  'umbra': 'Oscuridad',
  'none': 'Neutro',
};

String _elementLabel(String? e) {
  if (e == null || e.isEmpty) return '';
  final up = e.toUpperCase();
  if (up == 'TODOS' || up == 'ALL') return 'TODOS';
  return (_elementNames[e.toLowerCase()] ?? e).toUpperCase();
}

Color _elementColor(String? elem) {
  switch (elem?.toLowerCase()) {
    case 'ignis':
      return const Color(0xffea3830);
    case 'aqua':
      return const Color(0xff0098d7);
    case 'ventus':
      return const Color(0xff22af68);
    case 'terra':
      return const Color(0xffe68921);
    case 'lux':
      return const Color(0xffeacb3e);
    case 'umbra':
      return const Color(0xff9f6be1);
    default:
      return kTextMuted;
  }
}

const _termNames = {
  // Posición
  'vanguard': 'Vanguardia',
  'versatile': 'Versátil',
  'support': 'Apoyo',
  // Tipo de ataque
  'melee': 'Cuerpo a cuerpo',
  'ranged': 'A distancia',
  // Estilos
  'steady': 'Estable',
  'collector': 'Coleccionista',
  'adventurous': 'Aventurero',
  'dexterous': 'Hábil',
  'inquisitive': 'Curioso',
  'perceptive': 'Perspicaz',
  'diligent': 'Diligente',
  'reckless': 'Temerario',
  // Gachas
  'anniversary exclusive recruitment': 'Reclutamiento de aniversario',
  'limited trekker banner': 'Gacha limitado de trekker',
  'limited disc banner': 'Gacha limitado de disco',
  'permanent trekker banner': 'Gacha permanente de trekker',
  'permanent disc banner': 'Gacha permanente de disco',
  'opening act': 'Gacha de inicio',
  // Etiquetas de disco
  'hp': 'Vida',
  'skills': 'Habilidades',
  'crit': 'Crítico',
  'atk': 'Ataque',
  'def': 'Defensa',
  'ultimate': 'Definitiva',
  'auto attack': 'Ataque básico',
  'energy': 'Energía',
  'shield': 'Escudo',
  'healing': 'Curación',
  'mark': 'Marca',
  'minion': 'Invocación',
  // Recompensas
  'item': 'Objeto',
  'honor': 'Título',
};

String _term(String? v) {
  if (v == null || v.isEmpty) return '';
  return _termNames[v.toLowerCase()] ?? v;
}

List<dynamic> _asList(dynamic value) => value is List ? value : const [];
Map<String, dynamic> _asMap(dynamic value) => value is Map<String, dynamic>
    ? value
    : value is Map
    ? Map<String, dynamic>.from(value)
    : <String, dynamic>{};
String _string(dynamic value, [String fallback = '']) =>
    (value == null || '$value' == 'null') ? fallback : '$value';

const _months = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v > 9999999999 ? v : v * 1000);
  return DateTime.tryParse('$v')?.toLocal();
}

String _shortDate(DateTime? d) => d == null ? '' : '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

String _date(String value) {
  final d = _parseDate(value);
  if (d == null) return value;
  return '${_shortDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// "3d 4h", "5h 12m", "FINALIZADO"
String _remaining(DateTime? end, {DateTime? now}) {
  if (end == null) return '';
  final diff = end.difference(now ?? DateTime.now());
  if (diff.isNegative) return 'FINALIZADO';
  final d = diff.inDays;
  final h = diff.inHours % 24;
  final m = diff.inMinutes % 60;
  if (d > 0) return '${d}d ${h}h';
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

/// Limpia el marcado del juego: '&lt;color&gt;', ##Nombre#id#, &ParamN&, saltos especiales.
String _cleanGameText(String? raw, {List<dynamic>? params}) {
  if (raw == null) return '';
  var s = raw.replaceAll('\u000b', '\n');
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  s = s.replaceAllMapped(RegExp(r'##([^#]+)#\d+#'), (m) => m[1]!);
  s = s.replaceAllMapped(RegExp(r'&Param(\d+)&'), (m) {
    final i = int.parse(m[1]!) - 1;
    if (params == null || i < 0 || i >= params.length) return '?';
    return _paramRange('${params[i]}');
  });
  s = s.replaceAllMapped(RegExp(r'\{(\d+)\}'), (m) {
    final i = int.parse(m[1]!) - 1;
    if (params == null || i < 0 || i >= params.length) return m[0]!;
    return _paramRange('${params[i]}');
  });
  return s.trim();
}

String _paramRange(String p) {
  if (p.contains(',')) return '?';
  final parts = p.split('/');
  if (parts.length <= 1) return p;
  return '${parts.first}→${parts.last}';
}

/// Limpia HTML de las noticias oficiales.
String _cleanHtml(String? raw) {
  if (raw == null) return '';
  var s = raw.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  const entities = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&ndash;': '–',
    '&mdash;': '—',
    '&ge;': '≥',
    '&le;': '≤',
    '&quot;': '"',
    '&#39;': "'",
    '&lt;': '<',
    '&gt;': '>',
  };
  entities.forEach((k, v) => s = s.replaceAll(k, v));
  s = s.replaceAll(RegExp(r'[ \t]+\n'), '\n').replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trim();
}

/// Icono de un objeto del juego. Los discos rúnicos (ids 21xxxx) no tienen item_*.png:
/// su icono es la portada del disco (outfit_xxxx_b), igual que en la web.
List<String> _itemIcons(dynamic id) {
  final s = _string(id);
  final n = int.tryParse(s) ?? 0;
  if (n >= 210000 && n < 220000) {
    final d = (n % 10000).toString().padLeft(4, '0');
    return ['outfit_${d}_b.png', 'outfit_$d.png', 'item_$s.png'];
  }
  return ['item_$s.png'];
}

/// Miniatura de objeto con su icono correcto y alternativas.
Widget _itemThumb(dynamic id, {double size = 34, IconData fallbackIcon = Icons.inventory_2_outlined}) {
  final icons = _itemIcons(id);
  return _Thumb(icons.first, size: size, fallbackIcon: fallbackIcon, alt: icons.skip(1).toList());
}

/// Icono de retrato a partir del id del personaje (110 → head_11001_XL).
String _charHead(dynamic id) => '/stella/assets/head_${id}01_XL.png';
