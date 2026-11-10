import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

Uint8List encodeVarint(int value) {
  final res = <int>[];
  var n = value;
  while (n >= 0x80) {
    res.add((n & 0x7f) | 0x80);
    n >>= 7;
  }
  res.add(n);
  return Uint8List.fromList(res);
}

class EnergyData {
  int primary = 0;
  int nextDuration = 0;
  int updateTime = 0;

  static EnergyData parse(Uint8List data) {
    final result = EnergyData();
    int offset = 0;
    while (offset < data.length) {
      final tagByte = data[offset++];
      final fieldNum = tagByte >> 3;
      final wireType = tagByte & 0x07;

      if (wireType == 0) {
        int val = 0;
        int shift = 0;
        while (offset < data.length) {
          final b = data[offset++];
          val |= (b & 0x7f) << shift;
          if ((b & 0x80) == 0) break;
          shift += 7;
        }
        if (fieldNum == 1) result.primary = val;
        if (fieldNum == 4) result.updateTime = val;
        if (fieldNum == 5) result.nextDuration = val;
      } else if (wireType == 2) {
        int len = 0;
        int shift = 0;
        while (offset < data.length) {
          final b = data[offset++];
          len |= (b & 0x7f) << shift;
          if ((b & 0x80) == 0) break;
          shift += 7;
        }
        offset += len;
      }
    }
    return result;
  }
}

class PlayerDataInfo {
  String nickname = '';
  int uid = 0;
  int level = 1;
  int exp = 0;
  int charCount = 0;
  int discCount = 0;

  static PlayerDataInfo parse(Uint8List data) {
    final result = PlayerDataInfo();
    int offset = 0;
    while (offset < data.length) {
      // Decode multi-byte varint tag
      int tag = 0;
      int shift = 0;
      while (offset < data.length) {
        final b = data[offset++];
        tag |= (b & 0x7f) << shift;
        if ((b & 0x80) == 0) break;
        shift += 7;
      }
      final fieldNum = tag >> 3;
      final wireType = tag & 0x07;

      if (wireType == 0) {
        while (offset < data.length) {
          final b = data[offset++];
          if ((b & 0x80) == 0) break;
        }
      } else if (wireType == 2) {
        int len = 0;
        int lShift = 0;
        while (offset < data.length) {
          final b = data[offset++];
          len |= (b & 0x7f) << lShift;
          if ((b & 0x80) == 0) break;
          lShift += 7;
        }
        final fieldBytes = data.sublist(offset, offset + len);
        offset += len;

        if (fieldNum == 1) {
          // AccInfo
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
              if (sFn == 1) result.uid = val;
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
              if (sFn == 2) result.nickname = utf8.decode(strBytes, allowMalformed: true);
            }
          }
        } else if (fieldNum == 4) {
          // repeated Char
          result.charCount++;
        } else if (fieldNum == 8) {
          // WorldClassInfo
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
              if (sFn == 1) result.level = val;
              if (sFn == 2) result.exp = val;
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
          result.discCount++;
        }
      }
    }
    return result;
  }
}

void main() {
  test('Energy decode test', () {
    // primary = 142 (0x8e 0x01), nextDuration = 180 (0xb4 0x01), updateTime = 1731129600
    final bb = BytesBuilder();
    bb.addByte(0x08);
    bb.add(encodeVarint(142));
    bb.addByte(0x28);
    bb.add(encodeVarint(180));
    bb.addByte(0x20);
    bb.add(encodeVarint(1731129600));

    final energy = EnergyData.parse(bb.toBytes());
    expect(energy.primary, 142);
    expect(energy.nextDuration, 180);
    expect(energy.updateTime, 1731129600);
  });

  test('PlayerInfo decode test', () {
    final bb = BytesBuilder();

    // AccInfo (field 1): Id = 14296692857, NickName = "TyrantCommander"
    final accBb = BytesBuilder();
    accBb.addByte(0x08);
    accBb.add(encodeVarint(14296692857));
    accBb.addByte(0x12);
    final nickBytes = utf8.encode('TyrantCommander');
    accBb.add(encodeVarint(nickBytes.length));
    accBb.add(nickBytes);
    final accBytes = accBb.toBytes();

    bb.addByte(0x0a);
    bb.add(encodeVarint(accBytes.length));
    bb.add(accBytes);

    // Chars (field 4): 3 chars
    for (int i = 0; i < 3; i++) {
      bb.addByte(0x22);
      bb.addByte(0x02);
      bb.add([0x08, i + 1]);
    }

    // WorldClass (field 8): level = 45, exp = 8900
    final wcBb = BytesBuilder();
    wcBb.addByte(0x08);
    wcBb.add(encodeVarint(45));
    wcBb.addByte(0x10);
    wcBb.add(encodeVarint(8900));
    final wcBytes = wcBb.toBytes();

    bb.addByte(0x42);
    bb.add(encodeVarint(wcBytes.length));
    bb.add(wcBytes);

    // Discs (field 28): 5 discs
    final discTag = encodeVarint((28 << 3) | 2);
    for (int i = 0; i < 5; i++) {
      bb.add(discTag);
      bb.addByte(0x02);
      bb.add([0x08, i + 1]);
    }

    final pInfo = PlayerDataInfo.parse(bb.toBytes());
    expect(pInfo.nickname, 'TyrantCommander');
    expect(pInfo.uid, 14296692857);
    expect(pInfo.level, 45);
    expect(pInfo.exp, 8900);
    expect(pInfo.charCount, 3);
    expect(pInfo.discCount, 5);
  });
}
