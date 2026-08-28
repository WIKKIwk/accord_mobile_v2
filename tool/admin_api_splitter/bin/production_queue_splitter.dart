import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

const _partOfMobileApi = "part of '../mobile_api.dart';";
const _sourceRelativePath =
    'lib/src/core/api/admin/mobile_api_admin_production_queue.dart';
const _oldPartDirective =
    "part 'admin/mobile_api_admin_production_queue.dart';";

const _domains = <_DomainSpec>[
  _DomainSpec(
    id: 'runtime',
    fileName: 'mobile_api_admin_production_queue_runtime.dart',
  ),
  _DomainSpec(
    id: 'queue_models',
    fileName: 'mobile_api_admin_queue_models.dart',
  ),
  _DomainSpec(
    id: 'order_lifecycle',
    fileName: 'mobile_api_admin_order_lifecycle.dart',
    extensionName: 'MobileApiAdminOrderLifecycle',
  ),
  _DomainSpec(
    id: 'production_map',
    fileName: 'mobile_api_admin_production_map.dart',
    extensionName: 'MobileApiAdminProductionMap',
  ),
  _DomainSpec(
    id: 'capacity_schedule',
    fileName: 'mobile_api_admin_capacity_schedule.dart',
    extensionName: 'MobileApiAdminCapacitySchedule',
  ),
  _DomainSpec(
    id: 'queue_state',
    fileName: 'mobile_api_admin_queue_state.dart',
    extensionName: 'MobileApiAdminQueueState',
  ),
  _DomainSpec(
    id: 'queue_actions',
    fileName: 'mobile_api_admin_queue_actions.dart',
    extensionName: 'MobileApiAdminQueueActions',
  ),
  _DomainSpec(
    id: 'users',
    fileName: 'mobile_api_admin_users_list.dart',
    extensionName: 'MobileApiAdminUsersList',
  ),
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
    stdout.writeln('Current checkout matches the verified production split.');
    return;
  }
  if (!apply) {
    stdout.writeln('Dry run only. Pass --apply to write the verified split.');
    return;
  }

  _applyPlan(plan);
  stdout.writeln('Verified production split applied successfully.');
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

class _DomainSpec {
  const _DomainSpec({
    required this.id,
    required this.fileName,
    this.extensionName,
  });

  final String id;
  final String fileName;
  final String? extensionName;
}

class _DeclarationPiece {
  const _DeclarationPiece({
    required this.order,
    required this.key,
    required this.names,
    required this.source,
    required this.domain,
  });

  final int order;
  final String key;
  final List<String> names;
  final String source;
  final String domain;
}

class _MethodPiece {
  const _MethodPiece({
    required this.order,
    required this.name,
    required this.source,
    required this.domain,
  });

  final int order;
  final String name;
  final String source;
  final String domain;
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
    required this.declarations,
    required this.methods,
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
  final List<_DeclarationPiece> declarations;
  final List<_MethodPiece> methods;

  static _SplitPlan load(
    Directory root, {
    String? sourceCommit,
  }) {
    final sourcePath = File('${root.path}/$_sourceRelativePath');
    final mobileApiPath = File('${root.path}/lib/src/core/api/mobile_api.dart');
    final existingSource =
        sourcePath.existsSync() ? sourcePath.readAsStringSync() : '';
    final existingMobileApiSource = mobileApiPath.readAsStringSync();
    final source = sourceCommit == null
        ? existingSource
        : _readGitFile(root, sourceCommit, _sourceRelativePath);
    final mobileApiSource = sourceCommit == null
        ? existingMobileApiSource
        : _readGitFile(root, sourceCommit, 'lib/src/core/api/mobile_api.dart');
    if (source.isEmpty) {
      throw StateError('Expected an unsplit production queue source file.');
    }

    final parsed = parseString(
      content: source,
      path: sourcePath.path,
      throwIfDiagnostics: false,
    );
    if (parsed.errors.isNotEmpty) {
      throw StateError(
        'The source file must parse before extraction: '
        '${parsed.errors.join('\n')}',
      );
    }
    final extension = parsed.unit.declarations
        .whereType<ExtensionDeclaration>()
        .where((item) => item.name?.lexeme == 'MobileApiAdminProductionQueue')
        .singleOrNull;
    if (extension == null) {
      throw StateError(
        'Expected exactly one unsplit MobileApiAdminProductionQueue extension.',
      );
    }

    final methods = <_MethodPiece>[];
    for (var index = 0; index < extension.body.members.length; index++) {
      final member = extension.body.members[index];
      if (member is! MethodDeclaration) {
        throw StateError(
          'Unsupported extension member ${member.runtimeType} at index $index.',
        );
      }
      final name = member.name.lexeme;
      methods.add(
        _MethodPiece(
          order: index,
          name: name,
          source: source.substring(member.offset, member.end),
          domain: _methodDomain(name),
        ),
      );
    }

    final declarations = <_DeclarationPiece>[];
    for (var index = 0; index < parsed.unit.declarations.length; index++) {
      final declaration = parsed.unit.declarations[index];
      if (declaration == extension) continue;
      final names = _declarationNames(declaration);
      declarations.add(
        _DeclarationPiece(
          order: index,
          key: '${declaration.runtimeType}:$names',
          names: names,
          source: source.substring(declaration.offset, declaration.end),
          domain: _declarationDomain(names),
        ),
      );
    }

    final generatedSources = <File, String>{};
    for (final spec in _domains) {
      final domainDeclarations = declarations
          .where((item) => item.domain == spec.id)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      final domainMethods = methods
          .where((item) => item.domain == spec.id)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      final sections = <String>[
        for (final declaration in domainDeclarations) declaration.source,
      ];
      if (spec.extensionName != null && domainMethods.isNotEmpty) {
        final body =
            domainMethods.map((method) => method.source.trim()).join('\n\n');
        sections.add(
          'extension ${spec.extensionName} on MobileApi {\n$body\n}',
        );
      }
      generatedSources[File(
        '${root.path}/lib/src/core/api/admin/${spec.fileName}',
      )] = _partSource(sections);
    }

    return _SplitPlan(
      root: root,
      sourcePath: sourcePath,
      mobileApiPath: mobileApiPath,
      originalSource: source,
      originalMobileApiSource: mobileApiSource,
      existingSource: existingSource,
      existingMobileApiSource: existingMobileApiSource,
      generatedSources: generatedSources,
      updatedMobileApiSource: _updatedMobileApiSource(mobileApiSource),
      declarations: declarations,
      methods: methods,
    );
  }
}

