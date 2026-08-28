import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

const _partOfMobileApi = "part of '../mobile_api.dart';";
const _adminApiPart = "part 'admin/mobile_api_admin.dart';";

const _domains = <_DomainSpec>[
  _DomainSpec(
    id: 'settings',
    fileName: 'mobile_api_admin_settings_monitor.dart',
    extensionName: 'MobileApiAdminSettingsMonitor',
  ),
  _DomainSpec(
    id: 'production',
    fileName: 'mobile_api_admin_production_queue.dart',
    extensionName: 'MobileApiAdminProductionQueue',
  ),
  _DomainSpec(
    id: 'raw_materials',
    fileName: 'mobile_api_admin_raw_materials.dart',
    extensionName: 'MobileApiAdminRawMaterials',
  ),
  _DomainSpec(
    id: 'progress',
    fileName: 'mobile_api_admin_progress_qr.dart',
    extensionName: 'MobileApiAdminProgressQr',
  ),
  _DomainSpec(
    id: 'people',
    fileName: 'mobile_api_admin_users_workers.dart',
    extensionName: 'MobileApiAdminUsersWorkers',
  ),
  _DomainSpec(
    id: 'parties',
    fileName: 'mobile_api_admin_suppliers_customers.dart',
    extensionName: 'MobileApiAdminSuppliersCustomers',
  ),
  _DomainSpec(
    id: 'qolip',
    fileName: 'mobile_api_admin_qolip_orders.dart',
    extensionName: 'MobileApiAdminQolipOrders',
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
    stdout.writeln('Current checkout matches the verified AST split.');
    return;
  }

  if (!apply) {
    stdout.writeln('Dry run only. Pass --apply to write the verified split.');
    return;
  }

  _applyPlan(plan);
  stdout.writeln('Verified split applied successfully.');
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
    required this.extensionName,
  });

  final String id;
  final String fileName;
  final String extensionName;
}

class _DeclarationPiece {
  const _DeclarationPiece({
    required this.order,
    required this.kind,
    required this.names,
    required this.source,
    required this.domain,
  });

  final int order;
  final String kind;
  final List<String> names;
  final String source;
  final String domain;

  String get key => '$kind:${names.join(',')}';
}

class _MethodPiece {
  const _MethodPiece({
    required this.order,
    required this.name,
    required this.source,
    required this.method,
    required this.domain,
  });

  final int order;
  final String name;
  final String source;
  final MethodDeclaration method;
  final String domain;
}

class _SplitPlan {
  _SplitPlan({
    required this.root,
    required this.adminApiPath,
    required this.mobileApiPath,
    required this.originalAdminApiSource,
    required this.originalMobileApiSource,
    required this.existingAdminApiSource,
    required this.existingMobileApiSource,
    required this.sharedSource,
    required this.generatedSources,
    required this.updatedMobileApiSource,
    required this.declarations,
    required this.methods,
  });

  final Directory root;
  final File adminApiPath;
  final File mobileApiPath;
  final String originalAdminApiSource;
  final String originalMobileApiSource;
  final String existingAdminApiSource;
  final String existingMobileApiSource;
  final String sharedSource;
  final Map<File, String> generatedSources;
  final String updatedMobileApiSource;
  final List<_DeclarationPiece> declarations;
  final List<_MethodPiece> methods;

