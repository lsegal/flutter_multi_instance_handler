import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:win32/win32.dart';
import 'package:ffi/ffi.dart';

import 'controller.dart';

// ignore_for_file: non_constant_identifier_names

const ERROR_PIPE_CONNECTED = 0x80070217;
const ERROR_IO_PENDING = 0x800703E5;

final _kernel32 = DynamicLibrary.open('kernel32.dll');
int GetOverlappedResult(int hFile, Pointer<OVERLAPPED> lpOverlapped,
    Pointer<Uint32> lpNumberOfBytesTransferred, int bWait) {
  final fn = _kernel32.lookupFunction<
      Int32 Function(IntPtr hFile, Pointer<OVERLAPPED> lpOverlapped,
          Pointer<Uint32> lpNumberOfBytesTransferred, Uint32 bWait),
      int Function(
          int hFile,
          Pointer<OVERLAPPED> lpOverlapped,
          Pointer<Uint32> lpNumberOfBytesTransferred,
          int bWait)>('GetOverlappedResult');
  return fn(hFile, lpOverlapped, lpNumberOfBytesTransferred, bWait);
}

int CancelIo(int hFile) {
  final fn = _kernel32.lookupFunction<Int32 Function(IntPtr hFile),
      int Function(int hFile)>('CancelIo');
  return fn(hFile);
}

int GetNamedPipeClientProcessId(int hFile, Pointer<Uint32> clientProcessId) {
  final fn = _kernel32.lookupFunction<
      Int32 Function(IntPtr hFile, Pointer<Uint32> clientProcessId),
      int Function(int hFile,
          Pointer<Uint32> clientProcessId)>('GetNamedPipeClientProcessId');
  return fn(hFile, clientProcessId);
}

class InstanceControllerWindows extends InstanceController {
  final _handleKey = '$namespace:handle';

  @override
  Future<bool> checkAndInitialize(String pipeName,
      [List<String>? arguments]) async {
    final filename = "\\\\.\\pipe\\__multi_instance_handler__$pipeName";

    final prevHandle = await _extractPrevHandle();
    if (prevHandle != null) {
      DisconnectNamedPipe(prevHandle);
      CloseHandle(prevHandle);
    }

    final pipe = _createPipe(filename);
    _addPrevHandle(pipe);
    if (pipe == INVALID_HANDLE_VALUE) {
      _writePipeData(filename, arguments);
      return false;
    }

    final listenFn = (dynamic msg) {
      if (msg is SendPort) {
        msg.send(pipe);
      } else {
        channel.invokeMethod(onSecondInstanceMethodName, msg);
      }
    };
    final reader = ReceivePort()..listen(listenFn);
    await Isolate.spawn(_startReadPipeIsolate, reader.sendPort);
    return true;
  }

  Future<int?> _extractPrevHandle() async {
    final keys = prefs.getStringList(_handleKey);
    if (keys == null) return null;

    final handles =
        keys.map((k) => k.split(':').map((i) => int.parse(i))).toList();
    final idx = handles.indexWhere((arr) => arr.first == pid);
    if (idx < 0) return null;

    keys.removeAt(idx);
    prefs.setStringList(_handleKey, keys);

    return handles[idx].last;
  }

  void _addPrevHandle(int handle) {
    final list = prefs.getStringList(_handleKey) ?? [];
    list.add("$pid:$handle");
    prefs.setStringList(_handleKey, list);
  }

  void _writePipeData(String filename, List<String>? arguments) {
    final pipe = _openPipe(filename);
    final bytesString = jsonEncode(arguments ?? []);
    final bytes = bytesString.toNativeUtf8();
    final numWritten = malloc<Uint32>();
    try {
      final result =
          WriteFile(pipe, bytes, bytesString.length, numWritten, nullptr);
      if (result == 0) {
        throw _lastErrToString;
      }
    } finally {
      free(numWritten);
      free(bytes);
      CloseHandle(pipe);
    }
  }

  static void _startReadPipeIsolate(SendPort writer) {
    final reader = ReceivePort()
      ..listen((msg) => {if (msg is int) _readPipe(writer, msg)});
    writer.send(reader.sendPort);
  }

  static void _readPipe(SendPort writer, int pipeHandle) {
    final overlap = calloc<OVERLAPPED>();
    try {
      while (true) {
        while (true) {
          ConnectNamedPipe(pipeHandle, overlap);
          final err = GetLastError();
          if (err == ERROR_PIPE_CONNECTED) {
            sleep(Duration(milliseconds: 200));
            continue;
          } else if (err == ERROR_INVALID_HANDLE) {
            return;
          }
          break;
        }

        var dataSize = 16384;
        var data = calloc<Int8>(dataSize);
        final numRead = calloc<Uint32>();
        try {
          while (GetOverlappedResult(pipeHandle, overlap, numRead, 0) == 0) {
            sleep(Duration(milliseconds: 200));
          }

          ReadFile(pipeHandle, data, dataSize, numRead, overlap);
          final jsonData = data.cast<Utf8>().toDartString();
          writer.send(jsonDecode(jsonData));
        } catch (error) {
          stderr.writeln("[MultiInstanceHandler]: ERROR: $error");
        } finally {
          free(data);
          free(numRead);
          DisconnectNamedPipe(pipeHandle);
        }
      }
    } finally {
      free(overlap);
    }
  }

  static int _openPipe(String filename) {
    final cPipe = filename.toNativeUtf16();
    try {
      return CreateFile(
          cPipe, GENERIC_READ | GENERIC_WRITE, 0, nullptr, OPEN_EXISTING, 0, 0);
    } finally {
      free(cPipe);
    }
  }

  static int _createPipe(String filename) {
    final cPipe = filename.toNativeUtf16();
    try {
      return CreateNamedPipe(
        cPipe,
        PIPE_ACCESS_DUPLEX |
            FILE_FLAG_FIRST_PIPE_INSTANCE |
            FILE_FLAG_OVERLAPPED,
        PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_WAIT,
        PIPE_UNLIMITED_INSTANCES,
        4096,
        4096,
        0,
        nullptr,
      );
    } finally {
      malloc.free(cPipe);
    }
  }

  static String get _lastErrToString {
    Pointer<Utf16> errBuf = nullptr;
    try {
      FormatMessage(
          0x00000100 |
              FORMAT_MESSAGE_FROM_SYSTEM |
              FORMAT_MESSAGE_IGNORE_INSERTS,
          nullptr,
          GetLastError(),
          0,
          errBuf,
          0,
          nullptr);
      return errBuf.toDartString();
    } finally {
      free(errBuf);
    }
  }
}
