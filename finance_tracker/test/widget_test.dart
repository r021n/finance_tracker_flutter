import 'package:finance_tracker/src/features/wallets/providers/wallet_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_tracker/main.dart';

void main() {
  testWidgets('WalletListScreen renders empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletListProvider.overrideWith((ref) {
            final notifier = _FakeWalletListNotifier();
            return notifier;
          }),
        ],
        child: const FinanceTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Belum ada dompet. Ketuk + untuk membuat.'),
      findsOneWidget,
    );
  });
}
