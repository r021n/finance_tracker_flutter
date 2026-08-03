# Panduan Implementasi Fase 2 — Manajemen Multi-Dompet & Kategori

> Proyek: `finance_tracker` (Flutter)
> Referensi: `project.md` — Fase 2: Manajemen Multi-Dompet & Kategori (Core Data Engine)
> Status Prasyarat: Fase 1 selesai (Turso DB + `TursoClient` + `tursoClientProvider` sudah jalan)

---

## 0. Konteks & Versi Dependensi

Kode pada panduan ini **ditulis khusus untuk versi dependensi yang sudah ter-pin** di
`finance_tracker/pubspec.yaml` (bukan dokumentasi terbaru). Pastikan tidak meng-upgrade
versi berikut di luar kendali tanpa menyesuaikan kode.

| Package | Versi di `pubspec.yaml` | Yang dipakai di panduan |
|---|---|---|
| `flutter_riverpod` | `3.2.1` | `@riverpod`, `AsyncNotifier`, `ConsumerWidget`, `AsyncValue` |
| `riverpod_annotation` | `^4.0.2` | Anotasi `@Riverpod`/`@riverpod`, `part 'xxx.g.dart'` |
| `riverpod_generator` | `4.0.3` | Codegen provider dari class `_$XxxNotifier` |
| `freezed` / `freezed_annotation` | `3.2.5` / `^3.1.0` | `@freezed` + `part 'xxx.freezed.dart'` |
| `json_annotation` | `4.9.0` | `@JsonSerializable`, `@JsonKey`, `@Default` |
| `json_serializable` | `6.11.4` | Generate `fromJson`/`toJson` |
| `build_runner` | `^2.15.1` | Perintah build codegen |
| `flutter_dotenv` | `^6.0.1` | `dotenv.load()` (sudah di `initDatabase`) |
| `uuid` | `^4.6.0` | `Uuid().v4()` untuk ID record |
| `http` | `^1.2.0` | HTTP client Turso (sudah di `TursoClient`) |

Catatan perbedaan kecil dengan dokumentasi terbaru (2026): dokumentasi Riverpod kini
menunjuk `flutter_riverpod ^3.4.x` + `riverpod_annotation ^4.0.x` + `riverpod_generator
^4.0.x`, dan `json_serializable ^6.14`. **Syntax yang dipakai di sini tetap valid** untuk
versi ter-pin karena Riverpod 3.x tidak mengubah API `@riverpod`/`AsyncNotifier`, dan
`json_serializable` 6.x memakai anotasi yang sama.

---

## 1. Persiapan Sebelum Coding

### 1.1. Aktifkan kode generation (pertama kali)

Karena semua model memakai `@freezed` + `@riverpod`, kita perlu memastikan toolchain
codegen jalan. Jangan lupa ini adalah pertama kalinya `build_runner` dijalankan di proyek
(merupakan checklist Fase 1 yang belum tervalidasi).

```bash
# dari folder finance_tracker/
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

> Gunakan `dart run build_runner watch` selama proses development agar file `.g.dart` dan
> `.freezed.dart` ter-regenerate otomatis setiap file berubah.

### 1.2. Sembunyikan warning `invalid_annotation_target`

freezed 3.x berjalan bersama `json_serializable`; untuk menghindari warning
`invalid_annotation_target` pada generated code, tambahkan blok berikut di
`analysis_options.yaml` (rekomendasi resmi dari dokumentasi freezed 3.2.5):

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  errors:
    invalid_annotation_target: ignore

linter:
  rules:
```

---

## 2. Domain Dompet (Wallets)

Struktur folder yang akan dibuat:

```
lib/src/features/wallets/
├── domain/
│   └── wallet.dart              # Model + enum (freezed + json)
├── data/
│   └── wallet_repository.dart   # Akses Turso DB
├── providers/
│   └── wallet_providers.dart    # Riverpod codegen
└── presentation/
    ├── wallet_list_screen.dart
    ├── add_edit_wallet_bottom_sheet.dart
    └── widgets/
        └── wallet_card.dart
```

### 2.1. Model `Wallet` (`@freezed`)

