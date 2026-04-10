# 🔐 Encryptorium

[![Flutter](https://img.shields.io/badge/Flutter-3.10+-blue)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-blue)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20|%20Windows%20|%20Web%20|-lightgrey)](https://flutter.dev/multi-platform)

A cross‑platform encryption app built with Flutter that lets you encrypt and decrypt **text** and **files** using classic cryptographic algorithms: **DES**, **Triple DES (3DES)**, and **AES**.

Designed for **Android, Windows, and Web** – with full file support and a smooth, non‑blocking UI.

---

## ✨ Features

### ✅ Current

- **Text encryption & decryption** using:
  - **DES** – 64‑bit key (8 ASCII characters)
  - **Triple DES** – three independent 8‑character keys (must be different)
  - **AES** – 128, 192, or 256‑bit keys (16, 24, or 32 characters)
- **File encryption & decryption** – any file type (images, documents, archives)
  - Files are automatically Base64‑encoded before encryption, then decoded after decryption
  - On **native platforms** (Windows/Android), decrypted files are saved to the `Encryptorium` folder in the user’s documents
  - On **web**, decrypted files are automatically downloaded to the browser’s download folder
- **Random key generation** for DES and AES (printable ASCII) – available only on encryption pages
- **PKCS#7 padding** for block alignment
- **Base64 output** – safe for copy/paste and storage
- **Clipboard integration** – copy keys, ciphertext, or plaintext with one click
- **Clear, responsive UI** built with Flutter
- **Non‑blocking processing page**:
  - Shows a loading animation while encryption/decryption runs in the background
  - Prevents UI freezes, especially for large files or slow algorithms
  - Automatically returns you to the previous page when done

### 🚀 Optimizations (2025)

- Complete rewrite of **DES** using integer bitwise operations instead of slow string manipulation – **up to 10x faster**
- Precomputed S‑box lookup tables for DES
- AES micro‑optimizations
- Heavy crypto operations moved off the UI thread to keep the interface responsive

---

## 📱 Supported Platforms

| Platform | Status | Notes |
|----------|--------|-------|
| Android  | ✅ Fully supported | File picker works natively |
| Windows  | ✅ Fully supported | File picker works natively |
| Web      | ✅ Fully supported | File picker via HTML5; downloads handled automatically |

*Encryptorium runs anywhere Flutter runs – and looks great on every platform.*

---

## 🔐 Algorithms Overview

| Algorithm | Key Lengths (bits) | Rounds | Implementation |
|-----------|--------------------|--------|----------------|
| **DES**   | 64                 | 16     | Pure Dart, integer‑based, highly optimised |
| **3DES**  | 168 (3×56)         | 48     | Composed of three DES operations (encrypt‑decrypt‑encrypt) |
| **AES**   | 128 / 192 / 256    | 10 / 12 / 14 | Pure Dart, custom implementation |

All cryptographic cores are **hand‑written** in Dart – no external crypto libraries are used, making this project both a learning tool and a complete demonstration of block cipher internals.

---

## 🧪 How to Use

### Text Mode

1. Choose an algorithm from the main menu.
2. Enter your text (plaintext for encryption, ciphertext for decryption).
3. Provide the key(s):
   - Click **Random** (encryption pages) to generate a secure key automatically.
   - Or **paste** your own key (exact length required).
   - For Triple DES, the three keys must be **different**.
4. Press **Encrypt** or **Decrypt** – the processing page appears with a loading animation.
5. After a short wait, the result appears in the output field.
6. **Copy** the result to your clipboard with the copy button.

### File Mode

1. Click the **file picker** button (folder icon) next to the input field.
2. Select any file (text, image, document, etc.).
3. Enter the key(s) exactly as you did during encryption.
4. Press **Encrypt** or **Decrypt**.
5. The app will process the file in the background.
   - **Encryption**: The encrypted file (`.enc` suffix) will be saved/downloaded.
   - **Decryption**: The original file will be restored and saved/downloaded.

> All ciphertexts (both text and file mode) are **Base64‑encoded** – you can safely copy, share, or store them.

---

## 🛠️ Technology Stack

- **Flutter** – cross‑platform UI framework
- **Dart** – programming language
- **Custom crypto** – implementations of DES, 3DES, and AES based on official FIPS standards
- **No external crypto packages** – everything is written from scratch for clarity and learning
- **Background processing** – `compute()` / isolates for heavy operations

---

## 📦 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (version 3.10 or later)
- A code editor (VS Code, Android Studio, etc.)

### Clone & Run

```bash
git clone https://github.com/your-username/encryptorium.git
cd encryptorium
flutter pub get
flutter run
