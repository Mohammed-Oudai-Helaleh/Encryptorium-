import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:encryptorium/models/cipher.dart';

class Encryption {
  final String plainText;
  final String? key1;
  final String? key2;
  final String? key3;
  final CipherType algorithm;

  //----------------------------------------------------
  // Private constructor (validates keys)
  //----------------------------------------------------
  Encryption._({
    required this.plainText,
    required this.algorithm,
    this.key1,
    this.key2,
    this.key3,
  });

  //----------------------------------------------------
  // Named factory constructors
  //----------------------------------------------------
  factory Encryption.des(String plainText, String key) {
    return Encryption._(
        plainText: plainText, algorithm: CipherType.des, key1: key);
  }

  factory Encryption.tripleDes(
      String plainText, String key1, String key2, String key3) {
    return Encryption._(
        plainText: plainText,
        algorithm: CipherType.tripleDes,
        key1: key1,
        key2: key2,
        key3: key3);
  }

  factory Encryption.aes(String plainText, String key) {
    return Encryption._(
        plainText: plainText, algorithm: CipherType.aes, key1: key);
  }

  String encrypt() {
    switch (algorithm) {
      case CipherType.des:
        return _desEncrypt(plainText, key1!);
      case CipherType.tripleDes:
        return _tripleDesEncrypt(plainText, key1!, key2!, key3!);
      case CipherType.aes:
        return _aesEncrypt(plainText, key1!);
    }
  }

  String decrypt(String cipherText) {
    switch (algorithm) {
      case CipherType.des:
        return _desDecrypt(cipherText, key1!);
      case CipherType.tripleDes:
        return _tripleDesDecrypt(cipherText, key1!, key2!, key3!);
      case CipherType.aes:
        return _aesDecrypt(cipherText, key1!);
    }
  }

  //----------------------------------------------------
  // DES Encryption/Decryption
  //----------------------------------------------------
  String _desEncrypt(String plainText, String key) {
    List<int> plainBytes = List.from(utf8.encode(plainText));
    int padding = 8 - (plainBytes.length % 8);
    if (padding == 0) padding = 8;
    plainBytes.addAll(List.filled(padding, padding));

    Uint8List asciiKey = Uint8List.fromList(key.codeUnits);
    String key56 = removeParityBits(asciiKey);
    String key56Binary = stringToBinary(key56);
    List<String> subkeys = desSubkeysGeneration(key56Binary);

    List<int> cipherBytes = [];
    for (int i = 0; i < plainBytes.length; i += 8) {
      List<int> blockBytes = plainBytes.sublist(i, i + 8);
      String blockBinary = bytesToBinary(blockBytes);
      String encryptedBinary = _desEncryptBlock(blockBinary, subkeys);
      cipherBytes.addAll(binaryToBytes(encryptedBinary));
    }

    return String.fromCharCodes(cipherBytes);
  }

  String _desDecrypt(String cipherText, String key) {
    List<int> cipherBytes = cipherText.codeUnits;

    Uint8List asciiKey = Uint8List.fromList(key.codeUnits);
    String key56 = removeParityBits(asciiKey);
    String key56Binary = stringToBinary(key56);
    List<String> subkeys = desSubkeysGeneration(key56Binary);
    List<String> reversedSubkeys = subkeys.reversed.toList();

    List<int> plainBytes = [];
    for (int i = 0; i < cipherBytes.length; i += 8) {
      List<int> blockBytes = cipherBytes.sublist(i, i + 8);
      String blockBinary = bytesToBinary(blockBytes);
      String decryptedBinary = _desEncryptBlock(blockBinary, reversedSubkeys);
      plainBytes.addAll(binaryToBytes(decryptedBinary));
    }

    int padding = plainBytes.last;
    if (padding < 1 || padding > 8) {
      throw Exception('Invalid padding');
    }
    for (int i = 0; i < padding; i++) {
      if (plainBytes[plainBytes.length - 1 - i] != padding) {
        throw Exception('Invalid padding');
      }
    }
    plainBytes.removeRange(plainBytes.length - padding, plainBytes.length);

    return utf8.decode(plainBytes);
  }

  //----------------------------------------------------
  // Triple DES
  //----------------------------------------------------
  String _tripleDesEncrypt(String plainText, String key1, String key2, String key3) {
    final cycle1 = _desEncrypt(plainText, key1);
    final cycle2 = _desDecryptRaw(cycle1, key2);
    return _desEncryptRaw(cycle2, key3);
  }