List<String> _declarationNames(CompilationUnitMember declaration) {
  if (declaration is ClassDeclaration) {
    return [declaration.namePart.typeName.lexeme];
  }
  if (declaration is EnumDeclaration) {
    return [declaration.namePart.typeName.lexeme];
  }
  if (declaration is FunctionDeclaration) return [declaration.name.lexeme];
  if (declaration is TopLevelVariableDeclaration) {
    return [
      for (final variable in declaration.variables.variables)
        variable.name.lexeme,
    ];
  }
  if (declaration is TypeAlias) return [declaration.name.lexeme];
  return [declaration.runtimeType.toString()];
}

String _declarationDomain(List<String> names) {
  final name = names.single;
  if (name == '_TestModeCompletedQueueOrder') {
    return 'order_lifecycle';
  }
  if (name.startsWith('_testMode') ||
      name.startsWith('setMobileApiTestMode') ||
      name.startsWith('_requireCanonical') ||
      name == '_frozenOrderIds' ||
      name == '_TestModeApparatusTransferReceipt' ||
      name == '_TestModeScheduledCandidate') {
    return 'runtime';
  }
  if (name == 'ProductionMapSaveWithOrderResult' ||
      name == 'AdminProductionMapLiveSnapshot' ||
      name.startsWith('_adminProductionMap') ||
      name == 'AdminProductionWorkflowAuditViolation' ||
      name == 'AdminProductionWorkflowAuditReport' ||
      name == '_isSameProductionMapOrder' ||
      name == '_validateProductionMapQueueContract') {
    return 'production_map';
  }
  if (name.startsWith('AdminApparatusWorking') ||
      name.startsWith('AdminApparatusCapacity') ||
      name.startsWith('AdminApparatusDowntime') ||
      name.startsWith('AdminApparatusSchedule') ||
      name.startsWith('_normalizeTestModeCapacityProfile') ||
      name.startsWith('_testModeProfileForApparatus')) {
    return 'capacity_schedule';
  }
  if (name == 'AdminApparatusQueueActionResult') return 'queue_actions';
  if (name == 'AdminCompletedQueueOrder' ||
      name == 'AdminFrozenQueueOrder' ||
      name.startsWith('AdminCompletionRequest') ||
      name.startsWith('AdminProductionOrder') ||
      name == 'AdminClosedProductionOrder' ||
      name == '_TestModeCompletedQueueOrder' ||
      name == '_parseProductionMapStageStates') {
    return 'order_lifecycle';
  }
  if (name.startsWith('AdminQueue') ||
      name.startsWith('AdminApparatusQueue') ||
      name.startsWith('ApparatusQueue') ||
      name.startsWith('AdminOrderControl') ||
      name == 'adminProductionMapOrderControlFor' ||
      name.startsWith('_queue') ||
      name.startsWith('_parseAdminQueue') ||
      name == '_productionMapQueueContractException' ||
      name.startsWith('_requireProductionMap') ||
      name.startsWith('_parseRequiredProductionMap')) {
    return 'queue_models';
  }
  if (name == '_parseAdminOrderControls' ||
      name == '_parseAdminFrozenOrdersByApparatus' ||
      name == '_applyTestModeOrderControl' ||
      name == '_effectiveTestModeQueuePolicy') {
    return 'queue_state';
  }
  if (name == 'TopLevelVariableDeclaration') return 'runtime';
  throw StateError('Unclassified production queue declaration: $name');
}

