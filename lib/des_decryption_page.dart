import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:encryptorium/custom/my_outlined_button.dart';
import 'package:encryptorium/custom/my_text_field.dart';
import 'package:encryptorium/custom/random_key_button.dart';
import 'package:encryptorium/custom/copy_button.dart';
import 'package:encryptorium/custom/error_text.dart';
import 'package:encryptorium/custom/clear_all_button.dart';
import 'package:encryptorium/custom/file_picker_button.dart';
import 'package:encryptorium/custom/output_field.dart';
import 'package:encryptorium/models/cipher.dart';
import 'package:encryptorium/backend/encryption.dart';
import 'package:encryptorium/utils/file_utils.dart';
import 'package:encryptorium/utils/key_generator.dart';
import 'package:universal_html/html.dart' as html;

class DesDecryptPage extends StatefulWidget {
  final CipherType cipherType;

  const DesDecryptPage({Key? key, required this.cipherType}) : super(key: key);

  @override
  State<DesDecryptPage> createState() => _DesDecryptPageState();
}

class _DesDecryptPageState extends State<DesDecryptPage> {
  final TextEditingController _ciphertextController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();

  static const int _keyLength = 8;

  bool _isDecrypting = false;
  String? _ciphertextError;
  String? _keyError;
  bool _submitted = false;

  // Native file handling
  File? _selectedCipherFile;

  // Web file handling
  Uint8List? _selectedCipherFileBytes;
  String? _selectedCipherFileName;

  void _setRandomKey() {
    _keyController.text = generateRandomKey(_keyLength);
    _validateAll();
  }

