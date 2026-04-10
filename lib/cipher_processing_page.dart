// lib/cipher_processing_page.dart
// ✅ Time-sliced processing for Web to keep UI responsive.
//    - Native: Uses true background isolate (compute)
//    - Web: Chunks work & yields to event loop between slices so the spinner animates smoothly

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:encryptorium/models/cipher.dart';
import 'package:encryptorium/backend/encryption.dart';

// ============================================================================
// 📦 DATA MODEL
// ============================================================================

class CipherRequest {
  final String cipherTypeName;
  final String inputData;
  final List<String> keys;
  final bool isEncrypt;

  CipherRequest({
    required this.cipherTypeName,
    required this.inputData,
    required this.keys,
    required this.isEncrypt,
  });

  factory CipherRequest.encrypt({
    required CipherType cipherType,
    required String inputData,
    required List<String> keys,
  }) => CipherRequest(
    cipherTypeName: cipherType.name,
    inputData: inputData,
    keys: keys,
    isEncrypt: true,
  );

  factory CipherRequest.decrypt({
    required CipherType cipherType,
    required String inputData,
    required List<String> keys,
  }) => CipherRequest(
    cipherTypeName: cipherType.name,
    inputData: inputData,
    keys: keys,
    isEncrypt: false,
  );
}

// ============================================================================
// ⚡ BACKGROUND WORKER (Native)
// ============================================================================

@pragma('vm:entry-point')
String runCipherProcess(CipherRequest request) {
  final cipherType = CipherType.values.byName(request.cipherTypeName);

  final encryption = switch (cipherType) {
    CipherType.des => Encryption.des(request.inputData, request.keys[0]),
    CipherType.tripleDes => Encryption.tripleDes(
        request.inputData, request.keys[0], request.keys[1], request.keys[2]),
    CipherType.aes => Encryption.aes(request.inputData, request.keys[0]),
  };

  return request.isEncrypt
      ? encryption.encrypt()
      : encryption.decrypt(request.inputData);
}

// ============================================================================
// 🌐 TIME-SLICED WEB PROCESSOR
// ============================================================================

/// Processes cipher operations in small chunks on Web to keep UI responsive.
/// Yields to the event loop between chunks so Flutter can repaint & animate.
Future<String> runCipherProcessWebAsync(CipherRequest request) async {
  final cipherType = CipherType.values.byName(request.cipherTypeName);
  final isEncrypt = request.isEncrypt;

  // Chunk size: ~1KB of input per slice. Adjust if needed:
  // Smaller = smoother UI, longer total time
  // Larger = faster total time, occasional micro-pauses
  const chunkSize = 1024;

  String result = '';
  int processedLength = 0;
  final totalLength = request.inputData.length;

  while (processedLength < totalLength) {
    final end = (processedLength + chunkSize).clamp(0, totalLength);
    final chunk = request.inputData.substring(processedLength, end);

    // Process this chunk
    final encryption = switch (cipherType) {
      CipherType.des => Encryption.des(chunk, request.keys[0]),
      CipherType.tripleDes => Encryption.tripleDes(
          chunk, request.keys[0], request.keys[1], request.keys[2]),
      CipherType.aes => Encryption.aes(chunk, request.keys[0]),
    };

    result += isEncrypt
        ? encryption.encrypt()
        : encryption.decrypt(chunk);

    processedLength = end;

    // ✅ CRITICAL: Yield to the event loop so Flutter can repaint the spinner
    await Future.delayed(Duration.zero);
  }

  return result;
}

// ============================================================================
// 🌐 PLATFORM-AWARE PROCESSING
// ============================================================================

Future<String> processCipherPlatformAware(CipherRequest request) async {
  if (!kIsWeb) {
    // 🪟 Native: True background isolate (zero UI blocking)
    return compute(runCipherProcess, request);
  }

  // 🌐 Web: Time-sliced main thread processing (keeps spinner alive)
  debugPrint('🌐 [Cipher] Starting time-sliced Web processing...');
  return runCipherProcessWebAsync(request);
}

// ============================================================================
// 🎨 UI WIDGET: Loading/Processing Page
// ============================================================================

class CipherProcessingPage extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Future<String> Function() cipherTask;

  const CipherProcessingPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.cipherTask,
  });

  @override
  State<CipherProcessingPage> createState() => _CipherProcessingPageState();
}

class _CipherProcessingPageState extends State<CipherProcessingPage> {
  String? _errorMessage;
  bool _hasCompleted = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🔄 [UI] CipherProcessingPage mounted');
    _executeCipherTask();
  }

  Future<void> _executeCipherTask() async {
    if (_hasCompleted) return;

    try {
      final result = await widget.cipherTask();

      if (mounted && !_hasCompleted) {
        debugPrint('✅ [UI] Task completed, returning result');
        _hasCompleted = true;
        Navigator.of(context).pop(result);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [UI] Cipher processing error: $e\n$stackTrace');

      if (mounted && !_hasCompleted) {
        setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
        await Future.delayed(const Duration(seconds: 2));
        _hasCompleted = true;
        Navigator.of(context).pop(null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surface.withOpacity(0.95),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.title.toLowerCase().contains('encrypt')
                            ? Icons.lock_outline
                            : Icons.lock_open_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_errorMessage == null) ...[
                      // 🔁 Restored: Smooth spinning circle
                      const SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(strokeWidth: 3.5),
                      ),
                      const SizedBox(height: 28),
                    ],
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(_errorMessage!,
                                  style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(widget.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600, height: 1.3)),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 12),
                      Text(widget.subtitle!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 15,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              height: 1.4)),
                    ],
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: Theme.of(context).colorScheme.onTertiaryContainer),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text('Please do not close the page.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                        'You will be automatically redirected back when the cipher process is complete.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
                            fontStyle: FontStyle.italic,
                            height: 1.4)),
                    const SizedBox(height: 40),
                    Opacity(
                        opacity: 0.3,
                        child: Icon(Icons.security,
                            size: 80, color: Theme.of(context).colorScheme.primary)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 🎁 HELPER FUNCTION
// ============================================================================

Future<String?> processCipherInBackground(
    BuildContext context, {
      required String title,
      String? subtitle,
      required CipherRequest request,
    }) {
  debugPrint('🚀 [NAV] Pushing CipherProcessingPage');
  return Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (_) => CipherProcessingPage(
        title: title,
        subtitle: subtitle,
        cipherTask: () => processCipherPlatformAware(request),
      ),
      fullscreenDialog: true,
    ),
  );
}