  String _tripleDesDecrypt(String cipherText, String key1, String key2, String key3) {
    final cycle1 = _desDecryptRaw(cipherText, key3);
    final cycle2 = _desEncryptRaw(cycle1, key2);
    return _desDecrypt(cycle2, key1);
  }

  String _desEncryptRaw(String inputBytesUtf16, String key) {
    List<int> plainBytes = inputBytesUtf16.codeUnits;
    Uint8List asciiKey = Uint8List.fromList(key.codeUnits);
    String key56 = removeParityBits(asciiKey);
    String key56Binary = stringToBinary(key56);
    List<String> subkeys = desSubkeysGeneration(key56Binary);

    List<int> cipherBytes = [];
    for (int i = 0; i < plainBytes.length; i += 8) {
      List<int> blockBytes = plainBytes.sublist(i, i + 8);
      String blockBinary = bytesToBinary(blockBytes);
      String encryptedBinary = _desEncryptBlock(blockBinary, subkeys);
      cipherBytes.addAll(binaryToBytes(encryptedBinary));
    }
    return String.fromCharCodes(cipherBytes);
  }

  String _desDecryptRaw(String inputBytesUtf16, String key) {
    List<int> cipherBytes = inputBytesUtf16.codeUnits;
    Uint8List asciiKey = Uint8List.fromList(key.codeUnits);
    String key56 = removeParityBits(asciiKey);
    String key56Binary = stringToBinary(key56);
    List<String> subkeys = desSubkeysGeneration(key56Binary);
    List<String> reversedSubkeys = subkeys.reversed.toList();

    List<int> plainBytes = [];
    for (int i = 0; i < cipherBytes.length; i += 8) {
      List<int> blockBytes = cipherBytes.sublist(i, i + 8);
      String blockBinary = bytesToBinary(blockBytes);
      String decryptedBinary = _desEncryptBlock(blockBinary, reversedSubkeys);
      plainBytes.addAll(binaryToBytes(decryptedBinary));
    }
    return String.fromCharCodes(plainBytes);
  }

  //----------------------------------------------------
  // DES Helper Functions
  //----------------------------------------------------
  String stringToBinary(String text) {
    String binaryString = "";
    for (int i = 0; i < text.length; i++) {
      int codeUnit = text.codeUnitAt(i);
      String binary = codeUnit.toRadixString(2);
      String paddingBinary = binary.padLeft(8, '0');
      binaryString = binaryString + paddingBinary;
    }
    return binaryString;
  }

  String bytesToBinary(List<int> bytes) {
    StringBuffer sb = StringBuffer();
    for (int b in bytes) {
      sb.write(b.toRadixString(2).padLeft(8, '0'));
    }
    return sb.toString();
  }

  List<int> binaryToBytes(String binary) {
    assert(binary.length % 8 == 0);
    List<int> bytes = [];
    for (int i = 0; i < binary.length; i += 8) {
      String byteStr = binary.substring(i, i + 8);
      bytes.add(int.parse(byteStr, radix: 2));
    }
    return bytes;
  }

  List<String> splitIntoCodeUnitBlocks(String text, {int blockSizeInCodeUnits = 4}) {
    List<int> codeUnits = List.from(text.codeUnits);
    int remainder = codeUnits.length % blockSizeInCodeUnits;
    int paddingLength = remainder == 0 ? blockSizeInCodeUnits : blockSizeInCodeUnits - remainder;
    codeUnits.addAll(List.filled(paddingLength, paddingLength));
    List<String> blocks = [];
    for (int i = 0; i < codeUnits.length; i += blockSizeInCodeUnits) {
      blocks.add(String.fromCharCodes(codeUnits.sublist(i, i + blockSizeInCodeUnits)));
    }
    return blocks;
  }

  //----------------------------------------------------
  // DES permutations
  //----------------------------------------------------
  String compressionPermutation(String key56) {
    const pc2Table = [
      14, 17, 11, 24, 1, 5, 3, 28, 15, 6, 21, 10, 23, 19, 12, 4,
      26, 8, 16, 7, 27, 20, 13, 2, 41, 52, 31, 37, 47, 55, 30, 40,
      51, 45, 33, 48, 44, 49, 39, 56, 34, 53, 46, 42, 50, 36, 29, 32
    ];
    final output = StringBuffer();
    for (int i = 0; i < pc2Table.length; i++) {
      int sourceIndex = pc2Table[i] - 1;
      output.write(key56[sourceIndex]);
    }
    return output.toString();
  }

