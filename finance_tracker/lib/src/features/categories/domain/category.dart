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
