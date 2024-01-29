import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:english_words/english_words.dart';

enum Status { Uninitialized, Authenticated, Authenticating, Unauthenticated }

class AuthNotifier extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  Status _status = Status.Uninitialized;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Set<WordPair> _saved = <WordPair>{};

  AuthNotifier() {
    _auth.authStateChanges().listen(_onStateChanged);
  }
  Status get status => _status;
  User? get user => _user;
  Set<WordPair> get saved => _saved;

  Future<bool> signIn(String email, String password, Set<WordPair> wordPairs) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      
    } catch (e) {
      _status = Status.Unauthenticated;
      notifyListeners();
      return false;
    }
    try {
      _saved = await loadWords();
      _saved.addAll(wordPairs);
    
      saveWords(wordPairs);
      return true;
    } catch (e) {
      return true;
    }
    
  }

  Future<bool> signUp(String email, String password, Set<WordPair> wordPairs) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      _saved = wordPairs;
    } catch (e) {
      _status = Status.Unauthenticated;
      notifyListeners();
      return false;
    }

    try {
      saveWords(wordPairs);
      return true;
    } catch (e) {
      return true;
      // firebase problem, no need to handle :/
    }
  }

  Future signOut() async {
    _auth.signOut();
    _status = Status.Uninitialized;
    _user = null;
    _saved.clear();
    notifyListeners();
    return Future.delayed(Duration.zero);
  }

  Future<void> _onStateChanged(User? user) async {
    if (user == null) {
      _status = Status.Uninitialized;
      _saved.clear();
    } else {
      _user = user;
      _status = Status.Authenticated;
      _saved = await loadWords();
    }
    notifyListeners();
  }
Future<void> saveWords(Set<WordPair> wordPairs) async {
  if (_user != null) {
    WriteBatch batch = _firestore.batch();

    wordPairs.forEach((wordPair) {
      DocumentReference docRef = _firestore
          .collection('users')
          .doc(_user!.uid)
          .collection('words')
          .doc(wordPair.asPascalCase);

      batch.set(docRef, {
        'first': wordPair.first,
        'second': wordPair.second,
      });

      _saved.add(wordPair);
    });

    return await batch.commit();
  }
}
  Future<void> saveWord(WordPair wordPair) async {
    if (_user != null) {
      await _firestore.collection('users').doc(_user!.uid).collection('words').doc(wordPair.asPascalCase).set({
        'first': wordPair.first,
        'second': wordPair.second,
      });
      _saved.add(wordPair); 
    }
  }

  Future<Set<WordPair>> loadWords() async {
    Set<WordPair> wordPairs = {};

    if (_user != null) {
      QuerySnapshot snapshot = await _firestore.collection('users').doc(_user!.uid).collection('words').get();
      for (var doc in snapshot.docs) {
        wordPairs.add(WordPair(doc['first'], doc['second']));
      }
    }

    return wordPairs;
  }

  Future<void> removeWord(WordPair wordPair) async {
    if (_user != null) {
      _saved.remove(wordPair);
      await _firestore.collection('users').doc(_user!.uid).collection('words').doc(wordPair.asPascalCase).delete();
    }
  }
}