  String expansionPermutation(String string32) {
    const eTable = [
      32, 1, 2, 3, 4, 5, 4, 5, 6, 7, 8, 9, 8, 9, 10, 11,
      12, 13, 12, 13, 14, 15, 16, 17, 16, 17, 18, 19, 20, 21,
      20, 21, 22, 23, 24, 25, 24, 25, 26, 27, 28, 29, 28, 29, 30, 31, 32, 1
    ];
    final output = StringBuffer();
    for (int i = 0; i < eTable.length; i++) {
      int sourceBit = eTable[i];
      output.write(string32[sourceBit - 1]);
    }
    return output.toString();
  }

  String initialPermutation(String input64) {
    const ipTable = [
      58, 50, 42, 34, 26, 18, 10, 2, 60, 52, 44, 36, 28, 20, 12, 4,
      62, 54, 46, 38, 30, 22, 14, 6, 64, 56, 48, 40, 32, 24, 16, 8,
      57, 49, 41, 33, 25, 17, 9, 1, 59, 51, 43, 35, 27, 19, 11, 3,
      61, 53, 45, 37, 29, 21, 13, 5, 63, 55, 47, 39, 31, 23, 15, 7
    ];
    final output = StringBuffer();
    for (int i = 0; i < ipTable.length; i++) {
      int bitIndex = ipTable[i] - 1;
      output.write(input64[bitIndex]);
    }
    return output.toString();
  }

  String permutation(String input32) {
    const pBox = [
      16, 7, 20, 21, 29, 12, 28, 17, 1, 15, 23, 26, 5, 18, 31, 10,
      2, 8, 24, 14, 32, 27, 3, 9, 19, 13, 30, 6, 22, 11, 4, 25
    ];
    final output = StringBuffer();
    for (int i = 0; i < pBox.length; i++) {
      int bitIndex = pBox[i] - 1;
      output.write(input32[bitIndex]);
    }
    return output.toString();
  }

  String finalPermutation(String input64) {
    const ipInv = [
      40, 8, 48, 16, 56, 24, 64, 32, 39, 7, 47, 15, 55, 23, 63, 31,
      38, 6, 46, 14, 54, 22, 62, 30, 37, 5, 45, 13, 53, 21, 61, 29,
      36, 4, 44, 12, 52, 20, 60, 28, 35, 3, 43, 11, 51, 19, 59, 27,
      34, 2, 42, 10, 50, 18, 58, 26, 33, 1, 41, 9, 49, 17, 57, 25
    ];
    final output = StringBuffer();
    for (int i = 0; i < ipInv.length; i++) {
      int bitIndex = ipInv[i] - 1;
      output.write(input64[bitIndex]);
    }
    return output.toString();
  }

  //----------------------------------------------------
  // DES key preparation
  //----------------------------------------------------
  String removeParityBits(List<int> bytes) {
    List<int> sevenBitBlocks = [];
    for (int b in bytes) {
      sevenBitBlocks.add(b >> 1);
    }
    List<int> resultBytes = [];
    for (int i = 0; i < 7; i++) {
      int high = sevenBitBlocks[i] << 1;
      int low = (sevenBitBlocks[i + 1] >> 6) & 0x01;
      resultBytes.add(high | low);
    }
    return String.fromCharCodes(resultBytes);
  }

  List<String> desSubkeysGeneration(String key) {
    List<String> subkeys = <String>[];
    String c = key.substring(0, 28);
    String d = key.substring(28);
    List<int> shifts = [1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1];
    for (int round = 0; round < shifts.length; round++) {
      c = circularLeftShift(c, shifts[round]);
      d = circularLeftShift(d, shifts[round]);
      final combined = c + d;
      final subkey = compressionPermutation(combined);
      subkeys.add(subkey);
    }
    return subkeys;
  }

  String circularLeftShift(String key28, int shiftAmount) {
    return key28.substring(shiftAmount) + key28.substring(0, shiftAmount);
  }

