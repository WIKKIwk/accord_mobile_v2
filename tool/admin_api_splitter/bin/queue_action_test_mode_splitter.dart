import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

const _partOfMobileApi = "part of '../mobile_api.dart';";
const _sourceRelativePath =
    'lib/src/core/api/admin/mobile_api_admin_queue_action_result_test_mode.dart';
const _oldPartDirective =
    "part 'admin/mobile_api_admin_queue_action_result_test_mode.dart';";

const _generatedRelativePaths = <String>[
  _sourceRelativePath,
  'lib/src/core/api/admin/mobile_api_admin_queue_action_result_test_mode_context.dart',
  'lib/src/core/api/admin/mobile_api_admin_queue_action_result_test_mode_start.dart',
  'lib/src/core/api/admin/mobile_api_admin_queue_action_result_test_mode_worker_handoff.dart',
  'lib/src/core/api/admin/mobile_api_admin_queue_action_result_test_mode_pause.dart',
  'lib/src/core/api/admin/mobile_api_admin_queue_action_result_test_mode_roll_complete.dart',
  'lib/src/core/api/admin/mobile_api_admin_queue_action_result_test_mode_resume.dart',
  'lib/src/core/api/admin/mobile_api_admin_queue_action_result_test_mode_complete.dart',
];

const _newPartDirectives = <String>[
  _oldPartDirective,
  "part 'admin/mobile_api_admin_queue_action_result_test_mode_context.dart';",
  "part 'admin/mobile_api_admin_queue_action_result_test_mode_start.dart';",
  "part 'admin/mobile_api_admin_queue_action_result_test_mode_worker_handoff.dart';",
  "part 'admin/mobile_api_admin_queue_action_result_test_mode_pause.dart';",
  "part 'admin/mobile_api_admin_queue_action_result_test_mode_roll_complete.dart';",
  "part 'admin/mobile_api_admin_queue_action_result_test_mode_resume.dart';",
  "part 'admin/mobile_api_admin_queue_action_result_test_mode_complete.dart';",
];

const _branchNames = <String>[
  '_runStart',
  '_runWorkerHandoff',
  '_runPauseOrDetach',
  '_runRollComplete',
  '_runResume',
  '_runComplete',
];

const _branchFileSuffixes = <String>[
  'start',
  'worker_handoff',
  'pause',
  'roll_complete',
  'resume',
  'complete',
];

void main(List<String> args) {
  final apply = args.contains('--apply');
  final audit = args.contains('--audit');
  final root = Directory(
    _argument(args, '--root') ?? _repositoryRoot(),
  ).absolute;
  final plan = _SplitPlan.load(
    root,
    sourceCommit: _argument(args, '--source-commit'),
  );

  _verifyPlan(plan);
  _printPlan(plan);

  if (audit) {
    _verifyWrittenPlan(plan);
    stdout.writeln(
      'Current checkout matches the verified test-mode branch split.',
    );
    return;
  }
  if (!apply) {
    stdout.writeln('Dry run only. Pass --apply to write the verified split.');
    return;
  }

  _applyPlan(plan);
  stdout.writeln('Verified test-mode branch split applied successfully.');
}

String? _argument(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}

String _repositoryRoot() {
  final script = File.fromUri(Platform.script).absolute;
  return script.parent.parent.parent.parent.path;
}

String _readGitFile(Directory root, String commit, String relativePath) {
  final result = Process.runSync(
    'git',
    ['-C', root.path, 'show', '$commit:$relativePath'],
  );
  if (result.exitCode != 0) {
    throw StateError(
      'Unable to read $relativePath from $commit: ${result.stderr}',
    );
  }
  return result.stdout as String;
}

class _BranchPiece {
  const _BranchPiece({
    required this.condition,
    required this.body,
  });

  final String condition;
  final String body;
}

class _SplitPlan {
  _SplitPlan({
    required this.root,
    required this.sourcePath,
    required this.mobileApiPath,
    required this.originalSource,
    required this.originalMobileApiSource,
    required this.existingSource,
    required this.existingMobileApiSource,
    required this.generatedSources,
    required this.updatedMobileApiSource,
    required this.preambleSource,
    required this.tailSource,
    required this.finalElseSource,
    required this.branchPieces,
  });

