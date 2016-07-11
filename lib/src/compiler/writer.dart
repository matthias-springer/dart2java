// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' show File;

import 'package:path/path.dart' as path;

import 'compiler.dart' show CompilerOptions;

/// Writes output from the compiler to the filesystem.
///
/// As the [CodeGenerator] traverses the Dart AST, it will emit multiple files:
/// one Java file per Java class, summary files, and mapping files. This class
/// is repsonsible for opening a file at the proper path and writing the file
/// contents out to disk.
///
/// The compiler should depend only on the public interface of this class, so
/// that it's easy to add alternate implementations in the future.
class FileWriter {
  final CompilerOptions _options;

  /// Creates a [FileWriter] using the provided [CompilerOptions].
  ///
  /// [CompilerOptions.outputDir] is used as the base output directory for Java
  /// files. A Java class with package `org.example.foo` and class `FooBar`
  /// will be written to `${_options.outputDir}/org/example/foo/FooBar.java`.
  FileWriter(this._options);

  /// Write the [contents] to a file.
  ///
  /// [package] and [className] are used to generate the file name, following
  /// Java conventions. Returns the written file.
  File writeJavaFile(String package, String className, String contents) {
    var file = new File(path.join(_options.outputDir,
        package.replaceAll('.', path.separator), className + '.java'));
    file.createSync(recursive: true);
    file.writeAsStringSync(contents);
    return file;
  }
}
