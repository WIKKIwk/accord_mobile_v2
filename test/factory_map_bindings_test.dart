import 'dart:async';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/features/admin/logic/factory_map_bindings.dart';
import 'package:accord_mobile_v2/src/features/admin/logic/factory_map_mapping.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

AdminApparatus machine(
        {String id = 'a', String object = '', int revision = 1}) =>
    AdminApparatus(
        id: 'apparatus:test:$id',
        name: id,
        factoryMapObjectId: object,
        sourceRevision: revision);

Matcher failure(String reason) =>
    isA<FactoryMapBindingFailure>().having((e) => e.reason, 'reason', reason);

void main() {
  late AdminApparatus current;
  late List<AdminApparatus> others;
  late FactoryMapBindings bindings;
  late List<(int, String)> writes;
  Future<AdminApparatus> write(AdminApparatus item, String target) async {
    writes.add((item.sourceRevision, target));
    return current = item.copyWith(
        factoryMapObjectId: target, sourceRevision: item.sourceRevision + 1);
  }

  setUp(() {
    current = machine();
    others = [];
    writes = [];
    bindings = FactoryMapBindings(
        load: () async => [current, ...others],
        read: (_) async => current,
        write: write);
  });
  tearDown(() => bindings.dispose());

  test('attach, unlink, reattach persist and use fresh revisions', () async {
    final observed = current;
    current = current.copyWith(sourceRevision: 5);
    final attached = await bindings.save(observed, ' node:7:instance:2 ');
    expect(attached.factoryMapObjectId, 'node:7');
    final detached = await bindings.save(attached, '');
    expect(detached.factoryMapObjectId, isEmpty);
    final rebound = await bindings.save(detached, 'node:20');
    await bindings.refresh();
    expect(bindings.apparatus.single, rebound);
    expect(writes, [(5, 'node:7'), (6, ''), (7, 'node:20')]);
  });

  test('already applied operations are idempotent without a new write',
      () async {
    final observed = current;
    current = machine(object: 'node:7', revision: 3);
    expect(await bindings.save(observed, 'node:7'), current);
    expect(writes, isEmpty);
  });

  test('does not steal a placement changed since the card was opened',
      () async {
    final observed = machine(object: 'node:7');
    current = machine(object: 'node:20', revision: 2);
    await expectLater(bindings.save(observed, ''), throwsA(failure('changed')));
    expect(bindings.apparatus.single.factoryMapObjectId, 'node:20');
    expect(writes, isEmpty);
  });

  test('canonical duplicate owner is rejected before PATCH', () async {
    others = [machine(id: 'b', object: 'node:7:instance:3')];
    await expectLater(
        bindings.save(current, 'node:7'), throwsA(failure('duplicate')));
    expect(writes, isEmpty);
  });

  test('retired equipment can be unlinked but not attached', () async {
    current = current.copyWith(lifecycleState: 'retired');
    await expectLater(
        bindings.save(current, 'node:7'), throwsA(failure('retired')));
    current = current.copyWith(factoryMapObjectId: 'node:7');
    expect((await bindings.save(current, '')).factoryMapObjectId, isEmpty);
  });

  test('double tap issues only one mutation and refresh cannot race it',
      () async {
    final gate = Completer<AdminApparatus>();
    bindings.dispose();
    bindings = FactoryMapBindings(
        load: () async => [current],
        read: (_) async => current,
        write: (item, target) {
          writes.add((item.sourceRevision, target));
          return gate.future;
        });
    final save = bindings.save(current, 'node:7');
    await Future<void>.delayed(Duration.zero);
    await expectLater(
        bindings.save(current, 'node:20'), throwsA(failure('busy')));
    await bindings.refresh();
    gate.complete(machine(object: 'node:7', revision: 2));
    await save;
    expect(writes.length, 1);
    expect(bindings.saving, isFalse);
    expect(bindings.apparatus.single.factoryMapObjectId, 'node:7');
  });

  test('older GET completion cannot overwrite a committed placement', () async {
    final oldGet = Completer<List<AdminApparatus>>();
    var loads = 0;
    bindings.dispose();
    bindings = FactoryMapBindings(
        load: () => ++loads == 1 ? oldGet.future : Future.value([current]),
        read: (_) async => current,
        write: write);
    final refresh = bindings.refresh();
    await bindings.save(current, 'node:7');
    oldGet.complete([machine()]);
    await refresh;
    expect(bindings.apparatus.single.factoryMapObjectId, 'node:7');
    expect(bindings.loading, isFalse);
  });

  test('lost response is reconciled from server without repeating PATCH',
      () async {
    bindings.dispose();
    bindings = FactoryMapBindings(
        load: () async => [current],
        read: (_) async => current,
        write: (item, target) async {
          await write(item, target);
          throw StateError('connection lost after commit');
        });
    final saved = await bindings.save(current, 'node:7');
    expect(saved.factoryMapObjectId, 'node:7');
    expect(writes.length, 1);
  });

  test('unknown outcome is not reported as success; refresh restores readiness',
      () async {
    var offline = false;
    bindings.dispose();
    bindings = FactoryMapBindings(
        load: () async {
          if (offline) throw StateError('offline');
          return [current];
        },
        read: (_) async => current,
        write: (item, target) async {
          offline = true;
          throw StateError('lost');
        });
    await expectLater(
        bindings.save(current, 'node:7'), throwsA(failure('uncertain')));
    expect(bindings.ready, isFalse);
    expect(bindings.saving, isFalse);
    offline = false;
    await bindings.refresh();
    expect(bindings.ready, isTrue);
    expect(bindings.apparatus.single.factoryMapObjectId, isEmpty);
  });

  test('server ignoring JSON unlink is an error, not optimistic success',
      () async {
    current = machine(object: 'node:7');
    bindings.dispose();
    bindings = FactoryMapBindings(
        load: () async => [current],
        read: (_) async => current,
        write: (_, __) async => current);
    await expectLater(
        bindings.save(current, ''), throwsA(failure('not_applied')));
    expect(bindings.apparatus.single.factoryMapObjectId, 'node:7');
  });

  test('unrelated revision conflict retries once against latest revision',
      () async {
    var attempts = 0;
    bindings.dispose();
    bindings = FactoryMapBindings(
        load: () async => [current],
        read: (_) async => current,
        write: (item, target) async {
          if (++attempts == 1) {
            current = current.copyWith(sourceRevision: 2);
            throw const MobileApiException(
                code: 'apparatus_revision_conflict', message: 'conflict');
          }
          return write(item, target);
        });
    expect((await bindings.save(current, 'node:7')).sourceRevision, 3);
    expect(attempts, 2);
    expect(writes.single.$1, 2);
  });

  test('racing placement change is never overwritten by revision retry',
      () async {
    bindings.dispose();
    bindings = FactoryMapBindings(
        load: () async => [current],
        read: (_) async => current,
        write: (item, target) async {
          writes.add((item.sourceRevision, target));
          current = machine(object: 'node:20', revision: 2);
          throw const MobileApiException(
              code: 'apparatus_revision_conflict', message: 'conflict');
        });
    await expectLater(
        bindings.save(current, 'node:7'), throwsA(failure('changed')));
    expect(writes.length, 1);
  });

  test('permission errors are preserved without retry or optimistic update',
      () async {
    const denied = MobileApiException(
        code: 'forbidden', message: 'Denied', statusCode: 403);
    bindings.dispose();
    bindings = FactoryMapBindings(
        load: () async => [current],
        read: (_) async => current,
        write: (_, __) async => throw denied);
    await expectLater(bindings.save(current, 'node:7'), throwsA(same(denied)));
    expect(bindings.apparatus.single.factoryMapObjectId, isEmpty);
  });

  test('Rezka aliases and duplicate legacy owners are handled consistently',
      () {
    final rezka = machine(object: 'node:20:instance:3');
    expect(resolveFactoryMapApparatus([rezka], 'node:20'), rezka);
    final duplicate = machine(id: 'b', object: 'node:20');
    expect(resolveFactoryMapApparatus([rezka, duplicate], 'node:20'), isNull);
    expect(canonicalFactoryMapObjectId('node:20:instance:8'),
        'node:20:instance:8');
  });
}
