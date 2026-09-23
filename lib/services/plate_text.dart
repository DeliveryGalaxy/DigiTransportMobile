import 'package:flutter/services.dart';

const _lookalikes = {
  'Α': 'A', 'Ά': 'A', 'α': 'A', 'ά': 'A',
  'Β': 'B', 'β': 'B',
  'Ε': 'E', 'Έ': 'E', 'ε': 'E', 'έ': 'E',
  'Ζ': 'Z', 'ζ': 'Z',
  'Η': 'H', 'Ή': 'H', 'η': 'H', 'ή': 'H',
  'Ι': 'I', 'Ί': 'I', 'Ϊ': 'I', 'ι': 'I', 'ί': 'I', 'ϊ': 'I', 'ΐ': 'I',
  'Κ': 'K', 'κ': 'K',
  'Μ': 'M', 'μ': 'M',
  'Ν': 'N', 'ν': 'N',
  'Ο': 'O', 'Ό': 'O', 'ο': 'O', 'ό': 'O',
  'Ρ': 'P', 'ρ': 'P',
  'Τ': 'T', 'τ': 'T',
  'Υ': 'Y', 'Ύ': 'Y', 'Ϋ': 'Y', 'υ': 'Y', 'ύ': 'Y', 'ϋ': 'Y', 'ΰ': 'Y',
  'Χ': 'X', 'χ': 'X',
  'А': 'A', 'а': 'A',
  'В': 'B', 'в': 'B',
  'Е': 'E', 'е': 'E',
  'К': 'K', 'к': 'K',
  'М': 'M', 'м': 'M',
  'Н': 'H', 'н': 'H',
  'О': 'O', 'о': 'O',
  'Р': 'P', 'р': 'P',
  'С': 'C', 'с': 'C',
  'Т': 'T', 'т': 'T',
  'У': 'Y', 'у': 'Y',
  'Х': 'X', 'х': 'X',
};

String normalizePlate(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_lookalikes[char] ?? char.toUpperCase());
  }
  return buffer.toString();
}

class PlateTextInputFormatter extends TextInputFormatter {
  const PlateTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (!newValue.composing.isCollapsed) {
      return newValue;
    }
    final text = normalizePlate(newValue.text);
    if (text == newValue.text) {
      return newValue;
    }
    final offset = newValue.selection.end.clamp(0, text.length);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
