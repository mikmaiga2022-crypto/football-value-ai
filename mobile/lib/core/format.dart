import 'package:intl/intl.dart';

final NumberFormat _decimal = NumberFormat.decimalPattern('fr');

/// Nombre entier lisible : « 1 250 » — jamais de décimale inventée.
String formatCount(num value) => _decimal.format(value);

/// Pourcentage arrondi à une décimale, virgule française : « 13,1 % ».
String formatPercent(double ratio) =>
    '${_decimal.format((ratio * 1000).round() / 10)} %';
