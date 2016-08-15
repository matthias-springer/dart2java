// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library kernel.analyzer.ast_from_analyzer;

import '../ast.dart' as ast;
import '../frontend/accessors.dart';
import '../frontend/super_calls.dart';
import '../log.dart';
import '../type_algebra.dart';
import 'analyzer.dart';
import 'loader.dart';

/// Provides reference-level access to libraries, classes, and members.
///
/// "References level" objects are incomplete nodes that have no children but
/// can be used for linking until the loader upgrades the node to "body level".
///
/// The [ReferenceScope] is the most restrictive scope in a hierarchy of scopes
/// that provide increasing amounts of contextual information.  [TypeScope] is
/// used when type parameters might be in scope, and [MemberScope] is used when
/// building the body of a [ast.Member].
class ReferenceScope {
  final ReferenceLevelLoader loader;

  ReferenceScope(this.loader);

  bool get strongMode => loader.strongMode;

  ast.Library getLibraryReference(LibraryElement element) {
    if (element == null) return null;
    return loader.getLibraryReference(getBaseElement(element));
  }

  ast.Class getRootClassReference() {
    return loader.getRootClassReference();
  }

  ast.Class getClassReference(ClassElement element) {
    return loader.getClassReference(getBaseElement(element));
  }

  ast.Member getMemberReference(Element element) {
    return loader.getMemberReference(getBaseElement(element));
  }

  static Element getBaseElement(Element element) {
    if (element is Member) {
      return element.baseElement;
    }
    return element;
  }

  bool supportsGet(Element element) {
    return (element is PropertyAccessorElement &&
            element.isGetter &&
            !element.isAbstract) ||
        element is FieldElement ||
        element is TopLevelVariableElement ||
        element is MethodElement && !element.isAbstract ||
        isTopLevelFunction(element);
  }

  bool supportsSet(Element element) {
    return (element is PropertyAccessorElement &&
            element.isSetter &&
            !element.isAbstract) ||
        element is FieldElement && !element.isFinal && !element.isConst ||
        element is TopLevelVariableElement &&
            !element.isFinal &&
            !element.isConst;
  }

  bool supportsIndexGet(Element element) {
    return element is MethodElement &&
        element.name == '[]' &&
        !element.isAbstract;
  }

  bool supportsIndexSet(Element element) {
    return element is MethodElement &&
        element.name == '[]=' &&
        !element.isAbstract;
  }

  bool isTopLevelFunction(Element element) {
    return element is FunctionElement &&
        element.enclosingElement is CompilationUnitElement;
  }

  bool isLocalFunction(Element element) {
    return element is FunctionElement &&
        element.enclosingElement is! CompilationUnitElement;
  }

  bool isLocal(Element element) {
    return isLocalFunction(element) ||
        element is LocalVariableElement ||
        element is ParameterElement;
  }

  bool isInstanceMethod(Element element) {
    return element is MethodElement && !element.isStatic;
  }

  bool isStaticMethod(Element element) {
    return element is MethodElement && element.isStatic ||
        isTopLevelFunction(element);
  }

  bool isStaticVariableOrGetter(Element element) {
    element = desynthesizeGetter(element);
    return element is FieldElement && element.isStatic ||
        element is TopLevelVariableElement;
  }

  bool supportsMethodCall(Element element) {
    // Note that local functions are not valid targets for method calls because
    // they are not "methods" or even "procedures" in our AST.
    return element is MethodElement && !element.isAbstract ||
        isTopLevelFunction(element) ||
        element is ConstructorElement && element.isFactory;
  }

  bool supportsConstructorCall(Element element) {
    return element is ConstructorElement && !element.isFactory;
  }

  Element desynthesizeGetter(Element element) {
    if (element == null || !element.isSynthetic) return element;
    if (element is PropertyAccessorElement) return element.variable;
    if (element is FieldElement) return element.getter;
    return element;
  }

  Element desynthesizeSetter(Element element) {
    if (element == null || !element.isSynthetic) return element;
    if (element is PropertyAccessorElement) return element.variable;
    if (element is FieldElement) return element.setter;
    return element;
  }

  ast.Member resolveGet(Element element, Element auxiliary) {
    element = desynthesizeGetter(element);
    if (supportsGet(element)) return getMemberReference(element);
    auxiliary = desynthesizeGetter(auxiliary);
    if (supportsGet(auxiliary)) return getMemberReference(auxiliary);
    return null;
  }

  ast.Member resolveSet(Element element, Element auxiliary) {
    element = desynthesizeSetter(element);
    if (supportsSet(element)) return getMemberReference(element);
    auxiliary = desynthesizeSetter(auxiliary);
    if (supportsSet(auxiliary)) return getMemberReference(auxiliary);
    return null;
  }

  ast.Member resolveIndexGet(Element element, Element auxiliary) {
    if (supportsIndexGet(element)) return getMemberReference(element);
    if (supportsIndexGet(auxiliary)) return getMemberReference(auxiliary);
    return null;
  }

  ast.Member resolveIndexSet(Element element, Element auxiliary) {
    if (supportsIndexSet(element)) return getMemberReference(element);
    if (supportsIndexSet(auxiliary)) return getMemberReference(auxiliary);
    return null;
  }

  ast.Member resolveMethod(Element element) {
    return supportsMethodCall(element) ? getMemberReference(element) : null;
  }

  ast.Constructor resolveConstructor(Element element) {
    return supportsConstructorCall(element)
        ? getMemberReference(element)
        : null;
  }

  ast.Field resolveField(Element element) {
    if (element is FieldElement && !element.isSynthetic) {
      return getMemberReference(element);
    }
    return null;
  }
}

class TypeScope extends ReferenceScope {
  final Map<TypeParameterElement, ast.TypeParameter> localTypeParameters =
      <TypeParameterElement, ast.TypeParameter>{};

  TypeScope(ReferenceLevelLoader loader) : super(loader);

  String get location => '?';

  ast.TypeParameter getTypeParameterReference(TypeParameterElement element) {
    return localTypeParameters[element] ??
        loader.tryGetClassTypeParameter(element) ??
        (localTypeParameters[element] = new ast.TypeParameter(element.name));
  }

  ast.TypeParameter makeTypeParameter(TypeParameterElement element,
      {ast.DartType bound}) {
    var typeParameter = getTypeParameterReference(element);
    if (bound != null) {
      typeParameter.bound = bound;
    }
    return typeParameter;
  }

  ast.DartType buildType(DartType type) {
    return new TypeAnnotationBuilder(this).buildFromDartType(type);
  }

  ast.DartType buildTypeAnnotation(AstNode node) {
    return new TypeAnnotationBuilder(this).build(node);
  }

  ast.DartType buildOptionalTypeAnnotation(AstNode node) {
    return node == null ? null : new TypeAnnotationBuilder(this).build(node);
  }

  ast.DartType getInferredType(Expression node) {
    if (!strongMode) return const ast.DynamicType();
    // TODO: Is this official way to get the strong-mode inferred type?
    return buildType(node.staticType);
  }

  ast.DartType getInferredTypeArgument(Expression node, int index) {
    var type = getInferredType(node);
    return type is ast.InterfaceType && index < type.typeArguments.length
        ? type.typeArguments[index]
        : const ast.DynamicType();
  }

  ast.DartType getInferredReturnType(Expression node) {
    var type = getInferredType(node);
    return type is ast.FunctionType ? type.returnType : const ast.DynamicType();
  }

  List<ast.DartType> getInferredInvocationTypeArguments(
      InvocationExpression node) {
    if (!strongMode) return <ast.DartType>[];
    ast.DartType inferredFunctionType = buildType(node.staticInvokeType);
    ast.DartType genericFunctionType = buildType(node.function.staticType);
    if (genericFunctionType is ast.FunctionType) {
      if (genericFunctionType.typeParameters.isEmpty) return <ast.DartType>[];
      // Attempt to unify the two types to obtain a substitution of the type
      // variables.  If successful, use the substituted types in the order
      // they occur in the type parameter list.
      var substitution = unifyTypes(genericFunctionType.withoutTypeParameters,
          inferredFunctionType, genericFunctionType.typeParameters.toSet());
      if (substitution != null) {
        return genericFunctionType.typeParameters
            .map((p) => substitution[p] ?? const ast.DynamicType())
            .toList();
      }
      return new List<ast.DartType>.filled(
          genericFunctionType.typeParameters.length, const ast.DynamicType());
    } else {
      return <ast.DartType>[];
    }
  }

  List<ast.DartType> buildOptionalTypeArgumentList(TypeArgumentList node) {
    if (node == null) return <ast.DartType>[];
    return new TypeAnnotationBuilder(this).buildList(node.arguments);
  }

  List<ast.DartType> buildTypeArgumentList(TypeArgumentList node) {
    return new TypeAnnotationBuilder(this).buildList(node.arguments);
  }

  List<ast.TypeParameter> buildOptionalTypeParameterList(
      TypeParameterList node) {
    if (node == null) return <ast.TypeParameter>[];
    return node.typeParameters.map(buildTypeParameter).toList();
  }

  ast.TypeParameter buildTypeParameter(TypeParameter node) {
    return makeTypeParameter(node.element,
        bound:
            buildOptionalTypeAnnotation(node.bound) ?? const ast.DynamicType());
  }

  ConstructorElement findDefaultConstructor(ClassElement class_) {
    for (var constructor in class_.constructors) {
      // Note: isDefaultConstructor checks if the constructor is suitable for
      // being invoked without arguments.  It does not imply that it is
      // synthetic.
      if (constructor.isDefaultConstructor && !constructor.isFactory) {
        return constructor;
      }
    }
    return null;
  }
}

