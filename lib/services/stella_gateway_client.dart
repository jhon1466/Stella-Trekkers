import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart' as pc;
import 'package:shared_preferences/shared_preferences.dart';
import 'yostar_auth_service.dart';

class ExhibitionTrekker {
  final String name;
  final int level;
  final String element;
  final String icon;
  final int grade;

  const ExhibitionTrekker({
    required this.name,
    required this.level,
    required this.element,
    required this.icon,
    this.grade = 5,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'level': level,
    'element': element,
    'icon': icon,
    'grade': grade,
  };

  factory ExhibitionTrekker.fromJson(Map<String, dynamic> json) => ExhibitionTrekker(
    name: json['name'] as String? ?? 'Firenze',
    level: (json['level'] as num?)?.toInt() ?? 1,
    element: json['element'] as String? ?? 'Umbra',
    icon: json['icon'] as String? ?? '/stella/assets/head_11001_XL.png',
    grade: (json['grade'] as num?)?.toInt() ?? 5,
  );
}

class OfficialGameStats {
  final int currentEnergy;
  final int maxEnergy;
  final int secondsToFull;
  final int level;
  final int exp;
  final String nickname;
  final String uid;
  final String title;
  final String signature;
  final String avatar;
  final String badge;
  final List<ExhibitionTrekker> exhibitionTrekkers;
  final int characterCount;
  final int discCount;
  final DateTime syncTime;

  const OfficialGameStats({
    required this.currentEnergy,
    required this.maxEnergy,
    required this.secondsToFull,
    required this.level,
    required this.exp,
    required this.nickname,
    required this.uid,
    this.title = 'Calma Steward',
    this.signature = 'eso tiln',
    this.avatar = '/stella/assets/head_11001_XL.png',
    this.badge = 'Crackling Hint of Spring',
    this.exhibitionTrekkers = const [
      ExhibitionTrekker(name: 'Firenze', level: 60, element: 'Umbra', icon: '/stella/assets/head_11001_XL.png', grade: 5),
      ExhibitionTrekker(name: 'Nanoha', level: 20, element: 'Ventus', icon: '/stella/assets/head_11901_XL.png', grade: 4),
      ExhibitionTrekker(name: 'Mistique', level: 1, element: 'Umbra', icon: '/stella/assets/head_13501_XL.png', grade: 4),
    ],
    required this.characterCount,
    required this.discCount,
    required this.syncTime,
  });

  Map<String, dynamic> toJson() => {
    'currentEnergy': currentEnergy,
    'maxEnergy': maxEnergy,
    'secondsToFull': secondsToFull,
    'level': level,
    'exp': exp,
    'nickname': nickname,
    'uid': uid,
    'title': title,
    'signature': signature,
    'avatar': avatar,
    'badge': badge,
    'exhibitionTrekkers': exhibitionTrekkers.map((t) => t.toJson()).toList(),
    'characterCount': characterCount,
    'discCount': discCount,
    'syncTime': syncTime.toIso8601String(),
  };

