import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_up/views/profile.dart';
import 'package:sign_up/components/button.dart';
import 'package:sign_up/components/color.dart';
import 'package:sign_up/components/textfiled.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final employeeIdController = TextEditingController();
  final passwordController = TextEditingController();

  bool isChecked = false;
  bool isLoginFailed = false;
  bool isLoading = false;

  Future<void> login() async {
    if (employeeIdController.text.isEmpty || passwordController.text.isEmpty) {
      setState(() {
        isLoginFailed = true;
      });
      return;
    }

    setState(() {
      isLoading = true;
      isLoginFailed = false;
    });

    try {
      final url = Uri.parse("http://10.176.21.109:4000/api/login"); // Update API URL
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "employeeId": employeeIdController.text,
          "password": passwordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["success"]) {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", data["token"]);
          await prefs.setString("employeeID", employeeIdController.text); // ✅ FIX ADDED
        await prefs.setString("employeeName", data["employeeName"]);
        await prefs.setString("role", data["role"]);
        await prefs.setStringList("permissions",
            (data["permissions"] as List<dynamic>).map((e) => e.toString()).toList());
        await prefs.setStringList("menus",
            (data["menus"] as List<dynamic>).map((e) => jsonEncode(e)).toList());

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Profile()),
        );
      } else {
        setState(() {
          isLoginFailed = true;
        });
      }
    } catch (e) {
      setState(() {
        isLoginFailed = true;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
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
                  "LOGIN",
                  style: TextStyle(color: primaryColor, fontSize: 40),
                ),
                Image.asset("assets/image/pi.png"),
                InputField(
                    hint: "Employee ID",
                    icon: Icons.badge,
                    controller: employeeIdController,
                    enabled: true,
                    maxLines: 1),
                InputField(
                    hint: "Password",
                    icon: Icons.lock,
                    controller: passwordController,
                    passwordInvisible: true,
                    enabled: true,
                    maxLines: 1),
                ListTile(
                  horizontalTitleGap: 2,
                  title: const Text("Remember me"),
                  leading: Checkbox(
                    activeColor: primaryColor,
                    value: isChecked,
                    onChanged: (value) {
                      setState(() {
                        isChecked = value!;
                      });
                    },
                  ),
                ),
                Button(
                    label: isLoading ? "Logging in..." : "LOGIN",
                    press: () {
                      if (!isLoading) login();
                    }),
                isLoginFailed
                    ? Text(
                        "Invalid Employee ID or password",
                        style: TextStyle(color: Colors.red.shade900),
                      )
                    : const SizedBox(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
