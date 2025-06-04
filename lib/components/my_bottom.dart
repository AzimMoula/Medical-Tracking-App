import 'package:flutter/material.dart';

class MyBottom extends StatelessWidget {
  final Function()? onTap; 
  const MyBottom({super.key,required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:onTap ,
      child: Container(
        width: double.infinity, // ← This makes it expand horizontally
        padding: EdgeInsets.all(20.0),
        margin: EdgeInsets.symmetric(horizontal: 20.0),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Center( // ← Ensures text stays centered
          child: Text(
            "Sign In",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}