  //----------------------------------------------------
  // DES encryption block
  //----------------------------------------------------
  String _desEncryptBlock(String block, List<String> subkeys) {
    String blockAfterIP = initialPermutation(block);
    String left = blockAfterIP.substring(0, 32);
    String right = blockAfterIP.substring(32);

    for (int i = 0; i < 16; i++) {
      String newRight = xorBinaryStrings(left, feistelFunction(right, subkeys[i]));
      left = right;
      right = newRight;
    }

    String preOutput = right + left;
    return finalPermutation(preOutput);
  }

  String xorBinaryStrings(String a, String b) {
    assert(a.length == b.length);
    final result = StringBuffer();
    for (int i = 0; i < a.length; i++) {
      result.write(a[i] == b[i] ? '0' : '1');
    }
    return result.toString();
  }

  String feistelFunction(String right32, String subkey48) {
    String expanded = expansionPermutation(right32);
    String xored = xorBinaryStrings(expanded, subkey48);
    String substituted = sBoxSubstitution(xored);
    return permutation(substituted);
  }

  String sBoxSubstitution(String xored) {
    List<String> chunks = [];
    for (int i = 0; i < xored.length; i += 6) {
      chunks.add(xored.substring(i, i + 6));
    }
    final output32Bits = StringBuffer();
    const List<List<List<int>>> sBoxes = [
      // S1
      [
        [14, 4, 13, 1, 2, 15, 11, 8, 3, 10, 6, 12, 5, 9, 0, 7],
        [0, 15, 7, 4, 14, 2, 13, 1, 10, 6, 12, 11, 9, 5, 3, 8],
        [4, 1, 14, 8, 13, 6, 2, 11, 15, 12, 9, 7, 3, 10, 5, 0],
        [15, 12, 8, 2, 4, 9, 1, 7, 5, 11, 3, 14, 10, 0, 6, 13]
      ],
      // S2
      [
        [15, 1, 8, 14, 6, 11, 3, 4, 9, 7, 2, 13, 12, 0, 5, 10],
        [3, 13, 4, 7, 15, 2, 8, 14, 12, 0, 1, 10, 6, 9, 11, 5],
        [0, 14, 7, 11, 10, 4, 13, 1, 5, 8, 12, 6, 9, 3, 2, 15],
        [13, 8, 10, 1, 3, 15, 4, 2, 11, 6, 7, 12, 0, 5, 14, 9]
      ],
      // S3
      [
        [10, 0, 9, 14, 6, 3, 15, 5, 1, 13, 12, 7, 11, 4, 2, 8],
        [13, 7, 0, 9, 3, 4, 6, 10, 2, 8, 5, 14, 12, 11, 15, 1],
        [13, 6, 4, 9, 8, 15, 3, 0, 11, 1, 2, 12, 5, 10, 14, 7],
        [1, 10, 13, 0, 6, 9, 8, 7, 4, 15, 14, 3, 11, 5, 2, 12]
      ],
      // S4
      [
        [7, 13, 14, 3, 0, 6, 9, 10, 1, 2, 8, 5, 11, 12, 4, 15],
        [13, 8, 11, 5, 6, 15, 0, 3, 4, 7, 2, 12, 1, 10, 14, 9],
        [10, 6, 9, 0, 12, 11, 7, 13, 15, 1, 3, 14, 5, 2, 8, 4],
        [3, 15, 0, 6, 10, 1, 13, 8, 9, 4, 5, 11, 12, 7, 2, 14]
      ],
      // S5
      [
        [2, 12, 4, 1, 7, 10, 11, 6, 8, 5, 3, 15, 13, 0, 14, 9],
        [14, 11, 2, 12, 4, 7, 13, 1, 5, 0, 15, 10, 3, 9, 8, 6],
        [4, 2, 1, 11, 10, 13, 7, 8, 15, 9, 12, 5, 6, 3, 0, 14],
        [11, 8, 12, 7, 1, 14, 2, 13, 6, 15, 0, 9, 10, 4, 5, 3]
      ],
      // S6
      [
        [12, 1, 10, 15, 9, 2, 6, 8, 0, 13, 3, 4, 14, 7, 5, 11],
        [10, 15, 4, 2, 7, 12, 9, 5, 6, 1, 13, 14, 0, 11, 3, 8],
        [9, 14, 15, 5, 2, 8, 12, 3, 7, 0, 4, 10, 1, 13, 11, 6],
        [4, 3, 2, 12, 9, 5, 15, 10, 11, 14, 1, 7, 6, 0, 8, 13]
      ],
      // S7
      [
        [4, 11, 2, 14, 15, 0, 8, 13, 3, 12, 9, 7, 5, 10, 6, 1],
        [13, 0, 11, 7, 4, 9, 1, 10, 14, 3, 5, 12, 2, 15, 8, 6],
        [1, 4, 11, 13, 12, 3, 7, 14, 10, 15, 6, 8, 0, 5, 9, 2],
        [6, 11, 13, 8, 1, 4, 10, 7, 9, 5, 0, 15, 14, 2, 3, 12]
      ],
      // S8
      [
        [13, 2, 8, 4, 6, 15, 11, 1, 10, 9, 3, 14, 5, 0, 12, 7],
        [1, 15, 13, 8, 10, 3, 7, 4, 12, 5, 6, 11, 0, 14, 9, 2],
        [7, 11, 4, 1, 9, 12, 14, 2, 0, 6, 10, 13, 15, 3, 5, 8],
        [2, 1, 14, 7, 4, 10, 8, 13, 15, 12, 9, 0, 3, 5, 6, 11]
      ]
    ];

    for (int i = 0; i < 8; i++) {
      String chunk6Bit = chunks[i];
      int row = int.parse("${chunk6Bit[0]}${chunk6Bit[5]}", radix: 2);
      int col = int.parse(chunk6Bit.substring(1, 5), radix: 2);
      int value = sBoxes[i][row][col];
      output32Bits.write(value.toRadixString(2).padLeft(4, '0'));
    }
    return output32Bits.toString();
  }

