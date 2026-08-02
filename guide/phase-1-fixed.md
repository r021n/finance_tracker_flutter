# Panduan Fix Fase 1 — Arsitektur Projek, Setup Turso DB, & Pondasi Riverpod

> Finance Tracker (Flutter) — Agustus 2026
> Dokumentasi berdasarkan versi terbaru: `flutter_riverpod 3.4.2`, `riverpod_annotation 4.0.6`, `freezed 3.2.5`, `libsql_dart 0.9.0+0.9.30`, `flutter_dotenv 6.0.1`

---

## Daftar Isi

1. [Ringkasan Status Fase 1](#ringkasan-status-fase-1)
2. [Versi Package Terbaru (Agustus 2026)](#versi-package-terbaru-agustus-2026)
3. [Fix #1: Registrasi Asset `.env` di `pubspec.yaml`](#fix-1-registrasi-asset-env-di-pubspecyaml)
4. [Fix #2: Lengkapi `main.dart` dengan Widget App](#fix-2-lengkapi-maindart-dengan-widget-app)
5. [Fix #3: Perbaiki Typo SQL di `schema.dart`](#fix-3-perbaiki-typo-sql-di-schemadart)
6. [Fix #4: Update Versi Package ke Stable](#fix-4-update-versi-package-ke-stable)
7. [Fix #5: Update Widget Test](#fix-5-update-widget-test)
8. [Verification Steps](#verification-steps)
9. [Re-check Phase 1 Checklist](#re-check-phase-1-checklist)

---

## Ringkasan Status Fase 1

| Item | Status | Keterangan |
|------|--------|------------|
| `flutter create finance_tracker` | ✅ Selesai | - |
| Struktur folder Feature-First | ✅ Selesai | `core/`, `features/`, `shared/` sudah ada |
| `.gitignore` konfigurasi | ✅ Selesai | Sudah include `.env`, `*.g.dart`, `*.freezed.dart` |
| File `.env` & `.env.example` | ✅ Selesai | Sudah terisi dengan kredensial Turso |
| Dependensi di `pubspec.yaml` | ⚠️ Perlu Update | Versi perlu diupdate ke stable terbaru |
| `dart run build_runner build` | ❓ Belum Diverifikasi | Perlu dijalankan setelah fix |
| Database Turso | ✅ Selesai | URL & token sudah ada di `.env` |
| `libsql_dart` package | ✅ Selesai | Versi `0.9.0+0.9.30` sudah benar |
| `TursoClient` class | ✅ Selesai | API sudah sesuai dokumentasi |
| `tursoClientProvider` | ✅ Selesai | Sudah benar |
| DDL 6 tabel | ⚠️ Ada Typo | `FOREGIN KEY` → `FOREIGN KEY`, `TEXT PRIMARY TEXT` → `TEXT PRIMARY KEY` |
| `initDatabase()` | ✅ Selesai | Sudah dipanggil di `main.dart` |
| `flutter_dotenv` asset | ❌ **CRITICAL** | `.env` belum didaftarkan sebagai asset |
| `FinanceTrackerApp` widget | ❌ **CRITICAL** | Widget belum didefinisikan |

**Kesimpulan: Fase 1 BELUM SIAP untuk lanjut ke Fase 2 karena ada 2 issue critical.**

---

## Versi Package Terbaru (Agustus 2026)

Berdasarkan pub.dev (diakses Agustus 2026):

| Package | Versi Terbaru Stable | Versi di `pubspec.yaml` | Status |
|---------|---------------------|------------------------|--------|
| `flutter_riverpod` | `^3.4.2` | `^3.3.2` | Perlu update |
| `riverpod_annotation` | `^4.0.6` | `^4.0.3` | Perlu update |
| `riverpod_generator` | `^4.0.8` | `^4.0.4` | Perlu update |
| `freezed` | `^3.2.5` | `^3.2.6-dev.1` | **GUNAKAN STABLE** |
| `freezed_annotation` | `^3.1.0` | `^3.1.0` | ✅ OK |
| `json_annotation` | `^4.12.0` | `^4.12.0` | ✅ OK |
| `json_serializable` | `^6.14.1` | `^6.14.1` | ✅ OK |
| `build_runner` | `^2.15.1` | `^2.15.1` | ✅ OK |
| `libsql_dart` | `^0.9.0+0.9.30` | `^0.9.0+0.9.30` | ✅ OK |
| `flutter_dotenv` | `^6.0.1` | `^6.0.1` | ✅ OK |
| `uuid` | `^4.6.0` | `^4.6.0` | ✅ OK |

> **Catatan**: `freezed: ^3.2.6-dev.1` adalah versi pre-release. Gunakan `^3.2.5` (stable) untuk production.

---

## Fix #1: Registrasi Asset `.env` di `pubspec.yaml`

### Issue

File `.env` **belum didaftarkan** sebagai asset di `pubspec.yaml`. Menurut dokumentasi `flutter_dotenv` (v6.0.1):

> **2. Register it as an asset** in `pubspec.yaml`:
> ```yaml
> flutter:
>   assets:
>     - .env
> ```

Tanpa ini, aplikasi akan **crash** dengan error `FileNotFoundError` saat runtime karena `flutter_dotenv` tidak bisa menemukan file `.env` di asset bundle.

### Solusi

Buka `pubspec.yaml` dan tambahkan bagian `assets` di bawah `flutter:`:

```yaml
flutter:
  uses-material-design: true

  assets:
    - .env
```

### File Lengkap `pubspec.yaml` (Bagian `flutter:`)

```yaml
flutter:
  uses-material-design: true

  assets:
    - .env

  # fonts:
  #   - family: Schyler
  #     fonts:
  #       - asset: fonts/Schyler-Regular.ttf
```

> **Catatan Penting**:
> - Pastikan path `.env` sesuai dengan lokasi file `.env` di root projek.
> - Jika menggunakan path berbeda (misal: `assets/.env`), sesuaikan juga `fileName` di `dotenv.load()`.

---

## Fix #2: Lengkapi `main.dart` dengan Widget App

### Issue

File `lib/main.dart` mendefinisikan `FinanceTrackerApp()` sebagai child dari `ProviderScope`, tetapi **widget tersebut belum didefinisikan**. Ini akan menyebabkan **compilation error**.

### Solusi

Buka `lib/main.dart` dan tambahkan widget `FinanceTrackerApp`:

```dart
import 'package:finance_tracker/src/core/database/database_init.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initDatabase();

  runApp(const ProviderScope(child: FinanceTrackerApp()));
}

class FinanceTrackerApp extends StatelessWidget {
  const FinanceTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finance Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Finance Tracker - Phase 1 Complete'),
        ),
      ),
    );
  }
}
```

> **Catatan**:
> - Widget `FinanceTrackerApp` adalah `StatelessWidget` dengan `MaterialApp`.
> - Tema sementara menggunakan `Colors.green` sebagai seed color. Akan diupdate di fase berikutnya.
> - `debugShowCheckedModeBanner: false` untuk menyembunyikan banner "DEBUG" di mode development.

---

## Fix #3: Perbaiki Typo SQL di `schema.dart`

### Issue

Terdapat **3 typo** di `lib/src/core/database/schema.dart` yang akan menyebabkan error saat eksekusi DDL:

| Lokasi | Typo | Seharusnya |
|--------|------|------------|
| `kCreateTransactionsTable` | `FOREGIN KEY` | `FOREIGN KEY` |
| `kCreateBudgetsTable` | `FOREGIN KEY` | `FOREIGN KEY` |
| `kCreateSavingsGoalsTable` | `TEXT PRIMARY TEXT` | `TEXT PRIMARY KEY` |

### Solusi

Buka `lib/src/core/database/schema.dart` dan perbaiki ketiga typo tersebut:

#### 1. `kCreateTransactionsTable` (baris ~35)

**Sebelum:**
```dart
  FOREGIN KEY (wallet_id)   REFERENCES wallets(id)    ON DELETE CASCADE,
```

**Sesudah:**
```dart
  FOREIGN KEY (wallet_id)   REFERENCES wallets(id)    ON DELETE CASCADE,
```

#### 2. `kCreateBudgetsTable` (baris ~48)

**Sebelum:**
```dart
  FOREGIN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
```

**Sesudah:**
```dart
  FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
```

#### 3. `kCreateSavingsGoalsTable` (baris ~54)

**Sebelum:**
```dart
  id              TEXT PRIMARY TEXT,
```

**Sesudah:**
```dart
  id              TEXT PRIMARY KEY,
```

### File Lengkap `schema.dart` (Setelah Perbaikan)

```dart
const String kCreateWalletsTable = '''
CREATE TABLE IF NOT EXISTS wallets (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  type        TEXT NOT NULL,      -- Cash / Bank / E-Wallet
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
  type        TEXT NOT NULL,      -- expense / income
  icon        TEXT,
  color       TEXT,
  is_default  INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
''';

const String kCreateTransactionsTable = '''
CREATE TABLE IF NOT EXISTS transactions (
  id                TEXT PRIMARY KEY,
  wallet_id         TEXT NOT NULL,
  category_id       TEXT,
  amount            REAL NOT NULL,
  type              TEXT NOT NULL,      -- income / expense
  transaction_date  TEXT NOT NULL,
  note              TEXT,
  created_at        TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (wallet_id)   REFERENCES wallets(id)    ON DELETE CASCADE,
  FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
);
''';

const String kCreateBudgetsTable = '''
CREATE TABLE IF NOT EXISTS budgets (
  id            TEXT PRIMARY KEY,
  category_id   TEXT NOT NULL,
  amount_limit  REAL NOT NULL,
  month_year    TEXT NOT NULL,      -- format YYYY-MM
  created_at    TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(category_id, month_year),
  FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
);
''';

const String kCreateSavingsGoalsTable = '''
CREATE TABLE IF NOT EXISTS savings_goals (
  id              TEXT PRIMARY KEY,
  title           TEXT NOT NULL,
  target_amount   REAL NOT NULL,
  current_amount  REAL NOT NULL DEFAULT 0,
  target_date     TEXT,
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);
''';

const String kCreateRecurringRulesTable = '''
CREATE TABLE IF NOT EXISTS recurring_rules (
  id            TEXT PRIMARY KEY,
  wallet_id     TEXT NOT NULL,
  category_id   TEXT,
  amount        REAL NOT NULL,
  type          TEXT NOT NULL,      -- income / expense
  frequency     TEXT NOT NULL,      -- daily / weekly / monthly
  next_run_date TEXT NOT NULL,
  note          TEXT,
  FOREIGN KEY (wallet_id)   REFERENCES wallets(id)    ON DELETE CASCADE,
  FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
);
''';

const List<String> kInitSchemas = [
  kCreateWalletsTable,
  kCreateCategoriesTable,
  kCreateTransactionsTable,
  kCreateBudgetsTable,
  kCreateSavingsGoalsTable,
  kCreateRecurringRulesTable,
];
```

---

## Fix #4: Update Versi Package ke Stable

### Issue

- `freezed: ^3.2.6-dev.1` menggunakan versi **pre-release/dev**. Untuk production, gunakan versi stable.
- Beberapa package lain masih bisa diupdate ke versi terbaru stable.

### Solusi

Buka `pubspec.yaml` dan update versi berikut:

#### `dependencies`

```yaml
dependencies:
  flutter:
    sdk: flutter

  cupertino_icons: ^1.0.8
  flutter_riverpod: ^3.4.2          # update dari ^3.3.2
  riverpod_annotation: ^4.0.6       # update dari ^4.0.3
  freezed_annotation: ^3.1.0        # sudah benar
  json_annotation: ^4.12.0          # sudah benar
  flutter_dotenv: ^6.0.1            # sudah benar
  uuid: ^4.6.0                      # sudah benar
  libsql_dart: ^0.9.0+0.9.30        # sudah benar
```

#### `dev_dependencies`

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter

  flutter_lints: ^6.0.0
  build_runner: ^2.15.1              # sudah benar
  riverpod_generator: ^4.0.8         # update dari ^4.0.4
  freezed: ^3.2.5                    # update dari ^3.2.6-dev.1 (GUNAKAN STABLE)
  json_serializable: ^6.14.1         # sudah benar
```

### Alternatif: Auto-Update Semua

Jalankan perintah berikut untuk otomatis update ke versi terbaru:

```bash
flutter pub add flutter_riverpod riverpod_annotation freezed_annotation json_annotation flutter_dotenv uuid libsql_dart
flutter pub add --dev build_runner riverpod_generator freezed json_serializable
```

> `flutter pub add` akan otomatis mengambil versi terbaru yang kompatibel.

---

## Fix #5: Update Widget Test

### Issue

File `test/widget_test.dart` masih menggunakan template default Flutter yang mereferensikan `MyApp` (yang tidak ada). Test akan **fail** saat dijalankan.

### Solusi

Buka `test/widget_test.dart` dan ganti isinya:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_tracker/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FinanceTrackerApp());

    expect(find.text('Finance Tracker - Phase 1 Complete'), findsOneWidget);
  });
}
```

---

## Verification Steps

Setelah semua fix diterapkan, jalankan langkah-langkah berikut untuk memverifikasi:

### 1. Clean & Install Dependencies

```bash
flutter clean
flutter pub get
```

### 2. Jalankan Code Generator

```bash
dart run build_runner build --delete-conflicting-outputs
```

> **Catatan**: Jika belum ada model Freezed, perintah ini akan berhasil tanpa output error. Ini normal untuk Fase 1.

### 3. Jalankan Flutter Analyze

```bash
flutter analyze
```

Pastikan tidak ada error. Warning kecil masih bisa diterima.

### 4. Jalankan Test

```bash
flutter test
```

Pastikan test passes.

### 5. Jalankan Aplikasi

```bash
flutter run
```

Pastikan aplikasi:
- Tidak crash saat startup
- Menampilkan layar dengan teks "Finance Tracker - Phase 1 Complete"
- Tidak ada error di console

### 6. Verifikasi Database

Periksa di Turso Console (https://console.turso.io) apakah tabel-tabel sudah terbuat:
- `wallets`
- `categories`
- `transactions`
- `budgets`
- `savings_goals`
- `recurring_rules`

---

## Re-check Phase 1 Checklist

Gunakan checklist ini untuk memastikan Fase 1 benar-benar selesai:

### 1.1. Inisialisasi Projek & Struktur Folder

- [x] `flutter create finance_tracker` berhasil dijalankan
- [x] Struktur folder `lib/src/core`, `lib/src/features`, `lib/src/shared` sudah dibuat
- [x] `.gitignore` mengecualikan `.env`, `*.g.dart`, `*.freezed.dart`
- [x] File `.env` dan `.env.example` terbuat dengan `TURSO_DATABASE_URL` & `TURSO_AUTH_TOKEN`

### 1.2. Setup Dependensi & Code Generation

- [x] Semua dependensi di `pubspec.yaml` terpasang dengan versi stable terbaru
- [ ] `dart run build_runner build` berjalan tanpa error

### 1.3. Integrasi Turso DB

- [x] Database Turso berhasil dibuat & kredensial tercatat di `.env`
- [x] Package client LibSQL (`libsql_dart`) terpasang
- [x] Class `TursoClient` dibuat di `core/database/turso_client.dart` menggunakan `LibsqlClient.remote(...)`
- [x] `tursoClientProvider` (Riverpod) dibuat & digunakan untuk inject `LibsqlClient`

### 1.4. Perancangan Skema Database Initial

- [x] DDL untuk 6 tabel utama tersedia tanpa typo
- [x] Fungsi `initDatabase()` dibuat & dipanggil di `main.dart`
- [x] Asset `.env` didaftarkan di `pubspec.yaml`
- [x] Widget `FinanceTrackerApp` didefinisikan di `main.dart`

### Final Check

- [ ] Aplikasi dapat dijalankan (`flutter run`) tanpa error saat inisialisasi
- [ ] Tabel-tabel database terbuat di Turso
- [ ] `flutter analyze` tidak menampilkan error
- [ ] `flutter test` passes

---

## Catatan Teknis Penting

1. **Versi Package**: Selalu gunakan versi **stable** terbaru. Hindari versi `-dev` atau `-alpha` untuk production.

2. **flutter_dotenv Asset**: File `.env` **wajib** didaftarkan sebagai asset di `pubspec.yaml`. Tanpa ini, aplikasi akan crash.

3. **Freezed 3.x Syntax**: Gunakan `abstract class` bukan `class` saat mendefinisikan model Freezed:
   ```dart
   @freezed
   abstract class Person with _$Person {
     const factory Person({required String name}) = _Person;
   }
   ```

4. **Riverpod Code Generation**: Selalu tambahkan `part 'filename.g.dart';` di file yang menggunakan `@riverpod` annotation.

5. **libsql_dart API**: Koneksi bersifat eksplisit. Wajib panggil `await client.connect()` sebelum menjalankan SQL.

6. **Jangan Commit Secret**: File `.env` berisi token Turso dan harus selalu di-ignore git.

---

## Setelah Fix Ini Selesai

Setelah semua fix di atas diterapkan dan diverifikasi, projek sudah siap untuk **Fase 2: Manajemen Multi-Dompet & Kategori (Core Data Engine)**.

Fase 2 meliputi:
- Model & Repository Dompet (`Wallet`, `WalletRepository`)
- State Management Dompet (Riverpod `AsyncNotifier`)
- UI Multi-Dompet (`WalletCard`, `WalletListScreen`, `AddEditWalletBottomSheet`)
- Model & Repository Kategori (`Category`, `CategoryRepository`)
- State Management & UI Kategori

---

*Dokumen ini dibuat berdasarkan dokumentasi pub.dev Agustus 2026.*
*Terakhir diperbarui: 3 Agustus 2026*
