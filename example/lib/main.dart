import 'dart:io';

import 'package:flutter/material.dart';

import 'package:multi_instance_handler/multi_instance_handler.dart';

void main(List<String> arguments) async {
  // Check if we already have an instance and quit if we do.
  if (await isFirstInstance(arguments)) {
    runApp(MyApp());
  } else {
    print("Found existing instance, quitting!");
    exit(0);
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<String> _args = [];

  @override
  void initState() {
    // Callback when second instance is loaded
    onSecondInstance((List<String> args) {
      // Do something with the other instance's command line args (url launcher?)
      setState(() => _args = args);
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Text("Arguments from second instance: ${_args.toString()}"),
        ),
      ),
    );
  }
}