  //----------------------------------------------------
  // AES
  //----------------------------------------------------
  static const List<int> sBox = [
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16,
  ];

  static const List<int> invSBox = [
    0x52, 0x09, 0x6a, 0xd5, 0x30, 0x36, 0xa5, 0x38, 0xbf, 0x40, 0xa3, 0x9e, 0x81, 0xf3, 0xd7, 0xfb,
    0x7c, 0xe3, 0x39, 0x82, 0x9b, 0x2f, 0xff, 0x87, 0x34, 0x8e, 0x43, 0x44, 0xc4, 0xde, 0xe9, 0xcb,
    0x54, 0x7b, 0x94, 0x32, 0xa6, 0xc2, 0x23, 0x3d, 0xee, 0x4c, 0x95, 0x0b, 0x42, 0xfa, 0xc3, 0x4e,
    0x08, 0x2e, 0xa1, 0x66, 0x28, 0xd9, 0x24, 0xb2, 0x76, 0x5b, 0xa2, 0x49, 0x6d, 0x8b, 0xd1, 0x25,
    0x72, 0xf8, 0xf6, 0x64, 0x86, 0x68, 0x98, 0x16, 0xd4, 0xa4, 0x5c, 0xcc, 0x5d, 0x65, 0xb6, 0x92,
    0x6c, 0x70, 0x48, 0x50, 0xfd, 0xed, 0xb9, 0xda, 0x5e, 0x15, 0x46, 0x57, 0xa7, 0x8d, 0x9d, 0x84,
    0x90, 0xd8, 0xab, 0x00, 0x8c, 0xbc, 0xd3, 0x0a, 0xf7, 0xe4, 0x58, 0x05, 0xb8, 0xb3, 0x45, 0x06,
    0xd0, 0x2c, 0x1e, 0x8f, 0xca, 0x3f, 0x0f, 0x02, 0xc1, 0xaf, 0xbd, 0x03, 0x01, 0x13, 0x8a, 0x6b,
    0x3a, 0x91, 0x11, 0x41, 0x4f, 0x67, 0xdc, 0xea, 0x97, 0xf2, 0xcf, 0xce, 0xf0, 0xb4, 0xe6, 0x73,
    0x96, 0xac, 0x74, 0x22, 0xe7, 0xad, 0x35, 0x85, 0xe2, 0xf9, 0x37, 0xe8, 0x1c, 0x75, 0xdf, 0x6e,
    0x47, 0xf1, 0x1a, 0x71, 0x1d, 0x29, 0xc5, 0x89, 0x6f, 0xb7, 0x62, 0x0e, 0xaa, 0x18, 0xbe, 0x1b,
    0xfc, 0x56, 0x3e, 0x4b, 0xc6, 0xd2, 0x79, 0x20, 0x9a, 0xdb, 0xc0, 0xfe, 0x78, 0xcd, 0x5a, 0xf4,
    0x1f, 0xdd, 0xa8, 0x33, 0x88, 0x07, 0xc7, 0x31, 0xb1, 0x12, 0x10, 0x59, 0x27, 0x80, 0xec, 0x5f,
    0x60, 0x51, 0x7f, 0xa9, 0x19, 0xb5, 0x4a, 0x0d, 0x2d, 0xe5, 0x7a, 0x9f, 0x93, 0xc9, 0x9c, 0xef,
    0xa0, 0xe0, 0x3b, 0x4d, 0xae, 0x2a, 0xf5, 0xb0, 0xc8, 0xeb, 0xbb, 0x3c, 0x83, 0x53, 0x99, 0x61,
    0x17, 0x2b, 0x04, 0x7e, 0xba, 0x77, 0xd6, 0x26, 0xe1, 0x69, 0x14, 0x63, 0x55, 0x21, 0x0c, 0x7d,
  ];

