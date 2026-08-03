import "package:flutter/material.dart";

const Map<String, IconData> kAppIcons = {
  "wallet": Icons.account_balance_wallet,
  "cash": Icons.payments,
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
