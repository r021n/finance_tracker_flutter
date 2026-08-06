# Phase 2 - Fixed Code Guide

Dokumentasi ini berisi perbaikan error yang ditemukan dan sudah teruji.

## Error yang Ditemukan

### 1. Test File Error (`test/widget_test.dart`)

**Error:**
```
error - The argument type 'InvalidType Function(dynamic)' can't be assigned to the parameter type 'WalletListNotifier Function()'.
error - The function '_FakeWalletListNotifier' isn't defined.
```

**Penyebab:**
- `_FakeWalletListNotifier` tidak didefinisikan
- `overrideWith` menggunakan signature yang salah (parameter `ref` tidak diperlukan)

**Kode yang Benar:**

```dart
import 'package:finance_tracker/src/features/wallets/domain/wallet.dart';
import 'package:finance_tracker/src/features/wallets/providers/wallet_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_tracker/main.dart';

class _FakeWalletListNotifier extends WalletListNotifier {
  @override
  Future<List<Wallet>> build() async => [];
}

void main() {
  testWidgets('WalletListScreen renders empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletListProvider.overrideWith(() {
            return _FakeWalletListNotifier();
          }),
        ],
        child: const FinanceTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Belum ada dompet. Ketuk + untuk membuat'),
      findsOneWidget,
    );
  });
}
```

**Penjelasan Perbaikan:**

1. **Import `wallet.dart`** - Diperlukan untuk menggunakan class `Wallet`
2. **Definisi `_FakeWalletListNotifier`** - Harus extends class generated (`WalletListNotifier`) dan override method `build()`
3. **Signature `overrideWith`** - Untuk `AsyncNotifier`, gunakan `() =>` bukan `(ref) =>` karena notifier tidak menerima `ref` langsung
4. **Teks yang dicari** - Sesuaikan dengan text aktual di widget (`"Belum ada dompet. Ketuk + untuk membuat"` tanpa titik)

## Verifikasi

Jalankan perintah berikut untuk memastikan tidak ada error:

```bash
flutter analyze
flutter test
```

**Hasil yang diharapkan:**
```
Analyzing finance_tracker...
No issues found!

00:00 +1: All tests passed!
```

## Catatan Penting

- File `.g.dart` (generated) tidak perlu diubah
- pastikan `build_runner` sudah dijalankan sebelumnya jika ada perubahan pada provider
- Gunakan `flutter_riverpod: 3.2.1` sesuai yang tercantum di `pubspec.yaml`