  static const List<int> rcon = [
    0x01000000, 0x02000000, 0x04000000, 0x08000000, 0x10000000,
    0x20000000, 0x40000000, 0x80000000, 0x1B000000, 0x36000000,
    0x6C000000, 0xD8000000, 0xAB000000, 0x4D000000, 0x9A000000,
  ];

  String _aesEncrypt(String plainText, String key) {
    Uint8List keyBytes = Uint8List.fromList(key.codeUnits);
    if (keyBytes.length != 16 && keyBytes.length != 24 && keyBytes.length != 32) {
      throw Exception('AES key must be 16, 24, or 32 bytes (got ${keyBytes.length})');
    }

    List<int> expandedKey = _keyExpansion(keyBytes);
    int nR = (keyBytes.length ~/ 4) + 6;

    List<int> plainBytes = List.from(utf8.encode(plainText));
    int blockSize = 16;
    int padding = blockSize - (plainBytes.length % blockSize);
    if (padding == 0) padding = blockSize;
    plainBytes.addAll(List.filled(padding, padding));

    List<int> cipherBytes = [];
    for (int i = 0; i < plainBytes.length; i += blockSize) {
      Uint8List block = Uint8List.fromList(plainBytes.sublist(i, i + blockSize));
      Uint8List encryptedBlock = _aesEncryptBlock(block, expandedKey, nR);
      cipherBytes.addAll(encryptedBlock);
    }

    return base64.encode(cipherBytes);
  }

  String _aesDecrypt(String cipherText, String key) {
    List<int> cipherBytes = base64.decode(cipherText);

    Uint8List keyBytes = Uint8List.fromList(key.codeUnits);
    if (keyBytes.length != 16 && keyBytes.length != 24 && keyBytes.length != 32) {
      throw Exception('AES key must be 16, 24, or 32 bytes (got ${keyBytes.length})');
    }
    List<int> expandedKey = _keyExpansion(keyBytes);
    int nR = (keyBytes.length ~/ 4) + 6;

    List<int> plainBytes = [];
    int blockSize = 16;
    for (int i = 0; i < cipherBytes.length; i += blockSize) {
      Uint8List block = Uint8List.fromList(cipherBytes.sublist(i, i + blockSize));
      Uint8List decryptedBlock = _aesDecryptBlock(block, expandedKey, nR);
      plainBytes.addAll(decryptedBlock);
    }

    int padding = plainBytes.last;
    if (padding < 1 || padding > blockSize) {
      throw Exception('Invalid padding');
    }
    for (int i = 0; i < padding; i++) {
      if (plainBytes[plainBytes.length - 1 - i] != padding) {
        throw Exception('Invalid padding');
      }
    }
    plainBytes.removeRange(plainBytes.length - padding, plainBytes.length);

    return utf8.decode(plainBytes);
  }

  Uint8List _aesEncryptBlock(Uint8List block, List<int> expandedKey, int nR) {
    List<List<int>> state = List.generate(4, (i) => List.filled(4, 0));
    for (int col = 0; col < 4; col++) {
      for (int row = 0; row < 4; row++) {
        state[row][col] = block[4 * col + row];
      }
    }

    _addRoundKey(state, expandedKey.sublist(0, 4));

    for (int round = 1; round < nR; round++) {
      _subBytes(state);
      _shiftRows(state);
      _mixColumns(state);
      _addRoundKey(state, expandedKey.sublist(4 * round, 4 * (round + 1)));
    }

    _subBytes(state);
    _shiftRows(state);
    _addRoundKey(state, expandedKey.sublist(4 * nR, 4 * (nR + 1)));

    Uint8List result = Uint8List(16);
    for (int col = 0; col < 4; col++) {
      for (int row = 0; row < 4; row++) {
        result[4 * col + row] = state[row][col];
      }
    }
    return result;
  }

