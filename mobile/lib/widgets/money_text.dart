import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers.dart';
import '../services/currency_service.dart';

/// Renders an EUR amount in the user's preferred currency.
///
/// The backend always emits EUR — this widget applies the local
/// conversion using cached rates from [CurrencyService]. Falls
/// back to EUR while rates are still loading so the UI never
/// blanks out.
class MoneyText extends ConsumerStatefulWidget {
  const MoneyText(
    this.eur, {
    super.key,
    this.style,
    this.decimals,
    this.compact = false,
  });

  final double eur;
  final TextStyle? style;

  /// Explicit decimals. Default: 0 for compact (`€89`) or 2 when
  /// `compact` is false and the number is small.
  final int? decimals;

  /// When true, hides decimals for values ≥ 1 (e.g. "€89" instead
  /// of "€89.00"). Set false when precision matters (fuel prices).
  final bool compact;

  @override
  ConsumerState<MoneyText> createState() => _MoneyTextState();
}

class _MoneyTextState extends ConsumerState<MoneyText> {
  double? _converted;
  String? _lastCode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant MoneyText old) {
    super.didUpdateWidget(old);
    if (old.eur != widget.eur) _refresh();
  }

  Future<void> _refresh() async {
    final code = ref.read(currencyCodeProvider);
    _lastCode = code;
    final converted = await CurrencyService.instance
        .convertFromEur(widget.eur, code);
    if (!mounted) return;
    setState(() => _converted = converted);
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when the currency changes.
    final code = ref.watch(currencyCodeProvider);
    if (code != _lastCode) {
      // Trigger a refresh in the next microtask so we don't
      // setState during build.
      Future.microtask(_refresh);
    }
    final value = _converted ?? widget.eur;
    final symbol = currencySymbol(code);
    final decimals = widget.decimals ??
        (widget.compact && value.abs() >= 1 ? 0 : 2);
    final nf = NumberFormat.decimalPatternDigits(
      locale: Localizations.localeOf(context).toString(),
      decimalDigits: decimals,
    );
    final formatted = nf.format(value);
    // Currency symbol placement: symbol before value for € $ £,
    // after for Nordic kr / Ft / Kč / lei / zł / лв.
    final symbolFirst = const {'€', '\$', '£'}.contains(symbol);
    final text = symbolFirst ? '$symbol$formatted' : '$formatted $symbol';
    return Text(text, style: widget.style);
  }
}