/// Translates expressions, statements, and other constructs into [ast] nodes.
///
/// Naming convention:
/// - `buildX` may not be given null as argument (it may crash the compiler).
/// - `buildOptionalX` returns null or an empty list if given null
/// - `buildMandatoryX` returns an invalid node if given null.
class MemberScope extends TypeScope {
  final Map<LocalElement, ast.VariableDeclaration> localVariables =
      <LocalElement, ast.VariableDeclaration>{};

  /// A reference to the member currently being upgraded to body level.
  final ast.Member currentMember;

  ExpressionBuilder _expressionBuilder;
  StatementBuilder _statementBuilder;

  MemberScope(ReferenceLevelLoader loader, this.currentMember) : super(loader) {
    assert(currentMember != null);
    _expressionBuilder = new ExpressionBuilder(this);
    _statementBuilder = new StatementBuilder(this);
  }

  /// The library containing the code, currently at body level.
  ast.Library get currentLibrary => currentMember.enclosingLibrary;

  ast.Class get currentClass => currentMember.enclosingClass;

  bool get allowThis => _memberHasThis(currentMember);

  /// Returns a string for debugging use, indicating the location of the member
  /// being built.
  String get location {
    var library = currentMember.enclosingLibrary?.importUri ?? '<No Library>';
    var className = currentMember.enclosingClass == null
        ? null
        : (currentMember.enclosingClass?.name ?? '<Anonymous Class>');
    var member =
        currentMember.name?.name ?? '<Anonymous ${currentMember.runtimeType}>';
    return [library, className, member].join('::');
  }

  bool _memberHasThis(ast.Member member) {
    return member is ast.Procedure && !member.isStatic ||
        member is ast.Constructor;
  }

  ast.Name buildName(SimpleIdentifier node) {
    return new ast.Name(node.name, currentLibrary);
  }

  ast.Statement buildStatement(Statement node) {
    return _statementBuilder.build(node);
  }

  ast.Statement buildOptionalFunctionBody(FunctionBody body) {
    if (body == null || body is EmptyFunctionBody) return null;
    return buildMandatoryFunctionBody(body);
  }

  ast.Statement buildMandatoryFunctionBody(FunctionBody body) {
    if (body is BlockFunctionBody) {
      return buildStatement(body.block);
    }
    if (body is ExpressionFunctionBody) {
      return new ast.ReturnStatement(buildExpression(body.expression));
    }
    return new ast.InvalidStatement();
  }

  ast.AsyncMarker getAsyncMarker({bool isAsync: false, bool isStar: false}) {
    return ast.AsyncMarker.values[(isAsync ? 2 : 0) + (isStar ? 1 : 0)];
  }

  ast.FunctionNode buildFunctionNode(
      FormalParameterList formalParameters, FunctionBody body,
      {TypeName returnType,
      List<ast.TypeParameter> typeParameters,
      ast.DartType inferredReturnType}) {
    var positional = <ast.VariableDeclaration>[];
    var named = <ast.VariableDeclaration>[];
    int requiredParameterCount = 0;
    var formals = formalParameters?.parameters ?? const <FormalParameter>[];
    for (var parameter in formals) {
      var declaration = makeVariableDeclaration(parameter.element,
          initializer: parameter is DefaultFormalParameter
              ? buildOptionalExpression(parameter.defaultValue)
              : null,
          type: buildType(parameter.element.type));
      switch (parameter.kind) {
        case ParameterKind.REQUIRED:
          positional.add(declaration);
          ++requiredParameterCount;
          declaration.initializer = null;
          break;

        case ParameterKind.POSITIONAL:
          positional.add(declaration);
          break;

        case ParameterKind.NAMED:
          named.add(declaration);
          break;
      }
    }
    return new ast.FunctionNode(buildOptionalFunctionBody(body),
        typeParameters: typeParameters,
        positionalParameters: positional,
        namedParameters: named,
        requiredParameterCount: requiredParameterCount,
        returnType: buildOptionalTypeAnnotation(returnType) ??
            inferredReturnType ??
            const ast.DynamicType(),
        asyncMarker: getAsyncMarker(
            isAsync: body.isAsynchronous, isStar: body.isGenerator));
  }

  ast.Expression buildExpression(Expression node) {
    return _expressionBuilder.build(node);
  }

  ast.Expression buildOptionalExpression(Expression node) {
    return node == null ? null : _expressionBuilder.build(node);
  }

  Accessor buildLeftHandValue(Expression node) {
    return _expressionBuilder.buildLeftHandValue(node);
  }

  ast.Expression buildStringLiteral(Expression node) {
    List<ast.Expression> parts = <ast.Expression>[];
    new StringLiteralPartBuilder(this, parts).build(node);
    return parts.length == 1 && parts[0] is ast.StringLiteral
        ? parts[0]
        : new ast.StringConcatenation(parts);
  }

  ast.Expression buildThis() {
    if (allowThis) {
      return new ast.ThisExpression(currentClass.thisType);
    } else {
      return new ast.InvalidExpression();
    }
  }

  ast.Initializer buildInitializer(ConstructorInitializer node) {
    return new InitializerBuilder(this).build(node);
  }

  bool isFinal(Element element) {
    return element is VariableElement && element.isFinal ||
        element is FunctionElement;
  }

  bool isConst(Element element) {
    return element is VariableElement && element.isConst;
  }

  ast.VariableDeclaration getVariableReference(LocalElement element) {
    return localVariables.putIfAbsent(element, () {
      return new ast.VariableDeclaration(element.name,
          isFinal: isFinal(element), isConst: isConst(element));
    });
  }

  ast.DartType getInferredVariableType(Element element) {
    if (!strongMode) return const ast.DynamicType();
    if (element is FunctionTypedElement) {
      return buildType(element.type);
    } else if (element is VariableElement) {
      return buildType(element.type);
    } else {
      log.severe('Unexpected variable element: $element');
      return const ast.DynamicType();
    }
  }

  ast.VariableDeclaration makeVariableDeclaration(LocalElement element,
      {ast.DartType type, ast.Expression initializer}) {
    var declaration = getVariableReference(element);
    declaration.type = type ?? getInferredVariableType(element);
    if (initializer != null) {
      declaration.initializer = initializer..parent = declaration;
    }
    return declaration;
  }
}

class LabelStack {
  final List<String> labels; // Contains null for unlabeled targets.
  final LabelStack next;
  final List<ast.Statement> jumps = <ast.Statement>[];
  bool isSwitchTarget = false;

  LabelStack(String label, this.next) : labels = <String>[label];
  LabelStack.unlabeled(this.next) : labels = <String>[null];
  LabelStack.switchCase(String label, this.next)
      : isSwitchTarget = true,
        labels = <String>[label];
  LabelStack.many(this.labels, this.next);
}

class StatementBuilder extends GeneralizingAstVisitor<ast.Statement> {
  final MemberScope scope;
  final LabelStack breakStack, continueStack;

  StatementBuilder(this.scope, [this.breakStack, this.continueStack]);

  ast.Statement build(Statement node) {
    return node.accept(this);
  }

  ast.Statement buildOptional(Statement node) {
    return node?.accept(this);
  }

  ast.Statement buildInScope(
      Statement node, LabelStack breakNode, LabelStack continueNode) {
    return new StatementBuilder(scope, breakNode, continueNode).build(node);
  }

  void buildBlockMember(Statement node, List<ast.Statement> output) {
    if (node is LabeledStatement &&
        node.statement is VariableDeclarationStatement) {
      // If a variable is labeled, its scope is part of the enclosing block.
      LabeledStatement labeled = node;
      node = labeled.statement;
    }
    if (node is VariableDeclarationStatement) {
      VariableDeclarationList list = node.variables;
      ast.DartType type = scope.buildOptionalTypeAnnotation(list.type);
      for (VariableDeclaration decl in list.variables) {
        LocalElement local = decl.element as dynamic; // Cross cast.
        output.add(scope.makeVariableDeclaration(local,
            type: type,
            initializer: scope.buildOptionalExpression(decl.initializer)));
      }
    } else {
      output.add(build(node));
    }
  }

  ast.Statement makeBreakTarget(ast.Statement node, LabelStack stackNode) {
    if (stackNode.jumps.isEmpty) return node;
    var labeled = new ast.LabeledStatement(node);
    for (var jump in stackNode.jumps) {
      (jump as ast.BreakStatement).target = labeled;
    }
    return labeled;
  }

  LabelStack findLabelTarget(String label, LabelStack stack) {
    while (stack != null) {
      if (stack.labels.contains(label)) return stack;
      stack = stack.next;
    }
    return null;
  }

  ast.Statement visitAssertStatement(AssertStatement node) {
    return new ast.AssertStatement(scope.buildExpression(node.condition),
        scope.buildOptionalExpression(node.message));
  }

  ast.Statement visitBlock(Block node) {
    List<ast.Statement> statements = <ast.Statement>[];
    for (Statement statement in node.statements) {
      buildBlockMember(statement, statements);
    }
    return new ast.Block(statements);
  }

  ast.Statement visitBreakStatement(BreakStatement node) {
    var stackNode = findLabelTarget(node.label?.name, breakStack);
    if (stackNode == null) return new ast.InvalidStatement();
    var result = new ast.BreakStatement(null);
    stackNode.jumps.add(result);
    return result;
  }

  ast.Statement visitContinueStatement(ContinueStatement node) {
    var stackNode = findLabelTarget(node.label?.name, continueStack);
    if (stackNode == null) return new ast.InvalidStatement();
    var result = stackNode.isSwitchTarget
        ? new ast.ContinueSwitchStatement(null)
        : new ast.BreakStatement(null);
    stackNode.jumps.add(result);
    return result;
  }

  void addLoopLabels(Statement loop, LabelStack continueNode) {
    AstNode parent = loop.parent;
    if (parent is LabeledStatement) {
      for (var label in parent.labels) {
        continueNode.labels.add(label.label.name);
      }
    }
  }

