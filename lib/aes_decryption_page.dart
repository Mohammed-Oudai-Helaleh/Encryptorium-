import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:encryptorium/custom/my_outlined_button.dart';
import 'package:encryptorium/custom/my_text_field.dart';
import 'package:encryptorium/custom/error_text.dart';
import 'package:encryptorium/custom/clear_all_button.dart';
import 'package:encryptorium/custom/file_picker_button.dart';
import 'package:encryptorium/custom/copy_button.dart';
import 'package:encryptorium/custom/output_field.dart';
import 'package:encryptorium/models/cipher.dart';
import 'package:encryptorium/models/aes_key_length.dart';
import 'package:encryptorium/utils/file_utils.dart';
import 'package:universal_html/html.dart' as html;
import 'package:encryptorium/cipher_processing_page.dart';

class AesDecryptPage extends StatefulWidget {
  final CipherType cipherType;

  const AesDecryptPage({Key? key, required this.cipherType}) : super(key: key);

  @override
  State<AesDecryptPage> createState() => _AesDecryptPageState();
}

class _AesDecryptPageState extends State<AesDecryptPage> {
  final TextEditingController _ciphertextController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();

  // Validation errors
  String? _ciphertextError;
  String? _keyError;
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
    String? keyError;

    if (_selectedCipherFile == null &&
        _selectedCipherFileBytes == null &&
        _ciphertextController.text.isEmpty) {
      ciphertextError = 'Please enter ciphertext or select a file';
    }

    final key = _keyController.text;
    if (!AesKeyLength.validBytes.contains(key.length)) {
      keyError = 'Key must be exactly ${AesKeyLength.validBytes.join(', ')} characters (${AesKeyLength.validBytes.map((b) => '${b * 8} bits').join(', ')})';
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
    // 🔍 DEBUG: Confirm this method is called on Web
    if (kIsWeb) {
      debugPrint('🔓 [AES] _decrypt() STARTED');
      debugPrint('🔓 [AES] isFileMode: ${_selectedCipherFile != null || _selectedCipherFileBytes != null}');
    }

    _submitted = true;
    _validateAll();

    if (_ciphertextError != null || _keyError != null) {
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
            debugPrint('❌ [AES] Navigation/processing error: $e');
            debugPrint('❌ [AES] Stack: $stack');
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to read file: $e')),
          );
        }
        return;
      }
    }

    // 2️⃣ Create cipher request for DECRYPTION
    final request = CipherRequest.decrypt(
      cipherType: widget.cipherType,
      inputData: inputData,
      keys: [_keyController.text],
    );

    // 3️⃣ Navigate to processing page & run decryption (platform-aware)
    if (kIsWeb) {
      debugPrint('🔓 [AES] About to call processCipherInBackground...');
    }
    final result = await processCipherInBackground(
      context,
      title: 'Decrypting your data...',
      subtitle: isFileMode
          ? 'Processing: ${_selectedCipherFileName ?? "unknown"}'
          : 'Restoring plaintext with AES...',
      request: request,
    );

    // 4️⃣ Handle result after auto-redirect
    // 🔍 DEBUG: Confirm result received
    if (kIsWeb) {
      debugPrint('🔓 [AES] Received result: ${result != null ? 'SUCCESS' : 'NULL'}');
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
        title: const Text('AES - Decryption'),
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
                hintText: 'Key (16, 24, or 32 characters)',
                controller: _keyController,
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
          'Note: AES keys must be 16, 24, or 32 characters (128, 192, or 256 bits). Use the same key that was used for encryption.',
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