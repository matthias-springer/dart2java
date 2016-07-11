import 'compiler.dart' show CompilerOptions;

import 'package:kernel/ast.dart' as dart;
import 'package:path/path.dart' as path;

import '../java/ast.dart' as java;
import '../java/java_builder.dart' show JavaAstBuilder;
import '../java/java_emitter.dart' show JavaAstEmitter;
import 'runner.dart' show CompileErrorException;
import 'writer.dart' show FileWriter;
import 'compiler_state.dart';

class CodeGenerator {
  final CompilerOptions options;
  final FileWriter writer;

  CodeGenerator(this.options, this.writer);

  /// Compile [library] to a set of Java files.
  ///
  /// Returns the set of the files that have been written.
  Set<File> compile(dart.Library library) {
    String package = getJavaPackageName(options, library);

    var filesWritten = new Set<File>();

    if (library.procedures.isNotEmpty || library.fields.isNotEmpty) {
      // TODO(andrewkrieger): Check for name collisions.
      String className = package.split('.').last;
      java.ClassDecl cls =
          JavaAstBuilder.buildWrapperClass(package, className, library);
      filesWritten.add(writer.writeJavaFile(
          package, className, JavaAstEmitter.emitClassDecl(cls)));
    }

    for (var dartCls in library.classes) {
      java.ClassDecl cls = JavaAstBuilder.buildClass(package, dartCls, new CompilerState());
      filesWritten.add(writer.writeJavaFile(
          package, cls.name, JavaAstEmitter.emitClassDecl(cls)));
    }

    return filesWritten;
  }
}

/// Get a Java package name for a Dart Library.
///
/// The package name always has at least one identifier in it (it will never be
/// the empty string). The package name is essentially just
/// [options.packagePrefix] plus the relative path from [options.buildRoot] to
/// the [library] source file (with '/' replaced by '.', of course).
String getJavaPackageName(CompilerOptions options, dart.Library library) {
  String libraryPath = library.importUri.toFilePath();

  if (path.isWithin(options.buildRoot, libraryPath)) {
    // Omit empty parts, to handle cases like `packagePrefix == "org.example."`
    // or `packagePrefix == ""`.
    List<String> packageParts = options.packagePrefix
        .split('.')
        .where((String part) => part.isNotEmpty)
        .toList();
    String relativePath = path.relative(libraryPath, from: options.buildRoot);
    packageParts.addAll(path.split(path.withoutExtension(relativePath)));
    // TODO(andrewkrieger): Maybe validate the package name?
    return packageParts.join('.');
  } else {
    throw new CompileErrorException('All sources must be inside build-root.');
  }
}
