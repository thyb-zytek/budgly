import 'package:flutter/material.dart';

class CategoryIcon {
  final String iconName;
  final int iconCode;
  final String iconPack;
  final Map<String, String> labels;

  const CategoryIcon({
    required this.iconName,
    required this.iconCode,
    required this.iconPack,
    required this.labels,
  });

  factory CategoryIcon.fromJson(Map<String, dynamic> json) => CategoryIcon(
    iconName: json['icon_name'],
    iconCode: json['icon_code'] is String 
        ? int.parse(json['icon_code'] as String)
        : json['icon_code'] as int,
    iconPack: json['icon_pack'],
    labels: (json['labels'] as Map<String, dynamic>).map<String, String>(
      (String key, dynamic value) => MapEntry(key, value.toString()),
    ),
  );

  Map<String, dynamic> toJson() {
    return {
      'icon_name': iconName,
      'icon_code': iconCode,
      'icon_pack': iconPack,
      'labels': labels,
    };
  }

  IconData toIconData() {
    return IconData(
      // ignore: non_const_argument_for_const_parameter
      iconCode,
      // ignore: non_const_argument_for_const_parameter
      fontFamily: iconPack,
      matchTextDirection: true,
      fontPackage: null,
    );
  }

  CategoryIcon copyWith({
    String? iconName,
    int? iconCode,
    String? iconPack,
    Map<String, String>? labels,
  }) {
    return CategoryIcon(
      iconName: iconName ?? this.iconName,
      iconCode: iconCode ?? this.iconCode,
      iconPack: iconPack ?? this.iconPack,
      labels: labels ?? this.labels,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryIcon &&
        other.iconName == iconName &&
        other.iconCode == iconCode &&
        other.iconPack == iconPack;
  }

  @override
  int get hashCode {
    return iconName.hashCode ^ iconCode.hashCode ^ iconPack.hashCode;
  }
}
