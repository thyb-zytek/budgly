import 'dart:ui';

import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class Account {
  final String id;
  final String name;
  final Uri? picture;
  final Color? color;

  const Account({
    required this.id,
    required this.name,
    this.picture,
    this.color,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'],
      name: json['name'],
      picture: json['picture'] != null ? Uri.parse(json['picture']) : null,
      color: json['color'] != null ? Color(json['color']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'picture': picture?.toString(),
      'color': color?.toHexString(),
    };
  }
}
