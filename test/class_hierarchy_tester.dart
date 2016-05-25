// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:kernel/kernel.dart';
import 'package:kernel/class_hierarchy.dart';
import 'package:test/test.dart';
import 'class_hierarchy_basic.dart';
import 'util.dart';
import 'dart:io';
import 'dart:math';

/// Checks class hierarchy correctness by comparing every possible query
/// on a given program against a naive implementation.
main(List<String> args) {
  var options = readOptions(args);
  Program program = options.loadProgram();
  testClassHierarchyOnProgram(program, verbose: true);
}

void testClassHierarchyOnProgram(Program program, {bool verbose: false}) {
  BasicClassHierarchy basic = new BasicClassHierarchy(program);
  ClassHierarchy classHierarchy = new ClassHierarchy(program);
  int total = classHierarchy.classes.length;
  int progress = 0;
  for (var class1 in classHierarchy.classes) {
    for (var class2 in classHierarchy.classes) {
      bool isSubclass = classHierarchy.isSubclassOf(class1, class2);
      bool isSubmixture = classHierarchy.isSubmixtureOf(class1, class2);
      bool isSubtype = classHierarchy.isSubtypeOf(class1, class2);
      var asInstance = classHierarchy.getClassAsInstanceOf(class1, class2);
      if (isSubclass != basic.isSubclassOf(class1, class2)) {
        fail('isSubclassOf(${class1.name}, ${class2.name}) returned '
            '$isSubclass but should be ${!isSubclass}');
      }
      if (isSubmixture != basic.isSubmixtureOf(class1, class2)) {
        fail('isSubmixtureOf(${class1.name}, ${class2.name}) returned '
            '$isSubclass but should be ${!isSubclass}');
      }
      if (isSubtype != basic.isSubtypeOf(class1, class2)) {
        fail('isSubtypeOf(${class1.name}, ${class2.name}) returned '
            '$isSubtype but should be ${!isSubtype}');
      }
      if (asInstance != basic.getClassAsInstanceOf(class1, class2)) {
        fail('asInstanceOf(${class1.name}, ${class2.name}) returned '
            '$asInstance but should be '
            '${basic.getClassAsInstanceOf(class1, class2)}');
      }
    }
    ++progress;
    if (verbose) {
      stdout.write('\rSubclass queries ${100 * progress ~/ total}%');
    }
  }
  Set<Name> names = new Set<Name>();
  for (var classNode in classHierarchy.classes) {
    for (var member in classNode.members) {
      names.add(member.name);
    }
  }
  List<Name> nameList = names.toList();
  progress = 0;
  for (var classNode in classHierarchy.classes) {
    Iterable<Name> candidateNames =
        [basic.gettersAndCalls[classNode].keys,
         basic.setters[classNode].keys,
         pickRandom(nameList, 100)].expand((x) => x);
    for (Name name in candidateNames) {
      Member expectedGetter =
          basic.getDispatchTarget(classNode, name, setter: false);
      Member expectedSetter =
          basic.getDispatchTarget(classNode, name, setter: true);
      Member actualGetter = classHierarchy
          .getDispatchTarget(classNode, name, setter: false);
      Member actualSetter = classHierarchy
          .getDispatchTarget(classNode, name, setter: true);
      if (actualGetter != expectedGetter) {
        fail('lookupGetter($classNode, $name) returned '
            '$actualGetter but should be $expectedGetter');
      }
      if (actualSetter != expectedSetter) {
        fail('lookupSetter($classNode, $name) returned '
            '$actualSetter but should be $expectedSetter');
      }
    }
    ++progress;
    if (verbose) {
      stdout.write('\rEnvironment queries ${100 * progress ~/ total}%');
    }
  }
  if (verbose) {
    print('\rProgress 100%. Done.');
  }
}

var random = new Random(12345);

List pickRandom(List items, int n) {
  var result = [];
  for (int i = 0; i < n; ++i) {
    result.add(items[random.nextInt(items.length)]);
  }
  return result;
}