  Future<void> _pickEncryptedFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true, // Critical for web: loads file bytes into memory
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        setState(() {
          // Reset all file-related state
          _selectedCipherFile = null;
          _selectedCipherFileBytes = null;
          _selectedCipherFileName = null;

          if (kIsWeb) {
            // WEB: Use bytes and name from memory
            if (file.bytes != null) {
              _selectedCipherFileBytes = file.bytes;
              _selectedCipherFileName = file.name;
              _ciphertextController.text = file.name;
            }
          } else {
            // NATIVE (Windows/Android): Use file path
            if (file.path != null) {
              _selectedCipherFile = File(file.path!);
              _selectedCipherFileName = file.name;
              _ciphertextController.text = file.name ?? 'Unknown';
            }
          }

          _submitted = false;
          _ciphertextError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick file: $e')),
        );
      }
    }
  }

  void _validateAll() {
    String? ciphertextError;
    String? keyError;

    if (_selectedCipherFile == null &&
        _selectedCipherFileBytes == null &&
        _ciphertextController.text.isEmpty) {
      ciphertextError = 'Please enter ciphertext or select a file';
    }

    if (_keyController.text.length != _keyLength) {
      keyError = 'Key must be exactly $_keyLength characters';
    }

    setState(() {
      if (_submitted) {
        _ciphertextError = ciphertextError;
        _keyError = keyError;
      } else {
        _ciphertextError = null;
        _keyError = null;
      }
    });
  }

  Future<void> _decrypt() async {
    _submitted = true;
    _validateAll();

    if (_ciphertextError != null || _keyError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix errors before decrypting')),
      );
      return;
    }

    _outputController.clear();
    setState(() => _isDecrypting = true);

    try {
      if (kIsWeb) {
        await _decryptWeb();
      } else {
        await _decryptNative();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Decryption failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDecrypting = false);
      }
    }
  }

  Future<void> _decryptNative() async {
    final key = _keyController.text;

    if (_selectedCipherFile != null) {
      // ========== FILE MODE - Native platforms ==========
      final cipherFile = _selectedCipherFile!;
      final cipherText = await cipherFile.readAsString(encoding: utf8);

      final encryption = Encryption.des('', key);
      final base64Plain = encryption.decrypt(cipherText);
      final originalBytes = base64.decode(base64Plain);

      String originalFileName = _selectedCipherFileName ?? 'decrypted_file';
      if (originalFileName.endsWith('.enc')) {
        originalFileName = originalFileName.substring(0, originalFileName.length - 4);
      } else {
        originalFileName = 'decrypted_$originalFileName';
      }

      final encryptoriumDir = await getEncryptoriumDirectory();
      final outputPath = '${encryptoriumDir.path}/$originalFileName';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(originalBytes);

      _outputController.text = outputPath;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ File decrypted to: $outputPath')),
        );
      }
    } else {
      // ========== TEXT MODE - All platforms ==========
      final ciphertext = _ciphertextController.text;
      final encryption = Encryption.des('', key);
      final plaintext = encryption.decrypt(ciphertext);
      _outputController.text = plaintext;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Decryption completed successfully!')),
        );
      }
    }
  }

  Future<void> _decryptWeb() async {
    final key = _keyController.text;

    if (_selectedCipherFileBytes != null && _selectedCipherFileName != null) {
      // ========== FILE MODE - Web ==========
      final cipherText = utf8.decode(_selectedCipherFileBytes!);

      final encryption = Encryption.des('', key);
      final base64Plain = encryption.decrypt(cipherText);
      final originalBytes = base64.decode(base64Plain);

      String originalFileName = _selectedCipherFileName!;
      if (originalFileName.endsWith('.enc')) {
        originalFileName = originalFileName.substring(0, originalFileName.length - 4);
      } else {
        originalFileName = 'decrypted_$originalFileName';
      }

      // Trigger browser download for decrypted file
      await _downloadDecryptedFileWeb(originalFileName, originalBytes);

      _outputController.text = '📥 Downloaded: $originalFileName';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ File decrypted and downloaded: $originalFileName')),
        );
      }
    } else {
      // ========== TEXT MODE - All platforms (same as native) ==========
      final ciphertext = _ciphertextController.text;
      final encryption = Encryption.des('', key);
      final plaintext = encryption.decrypt(ciphertext);
      _outputController.text = plaintext;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Decryption completed successfully!')),
        );
      }
    }
  }

  /// Triggers a file download in the browser for binary data
  Future<void> _downloadDecryptedFileWeb(String fileName, List<int> bytes) async {
    if (!kIsWeb) return;

    final base64Data = base64.encode(bytes);
    final dataUri = 'data:application/octet-stream;base64,$base64Data';

    // Create and trigger download link
    final anchor = html.AnchorElement(href: dataUri)
      ..download = fileName
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
  }

  void _clearAll() {
    _ciphertextController.clear();
    _keyController.clear();
    _outputController.clear();
    setState(() {
      _submitted = false;
      _ciphertextError = null;
      _keyError = null;
      _selectedCipherFile = null;
      _selectedCipherFileBytes = null;
      _selectedCipherFileName = null;
    });
  }

  @override
  void dispose() {
    _ciphertextController.dispose();
    _keyController.dispose();
    _outputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine display name for ciphertext field
    final displayName = kIsWeb
        ? _selectedCipherFileName
        : (_selectedCipherFile?.uri.pathSegments.last ?? _selectedCipherFileName);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DES - Decryption'),
        actions: [
          ClearAllButton(onPressed: _clearAll),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCiphertextField(displayName),
            const SizedBox(height: 24),
            _buildKeyField(),
            const SizedBox(height: 32),
            _buildDecryptButton(),
            const SizedBox(height: 24),
            OutputField(
              label: 'Plaintext (Output)',
              controller: _outputController,
              hintText: _selectedCipherFile != null || _selectedCipherFileBytes != null
                  ? 'Decrypted file will be saved/downloaded here'
                  : 'Decrypted text will appear here',
              isFileMode: _selectedCipherFile != null || _selectedCipherFileBytes != null,
            ),
            const SizedBox(height: 16),

            // Web hint
            if (kIsWeb && (_selectedCipherFileBytes != null || _selectedCipherFile != null))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '💡 On web, decrypted files are automatically downloaded to your browser\'s download folder.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCiphertextField(String? displayName) {
    final bool hasFile = _selectedCipherFile != null || _selectedCipherFileBytes != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ciphertext / Encrypted File',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            FilePickerButton(onPressed: _pickEncryptedFile),
          ],
        ),
        const SizedBox(height: 8),
        MyTextField(
          hintText: hasFile
              ? 'File selected: ${displayName ?? "Unknown"}'
              : 'Paste encrypted text or pick a file',
          controller: _ciphertextController,
          height: 150,
          maxLines: 6,
          margin: EdgeInsets.zero,
          readOnly: hasFile,
          onChanged: (_) => _validateAll(),
        ),
        ErrorText(message: _ciphertextError),
      ],
    );
  }

  Widget _buildKeyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Encryption Key',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: MyTextField(
                hintText: 'Key (exactly 8 chars)',
                controller: _keyController,
                margin: EdgeInsets.zero,
                onChanged: (_) => _validateAll(),
              ),
            ),
            const SizedBox(width: 8),
            RandomKeyButton(onPressed: _setRandomKey),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.paste, size: 20),
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                if (data?.text != null) {
                  _keyController.text = data!.text!;
                  _validateAll();
                }
              },
              tooltip: 'Paste key',
            ),
            const SizedBox(width: 8),
            CopyButton(
              data: _keyController.text,
              message: 'Key copied to clipboard!',
            ),
          ],
        ),
        ErrorText(message: _keyError),
        const SizedBox(height: 4),
        Text(
          'Note: DES requires an 8‑character key (64 bits). Use the same key that was used for encryption.',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildDecryptButton() {
    return MyOutlinedButton(
      text: _isDecrypting ? 'Decrypting...' : 'Decrypt',
      onPressed: _isDecrypting ? null : _decrypt,
    );
  }
}