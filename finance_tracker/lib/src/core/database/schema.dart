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
