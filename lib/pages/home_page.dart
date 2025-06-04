import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
   HomePage({super.key});
  final user=FirebaseAuth.instance.currentUser;

  void Signout() {
    FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              // Add your logout logic here
              Signout();
            },
          ),
        ],
        title: Text("Home Page"),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: Center(child: Text("LoGGED IN AS "+(user?.email ?? "Guest")+"!",
      
      )),
    );
  }
}
