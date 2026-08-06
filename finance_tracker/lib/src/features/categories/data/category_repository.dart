import 'package:uuid/uuid.dart';

import '../../../core/database/turso_client.dart';
import '../domain/category.dart';

const _uuid = Uuid();

class CategoryRepository {
  CategoryRepository(this._client);

  final TursoClient _client;

  Future<List<Category>> getCategories() async {
    final rows = await _client.query(
      "SELECT * FROM categories ORDER BY created_at ASC",
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
    await _client.execute('DELETE FROM categories WHERE id = ?', args: [id]);
  }

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
