import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

const _partOfMobileApi = "part of '../mobile_api.dart';";
const _sourceRelativePath =
    'lib/src/core/api/admin/mobile_api_admin_queue_actions.dart';
const _oldPartDirective = "part 'admin/mobile_api_admin_queue_actions.dart';";

const _generatedRelativePaths = <String>[
  'lib/src/core/api/admin/mobile_api_admin_queue_action_models.dart',
  'lib/src/core/api/admin/mobile_api_admin_queue_action.dart',
  'lib/src/core/api/admin/mobile_api_admin_queue_action_result.dart',
  'lib/src/core/api/admin/mobile_api_admin_queue_action_result_test_mode.dart',
  'lib/src/core/api/admin/mobile_api_admin_queue_action_result_backend.dart',
];

const _newPartDirectives = <String>[
  "part 'admin/mobile_api_admin_queue_action_models.dart';",
  "part 'admin/mobile_api_admin_queue_action.dart';",
  "part 'admin/mobile_api_admin_queue_action_result.dart';",
  "part 'admin/mobile_api_admin_queue_action_result_test_mode.dart';",
  "part 'admin/mobile_api_admin_queue_action_result_backend.dart';",
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
    stdout
        .writeln('Current checkout matches the verified queue-actions split.');
    return;
  }
  if (!apply) {
    stdout.writeln('Dry run only. Pass --apply to write the verified split.');
    return;
  }

  _applyPlan(plan);
  stdout.writeln('Verified queue-actions split applied successfully.');
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
    required this.commonSource,
    required this.testModeSource,
    required this.backendSource,
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
  final String commonSource;
  final String testModeSource;
  final String backendSource;

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
      throw StateError('Expected the unsplit queue-actions source file.');
    }
    if (!originalMobileApiSource.contains(_oldPartDirective)) {
      throw StateError('The baseline mobile API has no queue-actions part.');
    }
    if (sourceCommit != null &&
        existingSource.isNotEmpty &&
        existingSource != originalSource) {
      throw StateError(
        'The current queue-actions source differs from the selected source '
        'commit; refusing to overwrite a dirty source file.',
      );
    }
    if (sourceCommit != null &&
        existingMobileApiSource != originalMobileApiSource &&
        existingSource.isNotEmpty) {
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
        'The queue-actions source must parse before extraction: '
        '${parsed.errors.join('\n')}',
      );
    }

    final extension = parsed.unit.declarations
        .whereType<ExtensionDeclaration>()
        .where((item) => item.name?.lexeme == 'MobileApiAdminQueueActions')
        .singleOrNull;
    if (extension == null) {
      throw StateError(
        'Expected exactly one MobileApiAdminQueueActions extension.',
      );
    }
    final methods =
        extension.body.members.whereType<MethodDeclaration>().toList();
    if (methods.length != 2) {
      throw StateError(
        'Expected exactly two queue-actions methods, found ${methods.length}.',
      );
    }
    MethodDeclaration methodNamed(String name) {
      final matches =
          methods.where((item) => item.name.lexeme == name).toList();
      if (matches.length != 1) {
        throw StateError('Expected exactly one $name method.');
      }
      return matches.single;
    }

    final actionMethod = methodNamed('adminApparatusQueueAction');
    final resultMethod = methodNamed('adminApparatusQueueActionResult');
    final resultBody = resultMethod.body;
    if (resultBody is! BlockFunctionBody) {
      throw StateError('The queue-action result must use a block body.');
    }
    final statements = resultBody.block.statements;
    final testModeIndex = statements.indexWhere(
      (statement) =>
          statement is IfStatement &&
          originalSource
              .substring(statement.offset, statement.end)
              .contains('TestModeController.instance.isEnabled()'),
    );
    if (testModeIndex < 0) {
      throw StateError('Could not locate the test-mode queue-action branch.');
    }
    final testModeIf = statements[testModeIndex];
    if (testModeIf is! IfStatement || testModeIf.thenStatement is! Block) {
      throw StateError('The test-mode queue-action branch must be a block.');
    }
    if (testModeIndex + 1 >= statements.length) {
      throw StateError('The production queue-action branch is missing.');
    }
    final testModeBlock = testModeIf.thenStatement as Block;
    final bodyBlock = resultBody.block;
    final commonSource = originalSource.substring(
      bodyBlock.leftBracket.end,
      testModeIf.offset,
    );
    final testModeSource = originalSource.substring(
      testModeBlock.leftBracket.end,
      testModeBlock.rightBracket.offset,
    );
    final backendSource = originalSource.substring(
      statements[testModeIndex + 1].offset,
      bodyBlock.rightBracket.offset,
    );

    final parameters = resultMethod.parameters;
    if (parameters == null) {
      throw StateError('The queue-action result has no parameter list.');
    }
    final parameterSource = originalSource.substring(
      parameters.offset,
      parameters.end,
    );
    final parameterNames = _parameterNames(originalSource, parameters);
    final methodPrefix = originalSource.substring(
      resultMethod.offset,
      parameters.offset,
    );
    final methodSuffix = originalSource.substring(
      parameters.end,
      resultBody.block.leftBracket.offset,
    );

    final testModeParameters = _appendParameters(
      parameterSource,
      const [
        'required String normalizedApparatusId',
        'required String trimmedIssueNote',
        'required bool issueFreezeRequested',
      ],
    );
    final backendParameters = _appendParameters(
      parameterSource,
      const ['required String trimmedIssueNote'],
    );
    final testModePrefix = methodPrefix.replaceFirst(
      'adminApparatusQueueActionResult',
      '_adminApparatusQueueActionResultTestMode',
    );
    final backendPrefix = methodPrefix.replaceFirst(
      'adminApparatusQueueActionResult',
      '_adminApparatusQueueActionResultBackend',
    );
    final dispatcherBody = _dispatcherBody(
      commonSource: commonSource,
      parameterNames: parameterNames,
    );
    final dispatcherMethod =
        '$methodPrefix$parameterSource$methodSuffix$dispatcherBody';
    final testModeMethod = '$testModePrefix$testModeParameters$methodSuffix{\n'
        '${testModeSource.trim()}\n}';
    final backendMethod = '$backendPrefix$backendParameters$methodSuffix{\n'
        '${backendSource.trim()}\n}';

    final classSource = _findResultClassSource(parsed.unit, originalSource);
    final generatedSources = <File, String>{
      File('${root.path}/${_generatedRelativePaths[0]}'):
          _partSource(classSource),
      File('${root.path}/${_generatedRelativePaths[1]}'):
          _extensionSource('MobileApiAdminQueueAction', [
        originalSource.substring(actionMethod.offset, actionMethod.end),
      ]),
      File('${root.path}/${_generatedRelativePaths[2]}'): _extensionSource(
          'MobileApiAdminQueueActionResult', [dispatcherMethod]),
      File('${root.path}/${_generatedRelativePaths[3]}'):
          _extensionSource('MobileApiAdminQueueActionResultTestMode', [
        testModeMethod,
      ]),
      File('${root.path}/${_generatedRelativePaths[4]}'):
          _extensionSource('MobileApiAdminQueueActionResultBackend', [
        backendMethod,
      ]),
    };

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
      commonSource: commonSource,
      testModeSource: testModeSource,
      backendSource: backendSource,
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
    throw StateError('Queue-action parameters contain duplicate names.');
  }
  return names;
}

