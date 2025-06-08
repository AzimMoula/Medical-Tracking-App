import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:medical_app1/components/myTextField.dart';
import 'package:medical_app1/components/my_bottom.dart';
import 'package:medical_app1/components/square_tile.dart';
import 'package:medical_app1/pages/login_page.dart';
import 'package:medical_app1/pages/register_page.dart';

class LoginOrRegsiter extends StatefulWidget {
  const LoginOrRegsiter({super.key});

  @override
  State<LoginOrRegsiter> createState() => _LoginOrRegsiterState();
}


class _LoginOrRegsiterState extends State<LoginOrRegsiter> {

  //Initially show login 
  bool showLoginPage = true;

  //toggel between login and register page
  void togglePage() {
    setState(() {
      showLoginPage = !showLoginPage;
    });
  }
  @override
  Widget build(BuildContext context) {
   if(showLoginPage) {
      return LoginPage(onTap: togglePage);
    } else {
      return RegisterPage(onTap: togglePage);
    }
  }
}