Buat `lib/src/features/wallets/domain/wallet.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet.freezed.dart';
part 'wallet.g.dart';

enum WalletType { cash, bank, eWallet }

@freezed
abstract class Wallet with _$Wallet {
  const Wallet._();

  const factory Wallet({
    required String id,
    required String name,
    required WalletType type,
    @Default(0.0) double balance,
    String? icon,
    String? color,
    String? createdAt,
  }) = _Wallet;

  factory Wallet.fromJson(Map<String, dynamic> json) => _$WalletFromJson(json);
}
```

Poin penting:

- `@JsonSerializable` tidak perlu ditulis manual karena freezed otomatis menautkan
  `json_serializable` selama ada `part 'wallet.g.dart'` dan factory `fromJson` memakai `=>`.
- Nama field pakai **camelCase** (`createdAt`, `balance`); kolom DB snake_case
  (`created_at`) dipetakan lewat `fieldRename: FieldRename.snake` yang **harus**
  ditambahkan via `build.yaml` atau per-kelas. Cara paling sederhana & konsisten: buat
  file `build.yaml` di root proyek (di sebelah `pubspec.yaml`):

```yaml
targets:
  $default:
    builders:
      json_serializable:
        options:
          field_rename: snake
          explicit_to_json: true
```

  > Dengan `field_rename: snake` global, `createdAt` ↔ `created_at`, `isDefault` ↔
  > `is_default` dipetakan otomatis. Ini membuat `Wallet.fromJson(row)` bisa dipakai
  > langsung terhadap hasil `query()` Turso yang ber-key nama kolom asli (snake_case).

- `enum WalletType { cash, bank, eWallet }` disimpan ke DB sebagai `.name`
  (`'cash'`, `'bank'`, `'eWallet'`) dan dibaca balik dengan cara yang sama oleh
  `json_serializable` (default enum encoding memakai `.name`). Pastikan konsisten saat
  menulis ke DB di repository.
- Konstruktor `const Wallet._();` diperlukan agar kita bisa menambahkan getter/method
  sendiri jika dibutuhkan di kemudian hari (mis. `formattedBalance`).

### 2.2. `WalletRepository`

Buat `lib/src/features/wallets/data/wallet_repository.dart`:

```dart
import 'package:uuid/uuid.dart';

import '../../../core/database/turso_client.dart';
import '../domain/wallet.dart';

const _uuid = Uuid();

class WalletRepository {
  WalletRepository(this._client);

  final TursoClient _client;

  Future<List<Wallet>> getWallets() async {
    final rows = await _client.query(
      'SELECT * FROM wallets ORDER BY created_at ASC',
    );
    return rows.map(Wallet.fromJson).toList();
  }

  Future<Wallet> createWallet({
    required String name,
    required WalletType type,
    required double initialBalance,
    String? icon,
    String? color,
  }) async {
    final now = DateTime.now().toIso8601String();
    final wallet = Wallet(
      id: _uuid.v4(),
      name: name,
      type: type,
      balance: initialBalance,
      icon: icon,
      color: color,
      createdAt: now,
    );

    await _client.execute(
      '''
      INSERT INTO wallets (id, name, type, balance, icon, color, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      args: [
        wallet.id,
        wallet.name,
        wallet.type.name,
        wallet.balance,
        wallet.icon,
        wallet.color,
        wallet.createdAt,
      ],
    );
    return wallet;
  }

  Future<void> updateWallet(Wallet wallet) async {
    await _client.execute(
      '''
      UPDATE wallets
      SET name = ?, type = ?, icon = ?, color = ?
      WHERE id = ?
      ''',
      args: [
        wallet.name,
        wallet.type.name,
        wallet.icon,
        wallet.color,
        wallet.id,
      ],
    );
  }

  Future<void> deleteWallet(String id) async {
    await _client.execute(
      'DELETE FROM wallets WHERE id = ?',
      args: [id],
    );
  }
}
```

Catatan:

- Saldo awal hanya di-set saat `createWallet`; `updateWallet` **tidak** menyentuh kolom
  `balance` (mutasi saldo baru diolah di Fase 3 saat pencatatan transaksi).
- `?` di SQL terisi oleh `args` yang di-encode `TursoClient._encodeArg`.
- ID memakai `Uuid().v4()`.

### 2.3. State Management Dompet (Riverpod codegen)

