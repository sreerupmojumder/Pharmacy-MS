import 'package:flutter/material.dart';

class CustomTextButton extends StatelessWidget {
  final Widget title;
  final VoidCallback? onTap;
  const CustomTextButton({super.key, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 42,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.all(Radius.circular(3)),
      ),
      child: TextButton(
        style: ButtonStyle(alignment: Alignment.center),
        onPressed: onTap,
        child: title,
      ),
    );
  }
}