  ast.Statement visitDoStatement(DoStatement node) {
    LabelStack breakNode = new LabelStack.unlabeled(breakStack);
    LabelStack continueNode = new LabelStack.unlabeled(continueStack);
    addLoopLabels(node, continueNode);
    var body = buildInScope(node.body, breakNode, continueNode);
    var loop = new ast.DoStatement(makeBreakTarget(body, continueNode),
        scope.buildExpression(node.condition));
    return makeBreakTarget(loop, breakNode);
  }

  ast.Statement visitWhileStatement(WhileStatement node) {
    LabelStack breakNode = new LabelStack.unlabeled(breakStack);
    LabelStack continueNode = new LabelStack.unlabeled(continueStack);
    addLoopLabels(node, continueNode);
    var body = buildInScope(node.body, breakNode, continueNode);
    var loop = new ast.WhileStatement(scope.buildExpression(node.condition),
        makeBreakTarget(body, continueNode));
    return makeBreakTarget(loop, breakNode);
  }

  ast.Statement visitEmptyStatement(EmptyStatement node) {
    return new ast.EmptyStatement();
  }

  ast.Statement visitExpressionStatement(ExpressionStatement node) {
    return new ast.ExpressionStatement(scope.buildExpression(node.expression));
  }

  static String _getLabelName(Label label) {
    return label.label.name;
  }

  ast.Statement visitLabeledStatement(LabeledStatement node) {
    // Only set up breaks here.  Loops handle labeling on their own.
    var breakNode = new LabelStack.many(
        node.labels.map(_getLabelName).toList(), breakStack);
    var body = buildInScope(node.statement, breakNode, continueStack);
    return makeBreakTarget(body, breakNode);
  }

  ast.Statement visitSwitchStatement(SwitchStatement node) {
    // Group all cases into case blocks.  Use parallel lists to collect the
    // intermediate terms until we are ready to create the AST nodes.
    LabelStack breakNode = new LabelStack.unlabeled(breakStack);
    LabelStack continueNode = continueStack;
    var cases = <ast.SwitchCase>[];
    var bodies = <List<Statement>>[];
    var labelToNode = <String, ast.SwitchCase>{};
    ast.SwitchCase currentCase = null;
    for (var member in node.members) {
      if (currentCase != null && currentCase.isDefault) {
        return new ast.InvalidStatement(); // Case clause after default.
      }
      if (currentCase == null) {
        currentCase = new ast.SwitchCase(<ast.Expression>[], null);
        cases.add(currentCase);
      }
      if (member is SwitchCase) {
        var expression = scope.buildExpression(member.expression);
        currentCase.expressions.add(expression..parent = currentCase);
      } else {
        currentCase.isDefault = true;
      }
      for (Label label in member.labels) {
        continueNode =
            new LabelStack.switchCase(label.label.name, continueNode);
        labelToNode[label.label.name] = currentCase;
      }
      if (member.statements?.isNotEmpty ?? false) {
        bodies.add(member.statements);
        currentCase = null;
      }
    }
    if (currentCase != null) {
      // Close off a trailing block.
      bodies.add(const <Statement>[]);
      currentCase = null;
    }
    // Now that the label environment is set up, build the bodies.
    var innerBuilder = new StatementBuilder(scope, breakNode, continueNode);
    for (int i = 0; i < cases.length; ++i) {
      var blockNodes = <ast.Statement>[];
      for (var statement in bodies[i]) {
        innerBuilder.buildBlockMember(statement, blockNodes);
      }
      cases[i].body = new ast.Block(blockNodes)..parent = cases[i];
    }
    // Unwind the stack of case labels and bind their jumps to the case target.
    while (continueNode != continueStack) {
      for (var jump in continueNode.jumps) {
        (jump as ast.ContinueSwitchStatement).target =
            labelToNode[continueNode.labels.first];
      }
      continueNode = continueNode.next;
    }
    var expression = scope.buildExpression(node.expression);
    var result = new ast.SwitchStatement(expression, cases);
    return makeBreakTarget(result, breakNode);
  }

  ast.Statement visitForStatement(ForStatement node) {
    List<ast.VariableDeclaration> variables = <ast.VariableDeclaration>[];
    ast.Expression initialExpression;
    if (node.variables != null) {
      VariableDeclarationList list = node.variables;
      var type = scope.buildOptionalTypeAnnotation(list.type);
      for (var variable in list.variables) {
        LocalElement local = variable.element as dynamic; // Cross cast.
        variables.add(scope.makeVariableDeclaration(local,
            initializer: scope.buildOptionalExpression(variable.initializer),
            type: type));
      }
    } else if (node.initialization != null) {
      initialExpression = scope.buildExpression(node.initialization);
    }
    var breakNode = new LabelStack.unlabeled(breakStack);
    var continueNode = new LabelStack.unlabeled(continueStack);
    addLoopLabels(node, continueNode);
    var body = buildInScope(node.body, breakNode, continueNode);
    var loop = new ast.ForStatement(
        variables,
        scope.buildOptionalExpression(node.condition),
        node.updaters.map(scope.buildExpression).toList(),
        makeBreakTarget(body, continueNode));
    loop = makeBreakTarget(loop, breakNode);
    if (initialExpression != null) {
      return new ast.Block(<ast.Statement>[
        new ast.ExpressionStatement(initialExpression),
        loop
      ]);
    }
    return loop;
  }

  ast.Statement visitForEachStatement(ForEachStatement node) {
    ast.VariableDeclaration variable;
    Accessor leftHand;
    if (node.loopVariable != null) {
      DeclaredIdentifier loopVariable = node.loopVariable;
      variable = scope.makeVariableDeclaration(loopVariable.element,
          type: scope.buildOptionalTypeAnnotation(loopVariable.type));
    } else if (node.identifier != null) {
      leftHand = scope.buildLeftHandValue(node.identifier);
      // TODO: In strong mode, set variable type based on iterable type.
      variable = new ast.VariableDeclaration(null, isFinal: true);
    }
    var breakNode = new LabelStack.unlabeled(breakStack);
    var continueNode = new LabelStack.unlabeled(continueStack);
    addLoopLabels(node, continueNode);
    var body = buildInScope(node.body, breakNode, continueNode);
    if (leftHand != null) {
      // Desugar
      //
      //     for (x in e) BODY
      //
      // to
      //
      //     for (var tmp in e) {
      //       x = tmp;
      //       BODY
      //     }
      body = new ast.Block(<ast.Statement>[
        new ast.ExpressionStatement(leftHand
            .buildAssignment(new ast.VariableGet(variable), voidContext: true)),
        body
      ]);
    }
    var loop = new ast.ForInStatement(
        variable,
        scope.buildExpression(node.iterable),
        makeBreakTarget(body, continueNode),
        isAsync: node.awaitKeyword != null);
    return makeBreakTarget(loop, breakNode);
  }

  ast.Statement visitIfStatement(IfStatement node) {
    return new ast.IfStatement(scope.buildExpression(node.condition),
        build(node.thenStatement), buildOptional(node.elseStatement));
  }

  ast.Statement visitReturnStatement(ReturnStatement node) {
    return new ast.ReturnStatement(
        scope.buildOptionalExpression(node.expression));
  }

  ast.Catch buildCatchClause(CatchClause node) {
    var exceptionVariable = node.exceptionParameter == null
        ? null
        : scope.makeVariableDeclaration(node.exceptionParameter.staticElement);
    var stackTraceVariable = node.stackTraceParameter == null
        ? null
        : scope.makeVariableDeclaration(node.stackTraceParameter.staticElement);
    return new ast.Catch(exceptionVariable, build(node.body),
        stackTrace: stackTraceVariable,
        guard: scope.buildOptionalTypeAnnotation(node.exceptionType) ??
            const ast.DynamicType());
  }

  ast.Statement visitTryStatement(TryStatement node) {
    ast.Statement statement = build(node.body);
    if (node.catchClauses.isNotEmpty) {
      statement = new ast.TryCatch(
          statement, node.catchClauses.map(buildCatchClause).toList());
    }
    if (node.finallyBlock != null) {
      statement = new ast.TryFinally(statement, build(node.finallyBlock));
    }
    return statement;
  }

  ast.Statement visitVariableDeclarationStatement(
      VariableDeclarationStatement node) {
    // This is only reached when a variable is declared in non-block level,
    // because visitBlock intercepts visits to its children.
    // An example where we hit this case is:
    //
    //   if (foo) var x = 5, y = x + 1;
    //
    // We wrap these in a block:
    //
    //   if (foo) {
    //     var x = 5;
    //     var y = x + 1;
    //   }
    //
    // Note that the use of a block here is required by the kernel language,
    // even if there is only one variable declaration.
    List<ast.Statement> statements = <ast.Statement>[];
    buildBlockMember(node, statements);
    return new ast.Block(statements);
  }

  ast.Statement visitYieldStatement(YieldStatement node) {
    return new ast.YieldStatement(scope.buildExpression(node.expression),
        isYieldStar: node.star != null);
  }

  ast.Statement visitFunctionDeclarationStatement(
      FunctionDeclarationStatement node) {
    var declaration = node.functionDeclaration;
    var expression = declaration.functionExpression;
    LocalElement element = declaration.element as dynamic; // Cross cast.
    // TODO: Set a function type on the variable.
    return new ast.FunctionDeclaration(
        scope.makeVariableDeclaration(element),
        scope.buildFunctionNode(expression.parameters, expression.body,
            typeParameters:
                scope.buildOptionalTypeParameterList(expression.typeParameters),
            returnType: declaration.returnType));
  }

  @override
  visitStatement(Statement node) {
    log.severe('Unhandled statement ${node.runtimeType} in ${scope.location}');
    return new ast.InvalidStatement();
  }
}

