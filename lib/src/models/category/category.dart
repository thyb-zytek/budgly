import 'package:app/src/models/account/account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class Category {
  final String id;
  final String name;
  final Color color;
  final IconData? icon;
  final Account account;

  Category({
    required this.id,
    required this.name,
    required this.color,
    this.icon,
    required this.account,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      color: Color(json['color']),
      icon: IconData(int.parse(json['icon'])),
      account: Account.fromJson(json['account'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color.toHexString(),
      'icon': icon?.codePoint,
      'account': account.toJson(),
    };
  }
}