  static _SplitPlan load(
    Directory root, {
    String? sourceCommit,
  }) {
    final adminApiPath = File(
      '${root.path}/lib/src/core/api/admin/mobile_api_admin.dart',
    );
    final mobileApiPath = File('${root.path}/lib/src/core/api/mobile_api.dart');
    final existingAdminSource = adminApiPath.readAsStringSync();
    final existingMobileSource = mobileApiPath.readAsStringSync();
    final adminSource = sourceCommit == null
        ? existingAdminSource
        : _readGitFile(
            root,
            sourceCommit,
            'lib/src/core/api/admin/mobile_api_admin.dart',
          );
    final mobileSource = sourceCommit == null
        ? existingMobileSource
        : _readGitFile(root, sourceCommit, 'lib/src/core/api/mobile_api.dart');
    final parsed = parseString(
      content: adminSource,
      path: adminApiPath.path,
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
        .where((item) => item.name?.lexeme == 'MobileApiAdmin')
        .singleOrNull;
    if (extension == null) {
      throw StateError(
        'Expected exactly one unsplit extension named MobileApiAdmin.',
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
      final domain = _methodDomain(name);
      methods.add(
        _MethodPiece(
          order: index,
          name: name,
          source: adminSource.substring(member.offset, member.end),
          method: member,
          domain: domain,
        ),
      );
    }

    final declarations = <_DeclarationPiece>[];
    for (var index = 0; index < parsed.unit.declarations.length; index++) {
      final declaration = parsed.unit.declarations[index];
      if (declaration == extension) continue;
      final names = _declarationNames(declaration);
      final domain = declaration is TopLevelVariableDeclaration
          ? 'shared'
          : _declarationDomain(names);
      declarations.add(
        _DeclarationPiece(
          order: index,
          kind: declaration.runtimeType.toString(),
          names: names,
          source: adminSource.substring(declaration.offset, declaration.end),
          domain: domain,
        ),
      );
    }

    final sharedParts = declarations
        .where((item) => item.domain == 'shared')
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final sharedSource = _partSource(
      [for (final piece in sharedParts) piece.source],
    );

    final generatedSources = <File, String>{};
    for (final spec in _domains) {
      final parts = declarations
          .where((item) => item.domain == spec.id)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      final domainMethods = methods
          .where((item) => item.domain == spec.id)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      final methodSource = _extensionSource(spec, domainMethods, adminSource);
      generatedSources[File(
        '${root.path}/lib/src/core/api/admin/${spec.fileName}',
      )] = _partSource([
        for (final part in parts) part.source,
        if (methodSource.isNotEmpty) methodSource,
      ]);
    }

    final updatedMobileApiSource = _updatedMobileApiSource(mobileSource);
    return _SplitPlan(
      root: root,
      adminApiPath: adminApiPath,
      mobileApiPath: mobileApiPath,
      originalAdminApiSource: adminSource,
      originalMobileApiSource: mobileSource,
      existingAdminApiSource: existingAdminSource,
      existingMobileApiSource: existingMobileSource,
      sharedSource: sharedSource,
      generatedSources: generatedSources,
      updatedMobileApiSource: updatedMobileApiSource,
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
  if (declaration is ExtensionDeclaration) {
    return [declaration.name?.lexeme ?? '<unnamed>'];
  }
  return [declaration.runtimeType.toString()];
}

String _declarationDomain(List<String> names) {
  if (names.contains('_testModeQueueActionControls') ||
      names.contains('_testModeProductionMapIsVisibleQueueOrder')) {
    return 'shared';
  }
  final value = names.join(' ');
  if (RegExp(r'(RawMaterial|rawMaterial)').hasMatch(value)) {
    return 'raw_materials';
  }
  if (RegExp(r'(Progress|progress|Laminatsiya|Rezka|Astatka|astatka)')
      .hasMatch(value)) {
    return 'progress';
  }
  if (RegExp(r'(Worker|worker|Role|role|SystemUser|systemUser|Capability)')
      .hasMatch(value)) {
    return 'people';
  }
  if (RegExp(r'(Supplier|supplier|Customer|customer|Taminotchi|taminotchi)')
      .hasMatch(value)) {
    return 'parties';
  }
  if (RegExp(r'(Qolip|qolip)').hasMatch(value)) return 'qolip';
  if (RegExp(r'(Settings|settings|ServerMonitor|serverMonitor|Backup|backup)')
      .hasMatch(value)) {
    return 'settings';
  }
  if (RegExp(
    r'(ProductionMap|productionMap|Apparatus|apparatus|Queue|queue|'
    r'Completion|completion|OrderControl|orderControl|Frozen|frozen|'
    r'Closed|closed|ProductionOrder|productionOrder|Capacity|capacity|'
    r'Downtime|downtime|Schedule|schedule|Workflow|workflow)',
  ).hasMatch(value)) {
    return 'production';
  }
  return 'shared';
}

String _methodDomain(String name) {
  if (name == 'baseUrl' ||
      RegExp(r'^(adminSettings|updateAdminSettings|adminActivity|'
              r'adminServerMonitor|adminStartBackup|adminImportBackup|'
              r'adminDownloadBackup)')
          .hasMatch(name) ||
      RegExp(r'^(_downloadFilename|_backupErrorMessage)').hasMatch(name)) {
    return 'settings';
  }
  if (RegExp(r'(RawMaterial|rawMaterial)').hasMatch(name)) {
    return 'raw_materials';
  }
  if (RegExp(r'(Progress|progress|ProgressQr|progressQr)').hasMatch(name)) {
    return 'progress';
  }
  if (RegExp(r'(Worker|worker|Role|role|SystemUser|systemUser|Capability)')
      .hasMatch(name)) {
    return 'people';
  }
  if (RegExp(r'(Supplier|supplier|Customer|customer|Taminotchi|taminotchi)')
      .hasMatch(name)) {
    return 'parties';
  }
  if (RegExp(r'(Qolip|qolip)').hasMatch(name)) return 'qolip';
  return 'production';
}

String _partSource(Iterable<String> parts) {
  final body = parts
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join('\n\n');
  return '$_partOfMobileApi\n\n$body\n';
}

String _extensionSource(
  _DomainSpec spec,
  List<_MethodPiece> methods,
  String originalSource,
) {
  if (methods.isEmpty) return '';
  final body = methods
      .map(
        (piece) => _transformBaseUrl(piece, originalSource).trim(),
      )
      .join('\n\n');
  return 'extension ${spec.extensionName} on MobileApi {\n$body\n}\n';
}

String _transformBaseUrl(_MethodPiece piece, String originalSource) {
  final visitor = _BaseUrlReferenceVisitor(
    methodOffset: piece.method.offset,
    source: originalSource,
  );
  piece.method.accept(visitor);
  final replacements = visitor.replacements.toList()
    ..sort((a, b) => b.start.compareTo(a.start));
  var result = piece.source;
  for (final replacement in replacements) {
    final localStart = replacement.start - piece.method.offset;
    final localEnd = replacement.end - piece.method.offset;
    result = result.replaceRange(localStart, localEnd, replacement.text);
  }
  return result;
}

class _Replacement {
  const _Replacement(this.start, this.end, this.text);

  final int start;
  final int end;
  final String text;
}

class _BaseUrlReferenceVisitor extends RecursiveAstVisitor<void> {
  _BaseUrlReferenceVisitor({
    required this.methodOffset,
    required this.source,
  });

  final int methodOffset;
  final String source;
  final List<_Replacement> replacements = [];

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == 'baseUrl' && _isUnqualified(node)) {
      final previous = node.offset > 0 ? source[node.offset - 1] : '';
      if (previous == r'$') {
        replacements.add(
          _Replacement(node.offset - 1, node.end, r'${MobileApi.baseUrl}'),
        );
      } else {
        replacements.add(
          _Replacement(node.offset, node.end, 'MobileApi.baseUrl'),
        );
      }
    }
    super.visitSimpleIdentifier(node);
  }

  bool _isUnqualified(SimpleIdentifier node) {
    if (node.parent is MethodDeclaration) return false;
    var index = node.offset - 1;
    while (index >= methodOffset && source[index].trim().isEmpty) {
      index -= 1;
    }
    if (index < methodOffset) return true;
    return source[index] != '.';
  }
}

String _updatedMobileApiSource(String source) {
  if (!source.contains(_adminApiPart)) {
    throw StateError(
        'The MobileApi library no longer contains the admin part.');
  }
  var result = source;
  final insertion = [
    for (final spec in _domains) "part 'admin/${spec.fileName}';",
  ].join('\n');
  if (!result.contains("part 'admin/${_domains.first.fileName}';")) {
    result = result.replaceFirst(_adminApiPart, '$_adminApiPart\n$insertion');
  }
  return result;
}

void _verifyPlan(_SplitPlan plan) {
  final original = parseString(
    content: plan.originalAdminApiSource,
    path: plan.adminApiPath.path,
    throwIfDiagnostics: false,
  );
  if (original.errors.isNotEmpty) {
    throw StateError('Original AST became invalid during planning.');
  }

  final generatedDeclarations = <String, int>{};
  final generatedDeclarationSources = <String, List<String>>{};
  final generatedMethods = <String, int>{};
  final generatedMethodSources = <String, List<String>>{};
  for (final entry in <File, String>{
    plan.adminApiPath: plan.sharedSource,
    ...plan.generatedSources,
  }.entries) {
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
        for (final member in declaration.body.members) {
          if (member is MethodDeclaration) {
            generatedMethods.update(
              member.name.lexeme,
              (count) => count + 1,
              ifAbsent: () => 1,
            );
            generatedMethodSources
                .putIfAbsent(member.name.lexeme, () => [])
                .add(entry.value.substring(member.offset, member.end).trim());
          }
        }
      } else {
        final piece = _DeclarationPiece(
          order: 0,
          kind: declaration.runtimeType.toString(),
          names: _declarationNames(declaration),
          source: '',
          domain: 'generated',
        );
        generatedDeclarations.update(
          piece.key,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        generatedDeclarationSources.putIfAbsent(piece.key, () => []).add(
            entry.value.substring(declaration.offset, declaration.end).trim());
      }
    }
  }

  for (final declaration in plan.declarations) {
    if (generatedDeclarations[declaration.key] != 1) {
      throw StateError(
        'Declaration ${declaration.key} was not emitted exactly once: '
        '${generatedDeclarations[declaration.key] ?? 0}.',
      );
    }
    final generatedSource =
        generatedDeclarationSources[declaration.key]!.single;
    if (generatedSource != declaration.source.trim()) {
      throw StateError(
        'Declaration ${declaration.key} was modified during extraction.',
      );
    }
  }
  if (generatedDeclarations.length != plan.declarations.length) {
    throw StateError(
        'Generated declaration set differs from the original set.');
  }
  for (final method in plan.methods) {
    if (generatedMethods[method.name] != 1) {
      throw StateError(
        'Extension method ${method.name} was not emitted exactly once: '
        '${generatedMethods[method.name] ?? 0}.',
      );
    }
    final generatedSource = generatedMethodSources[method.name]!.single;
    final expectedSource = _transformBaseUrl(
      method,
      plan.originalAdminApiSource,
    ).trim();
    if (generatedSource != expectedSource) {
      throw StateError(
        'Extension method ${method.name} differs from its AST-derived output.',
      );
    }
  }
  if (generatedMethods.length != plan.methods.length) {
    throw StateError(
        'Generated extension method set differs from the original set.');
  }

  final mobileApi = parseString(
    content: plan.updatedMobileApiSource,
    path: plan.mobileApiPath.path,
    throwIfDiagnostics: false,
  );
  if (mobileApi.errors.isNotEmpty) {
    throw StateError('Updated mobile_api.dart does not parse.');
  }
  for (final spec in _domains) {
    final directive = "part 'admin/${spec.fileName}';";
    if (!plan.updatedMobileApiSource.contains(directive)) {
      throw StateError('Missing generated part directive $directive.');
    }
  }
}

void _printPlan(_SplitPlan plan) {
  stdout.writeln('Autonomous AST extraction plan:');
  stdout.writeln('  declarations: ${plan.declarations.length}');
  stdout.writeln('  extension methods: ${plan.methods.length}');
  stdout.writeln('  shared file: ${plan.adminApiPath.path}');
  for (final entry in plan.generatedSources.entries) {
    final declarations = plan.declarations
        .where((piece) =>
            entry.key.path.endsWith(_fileNameForDomain(piece.domain)))
        .length;
    final methods = plan.methods
        .where((piece) =>
            entry.key.path.endsWith(_fileNameForDomain(piece.domain)))
        .length;
    stdout.writeln(
      '  ${entry.key.path}: $declarations declarations, $methods methods',
    );
  }
}

String _fileNameForDomain(String domain) {
  if (domain == 'shared') return 'mobile_api_admin.dart';
  return _domains.firstWhere((spec) => spec.id == domain).fileName;
}

void _applyPlan(_SplitPlan plan) {
  final originalFiles = <File, String>{
    plan.adminApiPath: plan.existingAdminApiSource,
    plan.mobileApiPath: plan.existingMobileApiSource,
  };
  for (final file in plan.generatedSources.keys) {
    if (file.existsSync()) originalFiles[file] = file.readAsStringSync();
  }

  try {
    plan.adminApiPath.writeAsStringSync(plan.sharedSource);
    for (final entry in plan.generatedSources.entries) {
      entry.key.parent.createSync(recursive: true);
      entry.key.writeAsStringSync(entry.value);
    }
    plan.mobileApiPath.writeAsStringSync(plan.updatedMobileApiSource);
    _verifyWrittenPlan(plan);
  } catch (error) {
    _restoreFiles(originalFiles, plan.generatedSources.keys);
    rethrow;
  }
}

void _verifyWrittenPlan(_SplitPlan plan) {
  if (plan.adminApiPath.readAsStringSync() != plan.sharedSource) {
    throw StateError(
        'The shared admin API file differs from the verified output.');
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
          'Generated file differs from the verified output: ${entry.key.path}.');
    }
  }
  _verifyPlan(plan);
}

void _restoreFiles(Map<File, String> originals, Iterable<File> generatedFiles) {
  for (final entry in originals.entries) {
    entry.key.writeAsStringSync(entry.value);
  }
  for (final file in generatedFiles) {
    if (!originals.containsKey(file) && file.existsSync()) file.deleteSync();
  }
}