class ExpressionBuilder
    extends GeneralizingAstVisitor /* <ast.Expression | Accessor> */ {
  final MemberScope scope;
  final ast.VariableDeclaration cascadeReceiver;
  ExpressionBuilder(this.scope, [this.cascadeReceiver]);

  ast.Expression build(Expression node) {
    var result = node.accept(this);
    ast.Expression expression;
    if (result is Accessor) {
      expression = result.buildSimpleRead();
    } else {
      expression = result;
    }
    var cast = getImplicitCast(node);
    if (cast != null) {
      expression = new ast.TypeCheckExpression(expression,
          scope.buildType(cast));
    }
    return expression;
  }

  Accessor buildLeftHandValue(Expression node) {
    var result = node.accept(this);
    if (result is Accessor) {
      return result;
    } else {
      return new ReadOnlyAccessor(result);
    }
  }

  ast.Expression visitAsExpression(AsExpression node) {
    return new ast.AsExpression(
        build(node.expression), scope.buildTypeAnnotation(node.type));
  }

  ast.Expression visitAssignmentExpression(AssignmentExpression node) {
    bool voidContext = isInVoidContext(node);
    String operator = node.operator.value();
    var leftHand = buildLeftHandValue(node.leftHandSide);
    var rightHand = build(node.rightHandSide);
    if (operator == '=') {
      return leftHand.buildAssignment(rightHand, voidContext: voidContext);
    } else if (operator == '??=') {
      return leftHand.buildNullAwareAssignment(
          scope.buildType(node.staticType), rightHand,
          voidContext: voidContext);
    } else {
      // Cut off the trailing '='.
      var name = new ast.Name(operator.substring(0, operator.length - 1));
      return leftHand.buildCompoundAssignment(
          scope.buildType(node.staticType), name, rightHand,
          voidContext: voidContext);
    }
  }

  ast.Expression visitAwaitExpression(AwaitExpression node) {
    return new ast.AwaitExpression(
        scope.buildType(node.staticType), build(node.expression));
  }

  ast.Arguments buildSingleArgument(Expression node) {
    return new ast.Arguments(<ast.Expression>[build(node)]);
  }

  ast.Expression visitBinaryExpression(BinaryExpression node) {
    String operator = node.operator.value();
    if (operator == '&&' || operator == '||') {
      return new ast.LogicalExpression.boolean(
          build(node.leftOperand), operator, build(node.rightOperand));
    } else if (operator == '??') {
      return new ast.LogicalExpression(scope.buildType(node.staticType),
          build(node.leftOperand), operator, build(node.rightOperand));
    }
    bool isNegated = false;
    if (operator == '!=') {
      isNegated = true;
      operator = '==';
    }
    ast.Expression expression;
    if (node.leftOperand is SuperExpression) {
      // TODO: Will the element resolve correctly in case of the '!=' operator?
      var method = scope.resolveMethod(node.staticElement);
      if (method == null) {
        // TODO: Preserve enough information to throw the right exception.
        return new ast.InvalidExpression();
      }
      expression = new ast.SuperMethodInvocation(
          scope.buildType(node.staticType),
          method,
          buildSingleArgument(node.rightOperand));
    } else {
      expression = new ast.MethodInvocation(
          scope.buildType(node.staticType),
          build(node.leftOperand),
          new ast.Name(operator),
          buildSingleArgument(node.rightOperand));
    }
    return isNegated ? new ast.Not(expression) : expression;
  }

  ast.Expression visitBooleanLiteral(BooleanLiteral node) {
    return new ast.BoolLiteral(node.value);
  }

  ast.Expression visitDoubleLiteral(DoubleLiteral node) {
    return new ast.DoubleLiteral(node.value);
  }

  ast.Expression visitIntegerLiteral(IntegerLiteral node) {
    return new ast.IntLiteral(node.value);
  }

  ast.Expression visitNullLiteral(NullLiteral node) {
    return new ast.NullLiteral();
  }

  ast.Expression visitSimpleStringLiteral(SimpleStringLiteral node) {
    return new ast.StringLiteral(node.value);
  }

  ast.Expression visitStringLiteral(StringLiteral node) {
    return scope.buildStringLiteral(node);
  }

  static Object _getTokenValue(Token token) {
    return token.value();
  }

  ast.Expression visitSymbolLiteral(SymbolLiteral node) {
    String value = node.components.map(_getTokenValue).join('.');
    return new ast.SymbolLiteral(value);
  }

  ast.Expression visitCascadeExpression(CascadeExpression node) {
    var receiver = build(node.target);
    // If receiver is a variable it would be tempting to reuse it, but it
    // might be reassigned in one of the cascade sections.
    var receiverVariable = new ast.VariableDeclaration.forValue(receiver,
        type: scope.getInferredType(node.target));
    var inner = new ExpressionBuilder(scope, receiverVariable);
    ast.Expression result = new ast.VariableGet(receiverVariable);
    for (var section in node.cascadeSections.reversed) {
      var dummy = new ast.VariableDeclaration.forValue(inner.build(section));
      result = new ast.Let(dummy, result);
    }
    return new ast.Let(receiverVariable, result);
  }

  ast.Expression makeCascadeReceiver() {
    assert(cascadeReceiver != null);
    return new ast.VariableGet(cascadeReceiver);
  }

  ast.Expression visitConditionalExpression(ConditionalExpression node) {
    return new ast.ConditionalExpression(
        scope.buildType(node.staticType),
        build(node.condition),
        build(node.thenExpression),
        build(node.elseExpression));
  }

  ast.Expression visitFunctionExpression(FunctionExpression node) {
    return new ast.FunctionExpression(scope.buildFunctionNode(
        node.parameters, node.body,
        typeParameters:
            scope.buildOptionalTypeParameterList(node.typeParameters),
        inferredReturnType: scope.getInferredReturnType(node)));
  }

  ast.Arguments buildArguments(ArgumentList valueArguments,
      {TypeArgumentList explicitTypeArguments,
      List<ast.DartType> inferTypeArguments()}) {
    var positional = <ast.Expression>[];
    var named = <ast.NamedExpression>[];
    for (var argument in valueArguments.arguments) {
      if (argument is NamedExpression) {
        named.add(new ast.NamedExpression(
            argument.name.label.name, build(argument.expression)));
      } else {
        // TODO: Return an error node if a positional argument occurs after
        //       a named argument.
        positional.add(build(argument));
      }
    }
    List<ast.DartType> typeArguments;
    if (explicitTypeArguments != null) {
      typeArguments = scope.buildTypeArgumentList(explicitTypeArguments);
    } else if (inferTypeArguments != null) {
      typeArguments = inferTypeArguments();
    }
    return new ast.Arguments(positional, named: named, types: typeArguments);
  }

  ast.Arguments buildArgumentsForInvocation(InvocationExpression node) {
    return buildArguments(node.argumentList,
        explicitTypeArguments: node.typeArguments,
        inferTypeArguments: () =>
            scope.getInferredInvocationTypeArguments(node));
  }

  static final ast.Name callName = new ast.Name('call');

  ast.Expression visitFunctionExpressionInvocation(
      FunctionExpressionInvocation node) {
    return new ast.MethodInvocation(scope.buildType(node.staticType),
        build(node.function), callName, buildArgumentsForInvocation(node));
  }

  visitPrefixedIdentifier(PrefixedIdentifier node) {
    switch (ElementKind.of(node.prefix.staticElement)) {
      case ElementKind.CLASS:
      case ElementKind.LIBRARY:
      case ElementKind.PREFIX:
      case ElementKind.IMPORT:
        // Should be resolved to a static access.
        // Do not invoke 'build', because the identifier should be seen as a
        // left-hand value or an expression depending on the context.
        return visitSimpleIdentifier(node.identifier);

      case ElementKind.CONSTRUCTOR:
      case ElementKind.ERROR:
      case ElementKind.EXPORT:
      case ElementKind.LABEL:
        return new ast.InvalidExpression();

      case ElementKind.DYNAMIC:
      case ElementKind.FUNCTION_TYPE_ALIAS:
      case ElementKind.TYPE_PARAMETER:
      // TODO: Check with the spec to see exactly when a type literal can be
      // used in a property access without surrounding parentheses.
      // For now, just fall through to the property access case.

      case ElementKind.FIELD:
      case ElementKind.TOP_LEVEL_VARIABLE:
      case ElementKind.FUNCTION:
      case ElementKind.METHOD:
      case ElementKind.GETTER:
      case ElementKind.SETTER:
      case ElementKind.LOCAL_VARIABLE:
      case ElementKind.PARAMETER:
        return PropertyAccessor.make(scope.buildType(node.staticType),
            build(node.prefix), scope.buildName(node.identifier));

      case ElementKind.UNIVERSE:
      case ElementKind.NAME:
      default:
        throw 'What is this? ${node} ${node.staticElement}';
    }
  }

  bool isStatic(Element element) {
    if (element is ClassMemberElement) {
      return element.isStatic || element.enclosingElement == null;
    }
    if (element is PropertyAccessorElement) {
      return element.isStatic || element.enclosingElement == null;
    }
    if (element is FunctionElement) {
      return element.isStatic;
    }
    return false;
  }

  visitSimpleIdentifier(SimpleIdentifier node) {
    Element element = node.staticElement;
    switch (ElementKind.of(element)) {
      case ElementKind.CLASS:
      case ElementKind.DYNAMIC:
      case ElementKind.FUNCTION_TYPE_ALIAS:
      case ElementKind.TYPE_PARAMETER:
        return new ast.TypeLiteral(scope.buildTypeAnnotation(node));

      case ElementKind.COMPILATION_UNIT:
      case ElementKind.CONSTRUCTOR:
      case ElementKind.EXPORT:
      case ElementKind.IMPORT:
      case ElementKind.LABEL:
      case ElementKind.LIBRARY:
      case ElementKind.PREFIX:
        return new ast.InvalidExpression();

      case ElementKind.ERROR: // This covers the case where nothing was found.
        return PropertyAccessor.make(scope.buildType(node.staticType),
            scope.buildThis(), scope.buildName(node));

      case ElementKind.FIELD:
      case ElementKind.TOP_LEVEL_VARIABLE:
      case ElementKind.GETTER:
      case ElementKind.SETTER:
      case ElementKind.METHOD:
        if (isStatic(element)) {
          Element auxiliary = node.auxiliaryElements?.staticElement;
          // TODO: If the getter and/or setter is unresolved then preserve
          // enough information to throw the right exception.
          return new StaticAccessor(
              scope.buildType(node.staticType),
              scope.resolveGet(element, auxiliary),
              scope.resolveSet(element, auxiliary));
        }
        return PropertyAccessor.make(scope.buildType(node.staticType),
            scope.buildThis(), scope.buildName(node));

      case ElementKind.FUNCTION:
        FunctionElement function = element;
        if (scope.isTopLevelFunction(function)) {
          return new StaticAccessor(scope.buildType(node.staticType),
              scope.getMemberReference(function), null);
        }
        return new VariableAccessor(scope.getVariableReference(function));

      case ElementKind.LOCAL_VARIABLE:
      case ElementKind.PARAMETER:
        return new VariableAccessor(scope.getVariableReference(element));

      case ElementKind.UNIVERSE:
      case ElementKind.NAME:
      default:
        log.severe('Unexpected element kind: $element');
        return new ast.InvalidExpression();
    }
  }

  visitIndexExpression(IndexExpression node) {
    if (node.isCascaded) {
      return IndexAccessor.make(scope.buildType(node.staticType),
          makeCascadeReceiver(), build(node.index));
    } else if (node.target is SuperExpression) {
      Element element = node.staticElement;
      Element auxiliary = node.auxiliaryElements?.staticElement;
      // TODO: If the getter and/or setter is unresolved then preserve
      // enough information to throw the right exception.
      return new SuperIndexAccessor(
          scope.buildType(node.staticType),
          build(node.index),
          scope.resolveIndexGet(element, auxiliary),
          scope.resolveIndexSet(element, auxiliary));
    } else {
      return IndexAccessor.make(scope.buildType(node.staticType),
          build(node.target), build(node.index));
    }
  }

  ConstructorElement resolveEffectiveTarget(ConstructorElement element) {
    ConstructorElement anchor = null;
    int anchorLifetime = 1;
    while (true) {
      ConstructorDeclaration node = element.computeNode();
      // TODO: Preserve enough information to throw the right exception.
      if (node == null) {
        log.severe('Could not find AST node for $element');
        return null;
      }
      if (node.redirectedConstructor == null) {
        return node.element;
      }
      element = node.redirectedConstructor.staticElement;
      if (element == null) return null; // Unresolved.
      if (anchor == element) return null; // Cyclic redirection.
      if (anchorLifetime & ++anchorLifetime == 0) {
        // Move the anchor every 2^Nth step.
        anchor = element;
      }
    }
  }

  ast.Expression visitInstanceCreationExpression(
      InstanceCreationExpression node) {
    TypeName type = node.constructorName.type;
    List<ast.DartType> inferTypeArguments() {
      var inferredType = scope.getInferredType(node);
      return inferredType is ast.InterfaceType
          ? inferredType.typeArguments
          : null;
    }
    var arguments = buildArguments(node.argumentList,
        explicitTypeArguments: type.typeArguments,
        inferTypeArguments: inferTypeArguments);
    var element = node.staticElement;
    if (element is ConstructorElement && element.isFactory) {
      if (node.isConst) {
        // Constant factory calls are resolved to their effective targets.
        element = resolveEffectiveTarget(element);
        // TODO: Preserve enough information to throw the right exception.
        if (element == null) {
          return new ast.InvalidExpression();
        }
        if (element.isExternal && element.isConst && element.isFactory) {
          ast.Member target = scope.resolveMethod(element);
          return target is ast.Procedure
              ? new ast.StaticInvocation(
                  scope.buildType(node.staticType), target, arguments,
                  isConst: true)
              : new ast.InvalidExpression();
        } else if (element.isConst && !element.enclosingElement.isAbstract) {
          ast.Constructor target = scope.resolveConstructor(element);
          return target != null
              ? new ast.ConstructorInvocation(
                  scope.buildType(node.staticType), target, arguments,
                  isConst: true)
              : new ast.InvalidExpression();
        } else {
          return new ast.InvalidExpression();
        }
      } else {
        // Non-constant call to factory procedure.
        var procedure = scope.resolveMethod(element);
        if (procedure == null) {
          // TODO: Preserve enough information to throw the right exception.
          return new ast.InvalidExpression();
        }
        return new ast.StaticInvocation(
            scope.buildType(node.staticType), procedure, arguments);
      }
    } else {
      // Ordinary constructor call.
      var constructor = scope.resolveConstructor(node.staticElement);
      if (constructor == null ||
          (node.isConst && !constructor.isConst) ||
          element.enclosingElement.isAbstract) {
        // TODO: Preserve enough information to throw the right exception.
        return new ast.InvalidExpression();
      }
      return new ast.ConstructorInvocation(
          scope.buildType(node.staticType), constructor, arguments,
          isConst: node.isConst);
    }
  }

  ast.Expression visitIsExpression(IsExpression node) {
    if (node.notOperator != null) {
      return new ast.Not(new ast.IsExpression(
          build(node.expression), scope.buildTypeAnnotation(node.type)));
    } else {
      return new ast.IsExpression(
          build(node.expression), scope.buildTypeAnnotation(node.type));
    }
  }

  ast.Expression visitMethodInvocation(MethodInvocation node) {
    Element element = node.methodName.staticElement;
    if (node.isCascaded) {
      return new ast.MethodInvocation(
          scope.buildType(node.staticType),
          makeCascadeReceiver(),
          scope.buildName(node.methodName),
          buildArgumentsForInvocation(node));
    } else if (node.target is SuperExpression) {
      var target = scope.resolveMethod(element);
      if (target == null) {
        // TODO: Preserve enough information to throw the right exception.
        return new ast.InvalidExpression();
      }
      return new ast.SuperMethodInvocation(scope.buildType(node.staticType),
          target, buildArgumentsForInvocation(node));
    } else if (scope.isLocal(element)) {
      return new ast.MethodInvocation(
          scope.buildType(node.staticType),
          new ast.VariableGet(scope.getVariableReference(element)),
          callName,
          buildArgumentsForInvocation(node));
    } else if (scope.isStaticMethod(element)) {
      var target = scope.resolveMethod(element);
      if (target == null) {
        // TODO: Preserve enough information to throw the right exception.
        return new ast.InvalidExpression();
      }
      return new ast.StaticInvocation(scope.buildType(node.staticType), target,
          buildArgumentsForInvocation(node));
    } else if (scope.isStaticVariableOrGetter(element)) {
      var target = scope.resolveGet(element, null);
      if (target == null) {
        // TODO: Preserve enough information to throw the right exception.
        return new ast.InvalidExpression();
      }
      return new ast.MethodInvocation(
          scope.buildType(node.staticType),
          new ast.StaticGet(
              scope.buildType(node.methodName.staticType), target),
          callName,
          buildArgumentsForInvocation(node));
    } else if (node.target == null) {
      return new ast.MethodInvocation(
          scope.buildType(node.staticType),
          scope.buildThis(),
          scope.buildName(node.methodName),
          buildArgumentsForInvocation(node));
    } else if (node.operator.value() == '?.') {
      var receiver = makeOrReuseVariable(build(node.target));
      return makeLet(
          receiver,
          new ast.ConditionalExpression(
              scope.buildType(node.staticType),
              buildIsNull(new ast.VariableGet(receiver)),
              new ast.NullLiteral(),
              new ast.MethodInvocation(
                  scope.buildType(node.staticType),
                  new ast.VariableGet(receiver),
                  scope.buildName(node.methodName),
                  buildArgumentsForInvocation(node))));
    } else {
      return new ast.MethodInvocation(
          scope.buildType(node.staticType),
          build(node.target),
          scope.buildName(node.methodName),
          buildArgumentsForInvocation(node));
    }
  }

  ast.Expression visitNamedExpression(NamedExpression node) {
    return new ast.InvalidExpression();
  }

  ast.Expression visitParenthesizedExpression(ParenthesizedExpression node) {
    return build(node.expression);
  }

  bool isInVoidContext(Expression node) {
    AstNode parent = node.parent;
    return parent is ForStatement &&
            (parent.updaters.contains(node) || parent.initialization == node) ||
        parent is ExpressionStatement;
  }

  ast.Expression visitPostfixExpression(PostfixExpression node) {
    String operator = node.operator.value();
    switch (operator) {
      case '++':
      case '--':
        var leftHand = buildLeftHandValue(node.operand);
        var binaryOperator = new ast.Name(operator[0]);
        return leftHand.buildPostfixIncrement(
            scope.buildType(node.staticType), binaryOperator,
            voidContext: isInVoidContext(node));

      default:
        return new ast.InvalidExpression();
    }
  }

  ast.Expression visitPrefixExpression(PrefixExpression node) {
    String operator = node.operator.value();
    switch (operator) {
      case '-':
      case '~':
        if (node.operand is SuperExpression) {
          var target = scope.resolveMethod(node.staticElement);
          if (target == null) {
            // TODO: Preserve enough information to throw the right exception.
            return new ast.InvalidExpression();
          }
          return new ast.SuperMethodInvocation(scope.buildType(node.staticType),
              target, new ast.Arguments.empty());
        }
        var name = new ast.Name(operator == '-' ? 'unary-' : '~');
        return new ast.MethodInvocation(scope.buildType(node.staticType),
            build(node.operand), name, new ast.Arguments.empty());

      case '!':
        return new ast.Not(build(node.operand));

      case '++':
      case '--':
        var leftHand = buildLeftHandValue(node.operand);
        var binaryOperator = new ast.Name(operator[0]);
        return leftHand.buildPrefixIncrement(
            scope.buildType(node.staticType), binaryOperator);

      default:
        return new ast.InvalidExpression();
    }
  }

  visitPropertyAccess(PropertyAccess node) {
    Expression target = node.target;
    if (node.isCascaded) {
      return PropertyAccessor.make(scope.buildType(node.staticType),
          makeCascadeReceiver(), scope.buildName(node.propertyName));
    } else if (target is SuperExpression) {
      Element element = node.propertyName.staticElement;
      Element auxiliary = node.propertyName.auxiliaryElements?.staticElement;
      // TODO: If the getter and/or setter is unresolved, preserve enough
      // information to throw the right exception.
      return new SuperPropertyAccessor(
          scope.buildType(node.staticType),
          scope.resolveGet(element, auxiliary),
          scope.resolveSet(element, auxiliary));
    } else if (target is Identifier && target.staticElement is ClassElement) {
      // Note that this case also covers null-aware static access on a class,
      // which is equivalent to a regular static access.
      Element element = node.propertyName.staticElement;
      Element auxiliary = node.propertyName.auxiliaryElements?.staticElement;
      // TODO: If the getter and/or setter is unresolved, preserve enough
      // information to throw the right exception.
      return new StaticAccessor(
          scope.buildType(node.staticType),
          scope.resolveGet(element, auxiliary),
          scope.resolveSet(element, auxiliary));
    } else if (node.operator.value() == '?.') {
      return new NullAwarePropertyAccessor(scope.buildType(node.staticType),
          build(target), scope.buildName(node.propertyName));
    } else {
      return PropertyAccessor.make(scope.buildType(node.staticType),
          build(target), scope.buildName(node.propertyName));
    }
  }

  ast.Expression visitRethrowExpression(RethrowExpression node) {
    return new ast.Rethrow();
  }

  ast.Expression visitSuperExpression(SuperExpression node) {
    return new ast.InvalidExpression();
  }

  ast.Expression visitThisExpression(ThisExpression node) {
    return scope.buildThis();
  }

  ast.Expression visitThrowExpression(ThrowExpression node) {
    return new ast.Throw(build(node.expression));
  }

  ast.Expression visitListLiteral(ListLiteral node) {
    ast.DartType type = node.typeArguments?.arguments?.isNotEmpty ?? false
        ? scope.buildTypeAnnotation(node.typeArguments.arguments[0])
        : scope.getInferredTypeArgument(node, 0);
    return new ast.ListLiteral(node.elements.map(build).toList(),
        typeArgument: type, isConst: node.constKeyword != null);
  }

  ast.Expression visitMapLiteral(MapLiteral node) {
    ast.DartType key, value;
    if (node.typeArguments != null && node.typeArguments.arguments.length > 1) {
      key = scope.buildTypeAnnotation(node.typeArguments.arguments[0]);
      value = scope.buildTypeAnnotation(node.typeArguments.arguments[1]);
    } else {
      key = scope.getInferredTypeArgument(node, 0);
      value = scope.getInferredTypeArgument(node, 1);
    }
    return new ast.MapLiteral(node.entries.map(buildMapEntry).toList(),
        keyType: key, valueType: value, isConst: node.constKeyword != null);
  }

  ast.MapEntry buildMapEntry(MapLiteralEntry node) {
    return new ast.MapEntry(build(node.key), build(node.value));
  }

  ast.Expression visitExpression(Expression node) {
    log.severe('Unhandled expression ${node.runtimeType} in ${scope.location}');
    return new ast.InvalidExpression();
  }
}

