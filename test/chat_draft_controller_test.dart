import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/features/chat/state/chat_draft_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ChatDraftController createDraft({
    String endpoint = 'https://erp.example',
    String accountId = 'operator:one',
    String conversationId = 'conversation:one',
    Future<SharedPreferences> Function()? loadPreferences,
  }) {
    final textController = TextEditingController();
    final draft = ChatDraftController(
      textController: textController,
      endpoint: endpoint,
      accountId: accountId,
      conversationId: conversationId,
      loadPreferences: loadPreferences,
    );
    addTearDown(() async {
      draft.dispose();
      await draft.flush();
      textController.dispose();
    });
    return draft;
  }

  test('restores an exact multiline draft and positions the cursor at its end',
      () async {
    final first = createDraft();
    await first.ready;
    first.textController.text = 'Salom\nIkkinchi qator  ';
    await first.flush();
    first.dispose();

    final reopened = createDraft(endpoint: 'https://erp.example/');
    await reopened.ready;
    expect(reopened.textController.text, 'Salom\nIkkinchi qator  ');
    expect(reopened.textController.selection.baseOffset,
        reopened.textController.text.length);
  });

  test('drafts are isolated by endpoint, account, and conversation', () async {
    final first = createDraft();
    await first.ready;
    first.textController.text = 'Private draft';
    await first.flush();

    for (final other in [
      createDraft(endpoint: 'https://other.example'),
      createDraft(accountId: 'operator:two'),
      createDraft(conversationId: 'conversation:two'),
    ]) {
      await other.ready;
      expect(other.textController.text, isEmpty);
    }
  });

  test('late restoration cannot replace text typed and then erased', () async {
    final first = createDraft();
    await first.ready;
    first.textController.text = 'Saved draft';
    await first.flush();
    first.dispose();
    final preferences = Completer<SharedPreferences>();
    final reopened = createDraft(loadPreferences: () => preferences.future);
    reopened.textController.text = 'New draft';
    reopened.textController.clear();
    preferences.complete(await SharedPreferences.getInstance());
    await reopened.ready;
    expect(reopened.textController.text, isEmpty);
    await reopened.flush();
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test('successful send clears only the captured draft', () async {
    final draft = createDraft();
    await draft.ready;
    draft.textController.text = 'Sent message';
    await draft.flush();
    final sent = draft.capture();
    draft.markSent(sent);
    await draft.flush();
    expect(draft.textController.text, isEmpty);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test('typing during a send preserves and persists the new draft', () async {
    final draft = createDraft();
    await draft.ready;
    draft.textController.text = 'First message';
    final sent = draft.capture();
    draft.textController.text = 'Second message';
    draft.markSent(sent);
    await draft.flush();
    expect(draft.textController.text, 'Second message');
    draft.dispose();
    final reopened = createDraft();
    await reopened.ready;
    expect(reopened.textController.text, 'Second message');
  });

  test('retyping identical text during send counts as a new draft', () async {
    final draft = createDraft();
    await draft.ready;
    draft.textController.text = 'Message';
    final sent = draft.capture();
    draft.textController.clear();
    draft.textController.text = 'Message';
    draft.markSent(sent);
    expect(draft.textController.text, 'Message');
  });

  test('cursor movement does not prevent clearing a successfully sent draft',
      () async {
    final draft = createDraft();
    await draft.ready;
    draft.textController.text = 'Message';
    final sent = draft.capture();
    draft.textController.selection = const TextSelection.collapsed(offset: 2);
    draft.markSent(sent);
    expect(draft.textController.text, isEmpty);
  });

  test('immediate reopen waits for the previous pending disposal write',
      () async {
    final preferences = Completer<SharedPreferences>();
    final first = createDraft(loadPreferences: () => preferences.future);
    first.textController.text = 'Leaving immediately';
    first.dispose();
    final reopened = createDraft();
    preferences.complete(await SharedPreferences.getInstance());
    await reopened.ready;
    expect(reopened.textController.text, 'Leaving immediately');
  });

  test('disposing before restoration does not delete a stored draft', () async {
    final first = createDraft();
    await first.ready;
    first.textController.text = 'Retained draft';
    await first.flush();
    first.dispose();
    final preferences = Completer<SharedPreferences>();
    final brieflyOpened =
        createDraft(loadPreferences: () => preferences.future);
    brieflyOpened.dispose();
    preferences.complete(await SharedPreferences.getInstance());
    await brieflyOpened.ready;
    final reopened = createDraft();
    await reopened.ready;
    expect(reopened.textController.text, 'Retained draft');
  });

  test('application background flushes before the debounce delay', () async {
    final draft = createDraft();
    await draft.ready;
    draft.textController.text = 'Background draft';
    draft.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await draft.flush();
    final preferences = await SharedPreferences.getInstance();
    expect(
        jsonDecode(
            preferences.getString(preferences.getKeys().single)!)['text'],
        'Background draft');
  });

  testWidgets('typing is debounced and stores the most recent text',
      (tester) async {
    final draft = createDraft();
    await draft.ready;
    final preferences = await SharedPreferences.getInstance();
    draft.textController.text = 'First';
    await tester.pump(const Duration(milliseconds: 200));
    draft.textController.text = 'Latest';
    await tester.pump(const Duration(milliseconds: 349));
    expect(preferences.getKeys(), isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(
        jsonDecode(
            preferences.getString(preferences.getKeys().single)!)['text'],
        'Latest');
  });

  test('late success after disposal removes the sent persisted draft',
      () async {
    final textController = TextEditingController();
    final draft = ChatDraftController(
      textController: textController,
      endpoint: 'https://erp.example',
      accountId: 'operator:one',
      conversationId: 'conversation:one',
    );
    await draft.ready;
    draft.textController.text = 'Sent while leaving';
    final sent = draft.capture();
    draft.dispose();
    textController.dispose();
    draft.markSent(sent);
    await draft.flush();

    final reopened = createDraft();
    await reopened.ready;
    expect(reopened.textController.text, isEmpty);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test('late success clears an unchanged draft already reopened', () async {
    final draft = createDraft();
    await draft.ready;
    draft.textController.text = 'Already sent';
    final sent = draft.capture();
    draft.dispose();
    final reopened = createDraft();
    await reopened.ready;
    expect(reopened.textController.text, 'Already sent');

    draft.markSent(sent);
    await draft.flush();
    expect(reopened.textController.text, isEmpty);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test('late success preserves newer text entered in a reopened conversation',
      () async {
    final draft = createDraft();
    await draft.ready;
    draft.textController.text = 'First message';
    final sent = draft.capture();
    draft.dispose();
    final reopened = createDraft();
    await reopened.ready;
    reopened.textController.text = 'New message';

    draft.markSent(sent);
    await reopened.flush();
    expect(reopened.textController.text, 'New message');
    reopened.dispose();
    final third = createDraft();
    await third.ready;
    expect(third.textController.text, 'New message');
  });

  test(
      'late success preserves identical text retyped and saved after reopening',
      () async {
    final draft = createDraft();
    await draft.ready;
    draft.textController.text = 'Same message';
    final sent = draft.capture();
    draft.dispose();
    final reopened = createDraft();
    await reopened.ready;
    reopened.textController.clear();
    reopened.textController.text = 'Same message';
    reopened.dispose();

    draft.markSent(sent);
    await draft.flush();
    final third = createDraft();
    await third.ready;
    expect(third.textController.text, 'Same message');
  });

  test('late success cannot restore sent text while reopening is still pending',
      () async {
    final draft = createDraft();
    await draft.ready;
    draft.textController.text = 'Already sent';
    final sent = draft.capture();
    draft.dispose();
    final preferences = Completer<SharedPreferences>();
    final reopened = createDraft(loadPreferences: () => preferences.future);

    draft.markSent(sent);
    preferences.complete(await SharedPreferences.getInstance());
    await reopened.ready;
    await draft.flush();
    expect(reopened.textController.text, isEmpty);
  });

  test('acknowledgment from a different scope cannot clear a draft', () async {
    final first = createDraft();
    final other = createDraft(accountId: 'operator:two');
    await Future.wait([first.ready, other.ready]);
    first.textController.text = 'Message';
    other.textController.text = 'Message';
    final sent = first.capture();
    other.markSent(sent);
    await other.flush();
    expect(first.textController.text, 'Message');
    expect(other.textController.text, 'Message');
    first.dispose();
    first.markSent(sent);
    await first.flush();
    expect(other.textController.text, 'Message');
  });

  test('plain-text drafts migrate without losing their content', () async {
    final first = createDraft();
    await first.ready;
    first.textController.text = 'Find storage key';
    await first.flush();
    first.dispose();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(preferences.getKeys().single, 'Legacy\ndraft');

    final reopened = createDraft();
    await reopened.ready;
    expect(reopened.textController.text, 'Legacy\ndraft');
    final sent = reopened.capture();
    reopened.dispose();
    reopened.markSent(sent);
    await reopened.flush();
    expect(preferences.getKeys(), isEmpty);
  });
}