  final Directory root;
  final File sourcePath;
  final File mobileApiPath;
  final String originalSource;
  final String originalMobileApiSource;
  final String existingSource;
  final String existingMobileApiSource;
  final Map<File, String> generatedSources;
  final String updatedMobileApiSource;
  final String preambleSource;
  final String tailSource;
  final String finalElseSource;
  final List<_BranchPiece> branchPieces;

  static _SplitPlan load(
    Directory root, {
    String? sourceCommit,
  }) {
    final sourcePath = File('${root.path}/$_sourceRelativePath');
    final mobileApiPath = File('${root.path}/lib/src/core/api/mobile_api.dart');
    final existingSource =
        sourcePath.existsSync() ? sourcePath.readAsStringSync() : '';
    final existingMobileApiSource = mobileApiPath.readAsStringSync();
    final originalSource = sourceCommit == null
        ? existingSource
        : _readGitFile(root, sourceCommit, _sourceRelativePath);
    final originalMobileApiSource = sourceCommit == null
        ? existingMobileApiSource
        : _readGitFile(root, sourceCommit, 'lib/src/core/api/mobile_api.dart');

    if (originalSource.isEmpty) {
      throw StateError('Expected the unsplit test-mode result source file.');
    }
    if (!originalMobileApiSource.contains(_oldPartDirective)) {
      throw StateError('The baseline mobile API has no test-mode part.');
    }
    final currentIsGeneratedSplit =
        existingSource.contains('_TestModeQueueActionContext') &&
            _newPartDirectives.skip(1).every(existingMobileApiSource.contains);
    if (sourceCommit != null &&
        existingSource.isNotEmpty &&
        existingSource != originalSource &&
        !currentIsGeneratedSplit) {
      throw StateError(
        'The current test-mode source differs from the selected source commit; '
        'refusing to overwrite a dirty source file.',
      );
    }
    if (sourceCommit != null &&
        existingMobileApiSource != originalMobileApiSource &&
        existingSource.isNotEmpty &&
        !currentIsGeneratedSplit) {
      throw StateError(
        'The current mobile API differs from the selected source commit; '
        'refusing to overwrite a dirty library directive file.',
      );
    }

    final parsed = parseString(
      content: originalSource,
      path: sourcePath.path,
      throwIfDiagnostics: false,
    );
    if (parsed.errors.isNotEmpty) {
      throw StateError(
        'The test-mode source must parse before extraction: '
        '${parsed.errors.join('\n')}',
      );
    }
    final extension = parsed.unit.declarations
        .whereType<ExtensionDeclaration>()
        .where(
          (item) =>
              item.name?.lexeme == 'MobileApiAdminQueueActionResultTestMode',
        )
        .singleOrNull;
    if (extension == null) {
      throw StateError(
        'Expected exactly one test-mode result extension.',
      );
    }
    final methods = extension.body.members
        .whereType<MethodDeclaration>()
        .where(
          (item) =>
              item.name.lexeme == '_adminApparatusQueueActionResultTestMode',
        )
        .toList();
    if (methods.length != 1) {
      throw StateError(
        'Expected exactly one test-mode result method, found ${methods.length}.',
      );
    }
    final method = methods.single;
    final methodBody = method.body;
    if (methodBody is! BlockFunctionBody) {
      throw StateError('The test-mode result method must use a block body.');
    }
    final bodyBlock = methodBody.block;
    final statements = bodyBlock.statements;
    final chainIndex = statements.indexWhere(
      (statement) =>
          statement is IfStatement &&
          originalSource
              .substring(statement.offset, statement.end)
              .contains("action == 'start'"),
    );
    if (chainIndex < 0) {
      throw StateError('Could not locate the test-mode action branch chain.');
    }

    final branchPieces = <_BranchPiece>[];
    var current = statements[chainIndex];
    Block? finalElse;
    IfStatement? lastIf;
    while (current is IfStatement) {
      final thenStatement = current.thenStatement;
      if (thenStatement is! Block) {
        throw StateError('Every test-mode action branch must use a block.');
      }
      branchPieces.add(
        _BranchPiece(
          condition: originalSource.substring(
            current.expression.offset,
            current.expression.end,
          ),
          body: originalSource.substring(
            thenStatement.leftBracket.end,
            thenStatement.rightBracket.offset,
          ),
        ),
      );
      lastIf = current;
      final elseStatement = current.elseStatement;
      if (elseStatement is IfStatement) {
        current = elseStatement;
      } else if (elseStatement is Block) {
        finalElse = elseStatement;
        break;
      } else {
        throw StateError('The test-mode action chain must end with else.');
      }
    }
    if (branchPieces.length != _branchNames.length ||
        finalElse == null ||
        lastIf == null) {
      throw StateError(
        'Expected ${_branchNames.length} action branches and a final else, '
        'found ${branchPieces.length}.',
      );
    }
    final preambleSource = originalSource.substring(
      bodyBlock.leftBracket.end,
      statements[chainIndex].offset,
    );
    final tailSource = originalSource.substring(
      lastIf.end,
      bodyBlock.rightBracket.offset,
    );
    final finalElseSource = originalSource.substring(
      finalElse.leftBracket.end,
      finalElse.rightBracket.offset,
    );
    final parameters = method.parameters;
    if (parameters == null) {
      throw StateError('The test-mode result method has no parameter list.');
    }
    final parameterNames = _parameterNames(originalSource, parameters);
    final preambleNames =
        _preambleNames(preambleSource, statements, chainIndex);
    final contextNames = <String>[
      ...parameterNames,
      ...preambleNames.where((name) => !parameterNames.contains(name)),
    ];

    final methodPrefix = originalSource.substring(
      method.offset,
      parameters.offset,
    );
    final parameterSource = originalSource.substring(
      parameters.offset,
      parameters.end,
    );
    final methodSuffix = originalSource.substring(
      parameters.end,
      bodyBlock.leftBracket.offset,
    );
    final dispatcherMethod = _dispatcherMethod(
      methodPrefix: methodPrefix,
      parameterSource: parameterSource,
      methodSuffix: methodSuffix,
      preambleSource: preambleSource,
      contextNames: contextNames,
      branchPieces: branchPieces,
      finalElseSource: finalElseSource,
    );
    final contextSource = _contextSource(contextNames);
    final generatedSources = <File, String>{
      File('${root.path}/${_generatedRelativePaths[0]}'):
          _extensionSource('MobileApiAdminQueueActionResultTestMode', [
        dispatcherMethod,
      ]),
      File('${root.path}/${_generatedRelativePaths[1]}'):
          _partSource(contextSource),
    };
    for (var index = 0; index < branchPieces.length; index++) {
      final piece = branchPieces[index];
      final body = _branchOutputBody(
        index: index,
        body: piece.body,
        tailSource: tailSource,
      );
      generatedSources[File(
        '${root.path}/lib/src/core/api/admin/'
        'mobile_api_admin_queue_action_result_test_mode_'
        '${_branchFileSuffixes[index]}.dart',
      )] = _extensionSource(
        '_MobileApiAdminQueueAction${_pascalCase(_branchFileSuffixes[index])}',
        [
          '''Future<AdminApparatusQueueActionResult> ${_branchNames[index]}() async {
$body
}''',
        ],
        targetType: '_TestModeQueueActionContext',
      );
    }

    return _SplitPlan(
      root: root,
      sourcePath: sourcePath,
      mobileApiPath: mobileApiPath,
      originalSource: originalSource,
      originalMobileApiSource: originalMobileApiSource,
      existingSource: existingSource,
      existingMobileApiSource: existingMobileApiSource,
      generatedSources: generatedSources,
      updatedMobileApiSource: originalMobileApiSource.replaceFirst(
        _oldPartDirective,
        _newPartDirectives.join('\n'),
      ),
      preambleSource: preambleSource,
      tailSource: tailSource,
      finalElseSource: finalElseSource,
      branchPieces: branchPieces,
    );
  }
}