class StringLiteralPartBuilder extends GeneralizingAstVisitor<Null> {
  final MemberScope scope;
  final List<ast.Expression> output;
  StringLiteralPartBuilder(this.scope, this.output);

  void build(Expression node) {
    node.accept(this);
  }

  void buildInterpolationElement(InterpolationElement node) {
    node.accept(this);
  }

  visitSimpleStringLiteral(SimpleStringLiteral node) {
    output.add(new ast.StringLiteral(node.value));
  }

  visitAdjacentStrings(AdjacentStrings node) {
    node.strings.forEach(build);
  }

  visitStringInterpolation(StringInterpolation node) {
    node.elements.forEach(buildInterpolationElement);
  }

  visitInterpolationString(InterpolationString node) {
    output.add(new ast.StringLiteral(node.value));
  }

  visitInterpolationExpression(InterpolationExpression node) {
    output.add(scope.buildExpression(node.expression));
  }
}

class TypeAnnotationBuilder extends GeneralizingAstVisitor<ast.DartType> {
  final TypeScope scope;

  TypeAnnotationBuilder(this.scope);

  ast.DartType build(AstNode node) {
    return node.accept(this);
  }

  List<ast.DartType> buildList(Iterable<AstNode> node) {
    return node.map(build).toList();
  }