String _methodDomain(String name) {
  if (name == 'adminUserList') return 'users';
  if (name == 'adminApparatusQueueAction' ||
      name == 'adminApparatusQueueActionResult') {
    return 'queue_actions';
  }
  if (name == 'adminApparatusCapacitySnapshot' ||
      name == 'adminSaveApparatusCapacityProfile' ||
      name == 'adminSaveApparatusDowntime' ||
      name == 'adminScheduleApparatusOrder' ||
      name == 'adminCancelApparatusScheduleReservation') {
    return 'capacity_schedule';
  }
  if (name == 'adminWipBatches' ||
      name == 'adminCompletedProductionMapOrders' ||
      name == 'adminProductionMapCompletionRequests' ||
      name == 'adminProductionMapCompletionRequestDecision' ||
      name == 'adminProductionMapCompletionRequestDecisions' ||
      name == 'adminClosedProductionMapOrders' ||
      name == 'adminLaminatsiyaAstatkaReport' ||
      name == 'adminRezkaAstatkaReport') {
    return 'order_lifecycle';
  }
  if (name == 'adminProductionMapQueueSnapshot' ||
      name == 'adminProductionMapOrderControl' ||
      name == 'adminProductionMapSequences' ||
      name == 'adminApparatusQueuePolicies' ||
      name == 'adminUpdateApparatusQueuePolicy' ||
      name == 'parseApparatusSequenceMap' ||
      name == 'parseNestedSequenceMap' ||
      name == 'parseApparatusQueueStateMap' ||
      name == 'parseApparatusQueuePolicyMap' ||
      name == 'adminSaveProductionMapSequence') {
    return 'queue_state';
  }
  if (name == 'adminRegenerateWerkaCode' ||
      name == 'adminResetOrders' ||
      name == 'adminCapabilities' ||
      name == 'adminProductionMaps' ||
      name == 'adminProductionMapAudit' ||
      name == 'adminProductionMap' ||
      name == 'adminSaveProductionMap' ||
      name == 'adminSaveProductionMapWithOrder' ||
      name == 'adminMoveProductionMapOrdersBatch' ||
      name == 'adminTransferProductionMapOrder' ||
      name == 'adminMoveProductionMapOrder' ||
      name == 'adminProductionMapLiveUri' ||
      name == 'adminProductionMapLiveEvents' ||
      name == 'adminRunProductionMap') {
    return 'production_map';
  }
  throw StateError('Unclassified production queue method: $name');
}

String _partSource(Iterable<String> sections) {
  final body = sections
      .map((section) => section.trim())
      .where((section) => section.isNotEmpty)
      .join('\n\n');
  return '$_partOfMobileApi\n\n$body\n';
}

String _updatedMobileApiSource(String source) {
  if (!source.contains(_oldPartDirective)) {
    throw StateError('The mobile API library no longer contains the old part.');
  }
  final replacement = [
    for (final domain in _domains) "part 'admin/${domain.fileName}';",
  ].join('\n');
  return source.replaceFirst(_oldPartDirective, replacement);
}

