import 'package:flutter/material.dart';
import 'package:app/src/shared/extensions/color.dart';

@immutable
class Account {
  final String? id;
  final String? userId;
  final String name;
  final String? picture;
  final String? pictureUrl;
  final Color? color;

  static const _sentinel = Object();

  const Account({
    this.id,
    this.userId,
    required this.name,
    this.picture,
    this.pictureUrl,
    this.color,
  });

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as String?,
    userId: json['user_id'] as String?,
    name: json['name'] as String,
    picture: json['picture'] != null ? json['picture'] as String : null,
    color: json['color'] != null ? HexColor.fromHex(json['color']) : null,
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'user_id': userId,
    'name': name,
    'picture': picture,
    'color': color!.toHex(),
  };

  Account copyWith({
  String? id,
  String? name,
  Object? picture = _sentinel,
  Object? pictureUrl = _sentinel,
  Color? color,
  String? userId,
}) {
  return Account(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    name: name ?? this.name,
    picture: picture == _sentinel ? this.picture : picture as String?,
    pictureUrl: pictureUrl == _sentinel ? this.pictureUrl : pictureUrl as String?,
    color: color ?? this.color,
  );
}

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Account && other.id == id;
  }
}