  /// Replace unbound type variables in [type] with 'dynamic' and convert
  /// to an [ast.DartType].
  ast.DartType buildClosedTypeFromDartType(DartType type) {
    return convertType(type, <TypeParameterElement>[]);
  }

  /// Convert to an [ast.DartType] and keep type variables.
  ast.DartType buildFromDartType(DartType type) {
    return convertType(type, null);
  }

  /// Converts [type] to an [ast.DartType], while replacing unbound type
  /// variables with 'dynamic'.
  ///
  /// If [boundVariables] is null, no type variables are replaced, otherwise all
  /// type variables except those in [boundVariables] are replaced.  In other
  /// words, it represents the bound variables, or "all variables" if omitted.
  ast.DartType convertType(
      DartType type, List<TypeParameterElement> boundVariables) {
    if (type is TypeParameterType) {
      if (boundVariables == null || boundVariables.contains(type)) {
        return new ast.TypeParameterType(
            scope.getTypeParameterReference(type.element));
      } else {
        return const ast.DynamicType();
      }
    } else if (type is InterfaceType) {
      var classNode = scope.getClassReference(type.element);
      if (type.typeArguments.length == 0) {
        return new ast.InterfaceType(classNode);
      }
      if (type.typeArguments.length != classNode.typeParameters.length) {
        log.warning('Type parameter arity error in $type');
        return const ast.InvalidType();
      }
      return new ast.InterfaceType(
          classNode, convertTypeList(type.typeArguments, boundVariables));
    } else if (type is FunctionType) {
      // TODO: Avoid infinite recursion in case of illegal circular typedef.
      boundVariables?.addAll(type.typeParameters);
      var positionals =
          concatenate(type.normalParameterTypes, type.optionalParameterTypes);
      var result = new ast.FunctionType(
          convertTypeList(positionals, boundVariables),
          convertType(type.returnType, boundVariables),
          typeParameters:
              convertTypeParameterList(type.typeFormals, boundVariables),
          namedParameters:
              convertTypeMap(type.namedParameterTypes, boundVariables),
          requiredParameterCount: type.normalParameterTypes.length);
      boundVariables?.removeRange(
          boundVariables.length - type.typeParameters.length,
          boundVariables.length);
      return result;
    } else if (type.isUndefined) {
      log.warning('Unresolved type found in ${scope.location}');
      return const ast.InvalidType();
    } else if (type.isVoid) {
      return const ast.VoidType();
    } else if (type.isDynamic) {
      return const ast.DynamicType();
    } else if (type.isBottom) {
      return const ast.BottomType();
    } else {
      log.severe('Unexpected DartType: $type');
      return const ast.InvalidType();
    }
  }

  static Iterable/*<E>*/ concatenate/*<E>*/(
          Iterable/*<E>*/ x, Iterable/*<E>*/ y) =>
      <Iterable<dynamic/*=E*/ >>[x, y].expand((z) => z);

  ast.TypeParameter convertTypeParameter(TypeParameterElement typeParameter,
      List<TypeParameterElement> boundVariables) {
    return scope.makeTypeParameter(typeParameter,
        bound: typeParameter.bound == null
            ? const ast.DynamicType()
            : convertType(typeParameter.bound, boundVariables));
  }

  List<ast.TypeParameter> convertTypeParameterList(
      Iterable<TypeParameterElement> typeParameters,
      List<TypeParameterElement> boundVariables) {
    if (typeParameters.isEmpty) return const <ast.TypeParameter>[];
    return typeParameters
        .map((tp) => convertTypeParameter(tp, boundVariables))
        .toList();
  }

  List<ast.DartType> convertTypeList(
      Iterable<DartType> types, List<TypeParameterElement> boundVariables) {
    if (types.isEmpty) return const <ast.DartType>[];
    return types.map((t) => convertType(t, boundVariables)).toList();
  }

  Map<String, ast.DartType> convertTypeMap(
      Map<String, DartType> types, List<TypeParameterElement> boundVariables) {
    if (types.isEmpty) return const <String, ast.DartType>{};
    var result = <String, ast.DartType>{};
    types.forEach((name, type) {
      result[name] = convertType(type, boundVariables);
    });
    return result;
  }

