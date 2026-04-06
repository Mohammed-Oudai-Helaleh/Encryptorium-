import 'dart:math';

const _printableAscii = ' !"#\$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~';

String generateRandomKey(int length) {
  final random = Random.secure();
  return String.fromCharCodes(
    Iterable.generate(
      length,
          (_) => _printableAscii.codeUnitAt(random.nextInt(_printableAscii.length)),
    ),
  );
}