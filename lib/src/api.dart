import 'controller.dart';

/// Returns whether the current process is the only instance of the app
/// running. If it returns false, another process is already running; the
/// command line arguments passed in as [args] will be forwarded to the previous
/// instance to be processed by the [onSecondInstance()] callback.
///
/// ```dart
/// void main(List<String> args) async {
///   if (await isFirstInstance(args)) {
///     onSecondInstance((args) => print("Args: ${args}"));
///     print("We are the first instance");
///   } else {
///     print("Another instance of this application is running");
///   }
/// }
/// ```
Future<bool> isFirstInstance([List<String>? args]) {
  return InstanceController.instance.checkFirstInstance(args ?? []);
}

/// Attaches a callback to be run whenever a second instance of the app is
/// executed. The arguments from that second instance will be passed into
/// the callback.
///
/// ```dart
/// onSecondInstance((List<String> args) => print("Arguments: $args"));
/// ```
void onSecondInstance(Function(List<String>) cb) {
  InstanceController.instance.callback = cb;
}
