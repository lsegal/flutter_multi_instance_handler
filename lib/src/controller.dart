import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'controller_windows.dart';

const namespace = 'pub.dev/packages/multi_instance_handler';
const MethodChannel channel = const MethodChannel(namespace);
const onSecondInstanceMethodName = 'onSecondInstance';

class InstanceController {
  static InstanceController? _instance;
  static InstanceController get instance {
    if (_instance == null) _instance = create();
    return _instance!;
  }

  Function(List<String>)? callback;

  late SharedPreferences prefs;

  static InstanceController create() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return InstanceControllerWindows();
      default:
        stderr.writeln(
            "[MultiInstanceHandler]: Unsupported platform: $defaultTargetPlatform, bypassing handler.");
        return InstanceController();
    }
  }

  InstanceController() {
    WidgetsFlutterBinding.ensureInitialized();
    _initChannel();
  }

  Future<bool> checkFirstInstance(List<String> arguments) async {
    prefs = await SharedPreferences.getInstance();

    final pipeName = prefs.getString('$namespace:pipe') ?? Uuid().v4();
    prefs.setString('$namespace:pipe', pipeName);

    return checkAndInitialize(pipeName, arguments);
  }

  Future<bool> checkAndInitialize(String pipeName, [List<String>? arguments]) {
    throw UnimplementedError();
  }

  void _initChannel() {
    channel.setMethodCallHandler((call) async {
      if (call.method == onSecondInstanceMethodName && callback != null) {
        final out = (call.arguments as List).map((a) => a.toString()).toList();
        callback!(out);
      }
      return null;
    });
  }
}
