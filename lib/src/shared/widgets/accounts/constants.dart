import 'package:flutter/material.dart';

class AccountEditingData {
  TextEditingController nameController;
  Color color;
  String? picture;
  bool isLocalPicture;

  AccountEditingData({
    required this.nameController,
    required this.color,
    this.picture,
    this.isLocalPicture = true,
  });
}