List<String> _parameterNames(
  String source,
  FormalParameterList parameters,
) {
  final names = <String>[];
  for (final parameter in parameters.parameters) {
    final raw = source.substring(parameter.offset, parameter.end).trim();
    final match = RegExp(
      r'([A-Za-z_][A-Za-z0-9_]*)\s*(?:=|$)',
    ).firstMatch(raw.replaceFirst(RegExp(r'^required\s+'), ''));
    if (match == null) {
      throw StateError('Could not determine parameter name from: $raw');
    }
    names.add(match.group(1)!);
  }
  if (names.toSet().length != names.length) {
    throw StateError('Test-mode parameters contain duplicate names.');
  }
  return names;
}

List<String> _preambleNames(
  String source,
  List<Statement> statements,
  int chainIndex,
) {
  final names = <String>[];
  for (final statement in statements.take(chainIndex)) {
    if (statement is VariableDeclarationStatement) {
      names.addAll(
        statement.variables.variables.map((variable) => variable.name.lexeme),
      );
    } else if (statement is FunctionDeclarationStatement) {
      names.add(statement.functionDeclaration.name.lexeme);
    }
  }
  if (names.toSet().length != names.length) {
    throw StateError('Test-mode preamble contains duplicate local names.');
  }
  return names;
}

String _branchOutputBody({
  required int index,
  required String body,
  required String tailSource,
}) {
  final output =
      index == 0 ? '${body.trim()}\n${tailSource.trim()}' : body.trim();
  if (index != 4) return output;

  const memberWrite =
      '_testModeProgressBatchesByQr[resumed.qrPayload] = resumed;';
  final memberWriteOffset = output.lastIndexOf(memberWrite);
  if (memberWriteOffset < 0) {
    throw StateError(
      'Expected the resume branch to contain its nullable batch write.',
    );
  }
  final withMemberPromotion = output.replaceRange(
    memberWriteOffset,
    memberWriteOffset + memberWrite.length,
    '_testModeProgressBatchesByQr[resumed!.qrPayload] = resumed;',
  );
  return withMemberPromotion;
}

