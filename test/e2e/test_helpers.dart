import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

Future<void> setupEmulators() async {
  FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
}

Future<String> createTestUser(FirebaseAuth auth, String email) async {
  final credential = await auth.createUserWithEmailAndPassword(
    email: email,
    password: 'test123456',
  );
  return credential.user!.uid;
}

Future<dynamic> callFunction(String name, Map<String, dynamic> data) async {
  final result = await FirebaseFunctions.instance.httpsCallable(name).call(data);
  return result.data;
}
