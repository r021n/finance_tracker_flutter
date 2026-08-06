import "package:flutter_riverpod/flutter_riverpod.dart";
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
      for (final c in current)
        if (c.id != id) c,
    ]);
  }
}
