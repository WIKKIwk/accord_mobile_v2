String qolipCodePrefixSuggestion(String firstQolipCode) {
  final code = firstQolipCode.trim();
  if (code.isEmpty || !RegExp(r'[0-9]$').hasMatch(code)) {
    return '';
  }
  return code.substring(0, code.length - 1);
}