String _contextSource(List<String> names) {
  final constructorParameters = [
    '    required this.api,',
    for (final name in names) '    required this.$name,',
  ].join('\n');
  final fields = [
    '  final MobileApi api;',
    for (final name in names) '  final dynamic $name;',
  ].join('\n');
  return '''class _TestModeQueueActionContext {
  _TestModeQueueActionContext({
$constructorParameters
  });

$fields

  Future<AdminRawMaterialStartRequirements>
      adminRawMaterialStartRequirements({
    required String orderId,
    required String apparatus,
    required List<String> materialBarcodes,
  }) {
    return api.adminRawMaterialStartRequirements(
      orderId: orderId,
      apparatus: apparatus,
      materialBarcodes: materialBarcodes,
    );
  }
}''';
}

String _dispatcherMethod({
  required String methodPrefix,
  required String parameterSource,
  required String methodSuffix,
  required String preambleSource,
  required List<String> contextNames,
  required List<_BranchPiece> branchPieces,
  required String finalElseSource,
}) {
  final contextArguments = [
    '        api: this,',
    for (final name in contextNames) '        $name: $name,',
  ].join('\n');
  final dispatch = StringBuffer();
  for (var index = 0; index < branchPieces.length; index++) {
    final keyword = index == 0 ? 'if' : 'else if';
    dispatch
      ..writeln('      $keyword (${branchPieces[index].condition}) {')
      ..writeln('        return context.${_branchNames[index]}();')
      ..writeln('      }');
  }
  dispatch
    ..writeln('      else {')
    ..writeln(finalElseSource.trim())
    ..writeln('      }');
  return '''$methodPrefix$parameterSource$methodSuffix{
${preambleSource.trim()}
      final context = _TestModeQueueActionContext(
$contextArguments
      );
${dispatch.toString().trimRight()}
  }''';
}

String _partSource(String body) => '$_partOfMobileApi\n\n$body\n';

String _extensionSource(
  String name,
  List<String> members, {
  String targetType = 'MobileApi',
}) {
  return '$_partOfMobileApi\n\n'
      'extension $name on $targetType {\n'
      '${members.map((member) => member.trim()).join('\n\n')}\n'
      '}\n';
}

String _pascalCase(String value) {
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join();
}

