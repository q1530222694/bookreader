import 'package:flutter/material.dart';

class ShellController {
  final ValueNotifier<int> index = ValueNotifier<int>(0);

  void setIndex(int i) {
    index.value = i;
  }
}