# Multi Instance Handler (`multi_instance_handler`)

Detects and handles multiple instances of an application. This library allows
you to forward command line arguments from second instances of an application,
force a single instance of an application, or both.

## Compatibility

This library is designed for use in Flutter applications. Support in Dart
tools is undefined.

This library currently only supports Flutter applications on the Windows
platform.

## Usage

```dart
import 'package:multi_instance_handler/multi_instance_handler.dart';

void main(List<String> arguments) async {
  if (await isFirstInstance(arguments)) {
    onSecondInstance((List<String> args) {
      print("Second instance launched with: $args");
    });
    runApp(MyApp());
  } else {
    print("Found existing instance, quitting!");
    exit(0);
  }
}
```

## TODO

- [ ] Add macOS support
- [ ] Add Linux support
- [ ] Ensure first instance window is hidden when loading (third-party issue).

## License & Author

This library was written by Loren Segal in 2021 and licensed under the terms of
the MIT license.
