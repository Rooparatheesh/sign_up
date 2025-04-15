import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void closeKeyboard(BuildContext context) {
  FocusScope.of(context).unfocus(); // ✅ Hide keyboard
  SystemChannels.textInput.invokeMethod('TextInput.hide'); // ✅ Ensure it's hidden
}