Buat `lib/src/features/wallets/providers/wallet_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/turso_client_provider.dart';
import '../data/wallet_repository.dart';
import '../domain/wallet.dart';

part 'wallet_providers.g.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(tursoClientProvider));
});

@Riverpod(keepAlive: true)
class WalletListNotifier extends _$WalletListNotifier {
  @override
  Future<List<Wallet>> build() async {
    return ref.watch(walletRepositoryProvider).getWallets();
  }

  Future<void> addWallet({
    required String name,
    required WalletType type,
    required double initialBalance,
    String? icon,
    String? color,
  }) async {
    final wallet = await ref
        .read(walletRepositoryProvider)
        .createWallet(
          name: name,
          type: type,
          initialBalance: initialBalance,
          icon: icon,
          color: color,
        );
    final current = await future;
    state = AsyncData([...current, wallet]);
  }

  Future<void> editWallet(Wallet wallet) async {
    await ref.read(walletRepositoryProvider).updateWallet(wallet);
    final current = await future;
    state = AsyncData([
      for (final w in current) w.id == wallet.id ? wallet : w,
    ]);
  }

  Future<void> removeWallet(String id) async {
    await ref.read(walletRepositoryProvider).deleteWallet(id);
    final current = await future;
    state = AsyncData([
      for (final w in current) if (w.id != id) w,
    ]);
  }
}
```

Poin penting Riverpod 3.x + riverpod_generator 4.x:

- `@Riverpod(keepAlive: true)` membuat provider **tidak** autoDispose, sehingga daftar
  dompet tidak di-fetch ulang setiap kali layar dibuka. Jika ingin autoDispose (data
  selalu fresh dari DB saat layar dibuka), ganti anotasi menjadi `@riverpod` polos.
- Class notifier harus bernama `WalletListNotifier` dan extends `_$WalletListNotifier`.
  Provider yang di-generate otomatis bernama `walletListNotifierProvider`.
- `build()` berisi inisialisasi async → otomatis menjadi `AsyncValue<List<Wallet>>`.
- Method mutasi menggunakan `await future` untuk menunggu state awal selesai di-load,
  lalu menimpa `state` dengan `AsyncData(...)` — tidak perlu `try/catch` manual.
- Nama file provider menyimpan `part 'wallet_providers.g.dart';` (sesuai nama file).

### 2.4. Widget & Halaman UI Dompet

#### a) Helper format uang

Buat `lib/src/core/utils/currency_formatter.dart`:

```dart
String formatCurrency(num amount) {
  final parts = amount.toStringAsFixed(2).split('.');
  final buffer = StringBuffer();
  for (var i = 0; i < parts[0].length; i++) {
    if (i > 0 && (parts[0].length - i) % 3 == 0) buffer.write('.');
    buffer.write(parts[0][i]);
  }
  return 'Rp ${buffer.toString()},${parts[1]}';
}
```

#### b) Helper warna (hex ↔ `Color`)

Buat `lib/src/core/utils/color_utils.dart`:

```dart
import 'package:flutter/material.dart';

Color colorFromHex(String? hex, {Color fallback = Colors.green}) {
  if (hex == null || hex.isEmpty) return fallback;
  var value = hex.replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

String colorToHex(Color color) {
  final rgb = (color.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0');
  return '#${rgb.toUpperCase()}';
}
```

> `color.toARGB32()` tersedia di Flutter versi SDK `^3.10.4` yang dipakai proyek ini.
> Jika SDK yang digunakan lebih lama, gunakan `(color.toARGB32 ...)` sudah cukup, atau
> fallback `color.value & 0x00FFFFFF` (deprecated di SDK baru).

#### c) Daftar ikon yang bisa dipilih

Buat `lib/src/shared/constants/app_icons.dart`:

```dart
import 'package:flutter/material.dart';

const Map<String, IconData> kAppIcons = {
  'wallet': Icons.account_balance_wallet,
  'cash': Icons.payments,
  'bank': Icons.account_balance,
  'food': Icons.restaurant,
  'transport': Icons.directions_bus,
  'bill': Icons.receipt_long,
  'fun': Icons.sports_esports,
  'shopping': Icons.shopping_bag,
  'health': Icons.medical_services,
  'salary': Icons.payments_outlined,
  'bonus': Icons.card_giftcard,
  'investment': Icons.trending_up,
  'star': Icons.star,
  'other': Icons.category,
};

IconData iconFromName(String? name) {
  if (name == null) return Icons.category;
  return kAppIcons[name] ?? Icons.category;
}
```

#### d) `WalletCard`

