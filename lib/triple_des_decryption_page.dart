import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:encryptorium/custom/my_outlined_button.dart';
import 'package:encryptorium/custom/my_text_field.dart';
import 'package:encryptorium/custom/copy_button.dart';
import 'package:encryptorium/custom/error_text.dart';
import 'package:encryptorium/custom/clear_all_button.dart';
import 'package:encryptorium/custom/file_picker_button.dart';
import 'package:encryptorium/custom/output_field.dart';
import 'package:encryptorium/models/cipher.dart';
import 'package:encryptorium/utils/file_utils.dart';
import 'package:universal_html/html.dart' as html;
import 'package:encryptorium/cipher_processing_page.dart';

class TripleDesDecryptPage extends StatefulWidget {
  final CipherType cipherType;

  const TripleDesDecryptPage({Key? key, required this.cipherType}) : super(key: key);

  @override
  State<TripleDesDecryptPage> createState() => _TripleDesDecryptPageState();
}

class _TripleDesDecryptPageState extends State<TripleDesDecryptPage> {
  final TextEditingController _ciphertextController = TextEditingController();
  final TextEditingController _key1Controller = TextEditingController();
  final TextEditingController _key2Controller = TextEditingController();
  final TextEditingController _key3Controller = TextEditingController();
  final TextEditingController _outputController = TextEditingController();

  static const int _keyLength = 8;

  // Validation errors
  String? _ciphertextError;
  String? _key1Error;
  String? _key2Error;
  String? _key3Error;
  bool _submitted = false;

  // Native file handling
  File? _selectedCipherFile;

  // Web file handling
  Uint8List? _selectedCipherFileBytes;
  String? _selectedCipherFileName;

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
    String? key1Error;
    String? key2Error;
    String? key3Error;

