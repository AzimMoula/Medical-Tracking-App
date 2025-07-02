import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medical_tracking_app/services/auth_service.dart';
import 'package:medical_tracking_app/widgets/button.dart';
import 'package:medical_tracking_app/widgets/square_tile.dart';
import 'package:medical_tracking_app/widgets/text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              spacing: 20,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 25),
                const Icon(Icons.local_hospital, size: 100),
                Text(
                  "Welcome back, we missed you!",
                  style: TextStyle(color: Colors.grey[700], fontSize: 16),
                ),
                Form(
                  key: _formKey,
                  child: Column(
                    spacing: 5,
                    children: [
                      CustomTextfield(
                        controller: emailController,
                        hintText: "Email",
                        keyboard: TextInputType.emailAddress,
                      ),
                      CustomTextfield(
                        controller: passwordController,
                        hintText: "Password",
                        obscureText: true,
                        keyboard: TextInputType.visiblePassword,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 25.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        "Forgot Password?",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                CustomButton(
                    text: "Sign In",
                    onTap: () async {
                      if (!_formKey.currentState!.validate()) return;
                      showDialog(
                        context: context,
                        builder: (context) =>
                            const Center(child: CircularProgressIndicator()),
                      );
                      final result =
                          await AuthService.signInWithEmailAndPassword(
                        emailController.text.trim(),
                        passwordController.text.trim(),
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        if (result['success']) {
                          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '${toBeginningOfSentenceCase(result['error'].toString())}: ${result['message']}'),
                              backgroundColor: Colors.red.shade900,
                            ),
                          );
                        }
                      }
                    }),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Row(
                    spacing: 25,
                    children: [
                      Expanded(
                        child: Divider(thickness: 0.5, color: Colors.grey[400]),
                      ),
                      Text(
                        "or continue with",
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      Expanded(
                        child: Divider(thickness: 0.5, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SquareTile(imagePath: "assets/google.png"),
                    SizedBox(width: 20),
                    SquareTile(imagePath: "assets/apple.png"),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Not a member? ",
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: Text(
                        "Register now",
                        style: TextStyle(color: Colors.blue[800]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
