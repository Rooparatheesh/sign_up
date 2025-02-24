import 'package:flutter/material.dart';
import 'package:sign_up/components/color.dart';

class Button extends StatelessWidget {
  final String label;
  final VoidCallback press;
  const Button({super.key, required this.label, required this.press});

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Container(
      width: size.width * .9,
      height: 55,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 30, 26, 94),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextButton(
        onPressed: press,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
