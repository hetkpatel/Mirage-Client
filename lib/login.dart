import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_session_manager/flutter_session_manager.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:http/http.dart' as http;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    SessionManager().destroy();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mirage"),
      ),
      body: Center(
        child: SizedBox(
          width: 400,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FormBuilder(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Connect to server",
                      style: TextStyle(fontSize: 24),
                    ),
                    SizedBox(height: 32),
                    FormBuilderTextField(
                      name: 'server',
                      decoration: InputDecoration(
                        labelText: 'Server URL (with port)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      validator: FormBuilderValidators.compose(
                        [
                          FormBuilderValidators.required(),
                          FormBuilderValidators.url(
                            protocols: ['http', 'https'],
                            requireProtocol: true,
                            regex: RegExp(
                              r'^https?:\/\/[a-zA-Z0-9.-]+:[0-9]+$',
                              multiLine: true,
                              dotAll: true,
                            ),
                            errorText:
                                'Enter valid server URL (ex. http://SERVER:PORT)',
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    FormBuilderTextField(
                      name: 'username',
                      decoration: InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      validator: FormBuilderValidators.required(),
                    ),
                    SizedBox(height: 10),
                    FormBuilderTextField(
                      name: 'password',
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      obscureText: true,
                      validator: FormBuilderValidators.required(),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: !_loading
                          ? () async {
                              // Connect to server
                              setState(() => _loading = true);
                              // Validate and save the form values
                              if (_formKey.currentState!.saveAndValidate()) {
                                // Send request to server to check if it is running
                                try {
                                  var res = await http.get(Uri.parse(
                                      _formKey.currentState!.value['server']));
                                  final resBody = res.body;
                                  if (res.statusCode >= 200 &&
                                      res.statusCode < 300) {
                                    // If it is running, then login
                                    if (resBody == 'Server is running!') {
                                      await SessionManager().set(
                                        "server",
                                        _formKey.currentState!.value['server']
                                            as String,
                                      );
                                      await SessionManager().set(
                                        "auth",
                                        'Basic ${base64.encode(utf8.encode('${_formKey.currentState!.value['username'] as String}:${_formKey.currentState!.value['password'] as String}'))}',
                                      );

                                      if (context.mounted) {
                                        Navigator.of(context)
                                            .pushReplacementNamed('/main');
                                      }
                                    } else {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Server is running but not configured'),
                                          ),
                                        );
                                      }
                                    }
                                  } else {
                                    // If it is not running, then show error message
                                    debugPrint(res.reasonPhrase);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(res.reasonPhrase ??
                                              'Trouble reaching the server'),
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  debugPrint(e.toString());
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('Trouble reaching the server'),
                                      ),
                                    );
                                  }
                                }
                              }
                              setState(() => _loading = false);
                            }
                          : null,
                      child: _loading
                          ? UnconstrainedBox(
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeCap: StrokeCap.round,
                              ),
                            )
                          : const Text(
                              "Connect",
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                    SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
