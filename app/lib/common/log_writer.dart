import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Log rotation system that maintains two log files in the temporary directory.
/// They are rotated when a size of [maxSizeBytes] is reached.
///
/// To avoid infinite recursion when logging critical errors, methods on this
/// class never throw.
///
/// If an error happens, the writer prints a message, goes into a [closed]
/// state, and silently does nothing from then on.
class LogWriter {
  static const defaultMaxSizeBytes = 32 * 1024;
  static const currentFileName = 'papageno.log';
  static const previousFileName = 'papageno.1.log';

  final int maxSizeBytes;
  final File _current;
  final File _previous;
  final _buffer = StringBuffer();
  RandomAccessFile _writer;
  Future<void> _pendingFlush;
  String _failureMessage;

  /// Creates a new instance asynchronously, which logs to the system's cache
  /// directory. May return a [closed] instance, but never fails.
  static Future<LogWriter> toCache({int maxSizeBytes = defaultMaxSizeBytes}) async {
    // Needed for getTemporaryDirectory() to work before runApp() has been called.
    WidgetsFlutterBinding.ensureInitialized();
    final directory = await getTemporaryDirectory();
    try {
      directory.createSync(recursive: true); // Setting recursive avoids exception on existence.
    } catch (e) {
      _logLoggerError('could not create directory ${directory.path}', e);
    }
    return LogWriter(directory: directory.path, maxSizeBytes: maxSizeBytes);
  }

  /// Creates a new instance that logs to the given directory. This directory
  /// must already exist, otherwise the logger goes into the [closed] state.
  LogWriter({@required String directory, this.maxSizeBytes}) :
    _current = File(path.join(directory, currentFileName)),
    _previous = File(path.join(directory, currentFileName))
  {
    try {
      _writer = _current.openSync(mode: FileMode.append);
    } catch (e) {
      _fail('could not open log file ${_current.path}', e);
    }
  }

  /// Asynchronously writes the given message into the log, appending a newline
  /// but doing no other formatting.
  void write(String message) {
    if (closed) {
      return;
    }
    _buffer.writeln(message);
    _scheduleFlush();
  }

  /// Closes the log file and transitions to the [closed] state.
  void close() {
    if (closed) {
      return;
    }
    try {
      _writer.closeSync();
    } catch (e) {
      // Ignored.
    }
    _writer = null;
  }

  bool get closed => _writer == null;

  Future<String> getContents() async {
    // Best-effort attempt to catch the latest content.
    await _pendingFlush;

    final buffer = StringBuffer();
    if (closed) {
      buffer.writeln('logging failed, contents below may be out of date: ${_failureMessage ?? '<no message>'}');
    }
    try {
      buffer.write(await _previous.readAsString());
    } catch (e) {
      buffer.writeln('could not read previous log file ${_previous.path}: $e');
    }
    // Note that we open the current file again here. We're not reusing the
    // currently open file handle, because other async operations might be
    // pending on it.
    try {
      buffer.write(await _current.readAsString());
    } catch (e) {
      buffer.writeln('could not read current log file ${_current.path}: $e');
    }
    return buffer.toString();
  }

  void _scheduleFlush() {
    _pendingFlush ??= _flush().whenComplete(() { _pendingFlush = null; });
  }

  Future<void> _flush() async {
    await _maybeRotate();

    final pendingWrite = _writer.writeString(_buffer.toString());
    _buffer.clear();
    try {
      await pendingWrite;
    } catch (e) {
      _fail('could not write to log file ${_writer.path}', e);
    }

    try {
      _writer.flushSync();
    } catch (e) {
      _fail('could not flush log file ${_writer.path}', e);
    }
  }

  Future<void> _maybeRotate() async {
    if (closed) {
      return;
    }
    int sizeBytes;
    try {
      sizeBytes = _writer.positionSync();
    } catch (e) {
      _fail('could not get size of log file ${_writer.path}', e);
    }
    if (sizeBytes >= maxSizeBytes) {
      try {
        // Of course there is a race condition where the file gets deleted by some other process,
        // right after we checked. But that's fine, because this check is just to avoid logging
        // an error if the file does not exist.
        if (!_previous.existsSync()) {
          return;
        }
      } catch (e) {
        _logLoggerError('could not check existence of log file ${_previous.path}', e);
      }
      try {
        _previous.deleteSync();
      } catch (e) {
        _logLoggerError('could not delete log file ${_previous.path}', e);
      }
      _writer.close();
      _writer = null;

      try {
        _current.renameSync(_previous.path);
      } catch (e) {
        _fail('could not rename log file ${_current.path} to ${_previous.path}', e);
      }

      try {
        _writer = _current.openSync(mode: FileMode.write);
      } catch (e) {
        _fail('could not open log file ${_current.path}', e);
      }
    }
  }

  void _fail(String message, dynamic e) {
    if (_failureMessage == null) {
      _failureMessage = '$message: $e';
      _logLoggerError(_failureMessage);
    }
    close();
  }

  static void _logLoggerError(String message, [dynamic e]) {
    if (e != null) {
      message = '$message: $e';
    }
    print('ERROR: $message'); // ignore: avoid_print
  }
}