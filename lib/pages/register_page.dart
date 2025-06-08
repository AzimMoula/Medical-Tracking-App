import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:medical_app1/components/myTextField.dart';
import 'package:medical_app1/components/my_bottom.dart';
import 'package:medical_app1/components/square_tile.dart';

class RegisterPage extends StatefulWidget {
  final Function()? onTap;
  RegisterPage({super.key, required this.onTap});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // TextEditingController for username and password
  final emailController = TextEditingController();

  final passwordController = TextEditingController();
final confirmPasswordController = TextEditingController();

  //sign  user up function
  void signUserUp() async {
  // Show loading circle
  showDialog(
    context: context,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );
//try creating the user
  try {
    //check if password and confirm password match
    if(passwordController.text == confirmPasswordController.text) {
    await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: emailController.text.trim(), // Trim whitespace
      password: passwordController.text.trim(),
    );
    } else {
      Navigator.pop(context);
      showerrorMessage("Passwords do not match");
      return;
    }

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
                const SizedBox(height: 25),
                //logo
                Icon(Icons.local_hospital, size: 50),
                const SizedBox(height: 25),
                //welcome back,we missed you
                Text(
                  "lets create an account for you!",
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
                 const SizedBox(height: 25),
                //confirm password textfield
                Mytextfield(
                  controller: confirmPasswordController,
                  hintText: "confirm Password",
                  obscureText: true,
                ),
            
                //forgot password?

            
                const SizedBox(height: 25),
                //sign in button
                MyBottom(
                  text: "Sign Up",
                  onTap: signUserUp),
            
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
                      "Already have an account? ",
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
            
                    GestureDetector(
                      onTap: widget.onTap, 
                      child: Text(
                        "Login now",
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
