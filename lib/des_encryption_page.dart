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
import 'package:encryptorium/utils/file_utils.dart';
import 'package:encryptorium/utils/key_generator.dart';
import 'package:universal_html/html.dart' as html;
import 'package:encryptorium/cipher_processing_page.dart';

class DesEncryptPage extends StatefulWidget {
  final CipherType cipherType;

  const DesEncryptPage({Key? key, required this.cipherType}) : super(key: key);

  @override
  State<DesEncryptPage> createState() => _DesEncryptPageState();
}

class _DesEncryptPageState extends State<DesEncryptPage> {
  final TextEditingController _plaintextController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();

  static const int _keyLength = 8;

  // Validation state
  String? _plaintextError;
  String? _keyError;
  bool _submitted = false;

  // Native file handling
  File? _selectedFile;

  // Web file handling
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;

  void _setRandomKey() {
    _keyController.text = generateRandomKey(_keyLength);
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
    String? keyError;

    if (_selectedFile == null &&
        _selectedFileBytes == null &&
        _plaintextController.text.isEmpty) {
      plaintextError = 'Please enter text to encrypt or pick a file';
    }

    if (_keyController.text.length != _keyLength) {
      keyError = 'Key must be exactly $_keyLength characters';
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
    // 🔍 DEBUG: Confirm this method is called on Web
    if (kIsWeb) {
      debugPrint('🔐 [DES] _encrypt() STARTED');
      debugPrint('🔐 [DES] isFileMode: ${_selectedFile != null || _selectedFileBytes != null}');
    }
    _submitted = true;
    _validateAll();

    if (_plaintextError != null || _keyError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix errors before encrypting')),
      );
      return;
    }

    _outputController.clear();

    // 1️⃣ Prepare input data for background processing
    final bool isFileMode = _selectedFile != null || _selectedFileBytes != null;
    String inputData = _plaintextController.text;

    if (isFileMode && _selectedFileBytes != null) {
      // Web file mode: encode bytes to base64 string for isolate transfer
      inputData = base64.encode(_selectedFileBytes!);
    } else if (isFileMode && _selectedFile != null) {
      // Native file mode: read file as bytes, then encode to base64
      try {
        final fileBytes = await _selectedFile!.readAsBytes();
        inputData = base64.encode(fileBytes);
      } catch (e, stack) {
        if (mounted) {
          if (kIsWeb) {
            debugPrint('❌ [DES] Navigation/processing error: $e');
            debugPrint('❌ [DES] Stack: $stack');
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to read file: $e')),
          );
        }
        return;
      }
    }

    // 2️⃣ Create cipher request
    final request = CipherRequest.encrypt(
      cipherType: widget.cipherType,
      inputData: inputData,
      keys: [_keyController.text],
    );

    // 3️⃣ Navigate to processing page & run encryption (platform-aware)
    if (kIsWeb) {
      debugPrint('🔐 [DES] About to call processCipherInBackground...');
    }
    final result = await processCipherInBackground(
      context,
      title: 'Encrypting your data...',
      subtitle: isFileMode
          ? 'Processing: ${_selectedFileName ?? "unknown"}'
          : 'Securing plaintext with DES...',
      request: request,
    );

    // 4️⃣ Handle result after auto-redirect
    // 🔍 DEBUG: Confirm result received
    if (kIsWeb) {
      debugPrint('🔐 [DES] Received result: ${result != null ? 'SUCCESS' : 'NULL'}');
    }
    if (result != null && mounted) {
      _handleEncryptionResult(result, isFileMode);
    }
  }

  /// Handles the encryption result: saves/downloads file or displays ciphertext
  void _handleEncryptionResult(String ciphertext, bool isFileMode) {
    if (isFileMode) {
      if (kIsWeb) {
        // 🌐 WEB: Trigger browser download for encrypted file
        _downloadEncryptedFileWeb('${_selectedFileName ?? 'file'}.enc', ciphertext);
        _outputController.text = '📥 Downloaded: ${_selectedFileName ?? 'file'}.enc';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ File encrypted and downloaded: ${_selectedFileName ?? 'file'}.enc'),
          ),
        );
      } else {
        // 💻 NATIVE: Save encrypted file to disk
        _saveEncryptedFileNative(ciphertext);
      }
    } else {
      // 📝 TEXT MODE: Display ciphertext in output field
      _outputController.text = ciphertext;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Encryption completed successfully!')),
      );
    }
  }

  /// Saves encrypted file to disk on native platforms (Windows/Android)
  Future<void> _saveEncryptedFileNative(String ciphertext) async {
    try {
      final encryptoriumDir = await getEncryptoriumDirectory();
      final fileName = '${_selectedFileName ?? 'file'}.enc';
      final outputPath = '${encryptoriumDir.path}/$fileName';
      final outputFile = File(outputPath);

      await outputFile.writeAsString(ciphertext, encoding: utf8);

      _outputController.text = outputPath;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ File encrypted to: $outputPath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save file: $e')),
        );
      }
    }
  }

  /// Triggers a browser download for encrypted content on web
  void _downloadEncryptedFileWeb(String fileName, String content) {
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
        title: const Text('DES - Encryption'),
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
            _buildKeyField(),
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
          'Note: DES requires an 8‑character key (64 bits). The key is read‑only and generated randomly.',
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
      text: 'Encrypt',
      onPressed: _encrypt,
    );
  }
}