Buat `lib/src/features/wallets/presentation/widgets/wallet_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/constants/app_icons.dart';
import '../../domain/wallet.dart';

class WalletCard extends ConsumerWidget {
  const WalletCard({super.key, required this.wallet, this.onTap});

  final Wallet wallet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = colorFromHex(wallet.color);
    final typeLabel = switch (wallet.type) {
      WalletType.cash => 'Cash',
      WalletType.bank => 'Bank',
      WalletType.eWallet => 'E-Wallet',
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(iconFromName(wallet.icon), color: color),
        ),
        title: Text(wallet.name),
        subtitle: Text(typeLabel),
        trailing: Text(
          formatCurrency(wallet.balance),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ),
    );
  }
}
```

#### e) `AddEditWalletBottomSheet`

Buat `lib/src/features/wallets/presentation/add_edit_wallet_bottom_sheet.dart`.
Bottom sheet dipakai untuk mode **tambah** (kosong) maupun **edit** (data dompet lama).
Berisi: nama, tipe, saldo awal (hanya mode tambah), pemilih warna, pemilih ikon.

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/color_utils.dart';
import '../../../../shared/constants/app_icons.dart';
import '../domain/wallet.dart';
import '../providers/wallet_providers.dart';

class AddEditWalletBottomSheet extends ConsumerStatefulWidget {
  const AddEditWalletBottomSheet({super.key, this.wallet});

  final Wallet? wallet;

  @override
  ConsumerState<AddEditWalletBottomSheet> createState() =>
      _AddEditWalletBottomSheetState();
}

