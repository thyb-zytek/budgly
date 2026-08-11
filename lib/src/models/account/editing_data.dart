import 'package:flutter/material.dart';

class AccountEditingData {
  final TextEditingController nameController;
  Color color;
  String? picture;
  bool get isLocalPicture => picture != null && !picture!.startsWith('http');

  AccountEditingData({
    required this.nameController,
    required this.color,
    this.picture,
  });
}