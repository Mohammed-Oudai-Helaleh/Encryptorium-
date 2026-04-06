import 'package:encryptorium/aes_encryption_page.dart';
import 'package:encryptorium/aes_decryption_page.dart';
import 'package:encryptorium/des_decryption_page.dart';
import 'package:encryptorium/des_encryption_page.dart';
import 'package:encryptorium/triple_des_decryption_page.dart';
import 'package:encryptorium/triple_des_encryption_page.dart';
import 'package:flutter/material.dart';
import 'package:encryptorium/custom/my_outlined_button.dart';
import 'package:encryptorium/models/cipher.dart';

class CipherActionPage extends StatelessWidget {
  final CipherType cipherType;

  const CipherActionPage({Key? key, required this.cipherType}) : super(key: key);

  String get cipherName {
  switch (cipherType) {
  case CipherType.des:
  return 'DES';
  case CipherType.tripleDes:
  return 'Triple DES';
  case CipherType.aes:
  return 'AES';
  }}

  void _goToEncryptPage(BuildContext context) {
    Widget page;
    switch (cipherType) {
      case CipherType.des:
        page = DesEncryptPage(cipherType: cipherType);
        break;
      case CipherType.tripleDes:
        page = TripleDesEncryptPage(cipherType: cipherType);
        break;
      case CipherType.aes:
        page = AesEncryptPage(cipherType: cipherType);
        break;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  // Similarly for decryption (create the pages first)
  void _goToDecryptPage(BuildContext context) {
    Widget page;
    switch (cipherType) {
      case CipherType.des:
        page = DesDecryptPage(cipherType: cipherType);
        break;
      case CipherType.tripleDes:
        page = TripleDesDecryptPage(cipherType: cipherType);
        break;
      case CipherType.aes:
        page = AesDecryptPage(cipherType: cipherType);
        break;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$cipherName - Choose Action'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MyOutlinedButton(
              text: 'Encrypt',
              onPressed: () => _goToEncryptPage(context),
            ),
            const SizedBox(height: 20),
            MyOutlinedButton(
              text: 'Decrypt',
              onPressed: () => _goToDecryptPage(context),
            ),
          ],
        ),
      ),
    );
  }
}