class _AddEditWalletBottomSheetState
    extends ConsumerState<AddEditWalletBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;

  late WalletType _type;
  late String _icon;
  late String _color;

  bool get _isEdit => widget.wallet != null;

  @override
  void initState() {
    super.initState();
    final w = widget.wallet;
    _nameController = TextEditingController(text: w?.name);
    _balanceController = TextEditingController(
      text: w == null ? '' : w.balance.toStringAsFixed(0),
    );
    _type = w?.type ?? WalletType.cash;
    _icon = w?.icon ?? 'wallet';
    _color = w?.color ?? '#4CAF50';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(walletListNotifierProvider.notifier);
    if (_isEdit) {
      final w = widget.wallet!;
      await notifier.editWallet(w.copyWith(name: _nameController.text, type: _type, icon: _icon, color: _color));
    } else {
      await notifier.addWallet(
        name: _nameController.text.trim(),
        type: _type,
        initialBalance: double.tryParse(_balanceController.text) ?? 0,
        icon: _icon,
        color: _color,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? 'Edit Dompet' : 'Tambah Dompet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Dompet',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            SegmentedButton<WalletType>(
              segments: const [
                ButtonSegment(value: WalletType.cash, label: Text('Cash')),
                ButtonSegment(value: WalletType.bank, label: Text('Bank')),
                ButtonSegment(value: WalletType.eWallet, label: Text('E-Wallet')),
              ],
              selected: {_type},
              onSelectionChanged: (selection) =>
                  setState(() => _type = selection.first),
            ),
            const SizedBox(height: 16),
            if (!_isEdit)
              TextFormField(
                controller: _balanceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Saldo Awal',
                  border: OutlineInputBorder(),
                ),
              ),
            if (!_isEdit) const SizedBox(height: 16),
            _ColorPickerField(
              selected: _color,
              onChanged: (value) => setState(() => _color = value),
            ),
            const SizedBox(height: 12),
            _IconPickerField(
              selected: _icon,
              onChanged: (value) => setState(() => _icon = value),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submit,
              child: Text(_isEdit ? 'Simpan' : 'Tambah'),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### f) Widget pemilih warna (`_ColorPickerField`)

Widget ini (dan pemilih ikon) sengaja ditulis sebagai **private widget dalam file yang
sama** agar file lebih ringkas. Jika ingin dipakai ulang di form lain (misal kategori),
pindahkan ke `lib/src/shared/widgets/` dan ubah nama menjadi `ColorPickerField`.

```dart
const _presetColors = [
  '#4CAF50', '#F44336', '#2196F3', '#FF9800', '#9C27B0',
  '#00BCD4', '#FFEB3B', '#795548', '#607D8B', '#E91E63',
];

class _ColorPickerField extends StatelessWidget {
  const _ColorPickerField({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedColor = colorFromHex(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Warna', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final hex in _presetColors)
              GestureDetector(
                onTap: () => onChanged(hex),
                child: CircleAvatar(
                  backgroundColor: colorFromHex(hex),
                  child: hex == selected
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Terpilih: $selectedColor',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
```

#### g) Widget pemilih ikon (`_IconPickerField`)

```dart
class _IconPickerField extends StatelessWidget {
  const _IconPickerField({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ikon', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in kAppIcons.entries)
              ChoiceChip(
                avatar: Icon(entry.value, size: 18),
                label: const SizedBox.shrink(),
                selected: entry.key == selected,
                onSelected: (_) => onChanged(entry.key),
              ),
          ],
        ),
      ],
    );
  }
}
```

#### h) `WalletListScreen`

Buat `lib/src/features/wallets/presentation/wallet_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/wallet_providers.dart';
import 'add_edit_wallet_bottom_sheet.dart';
import 'widgets/wallet_card.dart';

class WalletListScreen extends ConsumerWidget {
  const WalletListScreen({super.key});

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddEditWalletBottomSheet(),
    );
  }

  void _openEditSheet(BuildContext context, wallet) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddEditWalletBottomSheet(wallet: wallet),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletsAsync = ref.watch(walletListNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dompet')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddSheet(context),
        child: const Icon(Icons.add),
      ),
      body: walletsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gagal memuat dompet: $error'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(walletListNotifierProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (wallets) {
          if (wallets.isEmpty) {
            return const Center(child: Text('Belum ada dompet. Ketuk + untuk membuat.'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(walletListNotifierProvider.future),
            child: ListView.builder(
              itemCount: wallets.length,
              itemBuilder: (context, index) => WalletCard(
                wallet: wallets[index],
                onTap: () => _openEditSheet(context, wallets[index]),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

Poin penting:

- Pola `AsyncValue.when(loading/error/data)` adalah cara kanonik render state async.
- Error dilengkapi tombol retry: `ref.invalidate(walletListNotifierProvider)` akan
  mengulang `build()`.
- Pull-to-refresh memakai `ref.refresh(...future)`.

---

## 3. Domain Kategori (Categories)

Struktur folder:

```
lib/src/features/categories/
├── domain/
│   └── category.dart
├── data/
│   └── category_repository.dart   # CRUD + seed data
├── providers/
│   └── category_providers.dart
└── presentation/
    ├── category_list_screen.dart
    └── add_category_dialog.dart
```

### 3.1. Model `Category` (`@freezed`)

Buat `lib/src/features/categories/domain/category.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'category.freezed.dart';
part 'category.g.dart';

enum CategoryType { expense, income }

@freezed
abstract class Category with _$Category {
  const Category._();

  const factory Category({
    required String id,
    required String name,
    required CategoryType type,
    String? icon,
    String? color,
    @Default(false) bool isDefault,
    String? createdAt,
  }) = _Category;

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
}
```

Kolom `is_default` (snake_case) dipetakan ke `isDefault` secara otomatis oleh
`field_rename: snake` dari `build.yaml`.

### 3.2. `CategoryRepository` + Seed Data

Buat `lib/src/features/categories/data/category_repository.dart`:

```dart
import 'package:uuid/uuid.dart';

import '../../../core/database/turso_client.dart';
import '../domain/category.dart';

const _uuid = Uuid();

class CategoryRepository {
  CategoryRepository(this._client);

  final TursoClient _client;

  Future<List<Category>> getCategories() async {
    final rows = await _client.query(
      'SELECT * FROM categories ORDER BY created_at ASC',
    );
    return rows.map(Category.fromJson).toList();
  }

  Future<Category> createCategory({
    required String name,
    required CategoryType type,
    String? icon,
    String? color,
  }) async {
    final now = DateTime.now().toIso8601String();
    final category = Category(
      id: _uuid.v4(),
      name: name,
      type: type,
      icon: icon,
      color: color,
      isDefault: false,
      createdAt: now,
    );

    await _client.execute(
      '''
      INSERT INTO categories (id, name, type, icon, color, is_default, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      args: [
        category.id,
        category.name,
        category.type.name,
        category.icon,
        category.color,
        category.isDefault ? 1 : 0,
        category.createdAt,
      ],
    );
    return category;
  }

  Future<void> updateCategory(Category category) async {
    await _client.execute(
      '''
      UPDATE categories
      SET name = ?, icon = ?, color = ?
      WHERE id = ?
      ''',
      args: [category.name, category.icon, category.color, category.id],
    );
  }

  Future<void> deleteCategory(String id) async {
    await _client.execute(
      'DELETE FROM categories WHERE id = ?',
      args: [id],
    );
  }

  /// Menyisipkan kategori bawaan hanya jika tabel masih kosong.
  Future<void> seedDefaultCategoriesIfEmpty() async {
    final rows = await _client.query(
      'SELECT COUNT(*) AS count FROM categories',
    );
    final count = (rows.first['count'] as num).toInt();
    if (count > 0) return;

    for (final seed in _defaultCategories) {
      await _client.execute(
        '''
        INSERT INTO categories (id, name, type, icon, color, is_default, created_at)
        VALUES (?, ?, ?, ?, ?, 1, ?)
        ''',
        args: [
          _uuid.v4(),
          seed.name,
          seed.type.name,
          seed.icon,
          seed.color,
          DateTime.now().toIso8601String(),
        ],
      );
    }
  }

  static const _defaultCategories = [
    _CategorySeed('Makanan', CategoryType.expense, 'food', '#F44336'),
    _CategorySeed('Transportasi', CategoryType.expense, 'transport', '#2196F3'),
    _CategorySeed('Tagihan', CategoryType.expense, 'bill', '#FF9800'),
    _CategorySeed('Hiburan', CategoryType.expense, 'fun', '#9C27B0'),
    _CategorySeed('Belanja', CategoryType.expense, 'shopping', '#E91E63'),
    _CategorySeed('Kesehatan', CategoryType.expense, 'health', '#00BCD4'),
    _CategorySeed('Gaji', CategoryType.income, 'salary', '#4CAF50'),
    _CategorySeed('Bonus', CategoryType.income, 'bonus', '#FFEB3B'),
    _CategorySeed('Investasi', CategoryType.income, 'investment', '#607D8B'),
    _CategorySeed('Lainnya', CategoryType.income, 'other', '#795548'),
  ];
}

class _CategorySeed {
  const _CategorySeed(this.name, this.type, this.icon, this.color);

  final String name;
  final CategoryType type;
  final String icon;
  final String color;
}
```

Poin penting:

- `COUNT(*)` dibaca sebagai angka; gunakan `(rows.first['count'] as num).toInt()` agar
  aman baik Turso mengembalikan `int` maupun `double`.
- `is_default` ditulis sebagai `1`/`0` (kolom INTEGER), dan dibaca balik oleh
  `json_serializable` sebagai `bool` dari nilai `1`/`0` (json_serializable mengenali
  `0/1` sebagai `false/true` untuk field `bool`).
- Pemanggilan `seedDefaultCategoriesIfEmpty()` dilakukan di `build()` notifier (lihat
  3.3) sehingga seeding otomatis terjadi saat daftar kategori pertama kali dibuka.

### 3.3. `CategoryListNotifier` (Riverpod)

Buat `lib/src/features/categories/providers/category_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/turso_client_provider.dart';
import '../data/category_repository.dart';
import '../domain/category.dart';

part 'category_providers.g.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(tursoClientProvider));
});

@Riverpod(keepAlive: true)
class CategoryListNotifier extends _$CategoryListNotifier {
  @override
  Future<List<Category>> build() async {
    final repo = ref.watch(categoryRepositoryProvider);
    await repo.seedDefaultCategoriesIfEmpty();
    return repo.getCategories();
  }

  Future<void> addCategory({
    required String name,
    required CategoryType type,
    String? icon,
    String? color,
  }) async {
    final category = await ref
        .read(categoryRepositoryProvider)
        .createCategory(name: name, type: type, icon: icon, color: color);
    final current = await future;
    state = AsyncData([...current, category]);
  }

  Future<void> editCategory(Category category) async {
    await ref.read(categoryRepositoryProvider).updateCategory(category);
    final current = await future;
    state = AsyncData([
      for (final c in current) c.id == category.id ? category : c,
    ]);
  }

  Future<void> removeCategory(String id) async {
    await ref.read(categoryRepositoryProvider).deleteCategory(id);
    final current = await future;
    state = AsyncData([
      for (final c in current) if (c.id != id) c,
    ]);
  }
}
```

### 3.4. `CategoryListScreen` dengan TabBar

Buat `lib/src/features/categories/presentation/category_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/category.dart';
import '../providers/category_providers.dart';
import 'add_category_dialog.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../shared/constants/app_icons.dart';

class CategoryListScreen extends ConsumerWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryListNotifierProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kategori'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pengeluaran'),
              Tab(text: 'Pemasukan'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openAddDialog(context),
          child: const Icon(Icons.add),
        ),
        body: categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Gagal memuat kategori: $error')),
          data: (categories) => TabBarView(
            children: [
              _CategoryList(
                categories: categories
                    .where((c) => c.type == CategoryType.expense)
                    .toList(),
              ),
              _CategoryList(
                categories: categories
                    .where((c) => c.type == CategoryType.income)
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const AddCategoryDialog(),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.categories});

  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Center(child: Text('Belum ada kategori. Ketuk + untuk menambah.'));
    }
    return ListView.builder(
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final color = colorFromHex(category.color);
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(iconFromName(category.icon), color: color),
          ),
          title: Text(category.name),
          trailing: category.isDefault
              ? const Icon(Icons.auto_awesome, size: 16)
              : null,
        );
      },
    );
  }
}
```

> Catatan: widget pemilih warna & ikon pada dialog kategori dipakai ulang. Untuk itu,
> sebaiknya pindahkan `_ColorPickerField` dan `_IconPickerField` dari
> `add_edit_wallet_bottom_sheet.dart` ke `lib/src/shared/widgets/` (nama `ColorPickerField`
> dan `IconPickerField`) agar bisa di-import di kedua fitur. Panduan ini menampilkannya
> sekali; lakukan pemindahan itu bila ingin menghindari duplikasi.

### 3.5. `AddCategoryDialog`

Buat `lib/src/features/categories/presentation/add_category_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/category.dart';
import '../providers/category_providers.dart';

class AddCategoryDialog extends ConsumerStatefulWidget {
  const AddCategoryDialog({super.key, this.type = CategoryType.expense});

  final CategoryType type;

  @override
  ConsumerState<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends ConsumerState<AddCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  late CategoryType _type;
  late String _icon;
  late String _color;

  @override
  void initState() {
    super.initState();
    _type = widget.type;
    _icon = 'other';
    _color = '#4CAF50';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(categoryListNotifierProvider.notifier).addCategory(
          name: _nameController.text.trim(),
          type: _type,
          icon: _icon,
          color: _color,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Kategori'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nama Kategori',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              SegmentedButton<CategoryType>(
                segments: const [
                  ButtonSegment(
                    value: CategoryType.expense,
                    label: Text('Pengeluaran'),
                  ),
                  ButtonSegment(
                    value: CategoryType.income,
                    label: Text('Pemasukan'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) =>
                    setState(() => _type = selection.first),
              ),
              const SizedBox(height: 16),
              _DialogIconPicker(
                selected: _icon,
                onChanged: (value) => setState(() => _icon = value),
              ),
              const SizedBox(height: 12),
              _DialogColorPicker(
                selected: _color,
                onChanged: (value) => setState(() => _color = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}

class _DialogIconPicker extends StatelessWidget {
  const _DialogIconPicker({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final entry in kAppIcons.entries)
          ChoiceChip(
            avatar: Icon(entry.value, size: 18),
            label: const SizedBox.shrink(),
            selected: entry.key == selected,
            onSelected: (_) => onChanged(entry.key),
          ),
      ],
    );
  }
}

class _DialogColorPicker extends StatelessWidget {
  const _DialogColorPicker({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  static const _colors = [
    '#4CAF50', '#F44336', '#2196F3', '#FF9800', '#9C27B0',
    '#00BCD4', '#FFEB3B', '#795548', '#607D8B', '#E91E63',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final hex in _colors)
          GestureDetector(
            onTap: () => onChanged(hex),
            child: CircleAvatar(
              backgroundColor: colorFromHex(hex),
              child: hex == selected
                  ? const Icon(Icons.check, color: Colors.white)
                  : null,
            ),
          ),
      ],
    );
  }
}
```

---

## 4. Integrasi ke `main.dart`

Ubah `lib/main.dart` agar `home` menunjuk ke `WalletListScreen` (sekaligus memastikan
`ProviderScope` membungkus aplikasi):

```dart
import 'package:finance_tracker/src/core/database/database_init.dart';
import 'package:finance_tracker/src/features/wallets/presentation/wallet_list_screen.dart';
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
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: const WalletListScreen(),
    );
  }
}
```

Untuk mengecek layar kategori tanpa merombak navigasi, kamu bisa sementara mengganti
`home:` dengan `const CategoryListScreen()` (import dari
`package:finance_tracker/src/features/categories/presentation/category_list_screen.dart`).

---

## 5. Verifikasi

Jalankan secara berurutan dari folder `finance_tracker/`:

### 5.1. Generate kode

```bash
dart run build_runner build --delete-conflicting-outputs
```

Jika tidak ada error, akan muncul file baru:
- `wallet.freezed.dart`, `wallet.g.dart`
- `category.freezed.dart`, `category.g.dart`
- `wallet_providers.g.dart`, `category_providers.g.dart`

### 5.2. Analisis statis

```bash
flutter analyze
```

Harusnya `No issues found!`. Jika ada error terkait `_$WalletListNotifier` tidak dikenal,
berarti file `.g.dart` belum ter-generate (jalankan ulang build_runner).

### 5.3. Test

```bash
flutter test
```

> Catatan: test smoke bawaan (`widget_test.dart`) masih memanggil `FinanceTrackerApp`
> tanpa `initDatabase()`. Karena `home` sekarang `WalletListScreen` yang membaca provider
> (akses DB via Turso), test ini bisa gagal di lingkungan tanpa jaringan/DB. Untuk fase ini
> cukup: (1) perbarui smoke test menjadi sekadar memastikan aplikasi ter-render dengan
> mengetuk tombol tambah, atau (2) override provider di test. Panduan singkat override:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_tracker/src/features/wallets/providers/wallet_providers.dart';

void main() {
  testWidgets('WalletListScreen renders empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletListNotifierProvider.overrideWith((ref) {
            final notifier = _FakeWalletListNotifier();
            return notifier;
          }),
        ],
        child: const FinanceTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Belum ada dompet. Ketuk + untuk membuat.'), findsOneWidget);
  });
}
```

  (Implementasi `_FakeWalletListNotifier` menimpa `build()` agar mengembalikan daftar
  kosong tanpa menyentuh DB — detail kelas fiktif tersebut disesuaikan dengan struktur
  `_$WalletListNotifier` yang di-generate.)

### 5.4. Uji manual

1. `flutter run` → muncul layar **Dompet** (kosong, ada FAB `+`).
2. Ketuk `+` → isi nama, pilih tipe, saldo awal, warna, ikon → **Tambah**.
3. Dompet baru muncul dengan saldo & warna sesuai. Ketuk kartu → edit → **Simpan**.
4. (Opsional) set `home` ke `CategoryListScreen` → kategori bawaan otomatis ter-seed dan
   tampil terpisah di tab **Pengeluaran/Pemasukan**. Tambah kategori kustom → muncul di
   tab yang sesuai.
5. Matikan internet lalu buka kembali layar Dompet → pastikan muncul pesan error +
   tombol retry (perilaku async standard, bukan crash).

---

## 6. Checklist Fase 2

- [ ] **2.1** Model `Wallet` (`@freezed`) — `domain/wallet.dart`
- [ ] **2.1** `WalletRepository` — `getWallets`, `createWallet`, `updateWallet`, `deleteWallet`
- [ ] **2.2** `WalletListNotifier` (`@riverpod` / `@Riverpod(keepAlive: true)`) berbasis
      `AsyncNotifier<List<Wallet>>` dengan `addWallet`, `editWallet`, `removeWallet`
- [ ] **2.3** `WalletCard` (nama, jenis, saldo, warna)
- [ ] **2.3** `WalletListScreen`
- [ ] **2.3** `AddEditWalletBottomSheet` (nama, tipe Cash/Bank/E-Wallet, saldo awal,
      pemilih warna, pemilih ikon)
- [ ] **2.4** Model `Category` (`@freezed`)
- [ ] **2.4** `CategoryRepository` (CRUD) + `seedDefaultCategoriesIfEmpty()` (seed otomatis
      jika tabel kosong)
- [ ] **2.5** `CategoryListNotifier` (`AsyncNotifier<List<Category>>`)
- [ ] **2.5** `CategoryListScreen` dengan `TabBar` Pengeluaran/Pemasukan
- [ ] **2.5** `AddCategoryDialog`
- [ ] Verifikasi: `dart run build_runner build` ✓ `flutter analyze` ✓ `flutter test` ✓
