import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:medical_app1/components/myTextField.dart';
import 'package:medical_app1/components/my_bottom.dart';
import 'package:medical_app1/components/square_tile.dart';

class LoginPage extends StatefulWidget {
  final Function()? onTap;
  LoginPage({super.key, required this.onTap});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // TextEditingController for username and password
  final emailController = TextEditingController();

  final passwordController = TextEditingController();

  //sign in user function
  void signInUser() async {
  // Show loading circle
  showDialog(
    context: context,
    builder: (context) => const Center(child: CircularProgressIndicator()),
    
  );Navigator.pop(context);

  try {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: emailController.text.trim(), // Trim whitespace
      password: passwordController.text.trim(),
    );
    // Close loading circle on success
    
    if (mounted) Navigator.pop(context);
  } on FirebaseAuthException catch (e) {
    
    Navigator.pop(context);
    showerrorMessage(e.code);
  }
}  

 void showerrorMessage(String message) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.deepPurple,
        title: Center(
          child: Text(
            message,
            style: TextStyle(color: Colors.white),
          ),

          ),
      
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 50),
                //logo
                Icon(Icons.local_hospital, size: 100),
                const SizedBox(height: 50),
                //welcome back,we missed you
                Text(
                  "Welcome back, we missed you!",
                  style: TextStyle(color: Colors.grey[700], fontSize: 16),
                ),
                const SizedBox(height: 25),
                //email textfield
                Mytextfield(
                  controller: emailController,
                  hintText: "email",
                  obscureText: false,
                ),
                const SizedBox(height: 25),
                //password textfield
                Mytextfield(
                  controller: passwordController,
                  hintText: "Password",
                  obscureText: true,
                ),
            
                //forgot password?
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
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
            
                const SizedBox(height: 25),
                //sign in button
                MyBottom(
                  text: "Sign In",
                  onTap: signInUser),
            
                const SizedBox(height: 25),
                //or continue with
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Divider(thickness: 0.5, color: Colors.grey[400]),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25.0),
                        child: Text(
                          "or continue with",
            
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                      Expanded(
                        child: Divider(thickness: 0.5, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                //google +apple sign in buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    //google button
                    SquareTile(imagePath: "lib/images/google.png"),
            
                    SizedBox(width: 20),
                    //apple button
                    SquareTile(imagePath: "lib/images/apple.png"),
                  ],
                ),
                //not a member? register now
                const SizedBox(height: 25),
            
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Not a member? ",
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
            
                    GestureDetector(
                      onTap: widget.onTap, 
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
