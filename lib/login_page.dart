import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'auth_notifier.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatelessWidget {
  final Set<WordPair> saved;

  const LoginPage({required this.saved});
  @override
  Widget build(BuildContext context) {
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
                              .signIn(email, password, saved);
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
                              .signUp(email, password, saved);
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
  }
}