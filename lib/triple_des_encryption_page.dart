import 'dart:io';
import 'dart:convert';
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

// Web import - only used when kIsWeb is true
import 'dart:html' as html;

class TripleDesEncryptPage extends StatefulWidget {
  final CipherType cipherType;

  const TripleDesEncryptPage({Key? key, required this.cipherType}) : super(key: key);

  @override
  State<TripleDesEncryptPage> createState() => _TripleDesEncryptPageState();
}

class _TripleDesEncryptPageState extends State<TripleDesEncryptPage> {
  final TextEditingController _plaintextController = TextEditingController();
  final TextEditingController _key1Controller = TextEditingController();
  final TextEditingController _key2Controller = TextEditingController();
  final TextEditingController _key3Controller = TextEditingController();
  final TextEditingController _outputController = TextEditingController();

  static const int _keyLength = 8;

  bool _isEncrypting = false;
  String? _plaintextError;
  String? _key1Error;
  String? _key2Error;
  String? _key3Error;
  bool _submitted = false;

  // Native file handling
  File? _selectedFile;

  // Web file handling
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;

  void _generateRandomKey1() {
    String newKey;
    do {
      newKey = generateRandomKey(_keyLength);
    } while (newKey == _key2Controller.text || newKey == _key3Controller.text);
    _key1Controller.text = newKey;
    _validateAll();
  }

  void _generateRandomKey2() {
    String newKey;
    do {
      newKey = generateRandomKey(_keyLength);
    } while (newKey == _key1Controller.text || newKey == _key3Controller.text);
    _key2Controller.text = newKey;
    _validateAll();
  }

  void _generateRandomKey3() {
    String newKey;
    do {
      newKey = generateRandomKey(_keyLength);
    } while (newKey == _key1Controller.text || newKey == _key2Controller.text);
    _key3Controller.text = newKey;
    _validateAll();
  }

  Future<void> _pickFile() async {
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
          _selectedFile = null;
          _selectedFileBytes = null;
          _selectedFileName = null;

          if (kIsWeb) {
            // WEB: Use bytes and name from memory
            if (file.bytes != null) {
              _selectedFileBytes = file.bytes;
              _selectedFileName = file.name;
              _plaintextController.text = file.name;
            }
          } else {
            // NATIVE (Windows/Android): Use file path
            if (file.path != null) {
              _selectedFile = File(file.path!);
              _selectedFileName = file.name;
              _plaintextController.text = file.name ?? 'Unknown';
            }
          }

          _submitted = false;
          _plaintextError = null;
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
    String? plaintextError;
    String? key1Error;
    String? key2Error;
    String? key3Error;

    if (_selectedFile == null &&
        _selectedFileBytes == null &&
        _plaintextController.text.isEmpty) {
      plaintextError = 'Please enter text to encrypt or pick a file';
    }

    if (_key1Controller.text.length != _keyLength) {
      key1Error = 'Key 1 must be exactly $_keyLength characters';
    }
    if (_key2Controller.text.length != _keyLength) {
      key2Error = 'Key 2 must be exactly $_keyLength characters';
    }
    if (_key3Controller.text.length != _keyLength) {
      key3Error = 'Key 3 must be exactly $_keyLength characters';
    }

    // Uniqueness checks (only if lengths are correct)
    if (key1Error == null && key2Error == null && key3Error == null) {
      final key1 = _key1Controller.text;
      final key2 = _key2Controller.text;
      final key3 = _key3Controller.text;

      if (key1 == key2) {
        key1Error = 'Key 1 and Key 2 must be different';
        key2Error = 'Key 1 and Key 2 must be different';
      }
      if (key1 == key3) {
        key1Error = key1Error ?? 'Key 1 and Key 3 must be different';
        key3Error = 'Key 1 and Key 3 must be different';
      }
      if (key2 == key3) {
        key2Error = key2Error ?? 'Key 2 and Key 3 must be different';
        key3Error = key3Error ?? 'Key 2 and Key 3 must be different';
      }
    }

    setState(() {
      if (_submitted) {
        _plaintextError = plaintextError;
        _key1Error = key1Error;
        _key2Error = key2Error;
        _key3Error = key3Error;
      } else {
        _plaintextError = null;
        _key1Error = null;
        _key2Error = null;
        _key3Error = null;
      }
    });
  }

  Future<void> _encrypt() async {
    _submitted = true;
    _validateAll();

    if (_plaintextError != null ||
        _key1Error != null ||
        _key2Error != null ||
        _key3Error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix errors before encrypting')),
      );
      return;
    }

    _outputController.clear();
    setState(() => _isEncrypting = true);

