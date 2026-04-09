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
import 'package:encryptorium/models/aes_key_length.dart';
import 'package:encryptorium/utils/file_utils.dart';
import 'package:encryptorium/utils/key_generator.dart';
import 'package:universal_html/html.dart' as html;

class AesEncryptPage extends StatefulWidget {
  final CipherType cipherType;

  const AesEncryptPage({Key? key, required this.cipherType}) : super(key: key);

  @override
  State<AesEncryptPage> createState() => _AesEncryptPageState();
}

class _AesEncryptPageState extends State<AesEncryptPage> {
  final TextEditingController _plaintextController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();

  // Selected key length (default 128 bits / 16 bytes)
  AesKeyLength _selectedKeyLength = AesKeyLength.bits128;

  // Loading state
  bool _isEncrypting = false;

  // Validation errors
  String? _plaintextError;
  String? _keyError;

  // Whether the user has attempted to submit
  bool _submitted = false;

  // Native file handling
  File? _selectedFile;

  // Web file handling
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;

  // Helper to generate random key using the shared utility
  void _setRandomKey() {
    _keyController.text = generateRandomKey(_selectedKeyLength.bytes);
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

  // Validate all fields
  void _validateAll() {
    String? plaintextError;
    String? keyError;

    // Skip plaintext validation if a file is selected
    if (_selectedFile == null &&
        _selectedFileBytes == null &&
        _plaintextController.text.isEmpty) {
      plaintextError = 'Please enter text to encrypt or pick a file';
    }

    final key = _keyController.text;
    if (key.length != _selectedKeyLength.bytes) {
      keyError = 'Key must be exactly ${_selectedKeyLength.bytes} characters for ${_selectedKeyLength.displayName}';
    }

    setState(() {
      if (_submitted) {
        _plaintextError = plaintextError;
        _keyError = keyError;
      } else {
        _plaintextError = null;
        _keyError = null;
      }
    });
  }

  Future<void> _encrypt() async {
    _submitted = true;
    _validateAll();

    if (_plaintextError != null || _keyError != null) {
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

      final key = _keyController.text;

      await Encryption.createEncryptedFileStub(
        _selectedFile!.path,
        outputPath,
        algorithm: widget.cipherType,
        key1: key,
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
      final key = _keyController.text;

      final encryption = Encryption.aes(plaintext, key);
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
      final encryption = Encryption.aes(base64Plain, _keyController.text);
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
      final key = _keyController.text;

      final encryption = Encryption.aes(plaintext, key);
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
    _keyController.clear();
    _outputController.clear();
    setState(() {
      _submitted = false;
      _plaintextError = null;
      _keyError = null;
      _selectedFile = null;
      _selectedFileBytes = null;
      _selectedFileName = null;
    });
  }

  @override
  void dispose() {
    _plaintextController.dispose();
    _keyController.dispose();
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
        title: const Text('AES - Encryption'),
        actions: [
          ClearAllButton(onPressed: _clearAll),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Plaintext field with file picker
            _buildPlaintextField(displayName),
            const SizedBox(height: 24),

            // Key length selector
            _buildKeyLengthSelector(),
            const SizedBox(height: 16),

            // Key field with random button and copy
            _buildKeyField(),
            const SizedBox(height: 32),

            // Encrypt button
            _buildEncryptButton(),
            const SizedBox(height: 24),

            // Output field
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

  Widget _buildKeyLengthSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Key Length',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SegmentedButton<AesKeyLength>(
          segments: const [
            ButtonSegment(
              value: AesKeyLength.bits128,
              label: Text('128 bits'),
              icon: Icon(Icons.key),
            ),
            ButtonSegment(
              value: AesKeyLength.bits192,
              label: Text('192 bits'),
              icon: Icon(Icons.key),
            ),
            ButtonSegment(
              value: AesKeyLength.bits256,
              label: Text('256 bits'),
              icon: Icon(Icons.key),
            ),
          ],
          selected: {_selectedKeyLength},
          onSelectionChanged: (Set<AesKeyLength> newSelection) {
            setState(() {
              _selectedKeyLength = newSelection.first;
              _validateAll();
            });
          },
        ),
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
                hintText: 'Key (${_selectedKeyLength.bytes} chars)',
                controller: _keyController,
                margin: EdgeInsets.zero,
                readOnly: true,
                onChanged: (_) => _validateAll(),
              ),
            ),
            const SizedBox(width: 8),
            RandomKeyButton(onPressed: _setRandomKey),
            const SizedBox(width: 8),
            CopyButton(data: _keyController.text, message: 'Key copied to clipboard!'),
          ],
        ),
        ErrorText(message: _keyError),
        const SizedBox(height: 4),
        Text(
          'Note: AES requires a ${_selectedKeyLength.displayName} (${_selectedKeyLength.bytes} characters).',
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