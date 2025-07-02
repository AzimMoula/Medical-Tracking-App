import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseFirestore db = FirebaseFirestore.instance;
  static Future<Map<String, dynamic>> createUserWithEmailAndPassword(
      String name,
      String email,
      String password,
      String phone,
      String emergency) async {
    try {
      await auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password.trim());
      if (auth.currentUser != null) {
        await auth.currentUser!.updateDisplayName(name);
        await db.collection('users').doc(auth.currentUser!.uid).set({
          'id': auth.currentUser!.uid,
          'name': name,
          'phone': phone,
          'emergencyContacts': [emergency],
          'email': email,
          'createdAt': Timestamp.now(),
          'updated_at': Timestamp.now(),
        });
        return {
          'success': true,
          'message': 'Registration Successful',
        };
      } else {
        return {
          'success': false,
          'error': 'Registration Failed',
          'message': 'An Unknown Error Occured.'
        };
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("${e.message} ${e.code.replaceAll('-', ' ')}");
      return {
        'success': false,
        'error': e.code.replaceAll('-', ' '),
        'message': e.message
      };
    }
  }

  static Future<Map<String, dynamic>> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      await auth.signInWithEmailAndPassword(
          email: email.trim(), password: password.trim());
      if (auth.currentUser != null) {
        return {
          'success': true,
        };
      } else {
        return {
          'success': false,
          'error': 'Error',
          'message': 'An Unknown Error Occured.'
        };
      }
    } on FirebaseAuthException catch (e) {
      debugPrint(e.message);
      return {
        'success': false,
        'error': e.code.replaceAll('-', ' '),
        'message': e.message
      };
    }
  }

  static Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? gUser = await GoogleSignIn().signIn();
      final GoogleSignInAuthentication gAuth = await gUser!.authentication;
      final credential = GoogleAuthProvider.credential(
          accessToken: gAuth.accessToken, idToken: gAuth.idToken);
      await auth.signInWithCredential(credential);
      if (auth.currentUser != null) {
        return {
          'success': true,
        };
      } else {
        return {
          'success': false,
          'error': 'Error',
          'message': 'An Unknown Error Occured.'
        };
      }
    } on FirebaseAuthException catch (e) {
      debugPrint(e.message);
      return {
        'success': false,
        'error': e.code.replaceAll('-', ' '),
        'message': e.message
      };
    }
  }

  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      DocumentSnapshot doc = await db.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint("Error getting user profile: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final currentUser = auth.currentUser;
    if (currentUser != null) {
      return await getUserProfile(currentUser.uid);
    }
    return null;
  }

  static User? getCurrentUser() {
    return auth.currentUser;
  }

  static bool isLoggedIn() {
    return auth.currentUser != null;
  }

  static Future<Map<String, dynamic>> signOut() async {
    try {
      await auth.signOut();
      await GoogleSignIn().signOut();
      if (auth.currentUser == null) {
        return {
          'success': true,
        };
      } else {
        return {
          'success': false,
          'error': 'Error',
          'message': 'An Unknown Error Occured.'
        };
      }
    } on FirebaseAuthException catch (e) {
      debugPrint(e.message);
      return {
        'success': false,
        'error': e.code.replaceAll('-', ' '),
        'message': e.message
      };
    }
  }
}
