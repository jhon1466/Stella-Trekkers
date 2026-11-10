import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class YostarAccount {
  final String email;
  final String uid;
  final String token;
  final String nickname;
  final String picture;
  final int createdAt;

  /// Credenciales de cuenta Yostar (larga duración) para renovar el token de juego sin OTP.
  final String yostarUid;
  final String yostarToken;

  const YostarAccount({
    this.yostarUid = '',
    this.yostarToken = '',
    required this.email,
    required this.uid,
    required this.token,
    required this.nickname,
    required this.picture,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'uid': uid,
    'token': token,
    'nickname': nickname,
    'picture': picture,
    'createdAt': createdAt,
    'yostarUid': yostarUid,
    'yostarToken': yostarToken,
  };

  bool get canRefresh => yostarToken.isNotEmpty && yostarUid.isNotEmpty;

  YostarAccount copyWith({String? uid, String? token, String? nickname}) => YostarAccount(
    email: email,
    uid: uid ?? this.uid,
    token: token ?? this.token,
    nickname: nickname ?? this.nickname,
    picture: picture,
    createdAt: createdAt,
    yostarUid: yostarUid,
    yostarToken: yostarToken,
  );

  factory YostarAccount.fromJson(Map<String, dynamic> json) => YostarAccount(
    email: json['email'] as String? ?? '',
    uid: json['uid'] as String? ?? '',
    token: json['token'] as String? ?? '',
    nickname: json['nickname'] as String? ?? '',
    picture: json['picture'] as String? ?? '',
    createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
    yostarUid: json['yostarUid'] as String? ?? '',
    yostarToken: json['yostarToken'] as String? ?? '',
  );
}

class YostarAuthService {
  static const String sdkBaseUrl = 'https://en-sdk-api.yostarplat.com';
  static const String netKey = '886c085e4a8d30a703367b120dd8353948405ec2';

  static String _deviceId = 'abcdef0123456789';

  /// Identificador de dispositivo estable por instalación (los tokens van ligados a él).
  static Future<void> _loadDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('yostar_device_id');
    if (id == null || id.isEmpty) {
      // Las cuentas vinculadas antes de este cambio usaron el id fijo: se conserva.
      if (prefs.getString('official_yostar_account') != null) {
        id = _deviceId;
      } else {
        final r = Random.secure();
        id = List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
      }
      await prefs.setString('yostar_device_id', id);
    }
    _deviceId = id;
  }

  static Map<String, dynamic> _makeHead({String uid = '', String token = ''}) {
    return {
      'PID': 'US-NOVA',
      'Channel': 'googleplay',
      'Platform': 'android',
      'Version': '4.17.4',
      'GVersionNo': '56',
      'GBuildNo': '',
      'Lang': 'en',
      'DeviceID': _deviceId,
      'DeviceModel': 'Google Pixel 7',
      'UID': uid,
      'Token': token,
      'Time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
  }

  static String _buildAuthHeader(Map<String, dynamic> head, String bodyJson) {
    final headJson = jsonEncode(head);
    final toSign = '$headJson$bodyJson$netKey';
    final sign = md5.convert(utf8.encode(toSign)).toString().toUpperCase();
    return jsonEncode({
      'Head': head,
      'Sign': sign,
    });
  }

  /// Sends a 6-digit verification code to the player's email using the official Yostar SDK endpoint.
  static Future<void> sendVerificationCode(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw Exception('Por favor ingresa un correo electrónico válido.');
    }
    await _loadDeviceId();

    final bodyMap = {
      'Account': cleanEmail,
      'Randstr': '',
      'Ticket': '',
    };
    final bodyJson = jsonEncode(bodyMap);
    final head = _makeHead();
    final authHeader = _buildAuthHeader(head, bodyJson);

    final response = await http.post(
      Uri.parse('$sdkBaseUrl/yostar/send-code'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': authHeader,
      },
      body: bodyJson,
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Error de red al conectar con el servidor de Yostar (${response.statusCode}).');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final code = data['Code'] as int? ?? 0;
    if (code != 200) {
      final msg = data['Msg'] as String? ?? 'No se pudo enviar el código.';
      throw Exception('Servidor Yostar: $msg (Código $code)');
    }
  }

  /// Verifies the 6-digit code and logs into the official account.
  /// Returns the authenticated [YostarAccount] and persists credentials.
  static Future<YostarAccount> verifyCodeAndLogin(String email, String verificationCode) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanCode = verificationCode.trim();

    if (cleanCode.length != 6) {
      throw Exception('El código de verificación debe contener 6 dígitos.');
    }
    await _loadDeviceId();

    // Step 1: Verify code via /yostar/get-auth
    final getAuthBody = jsonEncode({
      'Account': cleanEmail,
      'Code': cleanCode,
    });
    final getAuthHead = _makeHead();
    final getAuthAuthHeader = _buildAuthHeader(getAuthHead, getAuthBody);

    final getAuthResp = await http.post(
      Uri.parse('$sdkBaseUrl/yostar/get-auth'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': getAuthAuthHeader,
      },
      body: getAuthBody,
    ).timeout(const Duration(seconds: 15));

    if (getAuthResp.statusCode != 200) {
      throw Exception('Error al validar código con Yostar (${getAuthResp.statusCode}).');
    }

    final getAuthData = jsonDecode(getAuthResp.body) as Map<String, dynamic>;
    if (getAuthData['Code'] != 200) {
      final msg = getAuthData['Msg'] as String? ?? 'Código de verificación incorrecto o expirado.';
      throw Exception(msg);
    }

    final authData = (getAuthData['Data'] as Map<String, dynamic>?) ?? {};
    final yostarUid = authData['UID']?.toString() ?? '';
    final yostarToken = authData['Token']?.toString() ?? '';

    final account = await _gameLogin(
      email: cleanEmail,
      yostarUid: yostarUid,
      yostarToken: yostarToken,
    );
    await saveAccount(account);
    return account;
  }

  /// Pide un token de juego nuevo con las credenciales de cuenta guardadas, sin OTP.
  /// Es lo mismo que hace el juego al abrirse.
  static Future<YostarAccount> refreshSession(YostarAccount current) async {
    if (!current.canRefresh) {
      throw Exception('La sesión caducó. Vincula la cuenta otra vez con tu código OTP (sólo esta vez).');
    }
    await _loadDeviceId();
    final fresh = await _gameLogin(
      email: current.email,
      yostarUid: current.yostarUid,
      yostarToken: current.yostarToken,
    );
    final merged = YostarAccount(
      email: current.email,
      uid: fresh.uid,
      token: fresh.token,
      nickname: current.nickname.isNotEmpty ? current.nickname : fresh.nickname,
      picture: fresh.picture.isNotEmpty ? fresh.picture : current.picture,
      createdAt: current.createdAt != 0 ? current.createdAt : fresh.createdAt,
      yostarUid: current.yostarUid,
      yostarToken: current.yostarToken,
    );
    await saveAccount(merged);
    return merged;
  }

  static Future<YostarAccount> _gameLogin({
    required String email,
    required String yostarUid,
    required String yostarToken,
  }) async {
    final cleanEmail = email;
    // Login via /user/login to obtain official game session token
    final loginBody = jsonEncode({
      'Type': 'yostar',
      'Token': yostarToken,
      'UserName': cleanEmail,
      'OpenID': yostarUid,
      'Secret': '',
      'CheckAccount': 0,
    });
    final loginHead = _makeHead();
    final loginAuthHeader = _buildAuthHeader(loginHead, loginBody);

    final loginResp = await http.post(
      Uri.parse('$sdkBaseUrl/user/login'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': loginAuthHeader,
      },
      body: loginBody,
    ).timeout(const Duration(seconds: 15));

    if (loginResp.statusCode != 200) {
      throw Exception('Error al iniciar sesión en el servidor oficial (${loginResp.statusCode}).');
    }

    final loginData = jsonDecode(loginResp.body) as Map<String, dynamic>;
    if (loginData['Code'] != 200) {
      final msg = loginData['Msg'] as String? ?? 'Error al iniciar sesión.';
      throw Exception(msg);
    }

    final dataObj = (loginData['Data'] as Map<String, dynamic>?) ?? {};
    final userInfo = (dataObj['UserInfo'] as Map<String, dynamic>?) ?? {};
    final yostarObj = (dataObj['Yostar'] as Map<String, dynamic>?) ?? {};

    final gameUid = userInfo['ID']?.toString() ?? yostarUid;
    final gameToken = userInfo['Token']?.toString() ?? '';
    final nickname = yostarObj['Nickname']?.toString() ?? cleanEmail.split('@').first;
    final picture = yostarObj['Picture']?.toString() ?? '';
    final createdAt = (userInfo['CreatedAt'] as num?)?.toInt() ?? (yostarObj['CreatedAt'] as num?)?.toInt() ?? 0;

    if (gameToken.isEmpty) {
      throw Exception('Yostar no devolvió un token de juego. Vuelve a vincular la cuenta.');
    }
    return YostarAccount(
      email: cleanEmail,
      uid: gameUid,
      token: gameToken,
      nickname: nickname,
      picture: picture,
      createdAt: createdAt,
      yostarUid: yostarUid,
      yostarToken: yostarToken,
    );
  }

  /// Persists account info in SharedPreferences.
  static Future<void> saveAccount(YostarAccount account) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('official_yostar_account', jsonEncode(account.toJson()));
  }

  /// Retrieves the saved account if present.
  static Future<YostarAccount?> getStoredAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('official_yostar_account');
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return YostarAccount.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Clears stored account credentials and official stats.
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('official_yostar_account');
    await prefs.remove('official_player_level');
    await prefs.remove('official_player_exp');
    await prefs.remove('official_player_name');
    await prefs.remove('official_sync_timestamp');
    // Datos del widget y del fondo elegido
    for (final k in ['widget_character_path', 'widget_character_name', 'widget_character_id',
        'official_current_energy', 'official_sync_epoch', 'official_char_count', 'official_disc_count',
        'official_stats', 'account_energy', 'account_energy_max', 'account_energy_full_minutes', 'account_energy_source']) {
      await prefs.remove(k);
    }
  }
}