    try {
      if (kIsWeb) {
        await _encryptWeb();
      } else {
        await _encryptNative();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Encryption failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isEncrypting = false);
      }
    }
  }

  Future<void> _encryptNative() async {
    if (_selectedFile != null) {
      // ========== FILE MODE - Native platforms ==========
      final encryptoriumDir = await getEncryptoriumDirectory();
      final inputFileName = _selectedFileName ?? 'file';
      final outputFileName = '$inputFileName.enc';
      final outputPath = '${encryptoriumDir.path}/$outputFileName';

      final key1 = _key1Controller.text;
      final key2 = _key2Controller.text;
      final key3 = _key3Controller.text;

      await Encryption.createEncryptedFileStub(
        _selectedFile!.path,
        outputPath,
        algorithm: widget.cipherType,
        key1: key1,
        key2: key2,
        key3: key3,
      );

      _outputController.text = outputPath;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ File encrypted! Saved to: $outputPath')),
        );
      }
    } else {
      // ========== TEXT MODE - All platforms ==========
      final plaintext = _plaintextController.text;
      final key1 = _key1Controller.text;
      final key2 = _key2Controller.text;
      final key3 = _key3Controller.text;

      final encryption = Encryption.tripleDes(plaintext, key1, key2, key3);
      final ciphertext = encryption.encrypt();
      _outputController.text = ciphertext;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Encryption completed successfully!')),
        );
      }
    }
  }

  Future<void> _encryptWeb() async {
    if (_selectedFileBytes != null && _selectedFileName != null) {
      // ========== FILE MODE - Web ==========
      final base64Plain = base64.encode(_selectedFileBytes!);
      final encryption = Encryption.tripleDes(
          base64Plain,
          _key1Controller.text,
          _key2Controller.text,
          _key3Controller.text
      );
      final cipherText = encryption.encrypt();

      // Trigger browser download
      final fileName = '${_selectedFileName!}.enc';
      await _downloadEncryptedFileWeb(fileName, cipherText);

      _outputController.text = '📥 Downloaded: $fileName';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ File encrypted and downloaded: $fileName')),
        );
      }
    } else {
      // ========== TEXT MODE - All platforms (same as native) ==========
      final plaintext = _plaintextController.text;
      final key1 = _key1Controller.text;
      final key2 = _key2Controller.text;
      final key3 = _key3Controller.text;

      final encryption = Encryption.tripleDes(plaintext, key1, key2, key3);
      final ciphertext = encryption.encrypt();
      _outputController.text = ciphertext;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Encryption completed successfully!')),
        );
      }
    }
  }

  /// Triggers a file download in the browser
  Future<void> _downloadEncryptedFileWeb(String fileName, String content) async {
    if (!kIsWeb) return;

    final bytes = utf8.encode(content);
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
    _plaintextController.clear();
    _key1Controller.clear();
    _key2Controller.clear();
    _key3Controller.clear();
    _outputController.clear();
    setState(() {
      _submitted = false;
      _plaintextError = null;
      _key1Error = null;
      _key2Error = null;
      _key3Error = null;
      _selectedFile = null;
      _selectedFileBytes = null;
      _selectedFileName = null;
    });
  }

  @override
  void dispose() {
    _plaintextController.dispose();
    _key1Controller.dispose();
    _key2Controller.dispose();
    _key3Controller.dispose();
    _outputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine display name for plaintext field
    final displayName = kIsWeb
        ? _selectedFileName
        : (_selectedFile?.uri.pathSegments.last ?? _selectedFileName);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Triple DES - Encryption'),
        actions: [
          ClearAllButton(onPressed: _clearAll),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPlaintextField(displayName),
            const SizedBox(height: 24),
            _buildKeyField(
              label: 'Key 1',
              controller: _key1Controller,
              hint: 'Key 1 (exactly 8 chars)',
              errorText: _key1Error,
              onRandom: _generateRandomKey1,
            ),
            const SizedBox(height: 16),
            _buildKeyField(
              label: 'Key 2',
              controller: _key2Controller,
              hint: 'Key 2 (exactly 8 chars)',
              errorText: _key2Error,
              onRandom: _generateRandomKey2,
            ),
            const SizedBox(height: 16),
            _buildKeyField(
              label: 'Key 3',
              controller: _key3Controller,
              hint: 'Key 3 (exactly 8 chars)',
              errorText: _key3Error,
              onRandom: _generateRandomKey3,
            ),
            const SizedBox(height: 32),
            _buildEncryptButton(),
            const SizedBox(height: 24),
            OutputField(
              label: 'Ciphertext (Output)',
              controller: _outputController,
              hintText: _selectedFile != null || _selectedFileBytes != null
                  ? 'Encrypted file will be saved/downloaded here'
                  : 'Encrypted text will appear here',
              isFileMode: _selectedFile != null || _selectedFileBytes != null,
            ),
            const SizedBox(height: 16),

            // Web hint
            if (kIsWeb && (_selectedFileBytes != null || _selectedFile != null))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '💡 On web, encrypted files are automatically downloaded to your browser\'s download folder.',
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

  Widget _buildPlaintextField(String? displayName) {
    final bool hasFile = _selectedFile != null || _selectedFileBytes != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Plaintext',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            FilePickerButton(onPressed: _pickFile),
          ],
        ),
        const SizedBox(height: 8),
        MyTextField(
          hintText: hasFile
              ? 'File selected: ${displayName ?? "Unknown"}'
              : 'Enter the text you wish to encrypt',
          controller: _plaintextController,
          height: 150,
          maxLines: 6,
          margin: EdgeInsets.zero,
          readOnly: hasFile,
          onChanged: (_) => _validateAll(),
        ),
        ErrorText(message: _plaintextError),
      ],
    );
  }

  Widget _buildKeyField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required String? errorText,
    required VoidCallback onRandom,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: MyTextField(
                hintText: hint,
                controller: controller,
                margin: EdgeInsets.zero,
                readOnly: true,
                onChanged: (_) => _validateAll(),
              ),
            ),
            const SizedBox(width: 8),
            RandomKeyButton(onPressed: onRandom),
            const SizedBox(width: 8),
            CopyButton(data: controller.text, message: 'Key copied to clipboard!'),
          ],
        ),
        ErrorText(message: errorText),
        const SizedBox(height: 4),
        Text(
          'Note: Triple DES requires three 8‑character keys (64 bits each). Keys must be different.',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildEncryptButton() {
    return MyOutlinedButton(
      text: _isEncrypting ? 'Encrypting...' : 'Encrypt',
      onPressed: _isEncrypting ? null : _encrypt,
    );
  }
}