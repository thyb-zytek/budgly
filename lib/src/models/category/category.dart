import 'package:app/src/core/extensions/color.dart';
import 'package:app/src/models/account/account.dart';
import 'package:app/src/models/category/category_icon.dart';
import 'package:flutter/material.dart';

class Category {
  final String? id;
  final String? name;
  final Color? color;
  final String? iconCode;
  final CategoryIcon? icon;
  final String accountId;

  Category({
    this.id,
    this.name,
    this.color,
    this.icon,
    this.iconCode,
    required this.accountId,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'],
    name: json['name'],
    color: HexColor.fromHex(json['color']),
    iconCode: json["icon"],
    accountId: json['account_id'],
  );

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'color': color?.toHex(),
      'icon': '0x${icon!.iconCode.toRadixString(16)}',
      'account_id': accountId,
    };
  }

  Category copyWith({
    String? id,
    String? name,
    Color? color,
    CategoryIcon? icon,
    Account? account,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      iconCode:
          icon != null ? '0x${icon.iconCode.toRadixString(16)}' : iconCode,
      accountId: account?.id ?? accountId,
    );
  }
}
