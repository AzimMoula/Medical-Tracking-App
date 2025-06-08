import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:medical_app1/pages/home_page.dart';
import 'package:medical_app1/pages/login_or_regsiter.dart';
import 'package:medical_app1/pages/login_page.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return HomePage();
          }
          //user is not logged in
          else {
            return LoginOrRegsiter();
          }
        },
      ),
    );
  }
}