String _appendParameters(String parameters, List<String> extras) {
  final closingBrace = parameters.lastIndexOf('}');
  if (closingBrace < 0) {
    throw StateError('Queue-action parameter list has no closing brace.');
  }
  final extraSource = extras.map((extra) => '    $extra,').join('\n');
  return '${parameters.substring(0, closingBrace)}\n$extraSource\n'
      '${parameters.substring(closingBrace)}';
}

String _dispatcherBody({
  required String commonSource,
  required List<String> parameterNames,
}) {
  final callArguments = <String>[
    for (final name in parameterNames) '      $name: $name,',
  ];
  final testCallArguments = [
    ...callArguments,
    '      normalizedApparatusId: normalizedApparatusId,',
    '      trimmedIssueNote: trimmedIssueNote,',
    '      issueFreezeRequested: issueFreezeRequested,',
  ].join('\n');
  final backendCallArguments = [
    ...callArguments,
    '      trimmedIssueNote: trimmedIssueNote,',
  ].join('\n');
  return '''{
${commonSource.trim()}
    if (await TestModeController.instance.isEnabled()) {
      return _adminApparatusQueueActionResultTestMode(
$testCallArguments
      );
    }
    return _adminApparatusQueueActionResultBackend(
$backendCallArguments
    );
  }''';
}

String _findResultClassSource(
  CompilationUnit unit,
  String source,
) {
  final classes = unit.declarations
      .whereType<ClassDeclaration>()
      .where((item) =>
          item.namePart.typeName.lexeme == 'AdminApparatusQueueActionResult')
      .toList();
  if (classes.length != 1) {
    throw StateError('Expected exactly one queue-action result class.');
  }
  return source.substring(classes.single.offset, classes.single.end);
}

String _partSource(String body) => '$_partOfMobileApi\n\n$body\n';

String _extensionSource(String name, List<String> members) {
  return '$_partOfMobileApi\n\n'
      'extension $name on MobileApi {\n'
      '${members.map((member) => member.trim()).join('\n\n')}\n'
      '}\n';
}

void _verifyPlan(_SplitPlan plan) {
  final original = parseString(
    content: plan.originalSource,
    path: plan.sourcePath.path,
    throwIfDiagnostics: false,
  );
  if (original.errors.isNotEmpty) {
    throw StateError('Original queue-actions AST became invalid.');
  }
  if (plan.commonSource.trim().isEmpty ||
      plan.testModeSource.trim().isEmpty ||
      plan.backendSource.trim().isEmpty) {
    throw StateError('One of the extracted queue-action regions is empty.');
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
  for (final region in [
    plan.commonSource,
    plan.testModeSource,
    plan.backendSource,
  ]) {
    if (!generatedText.contains(region.trim())) {
      throw StateError('An extracted queue-action source region was changed.');
    }
  }
  if (plan.updatedMobileApiSource.contains(_oldPartDirective)) {
    throw StateError('The old queue-actions part directive remains.');
  }
  for (final directive in _newPartDirectives) {
    if (!plan.updatedMobileApiSource.contains(directive)) {
      throw StateError('Missing generated part directive: $directive');
    }
  }
}

void _printPlan(_SplitPlan plan) {
  stdout.writeln('Autonomous AST queue-actions split plan:');
  for (final entry in plan.generatedSources.entries) {
    final lines = entry.value.split('\n').length - 1;
    stdout.writeln('  ${entry.key.path}: $lines lines');
  }
}

void _verifyWrittenPlan(_SplitPlan plan) {
  if (plan.sourcePath.existsSync()) {
    throw StateError('The old queue-actions source file still exists.');
  }
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
    if (plan.sourcePath.existsSync()) plan.sourcePath.deleteSync();
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