void _verifyPlan(_SplitPlan plan) {
  final original = parseString(
    content: plan.originalSource,
    path: plan.sourcePath.path,
    throwIfDiagnostics: false,
  );
  if (original.errors.isNotEmpty) {
    throw StateError('Original test-mode AST became invalid.');
  }
  if (plan.branchPieces.length != _branchNames.length ||
      plan.preambleSource.trim().isEmpty ||
      plan.tailSource.trim().isEmpty ||
      plan.finalElseSource.trim().isEmpty) {
    throw StateError('The verified test-mode split regions are incomplete.');
  }
  final generatedText = plan.generatedSources.values.join('\n');
  for (final entry in plan.generatedSources.entries) {
    final parsed = parseString(
      content: entry.value,
      path: entry.key.path,
      throwIfDiagnostics: false,
    );
    if (parsed.errors.isNotEmpty) {
      throw StateError(
        'Generated file ${entry.key.path} has syntax errors: '
        '${parsed.errors.join('\n')}',
      );
    }
  }
  final regions = <String, String>{
    'preamble': plan.preambleSource,
    'tail': plan.tailSource,
    'final else': plan.finalElseSource,
    for (var index = 0; index < plan.branchPieces.length; index++)
      'branch $index': _branchOutputBody(
        index: index,
        body: plan.branchPieces[index].body,
        tailSource: plan.tailSource,
      ),
  };
  for (final entry in regions.entries) {
    final preserved = entry.key == 'final else'
        ? generatedText.contains(entry.value.trim())
        : _containsExactlyOnce(generatedText, entry.value.trim());
    if (!preserved) {
      throw StateError(
        'A source-preservation region is missing or duplicated: '
        '${entry.key}.',
      );
    }
  }
  if (!_containsExactlyOnce(plan.updatedMobileApiSource, _oldPartDirective)) {
    throw StateError('The test-mode part directive is missing or duplicated.');
  }
  for (final directive in _newPartDirectives) {
    if (!plan.updatedMobileApiSource.contains(directive)) {
      throw StateError('Missing generated part directive: $directive');
    }
  }
}

bool _containsExactlyOnce(String source, String needle) {
  if (needle.isEmpty) return false;
  var count = 0;
  var offset = 0;
  while (true) {
    final index = source.indexOf(needle, offset);
    if (index < 0) return count == 1;
    count += 1;
    if (count > 1) return false;
    offset = index + needle.length;
  }
}

void _printPlan(_SplitPlan plan) {
  stdout.writeln('Autonomous AST test-mode branch split plan:');
  for (final entry in plan.generatedSources.entries) {
    final lines = entry.value.split('\n').length - 1;
    stdout.writeln('  ${entry.key.path}: $lines lines');
  }
}

void _verifyWrittenPlan(_SplitPlan plan) {
  for (final entry in plan.generatedSources.entries) {
    if (!entry.key.existsSync()) {
      throw StateError('Missing generated file: ${entry.key.path}');
    }
    if (entry.key.readAsStringSync() != entry.value) {
      throw StateError('Generated file differs from the verified plan: '
          '${entry.key.path}');
    }
  }
  if (plan.mobileApiPath.readAsStringSync() != plan.updatedMobileApiSource) {
    throw StateError('mobile_api.dart differs from the verified plan.');
  }
}

void _applyPlan(_SplitPlan plan) {
  final backups = <File, String?>{
    plan.sourcePath: plan.sourcePath.existsSync()
        ? plan.sourcePath.readAsStringSync()
        : null,
    plan.mobileApiPath: plan.mobileApiPath.readAsStringSync(),
    for (final file in plan.generatedSources.keys)
      file: file.existsSync() ? file.readAsStringSync() : null,
  };
  try {
    for (final entry in plan.generatedSources.entries) {
      entry.key.parent.createSync(recursive: true);
      entry.key.writeAsStringSync(entry.value);
    }
    plan.mobileApiPath.writeAsStringSync(plan.updatedMobileApiSource);
  } catch (_) {
    for (final entry in backups.entries) {
      final value = entry.value;
      if (value == null) {
        if (entry.key.existsSync()) entry.key.deleteSync();
      } else {
        entry.key.parent.createSync(recursive: true);
        entry.key.writeAsStringSync(value);
      }
    }
    rethrow;
  }
}
