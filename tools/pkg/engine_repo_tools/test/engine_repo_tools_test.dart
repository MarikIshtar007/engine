// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io' as io;
import 'package:async_helper/async_helper.dart';
import 'package:engine_repo_tools/engine_repo_tools.dart';
import 'package:litetest/litetest.dart';
import 'package:path/path.dart' as p;

void main() {
  late io.Directory emptyDir;

  void setUp() {
    emptyDir = io.Directory.systemTemp.createTempSync('engine_repo_tools.test');
  }

  void tearDown() {
    emptyDir.deleteSync(recursive: true);
  }

  group('Engine.fromSrcPath', () {
    group('should fail when', () {
      test('the path does not end in `${p.separator}src`', () {
        setUp();
        try {
          expect(
          () => Engine.fromSrcPath(emptyDir.path),
          _throwsInvalidEngineException,
        );
        } finally {
          tearDown();
        }
      });

      test('the path does not exist', () {
        setUp();
        try {
          expect(
            () => Engine.fromSrcPath(p.join(emptyDir.path, 'src')),
            _throwsInvalidEngineException,
          );
        } finally {
          tearDown();
        }
      });

      test('the path does not contain a "flutter" directory', () {
        setUp();
        try {
          final io.Directory srcDir = io.Directory(p.join(emptyDir.path, 'src'))..createSync();
          expect(
            () => Engine.fromSrcPath(srcDir.path),
            _throwsInvalidEngineException,
          );
        } finally {
          tearDown();
        }
      });

      test('returns an Engine', () {
        setUp();
        try {
          final io.Directory srcDir = io.Directory(p.join(emptyDir.path, 'src'))..createSync();
          io.Directory(p.join(srcDir.path, 'flutter')).createSync();
          io.Directory(p.join(srcDir.path, 'out')).createSync();

          final Engine engine = Engine.fromSrcPath(srcDir.path);

          expect(engine.srcDir.path, srcDir.path);
          expect(engine.flutterDir.path, p.join(srcDir.path, 'flutter'));
          expect(engine.outDir.path, p.join(srcDir.path, 'out'));
        } finally {
          tearDown();
        }
      });
    });
  });

  group('Engine.findWithin', () {
    late io.Directory emptyDir;

    void setUp() {
      emptyDir = io.Directory.systemTemp.createTempSync('engine_repo_tools.test');
    }

    void tearDown() {
      emptyDir.deleteSync(recursive: true);
    }

    group('should fail when', () {
      test('the path does not contain a "src" directory', () {
        setUp();
        try {
          expect(
            () => Engine.findWithin(emptyDir.path),
            throwsStateError,
          );
        } finally {
          tearDown();
        }
      });

      test('the path contains a "src" directory but it is not an engine root', () {
        setUp();
        try {
          final io.Directory srcDir = io.Directory(p.join(emptyDir.path, 'src'))..createSync();
          expect(
            () => Engine.findWithin(srcDir.path),
            throwsStateError,
          );
        } finally {
          tearDown();
        }
      });

      test('returns an Engine', () {
        setUp();
        try {
          final io.Directory srcDir = io.Directory(p.join(emptyDir.path, 'src'))..createSync();
          io.Directory(p.join(srcDir.path, 'flutter')).createSync();
          io.Directory(p.join(srcDir.path, 'out')).createSync();

          final Engine engine = Engine.findWithin(srcDir.path);

          expect(engine.srcDir.path, srcDir.path);
          expect(engine.flutterDir.path, p.join(srcDir.path, 'flutter'));
          expect(engine.outDir.path, p.join(srcDir.path, 'out'));
        } finally {
          tearDown();
        }
      });

      test('returns an Engine even if a "src" directory exists deeper in the tree', () {
        // It's common to have "src" directories, so if we have something like:
        //  /Users/.../engine/src/foo/bar/src/baz
        //
        // And we use `Engine.findWithin('/Users/.../engine/src/flutter/bar/src/baz')`,
        // we should still find the engine (in this case, the engine root is
        // `/Users/.../engine/src`).
        setUp();
        try {
          final io.Directory srcDir = io.Directory(p.join(emptyDir.path, 'src'))..createSync();
          io.Directory(p.join(srcDir.path, 'flutter')).createSync();
          io.Directory(p.join(srcDir.path, 'out')).createSync();

          final io.Directory nestedSrcDir = io.Directory(p.join(srcDir.path, 'flutter', 'bar', 'src', 'baz'))..createSync(recursive: true);

          final Engine engine = Engine.findWithin(nestedSrcDir.path);

          expect(engine.srcDir.path, srcDir.path);
          expect(engine.flutterDir.path, p.join(srcDir.path, 'flutter'));
          expect(engine.outDir.path, p.join(srcDir.path, 'out'));
        } finally {
          tearDown();
        }
      });
    });
  });

  test('outputs an empty list of targets', () {
    setUp();

    try {
      // Create a valid engine.
      io.Directory(p.join(emptyDir.path, 'src', 'flutter')).createSync(recursive: true);
      io.Directory(p.join(emptyDir.path, 'src', 'out')).createSync(recursive: true);

      final Engine engine = Engine.fromSrcPath(p.join(emptyDir.path, 'src'));
      expect(engine.outputs(), <Output>[]);
      expect(engine.latestOutput(), isNull);
    } finally {
      tearDown();
    }
  });

  test('outputs a list of targets', () {
    setUp();

    try {
      // Create a valid engine.
      io.Directory(p.join(emptyDir.path, 'src', 'flutter')).createSync(recursive: true);
      io.Directory(p.join(emptyDir.path, 'src', 'out')).createSync(recursive: true);

      // Create two targets in out: host_debug and host_debug_unopt_arm64.
      io.Directory(p.join(emptyDir.path, 'src', 'out', 'host_debug')).createSync(recursive: true);
      io.Directory(p.join(emptyDir.path, 'src', 'out', 'host_debug_unopt_arm64')).createSync(recursive: true);

      final Engine engine = Engine.fromSrcPath(p.join(emptyDir.path, 'src'));
      final List<String> outputs = engine.outputs().map((Output o) => p.basename(o.dir.path)).toList()..sort();
      expect(outputs, <String>[
        'host_debug',
        'host_debug_unopt_arm64',
      ]);
    } finally {
      tearDown();
    }
  });

  test('outputs the latest target and compile_commands.json', () {
    setUp();

    try {
      // Create a valid engine.
      io.Directory(p.join(emptyDir.path, 'src', 'flutter')).createSync(recursive: true);
      io.Directory(p.join(emptyDir.path, 'src', 'out')).createSync(recursive: true);

      // Create two targets in out: host_debug and host_debug_unopt_arm64.
      io.Directory(p.join(emptyDir.path, 'src', 'out', 'host_debug')).createSync(recursive: true);
      io.Directory(p.join(emptyDir.path, 'src', 'out', 'host_debug_unopt_arm64')).createSync(recursive: true);

      // Intentionnally make host_debug a day old to ensure it is not picked.
      final io.File oldJson = io.File(p.join(emptyDir.path, 'src', 'out', 'host_debug', 'compile_commands.json'))..createSync();
      oldJson.setLastModifiedSync(oldJson.lastModifiedSync().subtract(const Duration(days: 1)));

      io.File(p.join(emptyDir.path, 'src', 'out', 'host_debug_unopt_arm64', 'compile_commands.json')).createSync();

      final Engine engine = Engine.fromSrcPath(p.join(emptyDir.path, 'src'));
      final Output? latestOutput = engine.latestOutput();
      expect(latestOutput, isNotNull);
      expect(p.basename(latestOutput!.dir.path), 'host_debug_unopt_arm64');
      expect(latestOutput.compileCommandsJson, isNotNull);
    } finally {
      tearDown();
    }
  });
}

// This is needed because async_minitest and friends is not a proper testing
// library and is missing a lot of functionality that was exclusively added
// to pkg/test.
void _throwsInvalidEngineException(Object? o) {
  _checkThrow<InvalidEngineException>(o, (_){});
}

// Mostly copied from async_minitest.
void _checkThrow<T extends Object>(dynamic v, void Function(dynamic error) onError) {
  if (v is Future) {
    asyncStart();
    v.then((_) {
      Expect.fail('Did not throw');
    }, onError: (Object e, StackTrace s) {
      if (e is! T) {
        // ignore: only_throw_errors
        throw e;
      }
      onError(e);
      asyncEnd();
    });
    return;
  }
  v as void Function();
  Expect.throws<T>(v, (T e) {
    onError(e);
    return true;
  });
}
