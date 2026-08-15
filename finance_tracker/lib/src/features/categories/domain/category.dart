import 'package:freezed_annotation/freezed_annotation.dart';

part 'category.freezed.dart';
part 'category.g.dart';

enum CategoryType { expense, income }

bool _intToBool(dynamic value) => value == 1 || value == true;

@freezed
abstract class Category with _$Category {
  const Category._();

  const factory Category({
    required String id,
    required String name,
    required CategoryType type,
    String? icon,
    String? color,
    @JsonKey(fromJson: _intToBool) @Default(false) bool isDefault,
    String? createdAt,
  }) = _Category;

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
}
