import 'package:intl/intl.dart';

String formatNumber(int value) =>
    NumberFormat.decimalPattern('vi_VN').format(value);
String formatPrice(int value) => '${formatNumber(value)} ₫';
String formatDate(DateTime value) =>
    DateFormat('dd/MM/yyyy').format(value.toLocal());
String formatDateTime(DateTime value) =>
    DateFormat('dd/MM/yyyy · HH:mm').format(value.toLocal());
