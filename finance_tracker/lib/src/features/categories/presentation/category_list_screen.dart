import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/category.dart';
import '../providers/category_providers.dart';
import 'add_category_dialog.dart';
import '../../../core/utils/color_utils.dart';
import '../../../shared/constants/app_icons.dart';

class CategoryListScreen extends ConsumerWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryListProvider);

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
          error: (error, stack) =>
              Center(child: Text('Gagal memuat kategori: $error')),
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
      return const Center(
        child: Text('Belum ada kategori. Ketuk + untuk menambah.'),
      );
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