void _verifyPlan(_SplitPlan plan) {
  final original = parseString(
    content: plan.originalSource,
    path: plan.sourcePath.path,
    throwIfDiagnostics: false,
  );
  if (original.errors.isNotEmpty) {
    throw StateError('Original AST became invalid during planning.');
  }

  final generatedDeclarations = <String, List<String>>{};
  final generatedMethods = <String, List<String>>{};
  final generatedExtensionNames = <String>{};
  for (final entry in plan.generatedSources.entries) {
    final parsed = parseString(
      content: entry.value,
      path: entry.key.path,
      throwIfDiagnostics: false,
    );
    if (parsed.errors.isNotEmpty) {
      throw StateError(
        'Generated file ${entry.key.path} does not parse: '
        '${parsed.errors.join('\n')}',
      );
    }
    for (final declaration in parsed.unit.declarations) {
      if (declaration is ExtensionDeclaration) {
        final extensionName = declaration.name?.lexeme;
        if (extensionName == null ||
            !generatedExtensionNames.add(extensionName)) {
          throw StateError('Generated extension names must be unique.');
        }
        for (final member in declaration.body.members) {
          if (member is! MethodDeclaration) {
            throw StateError(
                'Generated extension contains a non-method member.');
          }
          generatedMethods
              .putIfAbsent(member.name.lexeme, () => [])
              .add(entry.value.substring(member.offset, member.end).trim());
        }
      } else {
        final names = _declarationNames(declaration);
        final key = '${declaration.runtimeType}:$names';
        generatedDeclarations.putIfAbsent(key, () => []).add(
            entry.value.substring(declaration.offset, declaration.end).trim());
      }
    }
  }

  if (generatedDeclarations.length != plan.declarations.length) {
    throw StateError(
        'Generated declaration set differs from the original set.');
  }
  for (final declaration in plan.declarations) {
    final outputs = generatedDeclarations[declaration.key];
    if (outputs == null || outputs.length != 1) {
      throw StateError(
        'Declaration ${declaration.key} was not emitted exactly once.',
      );
    }
    if (outputs.single != declaration.source.trim()) {
      throw StateError(
        'Declaration ${declaration.key} was modified during extraction.',
      );
    }
  }

  if (generatedMethods.length != plan.methods.length) {
    throw StateError('Generated method set differs from the original set.');
  }
  for (final method in plan.methods) {
    final outputs = generatedMethods[method.name];
    if (outputs == null || outputs.length != 1) {
      throw StateError('Method ${method.name} was not emitted exactly once.');
    }
    if (outputs.single != method.source.trim()) {
      throw StateError('Method ${method.name} was modified during extraction.');
    }
  }

  final mobileApi = parseString(
    content: plan.updatedMobileApiSource,
    path: plan.mobileApiPath.path,
    throwIfDiagnostics: false,
  );
  if (mobileApi.errors.isNotEmpty) {
    throw StateError('Updated mobile_api.dart does not parse.');
  }
  for (final domain in _domains) {
    final directive = "part 'admin/${domain.fileName}';";
    if (!plan.updatedMobileApiSource.contains(directive)) {
      throw StateError('Missing generated part directive $directive.');
    }
  }
}

void _printPlan(_SplitPlan plan) {
  stdout.writeln('Autonomous AST production split plan:');
  stdout.writeln('  declarations: ${plan.declarations.length}');
  stdout.writeln('  extension methods: ${plan.methods.length}');
  for (final entry in plan.generatedSources.entries) {
    final declarations = plan.declarations
        .where((piece) => piece.domain == _fileDomain(entry.key.path))
        .length;
    final methods = plan.methods
        .where((piece) => piece.domain == _fileDomain(entry.key.path))
        .length;
    stdout.writeln(
      '  ${entry.key.path}: $declarations declarations, $methods methods',
    );
  }
}

String _fileDomain(String path) =>
    _domains.firstWhere((domain) => path.endsWith(domain.fileName)).id;

void _applyPlan(_SplitPlan plan) {
  final originalFiles = <File, String>{
    plan.sourcePath: plan.existingSource,
    plan.mobileApiPath: plan.existingMobileApiSource,
  };
  for (final file in plan.generatedSources.keys) {
    if (file.existsSync()) originalFiles[file] = file.readAsStringSync();
  }

  try {
    for (final entry in plan.generatedSources.entries) {
      entry.key.parent.createSync(recursive: true);
      entry.key.writeAsStringSync(entry.value);
    }
    if (plan.sourcePath.existsSync()) plan.sourcePath.deleteSync();
    plan.mobileApiPath.writeAsStringSync(plan.updatedMobileApiSource);
    _verifyWrittenPlan(plan);
  } catch (error) {
    _restoreFiles(originalFiles, plan.generatedSources.keys, plan.sourcePath);
    rethrow;
  }
}

void _verifyWrittenPlan(_SplitPlan plan) {
  if (plan.sourcePath.existsSync()) {
    throw StateError('The old production queue file was not removed.');
  }
  if (plan.mobileApiPath.readAsStringSync() != plan.updatedMobileApiSource) {
    throw StateError('mobile_api.dart differs from the verified output.');
  }
  for (final entry in plan.generatedSources.entries) {
    if (!entry.key.existsSync()) {
      throw StateError('Generated file was not written: ${entry.key.path}.');
    }
    if (entry.key.readAsStringSync() != entry.value) {
      throw StateError(
        'Generated file differs from the verified output: ${entry.key.path}.',
      );
    }
  }
  _verifyPlan(plan);
}

void _restoreFiles(
  Map<File, String> originals,
  Iterable<File> generatedFiles,
  File removedSource,
) {
  for (final entry in originals.entries) {
    entry.key.parent.createSync(recursive: true);
    entry.key.writeAsStringSync(entry.value);
  }
  for (final file in generatedFiles) {
    if (!originals.containsKey(file) && file.existsSync()) file.deleteSync();
  }
  if (!originals.containsKey(removedSource) && removedSource.existsSync()) {
    removedSource.deleteSync();
  }
}
