// ignore_for_file: avoid_setters_without_getters
class HTMLHtmlElement {
  CSSStyleDeclarationX get style => CSSStyleDeclarationX._(Object);

  set innerHTML(Object html) {}

  NodeList querySelectorAll(String selectors) => NodeList();

  Node? querySelector(String selectors) => null;

  void addEventListener(String type, Object listener) {}
}

class NodeList {
  int get length => 0;

  Node? item(int index) => null;
}

class Node {
  String? getAttribute(String name) => null;

  String? get textContent => null;

  void replaceWith(Object node) {}
}

class HTMLScriptElement extends Node {
  String type = '';
  String src = '';
  String text = '';
}

class Event {}

extension type CSSStyleDeclarationX._(Object _) implements Object {
  set width(String width) {}

  set height(String height) {}

  set border(String border) {}

  void setProperty(String property, String value, [String priority = '']) {}
}

extension ToJSX on String {
  String get toJS => '';
}

extension EventListenerToJSX on void Function(Event) {
  Object get toJS => Object();
}