  ast.DartType visitSimpleIdentifier(SimpleIdentifier node) {
    Element element = node.staticElement;
    switch (ElementKind.of(element)) {
      case ElementKind.CLASS:
        return new ast.InterfaceType(scope.getClassReference(element));

      case ElementKind.DYNAMIC:
        return const ast.DynamicType();

      case ElementKind.FUNCTION_TYPE_ALIAS:
        FunctionTypeAliasElement functionType = element;
        return buildClosedTypeFromDartType(functionType.type);

      case ElementKind.TYPE_PARAMETER:
        return new ast.TypeParameterType(
            scope.getTypeParameterReference(element));

      case ElementKind.COMPILATION_UNIT:
      case ElementKind.CONSTRUCTOR:
      case ElementKind.EXPORT:
      case ElementKind.IMPORT:
      case ElementKind.LABEL:
      case ElementKind.LIBRARY:
      case ElementKind.PREFIX:
      case ElementKind.UNIVERSE:
      case ElementKind.ERROR: // This covers the case where nothing was found.
      case ElementKind.FIELD:
      case ElementKind.TOP_LEVEL_VARIABLE:
      case ElementKind.GETTER:
      case ElementKind.SETTER:
      case ElementKind.METHOD:
      case ElementKind.LOCAL_VARIABLE:
      case ElementKind.PARAMETER:
      case ElementKind.FUNCTION:
      case ElementKind.NAME:
      default:
        log.severe('Invalid type annotation: $element');
        return const ast.InvalidType();
    }
  }

  visitPrefixedIdentifier(PrefixedIdentifier node) {
    return build(node.identifier);
  }

  visitTypeName(TypeName node) {
    return buildFromDartType(node.type);
  }

  visitNode(AstNode node) {
    log.severe('Unexpected type annotation: $node');
    return new ast.InvalidType();
  }
}

class InitializerBuilder extends GeneralizingAstVisitor<ast.Initializer> {
  final MemberScope scope;

  InitializerBuilder(this.scope);

  ast.Initializer build(ConstructorInitializer node) {
    return node.accept(this);
  }

  visitConstructorFieldInitializer(ConstructorFieldInitializer node) {
    var target = scope.resolveField(node.fieldName.staticElement);
    if (target == null) {
      return new ast.InvalidInitializer();
    }
    return new ast.FieldInitializer(
        target, scope.buildExpression(node.expression));
  }

  visitSuperConstructorInvocation(SuperConstructorInvocation node) {
    var target = scope.resolveConstructor(node.staticElement);
    if (target == null) {
      return new ast.InvalidInitializer();
    }
    return new ast.SuperInitializer(
        target, scope._expressionBuilder.buildArguments(node.argumentList));
  }

  visitRedirectingConstructorInvocation(RedirectingConstructorInvocation node) {
    var target = scope.resolveConstructor(node.staticElement);
    if (target == null) {
      return new ast.InvalidInitializer();
    }
    return new ast.RedirectingInitializer(
        target, scope._expressionBuilder.buildArguments(node.argumentList));
  }

  visitNode(AstNode node) {
    log.severe('Unexpected constructor initializer: ${node.runtimeType}');
    return new ast.InvalidInitializer();
  }
}

DartObject extractMetadata(ElementAnnotation annotation) {
  return annotation.constantValue;
}

/// Brings a class from reference level to body level.
///
/// The enclosing library is assumed to be at body level already.
class ClassBodyBuilder extends GeneralizingAstVisitor<Null> {
  final TypeScope scope;
  final ast.Class currentClass;
  final ClassElement element;
  ast.Library get currentLibrary => currentClass.enclosingLibrary;

  ClassBodyBuilder(ReferenceLevelLoader loader, this.currentClass, this.element)
      : scope = new TypeScope(loader);

  void build(CompilationUnitMember node) {
    if (node == null) {
      throw 'Missing class declaration for $element';
    }
    node.accept(this);
    currentClass.analyzerMetadata =
        element.metadata.map(extractMetadata).toList();
  }

  void addTypeParameterBounds(TypeParameterList typeParameters) {
    if (typeParameters == null) return;
    int index = 0;
    for (var typeParameter in typeParameters.typeParameters) {
      if (typeParameter.bound != null) {
        currentClass.typeParameters[index].bound =
            scope.buildTypeAnnotation(typeParameter.bound);
      }
      ++index;
    }
  }

  void addImplementedClasses(ImplementsClause implementsClause) {
    if (implementsClause == null) return;
    for (var type in implementsClause.interfaces) {
      ast.DartType typeNode = scope.buildTypeAnnotation(type);
      if (typeNode is! ast.InterfaceType) {
        log.warning('Invalid implemented type: $type in ${scope.location}');
      } else {
        currentClass.implementedTypes.add(typeNode);
      }
    }
  }

  ast.InterfaceType buildMixinType(
      ast.InterfaceType baseType, Iterable<ast.DartType> mixins) {
    var result = baseType;
    for (var mixin in mixins) {
      if (mixin is! ast.InterfaceType) {
        log.warning('Invalid mixin application in ${scope.location}');
        return result;
      }
      var freshTypes = getFreshTypeParameters(currentClass.typeParameters);
      var mixinClass = new ast.MixinClass(
          freshTypes.substitute(result), freshTypes.substitute(mixin),
          typeParameters: freshTypes.freshTypeParameters, isAbstract: true);
      currentLibrary.addClass(mixinClass);
      result = new ast.InterfaceType(
          mixinClass,
          currentClass.typeParameters
              .map(_makeTypeParameterType)
              .toList(growable: false));
    }
    return result;
  }

  visitClassDeclaration(ClassDeclaration node) {
    ast.NormalClass classNode = currentClass;
    addTypeParameterBounds(node.typeParameters);
    // Build the super class reference and expand the 'with' clause into
    // separate mixin classes.
    bool isRootClass = node.element.supertype == null;
    if (!isRootClass) {
      ast.DartType superclass =
          scope.buildOptionalTypeAnnotation(node.extendsClause?.superclass) ??
              scope.getRootClassReference().rawType;
      if (superclass is! ast.InterfaceType) {
        // TODO: Handle the error case where the super class is InvalidType.
        log.warning('Unresolved type super type '
            '${node.extendsClause?.superclass} for ${node.element}');
        classNode.supertype =
            new ast.InterfaceType(scope.getRootClassReference());
      } else {
        if (node.withClause != null) {
          superclass = buildMixinType(superclass,
              node.withClause.mixinTypes.map(scope.buildTypeAnnotation));
        }
        classNode.supertype = superclass;
      }
    }
    addImplementedClasses(node.implementsClause);
    for (var member in node.members) {
      if (member is FieldDeclaration) {
        for (var variable in member.fields.variables) {
          classNode.addMember(scope.getMemberReference(variable.element));
        }
      } else {
        classNode.addMember(scope.getMemberReference(member.element));
      }
    }
    if (classNode.constructors.isEmpty) {
      var defaultConstructor = scope.findDefaultConstructor(node.element);
      if (defaultConstructor != null) {
        assert(defaultConstructor.enclosingElement == node.element);
        if (!defaultConstructor.isSynthetic) {
          throw 'Non-synthetic default constructor not in list of members. '
              '${node} $element $defaultConstructor';
        }
        classNode.addMember(scope.getMemberReference(defaultConstructor));
      }
    }
  }

  /// True for the `values` field of an `enum` class.
  static bool _isValuesField(FieldElement field) => field.name == 'values';

  visitEnumDeclaration(EnumDeclaration node) {
    ast.NormalClass classNode = currentClass;
    classNode.supertype = new ast.InterfaceType(scope.getRootClassReference());
    var intType =
        new ast.InterfaceType(scope.loader.getCoreClassReference('int'));
    var indexField =
        new ast.Field(new ast.Name('index'), isFinal: true, type: intType);
    classNode.addMember(indexField);
    var parameter = new ast.VariableDeclaration('index', type: intType);
    var function = new ast.FunctionNode(new ast.EmptyStatement(),
        positionalParameters: [parameter]);
    var superConstructor = scope.loader.getRootClassConstructorReference();
    var constructor = new ast.Constructor(function,
        name: new ast.Name(''),
        isConst: true,
        initializers: [
          new ast.FieldInitializer(indexField, new ast.VariableGet(parameter)),
          new ast.SuperInitializer(superConstructor, new ast.Arguments.empty())
        ]);
    classNode.addMember(constructor);
    int index = 0;
    var enumConstantFields = <ast.Field>[];
    for (var constant in node.constants) {
      ast.Field field = scope.getMemberReference(constant.element);
      field.initializer = new ast.ConstructorInvocation(classNode.thisType,
          constructor, new ast.Arguments([new ast.IntLiteral(index)]),
          isConst: true);
      field.type = new ast.InterfaceType(classNode);
      classNode.addMember(field);
      ++index;
      enumConstantFields.add(field);
    }
    // Add the 'values' field.
    var valuesFieldElement = element.fields.firstWhere(_isValuesField);
    ast.Field valuesField = scope.getMemberReference(valuesFieldElement);
    var enumType = new ast.InterfaceType(classNode);
    valuesField.type = new ast.InterfaceType(
        scope.loader.getCoreClassReference('List'), <ast.DartType>[enumType]);
    valuesField.initializer = new ast.ListLiteral(
        enumConstantFields.map(_makeStaticGet).toList(),
        isConst: true,
        typeArgument: enumType);
    classNode.addMember(valuesField);
    // TODO: Add the toString method.
  }

  visitClassTypeAlias(ClassTypeAlias node) {
    assert(node.withClause != null && node.withClause.mixinTypes.isNotEmpty);
    ast.MixinClass classNode = currentClass;
    addTypeParameterBounds(node.typeParameters);
    var baseType = scope.buildTypeAnnotation(node.superclass);
    var mixins = node.withClause.mixinTypes.map(scope.buildTypeAnnotation);
    classNode.supertype =
        buildMixinType(baseType, mixins.take(mixins.length - 1));
    classNode.mixedInType = mixins.last;
    addImplementedClasses(node.implementsClause);
    ClassElement element = node.element;
    assert(element.isMixinApplication);
    for (var constructor in element.constructors) {
      classNode.addMember(scope.getMemberReference(constructor));
    }
  }

  visitNode(AstNode node) {
    throw 'Unsupported class declaration: ${node.runtimeType}';
  }
}

