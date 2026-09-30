import 'package:budgly/src/core/extensions/color.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:flutter/material.dart';

@immutable
class Category {
  final String? id;
  final String? name;
  final Color? color;
  final String? iconCode;
  final CategoryIcon? icon;
  final String accountId;
  final double? monthlyThreshold;

  const Category({
    this.id,
    this.name,
    this.color,
    this.icon,
    this.iconCode,
    required this.accountId,
    this.monthlyThreshold,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'],
    name: json['name'],
    color: json['color'] != null ? HexColor.fromHex(json['color']) : null,
    iconCode: json["icon"],
    accountId: json['account_id'],
    monthlyThreshold: (json['monthly_threshold'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'color': color?.toHex(),
      'icon': icon != null ? '0x${icon!.iconCode.toRadixString(16)}' : iconCode,
      'account_id': accountId,
      if (monthlyThreshold != null) 'monthly_threshold': monthlyThreshold,
    };
  }

  Category copyWith({
    String? id,
    String? name,
    Color? color,
    CategoryIcon? icon,
    Account? account,
    double? monthlyThreshold,
    bool clearMonthlyThreshold = false,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      iconCode: icon != null
          ? '0x${icon.iconCode.toRadixString(16)}'
          : iconCode,
      accountId: account?.id ?? accountId,
      monthlyThreshold: clearMonthlyThreshold
          ? null
          : (monthlyThreshold ?? this.monthlyThreshold),
    );
  }

  // Same convention as Account: two Category instances represent the same
  // domain entity when they share the same server-assigned id, regardless
  // of which fields have since been edited on either copy.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Category) return false;
    if (id == null || other.id == null) return false;
    return other.id == id;
  }

  @override
  int get hashCode => id == null ? identityHashCode(this) : id.hashCode;
}
