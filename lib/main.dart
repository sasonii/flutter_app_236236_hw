import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App());
}

enum Status { Uninitialized, Authenticated, Authenticating, Unauthenticated }

class AuthNotifier extends ChangeNotifier {
  FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  Status _status = Status.Uninitialized;
  FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Set<WordPair> _saved = <WordPair>{};

  AuthNotifier() {
    _auth.authStateChanges().listen(_onStateChanged);
  }
  Status get status => _status;
  User? get user => _user;

  Future<bool> signIn(String email, String password, Set<WordPair> wordPairs) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _saved = await loadWords();
      _saved.addAll(wordPairs);
    
      for (var wordPair in wordPairs) {
        await saveWord(wordPair);
      }
      return true;
    } catch (e) {
      _status = Status.Unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp(String email, String password, Set<WordPair> wordPairs) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      _saved = wordPairs;
    
      for (var wordPair in _saved) {
        await saveWord(wordPair);
      }
      return true;
    } catch (e) {
      _status = Status.Unauthenticated;
      notifyListeners();
      return false;
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

class App extends StatelessWidget {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(
                  child: Text(snapshot.error.toString(),
                      textDirection: TextDirection.ltr)));
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return ChangeNotifierProvider(
            create: (context) => AuthNotifier(),
            child: const MyApp(),
          );
        }
        return Center(child: CircularProgressIndicator());
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // MODIFY with const
      title: 'Startup Name Generator',
      theme: ThemeData(
        // Add the 5 lines from here...
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
      ),
      home: const RandomWords(),
    );
  }
}

class RandomWords extends StatefulWidget {
  const RandomWords({super.key});

  @override
  State<RandomWords> createState() => _RandomWordsState();
}

class _RandomWordsState extends State<RandomWords>  with WidgetsBindingObserver{
  final _suggestions = <WordPair>[];
  final _biggerFont = const TextStyle(fontSize: 18);
  final _saved = <WordPair>{};
  @override
    void initState() {
      super.initState();
      WidgetsBinding.instance.addObserver(this);
    }

    @override
    void dispose() {
      WidgetsBinding.instance.removeObserver(this);
      super.dispose();
    }

    @override
    void didChangeAppLifecycleState(AppLifecycleState state) {
      if (state == AppLifecycleState.paused) {
        // App is being paused (closed)
        final authNotifier = context.read<AuthNotifier>();
        authNotifier.signOut();
      }
    }
  void _pushSaved() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          final tiles = _saved.map((pair) {
            return Dismissible(
                background: Container(
                  color: Colors.deepPurple,
                  child: const Row(
                    children: [
                      Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 36.0,
                      ),
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                direction: DismissDirection.horizontal,
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Confirm"),
                        content: const Text(
                            "Are you sure you wish to delete this item?"),
                        actions: <Widget>[
                          TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text("Yes")),
                          TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text("No"),
                          ),
                        ],
                      );
                    },
                  );
                },
                key: ValueKey<WordPair>(pair),
                onDismissed: (DismissDirection direction) {
                  setState(() {
                    _saved.remove(pair);
                    context.read<AuthNotifier>().removeWord(pair);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${pair.asPascalCase} dismissed',
                        textAlign: TextAlign.center,
                      ),
                      backgroundColor: Colors.deepPurple,
                    ),
                  );
                },
                child: ListTile(
                  title: Text(
                    pair.asPascalCase,
                    style: _biggerFont,
                  ),
                ));
          });

          final divided = tiles.isNotEmpty
              ? ListTile.divideTiles(
                  context: context,
                  tiles: tiles,
                ).toList()
              : <Widget>[];

          return Scaffold(
            appBar: AppBar(
              title: const Text('Saved Suggestions'),
            ),
            body: ListView(children: divided),
          );
        },
      ),
    );
  }

  void _login() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          // Define the controllers
          final emailController = TextEditingController();
          final passwordController = TextEditingController();
          // login screen with username and password
          return Scaffold(
              appBar: AppBar(
                title: const Text('Login'),
              ),
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // text that says "Login"
                    const Text(
                      'Welcome to Startup Names Generator, please log in',
                      style: TextStyle(
                        fontSize: 14,
                      ),
                    ),

                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                      ),
                    ),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                      ),
                      obscureText: true,
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        String email = emailController.text;
                        String password = passwordController.text;
                        Status status = context.read<AuthNotifier>().status;
                        if (status == Status.Uninitialized || status == Status.Unauthenticated) {
                          var res = await context
                              .read<AuthNotifier>()
                              .signIn(email, password, _saved);
                          if (res) {
                            Navigator.of(context).pop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'There was an error logging into the app',
                                  textAlign: TextAlign.center,
                                ),
                                backgroundColor: Colors.deepPurple,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Log in'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        String email = emailController.text;
                        String password = passwordController.text;
                        Status status = context.read<AuthNotifier>().status;
                        if (status == Status.Uninitialized || status == Status.Unauthenticated) {
                          var res = await context
                              .read<AuthNotifier>()
                              .signUp(email, password, _saved);
                          if (res) {
                            Navigator.of(context).pop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'There was an error logging into the app',
                                  textAlign: TextAlign.center,
                                ),
                                backgroundColor: Colors.deepPurple,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Sign up'),
                    ),
                  ],
                ),
              ));
        },
      ),
    );
  }

  void _logout() {
    Status status = context.read<AuthNotifier>().status;
    if (status == Status.Authenticated) {
      _saved.clear();
      context.read<AuthNotifier>().signOut();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Successfully logged out',
            textAlign: TextAlign.center,
          ),
          backgroundColor: Colors.deepPurple,
        ),
      );
    } else if (status == Status.Unauthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'There was an error logging out of the app',
            textAlign: TextAlign.center,
          ),
          backgroundColor: Colors.deepPurple,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Status status = context.watch<AuthNotifier>().status;
    Set<WordPair> userSaved = context.read<AuthNotifier>()._saved;
    _saved.addAll(userSaved);
    return Scaffold(
      // NEW from here ...
      appBar: AppBar(
        title: const Text('Startup Name Generator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.star),
            onPressed: _pushSaved,
            tooltip: 'Saved Suggestions',
          ),
          IconButton(
            icon: status == Status.Authenticated
                ? const Icon(Icons.exit_to_app)
                : const Icon(Icons.login),
            onPressed: status == Status.Authenticated ? _logout : _login,
            tooltip: 'Login',
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemBuilder: (context, i) {
          if (i.isOdd) return const Divider();

          final index = i ~/ 2;
          if (index >= _suggestions.length) {
            _suggestions.addAll(generateWordPairs().take(10));
          }

          final alreadySaved = _saved.contains(_suggestions[index]);

          return ListTile(
            title: Text(
              _suggestions[index].asPascalCase,
              style: _biggerFont,
            ),
            trailing: Icon(
              alreadySaved ? Icons.favorite : Icons.favorite_border,
              color: alreadySaved ? Colors.red : null,
              semanticLabel: alreadySaved ? 'Remove from saved' : 'Save',
            ),
            onTap: () {
              setState(() {
                if (alreadySaved) {
                  _saved.remove(_suggestions[index]);
                  context.read<AuthNotifier>().removeWord(_suggestions[index]);
                } else {
                  _saved.add(_suggestions[index]);
                  context.read<AuthNotifier>().saveWord(_suggestions[index]);
                }
              });
            },
          );
        },
      ), // NEW
    );
  }
}