  Uint8List _aesDecryptBlock(Uint8List block, List<int> expandedKey, int nR) {
    List<List<int>> state = List.generate(4, (i) => List.filled(4, 0));
    for (int col = 0; col < 4; col++) {
      for (int row = 0; row < 4; row++) {
        state[row][col] = block[4 * col + row];
      }
    }

    _addRoundKey(state, expandedKey.sublist(4 * nR, 4 * (nR + 1)));

    for (int round = nR - 1; round > 0; round--) {
      _invShiftRows(state);
      _invSubBytes(state);
      _addRoundKey(state, expandedKey.sublist(4 * round, 4 * (round + 1)));
      _invMixColumns(state);
    }

    _invShiftRows(state);
    _invSubBytes(state);
    _addRoundKey(state, expandedKey.sublist(0, 4));

    Uint8List result = Uint8List(16);
    for (int col = 0; col < 4; col++) {
      for (int row = 0; row < 4; row++) {
        result[4 * col + row] = state[row][col];
      }
    }
    return result;
  }

  List<int> _keyExpansion(Uint8List key) {
    int keyLen = key.length;
    int nK = keyLen ~/ 4;
    int nR = nK + 6;
    int totalWords = 4 * (nR + 1);
    List<int> w = List.filled(totalWords, 0);

    for (int i = 0; i < nK; i++) {
      w[i] = (key[4 * i] << 24) |
      (key[4 * i + 1] << 16) |
      (key[4 * i + 2] << 8) |
      key[4 * i + 3];
    }

    for (int i = nK; i < totalWords; i++) {
      int temp = w[i - 1];
      if (i % nK == 0) {
        temp = _subWord(_rotWord(temp)) ^ rcon[(i ~/ nK) - 1];
      } else if (nK > 6 && i % nK == 4) {
        temp = _subWord(temp);
      }
      w[i] = w[i - nK] ^ temp;
    }
    return w;
  }

  int _rotWord(int word) {
    return ((word << 8) & 0xFFFFFF00) | (word >> 24);
  }

  int _subWord(int word) {
    int b0 = sBox[(word >> 24) & 0xFF];
    int b1 = sBox[(word >> 16) & 0xFF];
    int b2 = sBox[(word >> 8) & 0xFF];
    int b3 = sBox[word & 0xFF];
    return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3;
  }

  int xTime(int x) {
    return ((x << 1) ^ ((x & 0x80) != 0 ? 0x1B : 0)) & 0xFF;
  }

  int mul(int a, int b) {
    int result = 0;
    for (int i = 0; i < 8; i++) {
      if ((b & 0x01) != 0) result ^= a;
      a = xTime(a);
      b >>= 1;
    }
    return result;
  }

