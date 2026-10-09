import 'package:flutter/services.dart';

/// Arabic-Indic (٠-٩) and Persian (۰-۹) digits as Latin 0-9, and the Arabic
/// decimal separator (٫) as a point.
///
/// Every character maps to exactly one character, so a caret position in the
/// input is still valid in the output.
String toLatinDigits(String input) {
  final out = StringBuffer();
  for (final unit in input.runes) {
    if (unit >= 0x0660 && unit <= 0x0669) {
      out.writeCharCode(0x30 + unit - 0x0660);
    } else if (unit >= 0x06F0 && unit <= 0x06F9) {
      out.writeCharCode(0x30 + unit - 0x06F0);
    } else if (unit == 0x066B) {
      out.write('.');
    } else {
      out.writeCharCode(unit);
    }
  }
  return out.toString();
}

/// Turns digits typed on an Arabic keyboard into Latin ones as they are
/// entered.
///
/// **Numeric fields only accepted 0-9**, so on a keyboard that types ٠-٩ —
/// common on Arabic layouts — a driver pressed the keys and nothing appeared:
/// the filter dropped every one. Converting at the field means everything
/// downstream, every `tryParse` included, keeps reading plain Latin digits.
class LatinDigitsInputFormatter extends TextInputFormatter {
  const LatinDigitsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = toLatinDigits(newValue.text);
    return text == newValue.text ? newValue : newValue.copyWith(text: text);
  }
}
