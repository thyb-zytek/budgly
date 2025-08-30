import 'dart:math';

import 'package:app/src/models/account/account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final Color color;
  final String themeMode;
  final String currency;
  final String language;
  final List<Account> accounts;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    Color? color,
    this.themeMode = 'system',
    this.currency = 'EUR',
    this.language = 'fr',
    List<Account>? accounts,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : color = color ?? UserProfile.generateRandomColor(),
       accounts = accounts ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['user_id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      color: json['color'] != null
          ? colorFromHex(json['color'] as String)
          : UserProfile.generateRandomColor(),
      themeMode: json['theme_mode']?.toString() ?? 'system',
      currency: json['currency']?.toString() ?? 'EUR',
      language: json['language']?.toString() ?? 'fr-FR',
      accounts: json['accounts'] != null
          ? (json['accounts'] as List)
              .map((account) => Account.fromJson(account))
              .toList()
          : [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'color': color.toHexString(),
      'theme_mode': themeMode,
      'currency': currency,
      'language': language,
      'accounts': accounts.map((account) => account.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? avatarUrl,
    Color? color,
    String? themeMode,
    String? currency,
    String? language,
    List<Account>? accounts,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      color: color ?? this.color,
      themeMode: themeMode ?? this.themeMode,
      currency: currency ?? this.currency,
      language: language ?? this.language,
      accounts: accounts ?? this.accounts,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  static Color generateRandomColor() {
    return Colors.primaries[Random().nextInt(Colors.primaries.length)];
  }
}