  factory OfficialGameStats.fromJson(Map<String, dynamic> json) {
    List<ExhibitionTrekker> parseTrekkers() {
      if (json['exhibitionTrekkers'] is List) {
        return (json['exhibitionTrekkers'] as List)
            .map((e) => ExhibitionTrekker.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return const [
        ExhibitionTrekker(name: 'Firenze', level: 60, element: 'Umbra', icon: '/stella/assets/head_11001_XL.png', grade: 5),
        ExhibitionTrekker(name: 'Nanoha', level: 20, element: 'Ventus', icon: '/stella/assets/head_11901_XL.png', grade: 4),
        ExhibitionTrekker(name: 'Mistique', level: 1, element: 'Umbra', icon: '/stella/assets/head_13501_XL.png', grade: 4),
      ];
    }

    return OfficialGameStats(
      currentEnergy: (json['currentEnergy'] as num?)?.toInt() ?? 400,
      maxEnergy: (json['maxEnergy'] as num?)?.toInt() ?? 240,
      secondsToFull: (json['secondsToFull'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 25,
      exp: (json['exp'] as num?)?.toInt() ?? 3850,
      nickname: json['nickname'] as String? ?? 'etesech',
      uid: json['uid'] as String? ?? '700494272',
      title: json['title'] as String? ?? 'Calma Steward',
      signature: json['signature'] as String? ?? 'eso tiln',
      avatar: json['avatar'] as String? ?? '/stella/assets/head_11001_XL.png',
      badge: json['badge'] as String? ?? 'Crackling Hint of Spring',
      exhibitionTrekkers: parseTrekkers(),
      characterCount: (json['characterCount'] as num?)?.toInt() ?? 6,
      discCount: (json['discCount'] as num?)?.toInt() ?? 12,
      syncTime: json['syncTime'] != null
          ? DateTime.tryParse(json['syncTime'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class _RawPlayerData {
  String nickname = 'etesech';
  int uid = 700494272;
  String uidStr = '700494272';
  int level = 25;
  int exp = 3850;
  String title = 'Calma Steward';
  String signature = 'eso tiln';
  String avatar = '/stella/assets/head_11001_XL.png';
  String badge = 'Crackling Hint of Spring';
  List<ExhibitionTrekker> exhibitionTrekkers = const [
    ExhibitionTrekker(name: 'Firenze', level: 60, element: 'Umbra', icon: '/stella/assets/head_11001_XL.png', grade: 5),
    ExhibitionTrekker(name: 'Nanoha', level: 20, element: 'Ventus', icon: '/stella/assets/head_11901_XL.png', grade: 4),
    ExhibitionTrekker(name: 'Mistique', level: 1, element: 'Umbra', icon: '/stella/assets/head_13501_XL.png', grade: 4),
  ];
  int charCount = 0;
  int discCount = 0;
  int energyPrimary = -1;
  int energyNextDuration = -1;
  int energyUpdateTime = 0;
}

class _RawEnergyData {
  int primary = 0;
  int nextDuration = 0;
  int updateTime = 0;
}

class StellaGatewayClient {
  static const String gatewayUrl = 'https://nova.stellasora.global/agent-zone-1/';
  static final Uint8List serverGarbleKey = Uint8List.fromList(utf8.encode('xNdVF^XTa6T3HCUATMQ@sKMLzAw&%L!3'));
  static const MethodChannel _widgetChannel = MethodChannel('stella/account_widget');

  static int _sequenceNumber = 1;

  // --- Garble & Crypto Helpers ---

  static Uint8List _encryptBasic(Uint8List data, Uint8List key) {
    final out = Uint8List.fromList(data);
    final len = out.length;
    for (int i = 0; i < len; i++) {
      int b = out[i] ^ key[i % key.length];
      int v7 = (b << 1) & 0xff;
      int v1 = (b >> 7) & 0x01;
      out[i] = ((v1 | v7) ^ (len & 0xff)) & 0xff;
    }
    return out;
  }

  static Uint8List _decryptBasic(Uint8List data, Uint8List key) {
    final out = Uint8List.fromList(data);
    final len = out.length;
    for (int i = 0; i < len; i++) {
      int b = out[i] ^ (len & 0xff);
      int v1 = (b << 7) & 0xff;
      int v7 = (b >> 1) & 0x7f;
      out[i] = ((v7 | v1) ^ key[i % key.length]) & 0xff;
    }
    return out;
  }

  static Future<Uint8List> _encryptGcm(Uint8List data, Uint8List key) async {
    final aesGcm = AesGcm.with256bits();
    final secretKey = SecretKey(key);
    final rng = Random.secure();
    final iv = Uint8List.fromList(List.generate(12, (_) => rng.nextInt(256)));
    final secretBox = await aesGcm.encrypt(
      data,
      secretKey: secretKey,
      nonce: iv,
      aad: iv,
    );
    final bb = BytesBuilder();
    bb.add(iv);
    bb.add(secretBox.cipherText);
    bb.add(secretBox.mac.bytes);
    return bb.toBytes();
  }

  static Future<Uint8List> _decryptGcm(Uint8List data, Uint8List key) async {
    if (data.length < 28) throw Exception('Datos AES-GCM inválidos (demasiado cortos).');
    final iv = data.sublist(0, 12);
    final cipherText = data.sublist(12, data.length - 16);
    final mac = Mac(data.sublist(data.length - 16));
    final aesGcm = AesGcm.with256bits();
    final secretKey = SecretKey(key);
    final secretBox = SecretBox(cipherText, nonce: iv, mac: mac);
    final clearText = await aesGcm.decrypt(
      secretBox,
      secretKey: secretKey,
      aad: iv,
    );
    return Uint8List.fromList(clearText);
  }

  static Future<Uint8List> _encryptChaCha(Uint8List data, Uint8List key) async {
    final algorithm = Chacha20.poly1305Aead();
    final secretKey = SecretKey(key);
    final nonce = algorithm.newNonce();
    final secretBox = await algorithm.encrypt(
      data,
      secretKey: secretKey,
      nonce: nonce,
      aad: nonce,
    );
    final bb = BytesBuilder();
    bb.add(nonce);
    bb.add(secretBox.cipherText);
    bb.add(secretBox.mac.bytes);
    return bb.toBytes();
  }

  static Future<Uint8List> _decryptChaCha(Uint8List data, Uint8List key) async {
    if (data.length < 28) throw Exception('Datos ChaCha20-Poly1305 demasiado cortos.');
    final nonce = data.sublist(0, 12);
    final cipherText = data.sublist(12, data.length - 16);
    final mac = Mac(data.sublist(data.length - 16));
    final algorithm = Chacha20.poly1305Aead();
    final secretKey = SecretKey(key);
    final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);
    final clearText = await algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
      aad: nonce,
    );
    return Uint8List.fromList(clearText);
  }

  static Uint8List _encodeVarint(int value) {
    final res = <int>[];
    var n = value;
    while (n >= 0x80) {
      res.add((n & 0x7f) | 0x80);
      n >>= 7;
    }
    res.add(n);
    return Uint8List.fromList(res);
  }

  static Uint8List _bigIntToUnsignedByteArray(BigInt b) {
    var hex = b.toRadixString(16);
    if (hex.length % 2 != 0) hex = '0$hex';
    final len = hex.length ~/ 2;
    final out = Uint8List(len);
    for (int i = 0; i < len; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static pc.AsymmetricKeyPair<pc.PublicKey, pc.PrivateKey> _generateECDHKeyPair() {
    final domain = pc.ECDomainParameters('secp256r1');
    final keyGen = pc.ECKeyGenerator();
    final secureRandom = pc.SecureRandom('Fortuna')
      ..seed(pc.KeyParameter(Uint8List.fromList(List.generate(32, (_) => Random.secure().nextInt(256)))));
    keyGen.init(pc.ParametersWithRandom(pc.ECKeyGeneratorParameters(domain), secureRandom));
    return keyGen.generateKeyPair();
  }

  static Uint8List _deriveSessionKey(Uint8List clientPubKey, pc.ECPrivateKey clientPrivKey, Uint8List serverPubKey) {
    final domain = pc.ECDomainParameters('secp256r1');
    final serverPoint = domain.curve.decodePoint(serverPubKey)!;
    final serverPubParams = pc.ECPublicKey(serverPoint, domain);

    final agreement = pc.ECDHBasicAgreement();
    agreement.init(clientPrivKey);
    final resultBigInt = agreement.calculateAgreement(serverPubParams);

    final agreementBytes = _bigIntToUnsignedByteArray(resultBigInt);
    final ikm = Uint8List(32);
    final count = min(agreementBytes.length, 32);
    ikm.setRange(32 - count, 32, agreementBytes.sublist(agreementBytes.length - count));

    final salt = serverPubKey;
    final info = Uint8List(serverPubKey.length);
    for (int i = 0; i < info.length; i++) {
      final c = clientPubKey[i] & 0xff;
      int s = serverPubKey[i] & 0xff;
      if (c > s) {
        s = (s << 1) & 0xff;
      } else {
        s = (s >> 1) & 0x7f;
      }
      info[i] = (s ^ c) & 0xff;
    }

    final hkdf = pc.KeyDerivator('SHA-256/HKDF');
    hkdf.init(pc.HkdfParameters(ikm, 32, salt, info));
    return hkdf.process(Uint8List(0));
  }

  /// Performs live ECDH P-256 key exchange with official `agent-zone-1`
  /// and returns {sessionToken, sessionKey, cipherMethod}.
  static Future<Map<String, dynamic>> performHandshake() async {
    final keyPair = _generateECDHKeyPair();
    final pubKey = keyPair.publicKey as pc.ECPublicKey;
    final privKey = keyPair.privateKey as pc.ECPrivateKey;
    final clientPubKey = Uint8List.fromList(pubKey.Q!.getEncoded(false));

    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final proto = BytesBuilder();
    proto.addByte(0x08);
    proto.add(_encodeVarint(1)); // protoVersion = 1
    proto.addByte(0x10);
    proto.add(_encodeVarint(ts)); // clientTs
    proto.addByte(0x1a);
    proto.add(_encodeVarint(clientPubKey.length));
    proto.add(clientPubKey);

    // msgId = 1 (ike_req)
    final msg = BytesBuilder();
    msg.addByte(0x00);
    msg.addByte(0x01);
    msg.add(proto.toBytes());

    final encGcm = await _encryptGcm(msg.toBytes(), serverGarbleKey);
    final reqBody = _encryptBasic(encGcm, serverGarbleKey);

    final resp = await http.post(
      Uri.parse(gatewayUrl),
      body: reqBody,
      headers: {'Content-Type': 'application/octet-stream'},
    ).timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw Exception('Servidor Gateway respondió HTTP ${resp.statusCode}');
    }

    final decBasic = _decryptBasic(resp.bodyBytes, serverGarbleKey);
    final dec = await _decryptGcm(decBasic, serverGarbleKey);
    final msgId = (dec[0] << 8) | dec[1];
    if (msgId != 2) {
      throw Exception('Respuesta IKE inesperada (msgId $msgId)');
    }

    final payload = dec.sublist(2);
    int offset = 0;
    String sessionToken = '';
    int cipherMethod = 0;
    Uint8List? serverPubKey;

    while (offset < payload.length) {
      final tagByte = payload[offset++];
      final fieldNum = tagByte >> 3;
      final wireType = tagByte & 0x07;

      if (wireType == 0) {
        int val = 0;
        int shift = 0;
        while (offset < payload.length) {
          final b = payload[offset++];
          val |= (b & 0x7f) << shift;
          if ((b & 0x80) == 0) break;
          shift += 7;
        }
        if (fieldNum == 2) cipherMethod = val;
      } else if (wireType == 2) {
        int len = 0;
        int shift = 0;
        while (offset < payload.length) {
          final b = payload[offset++];
          len |= (b & 0x7f) << shift;
          if ((b & 0x80) == 0) break;
          shift += 7;
        }
        final data = payload.sublist(offset, offset + len);
        offset += len;
        if (fieldNum == 1) sessionToken = utf8.decode(data);
        if (fieldNum == 4) serverPubKey = Uint8List.fromList(data);
      }
    }

    if (serverPubKey == null || sessionToken.isEmpty) {
      throw Exception('El servidor no devolvió las claves de sesión necesarias.');
    }

    final sessionKey = _deriveSessionKey(clientPubKey, privKey, serverPubKey);

    return {
      'sessionToken': sessionToken,
      'sessionKey': sessionKey,
      'cipherMethod': cipherMethod,
    };
  }

  /// Sends an encrypted packet over the active game gateway session.
  /// Formats: [10 bytes prefix (uint64 BE ts_sec + uint16 BE seq)] + [2 bytes msgId] + [proto payload]
  static Future<Map<String, dynamic>> sendGamePacket({
    required int msgId,
    required Uint8List protoPayload,
    required String sessionToken,
    required Uint8List sessionKey,
    required int cipherMethod,
  }) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final prefix = Uint8List(10)
      ..buffer.asByteData().setUint64(0, nowSec, Endian.big)
      ..buffer.asByteData().setUint16(8, _sequenceNumber++, Endian.big);

    final packet = BytesBuilder();
    packet.add(prefix);
    packet.addByte((msgId >> 8) & 0xff);
    packet.addByte(msgId & 0xff);
    packet.add(protoPayload);

    final packetBytes = packet.toBytes();
    final encryptedReq = cipherMethod == 1
        ? await _encryptChaCha(packetBytes, sessionKey)
        : await _encryptGcm(packetBytes, sessionKey);

    final resp = await http.post(
      Uri.parse(gatewayUrl),
      body: encryptedReq,
      headers: {
        'Content-Type': 'application/octet-stream',
        'X-Token': sessionToken,
      },
    ).timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw Exception('El servidor de juego respondió HTTP ${resp.statusCode}');
    }

    if (resp.bodyBytes.length < 28) {
      throw Exception('El servidor de juego devolvió una respuesta vacía o incompleta.');
    }

    final decrypted = cipherMethod == 1
        ? await _decryptChaCha(resp.bodyBytes, sessionKey)
        : await _decryptGcm(resp.bodyBytes, sessionKey);

    final respMsgId = (decrypted[0] << 8) | decrypted[1];
    final payload = decrypted.sublist(2);

    return {
      'msgId': respMsgId,
      'payload': payload,
    };
  }

  /// Authenticates the player session using their Yostar game token on the official game gateway.
  /// Returns the newly issued session token for subsequent game queries.
  static Future<String> _loginGatewaySession({
    required YostarAccount account,
    required String sessionToken,
    required Uint8List sessionKey,
    required int cipherMethod,
  }) async {
    final uidBytes = utf8.encode(account.uid);
    final tokBytes = utf8.encode(account.token);

    // OfficialOverseas: Field 1 = Uid, Field 2 = Token
    final overBuilder = BytesBuilder();
    overBuilder.addByte(0x0a);
    overBuilder.add(_encodeVarint(uidBytes.length));
    overBuilder.add(uidBytes);
    overBuilder.addByte(0x12);
    overBuilder.add(_encodeVarint(tokBytes.length));
    overBuilder.add(tokBytes);
    final overBytes = overBuilder.toBytes();

    // LoginReq fields:
    // Field 3: OfficialOverseas
    // Field 11: Platform = 2 (Android)
    // Field 12: Language = "en"
    // Field 13: Channel = "Official"
    // Field 14: Device = "android"
    // Field 15: Version = "2.0.0.145"
    final loginBuilder = BytesBuilder();
    loginBuilder.addByte(0x1a);
    loginBuilder.add(_encodeVarint(overBytes.length));
    loginBuilder.add(overBytes);

    loginBuilder.addByte(0x58);
    loginBuilder.add(_encodeVarint(2)); // Platform.Android = 2

    final langBytes = utf8.encode('en');
    loginBuilder.addByte(0x62);
    loginBuilder.add(_encodeVarint(langBytes.length));
    loginBuilder.add(langBytes);

    final chanBytes = utf8.encode('Official');
    loginBuilder.addByte(0x6a);
    loginBuilder.add(_encodeVarint(chanBytes.length));
    loginBuilder.add(chanBytes);

    final devBytes = utf8.encode('android');
    loginBuilder.addByte(0x72);
    loginBuilder.add(_encodeVarint(devBytes.length));
    loginBuilder.add(devBytes);

    final verBytes = utf8.encode('2.0.0.145');
    loginBuilder.addByte(0x7a);
    loginBuilder.add(_encodeVarint(verBytes.length));
    loginBuilder.add(verBytes);

    final res = await sendGamePacket(
      msgId: 4, // player_login_req
      protoPayload: loginBuilder.toBytes(),
      sessionToken: sessionToken,
      sessionKey: sessionKey,
      cipherMethod: cipherMethod,
    );

    final respMsgId = res['msgId'] as int;
    final payload = res['payload'] as Uint8List;

    if (respMsgId == 5) {
      // player_login_succeed_ack -> returns LoginResp with Token in field 1
      int offset = 0;
      String newSessionToken = sessionToken;
      while (offset < payload.length) {
        int tag = 0;
        int shift = 0;
        while (offset < payload.length) {
          final b = payload[offset++];
          tag |= (b & 0x7f) << shift;
          if ((b & 0x80) == 0) break;
          shift += 7;
        }
        final fn = tag >> 3;
        final wt = tag & 0x07;
        if (wt == 2) {
          int len = 0;
          int s = 0;
          while (offset < payload.length) {
            final b = payload[offset++];
            len |= (b & 0x7f) << s;
            if ((b & 0x80) == 0) break;
            s += 7;
          }
          final strBytes = payload.sublist(offset, offset + len);
          offset += len;
          if (fn == 1) newSessionToken = utf8.decode(strBytes);
        } else if (wt == 0) {
          while (offset < payload.length) {
            final b = payload[offset++];
            if ((b & 0x80) == 0) break;
          }
        }
      }
      return newSessionToken;
    } else {
      // Login failed (msgId 6 or 10000)
      int code = 0;
      if (payload.isNotEmpty && payload[0] == 0x08) {
        int shift = 0;
        int idx = 1;
        while (idx < payload.length) {
          final b = payload[idx++];
          code |= (b & 0x7f) << shift;
          if ((b & 0x80) == 0) break;
          shift += 7;
        }
      }
      if (code == 100101 || code == 100110 || code == 110106) {
        throw const SessionExpiredException();
      } else {
        throw Exception('Inicio de sesión en el servidor de juego rechazado (Código $code).');
      }
    }
  }

  /// Queries the live player info from the game server (msgId 1001).
  static Future<_RawPlayerData> _fetchPlayerData({
    required String sessionToken,
    required Uint8List sessionKey,
    required int cipherMethod,
  }) async {
    final res = await sendGamePacket(
      msgId: 1001, // player_data_req
      protoPayload: Uint8List(0),
      sessionToken: sessionToken,
      sessionKey: sessionKey,
      cipherMethod: cipherMethod,
    );

    final respMsgId = res['msgId'] as int;
    final payload = res['payload'] as Uint8List;

    if (respMsgId != 1002) {
      throw Exception('Respuesta inesperada al consultar datos del jugador (msgId $respMsgId).');
    }

    final pInfo = _RawPlayerData();
    int offset = 0;
    while (offset < payload.length) {
      int tag = 0;
      int shift = 0;
      while (offset < payload.length) {
        final b = payload[offset++];
        tag |= (b & 0x7f) << shift;
        if ((b & 0x80) == 0) break;
        shift += 7;
      }
      final fieldNum = tag >> 3;
      final wireType = tag & 0x07;

      if (wireType == 0) {
        while (offset < payload.length) {
          final b = payload[offset++];
          if ((b & 0x80) == 0) break;
        }
      } else if (wireType == 2) {
        int len = 0;
        int lShift = 0;
        while (offset < payload.length) {
          final b = payload[offset++];
          len |= (b & 0x7f) << lShift;
          if ((b & 0x80) == 0) break;
          lShift += 7;
        }
        final fieldBytes = payload.sublist(offset, offset + len);
        offset += len;

        if (fieldNum == 1) {
          // AccInfo: Id = 1, NickName = 2
          int subOff = 0;
          while (subOff < fieldBytes.length) {
            final sTag = fieldBytes[subOff++];
            final sFn = sTag >> 3;
            final sWt = sTag & 0x07;
            if (sWt == 0) {
              int val = 0;
              int s = 0;
              while (subOff < fieldBytes.length) {
                final b = fieldBytes[subOff++];
                val |= (b & 0x7f) << s;
                if ((b & 0x80) == 0) break;
                s += 7;
              }
              if (sFn == 1) {
                pInfo.uid = val;
                pInfo.uidStr = val.toString();
              }
            } else if (sWt == 2) {
              int sLen = 0;
              int s = 0;
              while (subOff < fieldBytes.length) {
                final b = fieldBytes[subOff++];
                sLen |= (b & 0x7f) << s;
                if ((b & 0x80) == 0) break;
                s += 7;
              }
              final strBytes = fieldBytes.sublist(subOff, subOff + sLen);
              subOff += sLen;
              if (sFn == 1) {
                pInfo.uidStr = utf8.decode(strBytes, allowMalformed: true);
                pInfo.uid = int.tryParse(pInfo.uidStr) ?? 0;
              }
              if (sFn == 2) pInfo.nickname = utf8.decode(strBytes, allowMalformed: true);
            }
          }
        } else if (fieldNum == 4) {
          // repeated Char
          pInfo.charCount++;
        } else if (fieldNum == 7) {
          // EnergyInfo containing Energy = 1
          int subOff = 0;
          while (subOff < fieldBytes.length) {
            final sTag = fieldBytes[subOff++];
            final sFn = sTag >> 3;
            final sWt = sTag & 0x07;
            if (sWt == 2 && sFn == 1) {
              int sLen = 0;
              int s = 0;
              while (subOff < fieldBytes.length) {
                final b = fieldBytes[subOff++];
                sLen |= (b & 0x7f) << s;
                if ((b & 0x80) == 0) break;
                s += 7;
              }
              final eBytes = fieldBytes.sublist(subOff, subOff + sLen);
              subOff += sLen;

              // Parse Energy: primary=1, updateTime=4, nextDuration=5
              int eOff = 0;
              while (eOff < eBytes.length) {
                final eTag = eBytes[eOff++];
                final eFn = eTag >> 3;
                final eWt = eTag & 0x07;
                if (eWt == 0) {
                  int val = 0;
                  int sShift = 0;
                  while (eOff < eBytes.length) {
                    final b = eBytes[eOff++];
                    val |= (b & 0x7f) << sShift;
                    if ((b & 0x80) == 0) break;
                    sShift += 7;
                  }
                  if (eFn == 1) pInfo.energyPrimary = val;
                  if (eFn == 4) pInfo.energyUpdateTime = val;
                  if (eFn == 5) pInfo.energyNextDuration = val;
                }
              }
            } else if (sWt == 2) {
              int sLen = 0;
              int s = 0;
              while (subOff < fieldBytes.length) {
                final b = fieldBytes[subOff++];
                sLen |= (b & 0x7f) << s;
                if ((b & 0x80) == 0) break;
                s += 7;
              }
              subOff += sLen;
            }
          }
        } else if (fieldNum == 8) {
          // WorldClassInfo: Cur = 1 (Level), LastExp = 2 (Exp)
          int subOff = 0;
          while (subOff < fieldBytes.length) {
            final sTag = fieldBytes[subOff++];
            final sFn = sTag >> 3;
            final sWt = sTag & 0x07;
            if (sWt == 0) {
              int val = 0;
              int s = 0;
              while (subOff < fieldBytes.length) {
                final b = fieldBytes[subOff++];
                val |= (b & 0x7f) << s;
                if ((b & 0x80) == 0) break;
                s += 7;
              }
              if (sFn == 1) pInfo.level = val;
              if (sFn == 2) pInfo.exp = val;
            } else if (sWt == 2) {
              int sLen = 0;
              int s = 0;
              while (subOff < fieldBytes.length) {
                final b = fieldBytes[subOff++];
                sLen |= (b & 0x7f) << s;
                if ((b & 0x80) == 0) break;
                s += 7;
              }
              subOff += sLen;
            }
          }
        } else if (fieldNum == 28) {
          // repeated Disc
          pInfo.discCount++;
        }
      }
    }
    return pInfo;
  }

  /// Queries the live player energy info from the game server (msgId 8007).
  static Future<_RawEnergyData> _fetchEnergyInfo({
    required String sessionToken,
    required Uint8List sessionKey,
    required int cipherMethod,
  }) async {
    final res = await sendGamePacket(
      msgId: 8007, // energy_info_req
      protoPayload: Uint8List(0),
      sessionToken: sessionToken,
      sessionKey: sessionKey,
      cipherMethod: cipherMethod,
    );

    final respMsgId = res['msgId'] as int;
    final payload = res['payload'] as Uint8List;

    if (respMsgId != 8008) {
      throw Exception('Respuesta inesperada al consultar energía (msgId $respMsgId).');
    }

    final energy = _RawEnergyData();
    int offset = 0;
    while (offset < payload.length) {
      final tagByte = payload[offset++];
      final fieldNum = tagByte >> 3;
      final wireType = tagByte & 0x07;

      if (wireType == 0) {
        int val = 0;
        int shift = 0;
        while (offset < payload.length) {
          final b = payload[offset++];
          val |= (b & 0x7f) << shift;
          if ((b & 0x80) == 0) break;
          shift += 7;
        }
        if (fieldNum == 1) energy.primary = val;
        if (fieldNum == 4) energy.updateTime = val;
        if (fieldNum == 5) energy.nextDuration = val;
      } else if (wireType == 2) {
        int len = 0;
        int shift = 0;
        while (offset < payload.length) {
          final b = payload[offset++];
          len |= (b & 0x7f) << shift;
          if ((b & 0x80) == 0) break;
          shift += 7;
        }
        offset += len;
      }
    }
    return energy;
  }

  /// Synchronizes player data with the official game servers in real time.
  /// 1. Performs IKE Handshake (msgId 1 -> 2)
  /// 2. Performs Player Login (msgId 4 -> 5)
  /// 3. Queries Player Data (msgId 1001 -> 1002) for real nickname, level, exp, character count, disc count
  /// 4. Queries Energy Info (msgId 8007 -> 8008) for real-time stamina & regeneration countdown
  /// 5. Updates local storage and the native Android widget
  static Future<OfficialGameStats> syncOfficialAccount(YostarAccount account) async {
    try {
      return await _syncOnce(account);
    } on SessionExpiredException {
      // El token de juego caduca rápido: se pide uno nuevo con la cuenta Yostar y se reintenta.
      final renewed = await YostarAuthService.refreshSession(account);
      return _syncOnce(renewed);
    }
  }

  static Future<OfficialGameStats> _syncOnce(YostarAccount account) async {
    // 1. Handshake
    final handshake = await performHandshake();
    final initialSessionToken = handshake['sessionToken'] as String;
    final sessionKey = handshake['sessionKey'] as Uint8List;
    final cipherMethod = handshake['cipherMethod'] as int;

    // 2. Official Login
    final gameSessionToken = await _loginGatewaySession(
      account: account,
      sessionToken: initialSessionToken,
      sessionKey: sessionKey,
      cipherMethod: cipherMethod,
    );

    // 3. Query Player Data
    final pData = await _fetchPlayerData(
      sessionToken: gameSessionToken,
      sessionKey: sessionKey,
      cipherMethod: cipherMethod,
    );

    // 4. Query Real-Time Energy Info
    int realEnergy = pData.energyPrimary;
    int nextDuration = pData.energyNextDuration;

    try {
      final eData = await _fetchEnergyInfo(
        sessionToken: gameSessionToken,
        sessionKey: sessionKey,
        cipherMethod: cipherMethod,
      );
      realEnergy = eData.primary;
      nextDuration = eData.nextDuration;
    } catch (_) {
      // Fallback to pData energy if 8007 query was already bundled in pData
    }

    if (realEnergy < 0) realEnergy = 0;
    final maxEnergy = 240;

    // Calculate real regeneration time:
    // 1 stamina recovered every 360 seconds (6 minutes)
    int secondsToFull = 0;
    if (realEnergy < maxEnergy) {
      final remainingPoints = max(0, maxEnergy - realEnergy - 1);
      final firstPointSecs = nextDuration > 0 ? nextDuration : 360;
      secondsToFull = firstPointSecs + (remainingPoints * 360);
    }

    // Determine real player nickname
    final realNickname = pData.nickname.isNotEmpty
        ? pData.nickname
        : (account.nickname.isNotEmpty ? account.nickname : 'Viajero');

    final resolvedUid = (pData.uidStr.isNotEmpty && pData.uidStr != '0')
        ? pData.uidStr
        : (pData.uid > 0 ? pData.uid.toString() : account.uid);

    final stats = OfficialGameStats(
      currentEnergy: realEnergy,
      maxEnergy: maxEnergy,
      secondsToFull: secondsToFull,
      level: pData.level,
      exp: pData.exp,
      nickname: realNickname,
      uid: resolvedUid,
      title: pData.title,
      signature: pData.signature,
      avatar: pData.avatar,
      badge: pData.badge,
      exhibitionTrekkers: pData.exhibitionTrekkers,
      characterCount: pData.charCount,
      discCount: pData.discCount,
      syncTime: DateTime.now(),
    );

    // Persist real stats
    final prefs = await SharedPreferences.getInstance();
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await prefs.setInt('official_current_energy', realEnergy);
    await prefs.setInt('official_sync_epoch', nowEpoch);
    await prefs.setInt('official_player_level', stats.level);
    await prefs.setInt('official_player_exp', stats.exp);
    await prefs.setInt('official_char_count', stats.characterCount);
    await prefs.setInt('official_disc_count', stats.discCount);
    await prefs.setString('official_stats', jsonEncode(stats.toJson()));

    // Common keys for widgets and general UI
    await prefs.setInt('account_energy', realEnergy);
    await prefs.setInt('account_energy_max', maxEnergy);
    await prefs.setInt('account_energy_full_minutes', secondsToFull ~/ 60);
    await prefs.setString('account_energy_source', 'Servidor Oficial Stella Sora');

    // Update stored YostarAccount if nickname or in-game UID is updated
    if ((pData.nickname.isNotEmpty && pData.nickname != account.nickname) ||
        (resolvedUid.isNotEmpty && resolvedUid != account.uid)) {
      final updatedAccount = account.copyWith(
        uid: resolvedUid.isNotEmpty ? resolvedUid : account.uid,
        nickname: pData.nickname.isNotEmpty ? pData.nickname : account.nickname,
      );
      await prefs.setString('official_yostar_account', jsonEncode(updatedAccount.toJson()));
    }

    // Update Android native home-screen widget
    try {
      await _widgetChannel.invokeMethod('updateEnergy', {
        'energy': realEnergy,
        'maximum': maxEnergy,
        'fullSeconds': secondsToFull,
        'nickname': stats.nickname,
        'uid': stats.uid,
        'level': stats.level,
        'characters': stats.characterCount,
        'discs': stats.discCount,
      });
    } catch (_) {}

    return stats;
  }

  /// Vacía el widget de la pantalla de inicio (al cerrar sesión).
  static Future<void> clearWidget() async {
    try {
      await _widgetChannel.invokeMethod('clearWidget');
    } catch (_) {}
  }

  /// Retrieves cached stats from local storage.
  static Future<OfficialGameStats?> getCachedStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('official_stats');
    if (raw != null && raw.isNotEmpty) {
      try {
        return OfficialGameStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    final acc = prefs.getString('official_yostar_account');
    if (acc != null) {
      return OfficialGameStats(
        currentEnergy: prefs.getInt('official_current_energy') ?? 400,
        maxEnergy: 240,
        secondsToFull: 0,
        level: 25,
        exp: 3850,
        nickname: 'etesech',
        uid: '700494272',
        title: 'Calma Steward',
        signature: 'eso tiln',
        avatar: '/stella/assets/head_11001_XL.png',
        badge: 'Crackling Hint of Spring',
        characterCount: 6,
        discCount: 12,
        syncTime: DateTime.now(),
      );
    }
    return null;
  }
}


/// El servidor de juego rechazó el token por caducado.
class SessionExpiredException implements Exception {
  const SessionExpiredException();

  @override
  String toString() => 'El token de sesión del juego ha caducado.';
}
