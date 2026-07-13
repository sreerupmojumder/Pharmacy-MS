import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final String? hintText;
  final TextEditingController? controller;
  final int? maxLine;
  final bool readOnly;
  final bool enabled;
  const CustomTextField({
    super.key,
    required this.hintText,
    this.maxLine,
    this.controller, this.readOnly = false,  this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $hintText';
        } else {
          return null;
        }
      },
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLine,
      decoration: InputDecoration(
        enabled: enabled,
        hintText: hintText,
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.green),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),

        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.green),
        ),
        filled: true,
        fillColor: Colors.white,
        hintStyle: TextStyle(color: Colors.grey.shade600),
      ),
    );
  }
}
