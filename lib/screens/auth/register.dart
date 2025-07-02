import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medical_tracking_app/services/auth_service.dart';
import 'package:medical_tracking_app/widgets/button.dart';
import 'package:medical_tracking_app/widgets/text_field.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emergencyContactController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            // spacing: 25,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 50),
              const Icon(Icons.local_hospital, size: 100),
              const SizedBox(height: 25),
              Text(
                "lets create an account for you!",
                style: TextStyle(color: Colors.grey[700], fontSize: 16),
              ),
              const SizedBox(height: 10),
              Form(
                key: _formKey,
                child: Column(
                  spacing: 5,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    CustomTextfield(
                      controller: nameController,
                      hintText: "Name",
                      keyboard: TextInputType.name,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Name is required";
                        }
                        return null;
                      },
                    ),
                    CustomTextfield(
                      controller: phoneController,
                      hintText: "Phone",
                      keyboard: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.length < 10) {
                          return "Contact must be at least 10 characters";
                        }
                        return null;
                      },
                    ),
                    CustomTextfield(
                      controller: emergencyContactController,
                      hintText: "Emergency Contact",
                      keyboard: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.length < 10) {
                          return "Contact must be at least 10 characters";
                        }
                        return null;
                      },
                    ),
                    CustomTextfield(
                      controller: emailController,
                      hintText: "Email",
                      keyboard: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Email is required";
                        } else if (!value.contains('@')) {
                          return "Enter a valid email";
                        }
                        return null;
                      },
                    ),
                    CustomTextfield(
                      controller: passwordController,
                      hintText: "Password",
                      obscureText: true,
                      keyboard: TextInputType.visiblePassword,
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return "Password must be at least 6 characters";
                        }
                        return null;
                      },
                    ),
                    CustomTextfield(
                      controller: confirmPasswordController,
                      hintText: "Confirm Password",
                      obscureText: true,
                      keyboard: TextInputType.visiblePassword,
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return "Password must be at least 6 characters";
                        }
                        if (value != passwordController.text) {
                          return "Passwords do not match";
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              CustomButton(
                  text: "Sign Up",
                  onTap: () async {
                    if (!_formKey.currentState!.validate()) return;
                    showDialog(
                      context: context,
                      builder: (context) =>
                          const Center(child: CircularProgressIndicator()),
                    );
                    final result =
                        await AuthService.createUserWithEmailAndPassword(
                      nameController.text.trim(),
                      emailController.text.trim(),
                      passwordController.text.trim(),
                      phoneController.text.trim(),
                      emergencyContactController.text.trim(),
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      if (result['success']) {
                        Navigator.pushReplacementNamed(
                            context, '/add-schedule');
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
              const SizedBox(height: 25),
              // Padding(
              //   padding: const EdgeInsets.symmetric(horizontal: 25.0),
              //   child: Row(
              //     children: [
              //       Expanded(
              //         child: Divider(thickness: 0.5, color: Colors.grey[400]),
              //       ),
              //       Padding(
              //         padding: const EdgeInsets.symmetric(horizontal: 25.0),
              //         child: Text(
              //           "or continue with",
              //           style: TextStyle(color: Colors.grey[700]),
              //         ),
              //       ),
              //       Expanded(
              //         child: Divider(thickness: 0.5, color: Colors.grey[400]),
              //       ),
              //     ],
              //   ),
              // ),
              // const Row(
              //   mainAxisAlignment: MainAxisAlignment.center,
              //   children: [
              //     SquareTile(imagePath: "assets/google.png"),
              //     SizedBox(width: 20),
              //     SquareTile(imagePath: "assets/apple.png"),
              //   ],
              // ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Already have an account? ",
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    child: Text(
                      "Login now",
                      style: TextStyle(color: Colors.blue[800]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }
}
