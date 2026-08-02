# Panduan Fase 1 — Arsitektur Projek, Setup Turso DB, & Pondasi Riverpod

> Finance Tracker (Flutter)
> Fase ini bertujuan membangun fondasi projek: struktur folder *Feature-First*, dependensi & code generation, integrasi database Turso (LibSQL), serta skema database awal.

---

## Daftar Isi

1. [1.1 Inisialisasi Projek & Struktur Folder](#11-inisialisasi-projek--struktur-folder)
2. [1.2 Setup Dependensi & Code Generation](#12-setup-dependensi--code-generation)
3. [1.3 Integrasi Turso DB (LibSQL Client)](#13-integrasi-turso-db-libsql-client)
4. [1.4 Perancangan Skema Database Initial (DDL SQL)](#14-perancangan-skema-database-initial-ddl-sql)
5. [Checklist Verifikasi Fase 1](#checklist-verifikasi-fase-1)

---

## 1.1. Inisialisasi Projek & Struktur Folder

### 1.1.1 Jalankan command `flutter create`

Pastikan Flutter SDK sudah terpasang dan bisa diakses dari terminal, lalu jalankan command berikut di direktori projek tempat kamu ingin membuat aplikasi:

```bash
flutter create finance_tracker
```

> **Catatan**: Jika kamu sudah berada di dalam folder `finance_tracker` (kosong), gunakan:
> ```bash
> flutter create .
> ```

Setelah selesai, masuk ke folder projek:

```bash
cd finance_tracker
```

### 1.1.2 Buat struktur folder *Feature-First Architecture*

Di dalam folder `lib/`, buat struktur folder berikut (disarankan lewat IDE/editor, atau command `mkdir`):

```
lib/
└── src/
    ├── core/          # database, network, theme, utils
    ├── features/      # wallets, categories, transactions, budgeting, savings, dashboard, reports, auth
    └── shared/        # widgets, constants
```

**Hasil akhir yang diharapkan:**
```
lib/
├── main.dart
└── src/
    ├── core/
    │   ├── database/
    │   ├── network/
    │   ├── theme/
    │   └── utils/
    ├── features/
    │   ├── wallets/
    │   ├── categories/
    │   ├── transactions/
    │   ├── budgeting/
    │   ├── savings/
    │   ├── dashboard/
    │   ├── reports/
    │   └── auth/
    └── shared/
        ├── widgets/
        └── constants/
```

> **Catatan**: Buat folder ini sekarang untuk persiapan fase-fase berikutnya. Pada Fase 1, kita hanya akan mengisi bagian `core/database/` dan beberapa file pendukung.

### 1.1.3 Konfigurasi file `.gitignore`

Buka file `.gitignore` bawaan Flutter dan pastikan area tambahan berikut tersimpan (untuk menyembunyikan file rahasia & hasil code generation):

```gitignore
# Generated code (Riverpod / Freezed / JsonSerializable)
*.g.dart
*.freezed.dart

# Environment & secrets
.env
.env.local
*.env
```

> **Penting**: Jangan pernah commit file `.env` karena berisi token autentikasi Turso.

### 1.1.4 Tambahkan file `.env` dan `.env.example`

Buat dua file di **root projek**:

**File `.env.example`** (template, aman untuk di-commit):
```dotenv
TURSO_DATABASE_URL=libsql://your-database-name.turso.io
TURSO_AUTH_TOKEN=your-auth-token
```

**File `.env`** (nilai asli, di-ignore oleh git):
```dotenv
TURSO_DATABASE_URL=libsql://your-database-name.turso.io
TURSO_AUTH_TOKEN=eyJhbGciOi...token-asli-kamu...
```

> Isi nilai sebenarnya akan diambil pada langkah [1.3.1](#131-buat-database-di-turso).

---

## 1.2. Setup Dependensi & Code Generation

### 1.2.1 Tambahkan dependensi di `pubspec.yaml`

Buka `pubspec.yaml` lalu tambahkan dependensi berikut pada bagian `dependencies` dan `dev_dependencies`:

**`dependencies` (runtime):**
```yaml
dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_riverpod: ^3.0.0
  riverpod_annotation: ^3.0.0

  # Code Gen & Model
  freezed_annotation: ^2.4.0
  json_annotation: ^4.9.0

  # Utils
  flutter_dotenv: ^5.1.0
  uuid: ^4.5.0
  # cek versi terbaru pada bagian 1.3.2
  libsql_dart: ^0.9.0+0.9.30   # contoh; sesuaikan dengan versi aktual
```

**`dev_dependencies`:**
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter

  # Code generation
  build_runner: ^2.4.0
  riverpod_generator: ^3.0.0
  freezed: ^2.5.0
  json_serializable: ^6.8.0
```

> **Penting**: Angka versi di atas (`^x.y.z`) adalah **contoh**. Selalu gunakan versi terbaru yang tersedia. Cara termudah:
> ```bash
> flutter pub add flutter_riverpod riverpod_annotation freezed_annotation json_annotation flutter_dotenv uuid
> flutter pub add --dev build_runner riverpod_generator freezed json_serializable
> ```
> Perintah `flutter pub add` akan otomatis mengambil versi terbaru yang kompatibel.

Setelah itu jalankan:
```bash
flutter pub get
```

### 1.2.2 Jalankan `build_runner` untuk menguji generator

Jalankan perintah berikut untuk memastikan generator berfungsi dengan baik:

```bash
dart run build_runner build
```

Jika belum ada file yang membutuhkan generasi, perintah ini akan berhasil dijalankan tanpa output error. Untuk menguji bahwa generator benar-benar bekerja, kamu bisa membuat struktur model minimal Freezed pada langkah Fase 2. Untuk kebutuhan Fase 1, cukup pastikan perintah di atas tidak error.

> Untuk mode *watch* (otomatis regenerate saat file berubah):
> ```bash
> dart run build_runner watch
> ```

---

## 1.3. Integrasi Turso DB (LibSQL Client)

### 1.3.1 Buat database baru di Turso CLI / Console

**Opsi A — Via Console (UI):**
1. Login/daftar di [https://console.turso.io](https://console.turso.io).
2. Klik **Create New Database**.
3. Isi nama database (misal: `finance_tracker`), pilih lokasi, lalu **Create**.
4. Salin `URL` dan `Auth Token` yang ditampilkan.

**Opsi B — Via CLI:**
```bash
# Install Turso CLI (jika belum):
# macOS/Linux: curl -sSfL https://get.turso.tech/install.sh | bash
# Windows (via scoop): scoop install turso
# (kunjungi docs Turso untuk metode instalasi pada sistem operasi kamu)

turso auth login
turso db create finance_tracker
turso db show finance_tracker
```

Catat nilai yang dihasilkan, lalu isi ke file `.env`:
- `TURSO_DATABASE_URL` = URL yang diberikan (biasanya `libsql://...turso.io`)
- `TURSO_AUTH_TOKEN` = Auth Token

### 1.3.2 Tambahkan package Klien LibSQL (libsql_dart)

Untuk aplikasi Flutter, kamu perlu client LibSQL.

**Rekomendasi**: gunakan package [`libsql_dart`](https://pub.dev/packages/libsql_dart) (client LibSQL/Turso untuk Dart & Flutter).

```bash
flutter pub add libsql_dart
```

> **Catatan**: Package `libsql_dart` mendukung local, remote, dan embedded replica. Untuk panduan ini kita fokus ke mode **remote** (koneksi langsung ke Turso).

> Untuk memastikan nama & versi package terbaru, cek di [pub.dev/packages/libsql_dart](https://pub.dev/packages/libsql_dart).

### 1.3.3 Buat class `TursoClient`

Buat folder `lib/src/core/database/`, lalu buat file `turso_client.dart`:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:libsql_dart/libsql_dart.dart';

class TursoClient {
  static LibsqlClient? _instance;

  // URL dan token dibaca dari environment (file .env)
  static String get _databaseUrl =>
      dotenv.env['TURSO_DATABASE_URL'] ??
      (throw StateError('TURSO_DATABASE_URL tidak di-set di .env'));

  static String get _authToken =>
      dotenv.env['TURSO_AUTH_TOKEN'] ??
      (throw StateError('TURSO_AUTH_TOKEN tidak di-set di .env'));

  /// Mengembalikan instance LibsqlClient (remote) sebagai singleton.
  /// Sebelum melakukan query/execute, wajib memanggil `client.connect()`.
  static LibsqlClient get client {
    _instance ??= LibsqlClient.remote(
      _databaseUrl,
      authToken: _authToken,
    );
    return _instance!;
  }
}
```

> **Catatan kritis**: Untuk `libsql_dart`, koneksi bersifat eksplisit. Kamu **wajib** memanggil `await client.connect()` sebelum menjalankan SQL apapun. Yang penting dalam class ini:
> 1. Membaca URL & token dari environment (jangan hardcode).
> 2. Menyimpan `LibsqlClient` instance sebagai singleton.
> 3. Menyediakan akses ke client untuk eksekusi SQL (execute / query).

### 1.3.4 Buat `tursoClientProvider` menggunakan Riverpod

Buat file `lib/src/core/database/turso_client_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libsql_dart/libsql_dart.dart';
import 'turso_client.dart';

/// Penyedia (provider) yang menyalurkan instance LibsqlClient ke seluruh layer.
/// Pastikan sudah menjalankan `await initDatabase()` (yang memanggil `connect()`)
/// sebelum provider ini dipakai untuk query/execute.
final tursoClientProvider = Provider<LibsqlClient>((ref) {
  return TursoClient.client;
});
```

Setelah dibuat, **wajib** menjalankan `build_runner`:

```bash
dart run build_runner build
```

> **Penjelasan**: `tursoClientProvider` akan dipakai oleh repository yang dibuat pada Fase 2–5 agar seluruh lapisan data memakai satu instance koneksi yang sama (dependency injection via Riverpod).

---

## 1.4. Perancangan Skema Database Initial (DDL SQL)

### 1.4.1 Tulis script DDL untuk tabel-tabel utama

Buat file `lib/src/core/database/schema.dart` yang berisi konstanta SQL untuk membuat tabel. Berikut DDL untuk 6 tabel utama:

```dart
const String kCreateWalletsTable = '''
CREATE TABLE IF NOT EXISTS wallets (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  type        TEXT NOT NULL,        -- Cash / Bank / E-Wallet
  balance     REAL NOT NULL DEFAULT 0,
  icon        TEXT,
  color       TEXT,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
''';

const String kCreateCategoriesTable = '''
CREATE TABLE IF NOT EXISTS categories (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  type        TEXT NOT NULL,        -- expense / income
  icon        TEXT,
  color       TEXT,
  is_default  INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
''';

const String kCreateTransactionsTable = '''
CREATE TABLE IF NOT EXISTS transactions (
  id               TEXT PRIMARY KEY,
  wallet_id        TEXT NOT NULL,
  category_id      TEXT,
  amount           REAL NOT NULL,
  type             TEXT NOT NULL,   -- income / expense
  transaction_date TEXT NOT NULL,
  note             TEXT,
  created_at       TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (wallet_id)   REFERENCES wallets(id)    ON DELETE CASCADE,
  FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
);
''';

const String kCreateBudgetsTable = '''
CREATE TABLE IF NOT EXISTS budgets (
  id           TEXT PRIMARY KEY,
  category_id  TEXT NOT NULL,
  amount_limit REAL NOT NULL,
  month_year   TEXT NOT NULL,       -- format YYYY-MM
  created_at   TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(category_id, month_year),
  FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
);
''';

const String kCreateSavingsGoalsTable = '''
CREATE TABLE IF NOT EXISTS savings_goals (
  id             TEXT PRIMARY KEY,
  title          TEXT NOT NULL,
  target_amount  REAL NOT NULL,
  current_amount REAL NOT NULL DEFAULT 0,
  target_date    TEXT,
  created_at     TEXT NOT NULL DEFAULT (datetime('now'))
);
''';

const String kCreateRecurringRulesTable = '''
CREATE TABLE IF NOT EXISTS recurring_rules (
  id             TEXT PRIMARY KEY,
  wallet_id      TEXT NOT NULL,
  category_id    TEXT,
  amount         REAL NOT NULL,
  type           TEXT NOT NULL,     -- income / expense
  frequency      TEXT NOT NULL,     -- daily / weekly / monthly
  next_run_date  TEXT NOT NULL,
  note           TEXT,
  FOREIGN KEY (wallet_id)   REFERENCES wallets(id)    ON DELETE CASCADE,
  FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
);
''';

/// Semua statemen DDL digabung, dijalankan berurutan saat init.
const List<String> kInitSchemas = [
  kCreateWalletsTable,
  kCreateCategoriesTable,
  kCreateTransactionsTable,
  kCreateBudgetsTable,
  kCreateSavingsGoalsTable,
  kCreateRecurringRulesTable,
];
```

### 1.4.2 Buat fungsi `initDatabase()`

Buat fungsi yang mengeksekusi pembuatan tabel saat aplikasi pertama kali diinisialisasi. Letakkan di `lib/src/core/database/turso_client.dart` atau file `database_init.dart`:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'schema.dart';
import 'turso_client.dart';

/// Inisialisasi database: load env, connect ke Turso, jalankan DDL untuk membuat tabel.
/// Dipanggil sekali saat aplikasi pertama kali dibuka.
Future<void> initDatabase() async {
  // 1. Load file .env agar URL & token tersedia
  await dotenv.load();

  // 2. Ambil instance client & lakukan connect
  final client = TursoClient.client;
  await client.connect();

  // 3. Eksekusi semua statemen DDL berurutan (pakai execute untuk DDL)
  for (final schema in kInitSchemas) {
    await client.execute(schema);
  }
}
```

### 1.4.3 Memanggil `initDatabase()` di `main.dart`

Ubah `lib/main.dart` agar memanggil `initDatabase()` sebelum aplikasi dirender:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/core/database/turso_client.dart';
import 'app.dart'; // sesuaikan dengan file root aplikasi kamu

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi database (load env + buat tabel)
  await initDatabase();

  runApp(
    const ProviderScope(
      child: FinanceTrackerApp(),
    ),
  );
}
```

> **Catatan**: `ProviderScope` dari `flutter_riverpod` membungkus seluruh aplikasi agar semua provider (termasuk `tursoClientProvider`) tersedia.

---

## Checklist Verifikasi Fase 1

Gunakan checklist ini untuk memastikan Fase 1 selesai:

- [ ] `flutter create finance_tracker` berhasil dijalankan.
- [ ] Struktur folder `lib/src/core`, `lib/src/features`, `lib/src/shared` sudah dibuat.
- [ ] `.gitignore` mengecualikan `.env`, `*.g.dart`, `*.freezed.dart`.
- [ ] File `.env` dan `.env.example` terbuat dengan `TURSO_DATABASE_URL` & `TURSO_AUTH_TOKEN`.
- [ ] Semua dependensi di `pubspec.yaml` terpasang.
- [ ] `dart run build_runner build` berjalan tanpa error.
- [ ] Database Turso berhasil dibuat & kredensial tercatat di `.env`.
- [ ] Package client LibSQL (`libsql_dart`) terpasang.
- [ ] Class `TursoClient` dibuat di `core/database/turso_client.dart` menggunakan `LibsqlClient.remote(...)`.
- [ ] `tursoClientProvider` (Riverpod) dibuat & digunakan untuk inject `LibsqlClient`.
- [ ] DDL untuk 6 tabel utama (`wallets`, `categories`, `transactions`, `budgets`, `savings_goals`, `recurring_rules`) tersedia.
- [ ] Fungsi `initDatabase()` dibuat & dipanggil di `main.dart`.
- [ ] Aplikasi dapat dijalankan (`flutter run`) tanpa error saat inisialisasi.

---

## Catatan Teknis Penting

1. **Versi package**: Selalu gunakan versi stabil terbaru. Sebelum implementasi, cek dokumentasi package `libsql_dart` (supaya API koneksi database akurat) dan dokumentasi `flutter_riverpod` / `riverpod_generator` (untuk sintaks codegen terbaru).
2. **Jangan commit secret**: File `.env` berisi token Turso dan harus selalu di-ignore git.
3. **URL malam**. Konversi `libsql://` menjadi `https://` jika diperlukan oleh client HTTP/Turso tertentu.
4. **Penamaan**: Gunakan `TURSO_DATABASE_URL` dan `TURSO_AUTH_TOKEN` secara konsisten agar mudah dibaca di environment.
