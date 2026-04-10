import 'package:encryptorium/models/cipher.dart';
import 'package:flutter/material.dart';
import 'package:encryptorium/cipher_action_page.dart';
import 'package:encryptorium/custom/my_outlined_button.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),      // light theme
      darkTheme: ThemeData.dark(),   // dark theme
      themeMode: ThemeMode.system,   // follow system setting
      title: 'Encryptorium',
      home: const MyHomePage(title: 'Choose Cipher'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: .center,
          children: [
            MyOutlinedButton(
              text: 'DES',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CipherActionPage(cipherType: CipherType.des),
                  ),
                );
              },
            ),
            MyOutlinedButton(
              text: 'Triple DES',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CipherActionPage(cipherType: CipherType.tripleDes),
                  ),
                );
              },
            ),
            MyOutlinedButton(
              text: 'AES',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CipherActionPage(cipherType: CipherType.aes),
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }
}