  void _subBytes(List<List<int>> state) {
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        state[i][j] = sBox[state[i][j]];
      }
    }
  }

  void _invSubBytes(List<List<int>> state) {
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        state[i][j] = invSBox[state[i][j]];
      }
    }
  }

  void _shiftRows(List<List<int>> state) {
    List<int> temp = List.from(state[1]);
    for (int i = 0; i < 4; i++) {
      state[1][i] = temp[(i + 1) % 4];
    }
    temp = List.from(state[2]);
    for (int i = 0; i < 4; i++) {
      state[2][i] = temp[(i + 2) % 4];
    }
    temp = List.from(state[3]);
    for (int i = 0; i < 4; i++) {
      state[3][i] = temp[(i + 3) % 4];
    }
  }

  void _invShiftRows(List<List<int>> state) {
    List<int> temp = List.from(state[1]);
    for (int i = 0; i < 4; i++) {
      state[1][i] = temp[(i + 3) % 4];
    }
    temp = List.from(state[2]);
    for (int i = 0; i < 4; i++) {
      state[2][i] = temp[(i + 2) % 4];
    }
    temp = List.from(state[3]);
    for (int i = 0; i < 4; i++) {
      state[3][i] = temp[(i + 1) % 4];
    }
  }

  void _mixColumns(List<List<int>> state) {
    for (int c = 0; c < 4; c++) {
      int a0 = state[0][c];
      int a1 = state[1][c];
      int a2 = state[2][c];
      int a3 = state[3][c];
      state[0][c] = mul(0x02, a0) ^ mul(0x03, a1) ^ a2 ^ a3;
      state[1][c] = a0 ^ mul(0x02, a1) ^ mul(0x03, a2) ^ a3;
      state[2][c] = a0 ^ a1 ^ mul(0x02, a2) ^ mul(0x03, a3);
      state[3][c] = mul(0x03, a0) ^ a1 ^ a2 ^ mul(0x02, a3);
    }
  }

  void _invMixColumns(List<List<int>> state) {
    for (int c = 0; c < 4; c++) {
      int a0 = state[0][c];
      int a1 = state[1][c];
      int a2 = state[2][c];
      int a3 = state[3][c];
      state[0][c] = mul(0x0e, a0) ^ mul(0x0b, a1) ^ mul(0x0d, a2) ^ mul(0x09, a3);
      state[1][c] = mul(0x09, a0) ^ mul(0x0e, a1) ^ mul(0x0b, a2) ^ mul(0x0d, a3);
      state[2][c] = mul(0x0d, a0) ^ mul(0x09, a1) ^ mul(0x0e, a2) ^ mul(0x0b, a3);
      state[3][c] = mul(0x0b, a0) ^ mul(0x0d, a1) ^ mul(0x09, a2) ^ mul(0x0e, a3);
    }
  }

  void _addRoundKey(List<List<int>> state, List<int> roundKeyWords) {
    for (int col = 0; col < 4; col++) {
      int word = roundKeyWords[col];
      state[0][col] = state[0][col] ^ ((word >> 24) & 0xFF);
      state[1][col] = state[1][col] ^ ((word >> 16) & 0xFF);
      state[2][col] = state[2][col] ^ ((word >> 8) & 0xFF);
      state[3][col] = state[3][col] ^ (word & 0xFF);
    }
  }

  //----------------------------------------------------
  // File Encryption - Platform-Aware
  //----------------------------------------------------

  static Future<void> createEncryptedFileStub(
      String inputPath,
      String outputPath, {
        required CipherType algorithm,
        String? key1,
        String? key2,
        String? key3,
      }) async {
    // This method is for native platforms only
    await encryptFile(
      inputPath,
      outputPath,
      algorithm: algorithm,
      key1: key1,
      key2: key2,
      key3: key3,
    );
  }

  static Future<void> encryptFile(
      String inputPath,
      String outputPath, {
        required CipherType algorithm,
        String? key1,
        String? key2,
        String? key3,
      }) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw Exception('Input file does not exist: $inputPath');
    }

    final bytes = await inputFile.readAsBytes();
    final base64Plain = base64.encode(bytes);

    Encryption encryption;
    switch (algorithm) {
      case CipherType.des:
        encryption = Encryption.des(base64Plain, key1!);
        break;
      case CipherType.tripleDes:
        encryption = Encryption.tripleDes(base64Plain, key1!, key2!, key3!);
        break;
      case CipherType.aes:
        encryption = Encryption.aes(base64Plain, key1!);
        break;
    }

    final cipherText = encryption.encrypt();
    final outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(cipherText, encoding: utf8);

    print('✅ File encrypted to: ${outputFile.absolute.path}');
  }

  static Future<void> decryptFile(
      String inputPath,
      String outputPath, {
        required CipherType algorithm,
        String? key1,
        String? key2,
        String? key3,
      }) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw Exception('Input file does not exist: $inputPath');
    }

    final cipherText = await inputFile.readAsString(encoding: utf8);

    Encryption encryption;
    switch (algorithm) {
      case CipherType.des:
        encryption = Encryption.des('', key1!);
        break;
      case CipherType.tripleDes:
        encryption = Encryption.tripleDes('', key1!, key2!, key3!);
        break;
      case CipherType.aes:
        encryption = Encryption.aes('', key1!);
        break;
    }

    final base64Plain = encryption.decrypt(cipherText);
    final bytes = base64.decode(base64Plain);
    final outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(bytes);

    print('✅ File decrypted to: ${outputFile.absolute.path}');
  }
}