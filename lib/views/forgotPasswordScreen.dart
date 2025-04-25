import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sign_up/components/button.dart';
import 'package:sign_up/components/color.dart';
import 'package:sign_up/components/textfiled.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final employeeIdController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;
  String? successMessage;

  Future<void> resetPassword() async {
    if (employeeIdController.text.isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      setState(() {
        errorMessage = "All fields are required";
        successMessage = null;
      });
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      setState(() {
        errorMessage = "Passwords do not match";
        successMessage = null;
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
      successMessage = null;
    });

  try {
  final url = Uri.parse("http://10.176.20.30:4000/forgot-password");
  final response = await http.post(
    url,
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "employee_id": employeeIdController.text,
      "new_password": passwordController.text,
      "confirm_password": confirmPasswordController.text,
    }),
  );

  print("Status code: ${response.statusCode}");
  print("Response body: ${response.body}");

  final data = jsonDecode(response.body);

  if (response.statusCode == 200) {
    setState(() {
      successMessage = data["message"] ?? "Password reset successfully. Please log in.";
      errorMessage = null;
    });
  } else {
    setState(() {
      errorMessage = data["message"] ?? "Failed to reset password";
    });
  }
} catch (e) {
  setState(() {
    errorMessage = "Unexpected error: $e";
  });
}
  }

  Map<String, dynamic> _parseResponse(String responseBody) {
    try {
      return jsonDecode(responseBody);
    } catch (_) {
      return {"message": "Unexpected response from server"};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "RESET PASSWORD",
                  style: TextStyle(color: primaryColor, fontSize: 30),
                ),
                 Image.asset(
  "assets/image/pi.png",
  height: 150, // Set the height
  width: 100,  // Set the width
),
                InputField(
                  hint: "Enter Employee ID",
                  icon: Icons.badge,
                  controller: employeeIdController,
                  enabled: true,
                  maxLines: 1,
                ),
                InputField(
                  hint: "New Password",
                  icon: Icons.lock,
                  controller: passwordController,
                  passwordInvisible: true,
                  enabled: true,
                  maxLines: 1,
                ),
                InputField(
                  hint: "Re-enter Password",
                  icon: Icons.lock_outline,
                  controller: confirmPasswordController,
                  passwordInvisible: true,
                  enabled: true,
                  maxLines: 1,
                ),
                Button(
                  label: isLoading ? "Processing..." : "RESET PASSWORD",
                  press: () {
                    if (!isLoading) resetPassword();
                  },
                ),
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      errorMessage!,
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),
                if (successMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      successMessage!,
                      style: const TextStyle(color: Colors.green),
                    ),
                  ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Back to Login
                  },
                  child: const Text("Back to Login"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
