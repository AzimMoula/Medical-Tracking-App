import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
 HomePage({super.key});

  final user = FirebaseAuth.instance.currentUser!;
  //sign out user
  void signUserOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Page'),
        backgroundColor: const Color.fromARGB(255, 78, 148, 233),

        actions: [IconButton(onPressed: signUserOut, icon: Icon(Icons.logout))],
      ),
      body: Center(child: Text("Logged in as "+user.email!,
      style: TextStyle(fontSize: 20, color: Colors.black54, fontWeight: FontWeight.bold
      )),
    ));
  }
}