/// Brings a member from reference level to body level.
///
/// The enclosing library and class are assumed to be at body level already.
class MemberBodyBuilder extends GeneralizingAstVisitor<Null> {
  final MemberScope scope;
  final Element element;
  ast.Member get currentMember => scope.currentMember;

  MemberBodyBuilder(
      ReferenceLevelLoader loader, ast.Member member, this.element)
      : scope = new MemberScope(loader, member);

  static bool _isClassElement(Element element) {
    return element is ClassElement;
  }

  void build(AstNode node) {
    if (node != null) {
      node.accept(this);
      currentMember.analyzerMetadata =
          this.element.metadata.map(extractMetadata).toList();
      return;
    }
    Element element = this.element; // Allow type promotion.
    assert(element.isSynthetic);
    ClassElement enclosingClass = element.getAncestor(_isClassElement);
    if (element is ConstructorElement && enclosingClass.isMixinApplication) {
      buildMixinConstructor(element);
      return;
    }
    if (element is ConstructorElement && element.isDefaultConstructor) {
      buildDefaultConstructor(element);
      return;
    }
    if (enclosingClass != null &&
        enclosingClass.isEnum &&
        element.name == 'values') {
      return; // Built when enclosing enum class is built.
    }
    log.warning('Unrecognized synthetic member: $element (${element.kind})');
  }

  void buildDefaultConstructor(ConstructorElement element) {
    ast.Constructor constructor = currentMember;
    constructor.function = new ast.FunctionNode(new ast.EmptyStatement(),
        returnType: const ast.VoidType())..parent = constructor;
    var class_ = element.enclosingElement;
    if (class_.supertype != null) {
      // DESIGN TODO: If the super class is a mixin application, we will link to
      // a constructor not in the immediate super class.  Is this a problem?
      var superConstructor =
          scope.findDefaultConstructor(class_.supertype.element);
      var target = scope.resolveConstructor(superConstructor);
      if (target == null) {
        constructor.initializers
            .add(new ast.InvalidInitializer()..parent = constructor);
      } else {
        var arguments = new ast.Arguments.empty();
        constructor.initializers.add(
            new ast.SuperInitializer(target, arguments)..parent = constructor);
      }
    }
  }

  void buildMixinConstructor(ConstructorElement element) {
    ast.Constructor constructor = currentMember;
    ClassElement classElement = element.enclosingElement;
    // Find corresponding constructor in super class.
    var targetConstructor = classElement.supertype.element.constructors
        .firstWhere((c) => c.name == element.name);
    var positionalParameters = <ast.VariableDeclaration>[];
    var namedParameters = <ast.VariableDeclaration>[];
    var positionalArguments = <ast.Expression>[];
    var namedArguments = <ast.NamedExpression>[];
    int requiredParameterCount = 0;
    for (var parameter in element.parameters) {
      var variable = new ast.VariableDeclaration(parameter.name,
          type: scope.getInferredVariableType(parameter));
      var argument = new ast.VariableGet(variable);
      switch (parameter.parameterKind) {
        case ParameterKind.REQUIRED:
          ++requiredParameterCount;
          positionalParameters.add(variable);
          positionalArguments.add(argument);
          break;

        case ParameterKind.POSITIONAL:
          positionalParameters.add(variable);
          positionalArguments.add(argument);
          break;

        case ParameterKind.NAMED:
          namedParameters.add(variable);
          namedArguments.add(new ast.NamedExpression(parameter.name, argument));
          break;
      }
    }
    var typeArguments =
        classElement.supertype.typeArguments.map(scope.buildType).toList();
    constructor.function = new ast.FunctionNode(new ast.EmptyStatement(),
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        requiredParameterCount: requiredParameterCount,
        returnType: const ast.VoidType())..parent = constructor;
    constructor.initializers.add(new ast.SuperInitializer(
        scope.getMemberReference(targetConstructor),
        new ast.Arguments(positionalArguments,
            named: namedArguments,
            types: typeArguments))..parent = constructor);
  }

  visitConstructorDeclaration(ConstructorDeclaration node) {
    if (node.factoryKeyword != null) {
      buildFactoryConstructor(node);
    } else {
      buildGenerativeConstructor(node);
    }
  }

  void buildGenerativeConstructor(ConstructorDeclaration node) {
    ast.Constructor constructor = currentMember;
    constructor.function = scope.buildFunctionNode(node.parameters, node.body,
        inferredReturnType: const ast.VoidType())..parent = constructor;
    for (var parameter in node.parameters.parameterElements) {
      if (parameter is FieldFormalParameterElement) {
        var initializer = new ast.FieldInitializer(
            scope.getMemberReference(parameter.field),
            new ast.VariableGet(scope.getVariableReference(parameter)));
        constructor.initializers.add(initializer..parent = constructor);
      }
    }
    bool hasExplicitConstructorCall = false;
    for (var initializer in node.initializers) {
      var node = scope.buildInitializer(initializer);
      constructor.initializers.add(node..parent = constructor);
      if (node is ast.SuperInitializer || node is ast.RedirectingInitializer) {
        hasExplicitConstructorCall = true;
      }
    }
    ClassElement classElement = node.element.enclosingElement;
    if (classElement.supertype != null && !hasExplicitConstructorCall) {
      ConstructorElement targetElement =
          scope.findDefaultConstructor(classElement.supertype.element);
      ast.Constructor target = scope.resolveConstructor(targetElement);
      ast.Initializer initializer = target == null
          ? new ast.InvalidInitializer()
          : new ast.SuperInitializer(
              target, new ast.Arguments(<ast.Expression>[]));
      constructor.initializers.add(initializer..parent = constructor);
    } else {
      moveSuperCallLast(constructor);
    }
  }

  void buildFactoryConstructor(ConstructorDeclaration node) {
    ast.Procedure procedure = currentMember;
    ClassElement classElement = node.element.enclosingElement;
    ast.NormalClass classNode = procedure.enclosingClass;
    var types = getFreshTypeParameters(classNode.typeParameters);
    for (int i = 0; i < classElement.typeParameters.length; ++i) {
      scope.localTypeParameters[classElement.typeParameters[i]] =
          types.freshTypeParameters[i];
    }
    var function = scope.buildFunctionNode(node.parameters, node.body,
        typeParameters: types.freshTypeParameters,
        inferredReturnType: new ast.InterfaceType(classNode,
            types.freshTypeParameters.map(_makeTypeParameterType).toList()));
    procedure.function = function..parent = procedure;
    if (node.redirectedConstructor != null) {
      assert(function.body == null);
      ConstructorElement targetElement =
          node.redirectedConstructor.staticElement;
      ast.Member target = targetElement.isFactory
          ? scope.resolveMethod(targetElement)
          : scope.resolveConstructor(targetElement);
      if (targetElement == null ||
          !targetElement.isFactory &&
              targetElement.enclosingElement.isAbstract) {
        log.warning('Unresolved redirecting factory in ${scope.location}');
        // TODO: Preserve enough information to throw the right exception.
        function.body = new ast.InvalidStatement()..parent = function;
      } else {
        var positional =
            function.positionalParameters.map(_makeVariableGet).toList();
        var named =
            function.namedParameters.map(_makeNamedExpressionFrom).toList();
        var types =
            function.typeParameters.map(_makeTypeParameterType).toList();
        var arguments =
            new ast.Arguments(positional, named: named, types: types);
        var invocation = target is ast.Constructor
            ? new ast.ConstructorInvocation(
                scope.buildType(targetElement.enclosingElement.type),
                target,
                arguments)
            : new ast.StaticInvocation(
                scope.buildType(targetElement.returnType), target, arguments);
        function.body = new ast.ReturnStatement(invocation)..parent = function;
      }
    }
  }

  visitMethodDeclaration(MethodDeclaration node) {
    ast.Procedure procedure = currentMember;
    procedure.function = scope.buildFunctionNode(node.parameters, node.body,
        returnType: node.returnType,
        inferredReturnType: scope.buildType(node.element.returnType),
        typeParameters:
            scope.buildOptionalTypeParameterList(node.typeParameters))
      ..parent = procedure;
  }

  visitVariableDeclaration(VariableDeclaration node) {
    ast.Field field = currentMember;
    field.type = scope.buildType(node.element.type);
    if (node.initializer != null) {
      field.initializer = scope.buildExpression(node.initializer)
        ..parent = field;
    }
  }

  visitFunctionDeclaration(FunctionDeclaration node) {
    var function = node.functionExpression;
    ast.Procedure procedure = currentMember;
    procedure.function = scope.buildFunctionNode(
        function.parameters, function.body,
        returnType: node.returnType,
        typeParameters:
            scope.buildOptionalTypeParameterList(function.typeParameters))
      ..parent = procedure;
  }

  visitEnumConstantDeclaration(EnumConstantDeclaration node) {
    // Nothing to do.  These members are fully built at reference level.
  }

  visitNode(AstNode node) {
    log.severe('Unexpected class or library member: $node');
  }
}

/// Constructor alias for [ast.TypeParameterType], use instead of a closure.
ast.DartType _makeTypeParameterType(ast.TypeParameter parameter) {
  return new ast.TypeParameterType(parameter);
}

/// Constructor alias for [ast.VariableGet], use instead of a closure.
ast.VariableGet _makeVariableGet(ast.VariableDeclaration variable) {
  return new ast.VariableGet(variable);
}

/// Constructor alias for [ast.StaticGet], use instead of a closure.
ast.StaticGet _makeStaticGet(ast.Field field) {
  return new ast.StaticGet(field.type, field);
}

/// Create a named expression with the name and value of the given variable.
ast.NamedExpression _makeNamedExpressionFrom(ast.VariableDeclaration variable) {
  return new ast.NamedExpression(variable.name, new ast.VariableGet(variable));
}