    if (_selectedCipherFile == null &&
        _selectedCipherFileBytes == null &&
        _ciphertextController.text.isEmpty) {
      ciphertextError = 'Please enter ciphertext or select a file';
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

    // Uniqueness checks
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
        _ciphertextError = ciphertextError;
        _key1Error = key1Error;
        _key2Error = key2Error;
        _key3Error = key3Error;
      } else {
        _ciphertextError = null;
        _key1Error = null;
        _key2Error = null;
        _key3Error = null;
      }
    });
  }

  Future<void> _decrypt() async {
    // 🔍 DEBUG: Confirm this method is called on Web
    if (kIsWeb) {
      debugPrint('🔓 [3DES] _decrypt() STARTED');
      debugPrint('🔓 [3DES] isFileMode: ${_selectedCipherFile != null || _selectedCipherFileBytes != null}');
    }

    _submitted = true;
    _validateAll();

    if (_ciphertextError != null ||
        _key1Error != null ||
        _key2Error != null ||
        _key3Error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix errors before decrypting')),
      );
      return;
    }

    _outputController.clear();

    // 1️⃣ Prepare input data for background processing
    final bool isFileMode = _selectedCipherFile != null || _selectedCipherFileBytes != null;
    String inputData = _ciphertextController.text;

    if (isFileMode && _selectedCipherFileBytes != null) {
      // Web file mode: decode bytes to UTF-8 string for isolate transfer
      inputData = utf8.decode(_selectedCipherFileBytes!);
    } else if (isFileMode && _selectedCipherFile != null) {
      // Native file mode: read file as string directly
      try {
        inputData = await _selectedCipherFile!.readAsString(encoding: utf8);
      } catch (e, stack) {
        if (mounted) {
          if (kIsWeb) {
            debugPrint('❌ [3DES] Navigation/processing error: $e');
            debugPrint('❌ [3DES] Stack: $stack');
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to read file: $e')),
          );
        }
        return;
      }
    }

    // 2️⃣ Create cipher request for DECRYPTION (3 keys for Triple DES)
    final request = CipherRequest.decrypt(
      cipherType: widget.cipherType,
      inputData: inputData,
      keys: [_key1Controller.text, _key2Controller.text, _key3Controller.text],
    );

    // 3️⃣ Navigate to processing page & run decryption (platform-aware)
    if (kIsWeb) {
      debugPrint('🔓 [3DES] About to call processCipherInBackground...');
    }
    final result = await processCipherInBackground(
      context,
      title: 'Decrypting your data...',
      subtitle: isFileMode
          ? 'Processing: ${_selectedCipherFileName ?? "unknown"}'
          : 'Restoring plaintext with Triple DES...',
      request: request,
    );

    // 4️⃣ Handle result after auto-redirect
    // 🔍 DEBUG: Confirm result received
    if (kIsWeb) {
      debugPrint('🔓 [3DES] Received result: ${result != null ? 'SUCCESS' : 'NULL'}');
    }
    if (result != null && mounted) {
      _handleDecryptionResult(result, isFileMode);
    }
  }

  /// Handles the decryption result: saves/downloads file or displays plaintext
  void _handleDecryptionResult(String plaintext, bool isFileMode) {
    if (isFileMode) {
      if (kIsWeb) {
        // 🌐 WEB: Decode base64 plaintext to bytes, then trigger download
        try {
          final originalBytes = base64.decode(plaintext);
          String originalFileName = _selectedCipherFileName ?? 'decrypted_file';
          if (originalFileName.endsWith('.enc')) {
            originalFileName = originalFileName.substring(0, originalFileName.length - 4);
          } else {
            originalFileName = 'decrypted_$originalFileName';
          }
          _downloadDecryptedFileWeb(originalFileName, originalBytes);
          _outputController.text = '📥 Downloaded: $originalFileName';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ File decrypted and downloaded: $originalFileName')),
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to decode decrypted file: $e')),
            );
          }
        }
      } else {
        // 💻 NATIVE: Save decrypted file to disk
        _saveDecryptedFileNative(plaintext);
      }
    } else {
      // 📝 TEXT MODE: Display plaintext in output field
      _outputController.text = plaintext;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Decryption completed successfully!')),
      );
    }
  }

  /// Saves decrypted file to disk on native platforms (Windows/Android)
  Future<void> _saveDecryptedFileNative(String base64Plaintext) async {
    try {
      final originalBytes = base64.decode(base64Plaintext);
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save file: $e')),
        );
      }
    }
  }

  /// Triggers a file download in the browser for binary data
  void _downloadDecryptedFileWeb(String fileName, List<int> bytes) {
    if (!kIsWeb) return;

    final base64Data = base64.encode(bytes);
    final dataUri = 'application/octet-stream;base64,$base64Data';

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
    _key1Controller.clear();
    _key2Controller.clear();
    _key3Controller.clear();
    _outputController.clear();
    setState(() {
      _submitted = false;
      _ciphertextError = null;
      _key1Error = null;
      _key2Error = null;
      _key3Error = null;
      _selectedCipherFile = null;
      _selectedCipherFileBytes = null;
      _selectedCipherFileName = null;
    });
  }

  @override
  void dispose() {
    _ciphertextController.dispose();
    _key1Controller.dispose();
    _key2Controller.dispose();
    _key3Controller.dispose();
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
        title: const Text('Triple DES - Decryption'),
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
            _buildKeyField(
              label: 'Key 1',
              controller: _key1Controller,
              hint: 'Key 1 (exactly 8 chars)',
              errorText: _key1Error,
            ),
            const SizedBox(height: 16),
            _buildKeyField(
              label: 'Key 2',
              controller: _key2Controller,
              hint: 'Key 2 (exactly 8 chars)',
              errorText: _key2Error,
            ),
            const SizedBox(height: 16),
            _buildKeyField(
              label: 'Key 3',
              controller: _key3Controller,
              hint: 'Key 3 (exactly 8 chars)',
              errorText: _key3Error,
            ),
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

  Widget _buildKeyField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required String? errorText,
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
                onChanged: (_) => _validateAll(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.paste, size: 20),
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                if (data?.text != null) {
                  controller.text = data!.text!;
                  _validateAll();
                }
              },
              tooltip: 'Paste key',
            ),
            const SizedBox(width: 8),
            CopyButton(
              data: controller.text,
              message: 'Key copied to clipboard!',
            ),
          ],
        ),
        ErrorText(message: errorText),
        const SizedBox(height: 4),
        Text(
          'Note: Triple DES requires three 8‑character keys (64 bits each). Keys must be different. Use the same keys that were used for encryption.',
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
      text: 'Decrypt',
      onPressed: _decrypt,
    );
  }
}