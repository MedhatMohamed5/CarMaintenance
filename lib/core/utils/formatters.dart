import 'package:intl/intl.dart';

/// Number / date formatting helpers.
///
/// Every formatter takes the active app locale so month names and word order
/// follow the UI language.
///
/// **Digits deliberately stay Latin even in Arabic.** `intl` would render
/// Arabic-Indic numerals (٢٩٬٨٠٠) for the `ar` locale, but odometer readings,
/// prices and plate-style figures are read in Latin digits by essentially
/// every Egyptian driver — and mixing the two inside one card is worse than
/// either alone. [_digits] therefore pins numeric patterns to `en` while
/// [_words] keeps month names in the user's language.
class Fmt {
  const Fmt._();

  /// Locale used for anything made of digits.
  static String _digits(String _) => 'en';

  /// Locale used for anything made of words (month names, weekdays).
  static String _words(String locale) => locale;

  static String int0(num v, String locale) =>
      NumberFormat.decimalPattern(_digits(locale)).format(v.round());

  static String dec1(num v, String locale) =>
      NumberFormat('#,##0.0', _digits(locale)).format(v);

  static String dec2(num v, String locale) =>
      NumberFormat('#,##0.00', _digits(locale)).format(v);

  /// Money without a currency symbol — the symbol is rendered separately so it
  /// can be styled (smaller, muted) next to the figure.
  static String money(num v, String locale) => v.abs() >= 1000
      ? NumberFormat('#,##0', _digits(locale)).format(v)
      : NumberFormat('#,##0.##', _digits(locale)).format(v);

  /// Compact money for tight tiles: 12.4K, 1.2M.
  static String moneyCompact(num v, String locale) =>
      NumberFormat.compact(locale: _digits(locale)).format(v);

  static String date(DateTime d, String locale) =>
      DateFormat('dd-MM-yyyy', _digits(locale)).format(d);

  static String dateLong(DateTime d, String locale) =>
      DateFormat('d MMMM yyyy', _words(locale)).format(d);

  static String monthYear(DateTime d, String locale) =>
      DateFormat('MMM yyyy', _words(locale)).format(d);

  static String monthShort(DateTime d, String locale) =>
      DateFormat('MMM', _words(locale)).format(d);
}

/// Date helpers used by the predictors. All comparisons are date-only so a
/// countdown never flickers because of the time component.
class DateX {
  const DateX._();

  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime today() => dayOnly(DateTime.now());

  /// Whole days from today until [target]; negative when [target] is past.
  static int daysUntil(DateTime target) =>
      dayOnly(target).difference(today()).inDays;

  static int daysBetween(DateTime a, DateTime b) =>
      dayOnly(b).difference(dayOnly(a)).inDays;
}
