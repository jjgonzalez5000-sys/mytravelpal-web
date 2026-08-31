import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Currency conversion via [frankfurter.app](https://www.frankfurter.app/) —
/// a free, no-key ECB-backed exchange rate service. All backend
/// prices are in EUR; conversion happens client-side so switching
/// currency is instant.
///
/// Rates are cached for 24 h — official ECB rates only update
/// daily so a fresh fetch per day is enough.
class CurrencyService {
  CurrencyService._();
  static final instance = CurrencyService._();

  static const _url = 'https://api.frankfurter.app/latest?from=EUR';
  static const _cacheKey = 'currency_rates.v1';
  static const _timestampKey = 'currency_rates_at.v1';
  static const _cacheTtl = Duration(hours: 24);

  Map<String, double>? _memoryCache;

  /// Get rates map (target-code → EUR-to-target multiplier).
  /// Uses SharedPreferences cache first; refreshes from the
  /// network when older than 24 h.
  Future<Map<String, double>> rates({http.Client? client}) async {
    if (_memoryCache != null) return _memoryCache!;
    final prefs = await SharedPreferences.getInstance();
    final cachedAt = prefs.getInt(_timestampKey);
    final raw = prefs.getString(_cacheKey);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (raw != null &&
        cachedAt != null &&
        now - cachedAt < _cacheTtl.inMilliseconds) {
      final map = (jsonDecode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble()));
      _memoryCache = map;
      return map;
    }
    // Fetch fresh. On failure, return whatever's in the cache
    // (even stale) so the app degrades gracefully instead of
    // showing raw EUR to a user who picked GBP.
    try {
      final http_ = client ?? http.Client();
      final response = await http_.get(Uri.parse(_url))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rates = (body['rates'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toDouble()));
        // EUR itself isn't in the response — add it as 1.0.
        rates['EUR'] = 1.0;
        await prefs.setString(_cacheKey, jsonEncode(rates));
        await prefs.setInt(_timestampKey, now);
        _memoryCache = rates;
        return rates;
      }
    } catch (_) {
      // Fall through to cached (possibly stale) or empty.
    }
    if (raw != null) {
      final map = (jsonDecode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble()));
      _memoryCache = map;
      return map;
    }
    // Absolute fallback: everything is EUR.
    return {'EUR': 1.0};
  }

  /// Convert an EUR amount to `targetCode`. Falls back to the
  /// input value when rates aren't cached yet.
  Future<double> convertFromEur(double eur, String targetCode) async {
    if (targetCode == 'EUR') return eur;
    final r = await rates();
    final rate = r[targetCode];
    if (rate == null) return eur;
    return eur * rate;
  }

  /// Synchronous convert using the in-memory cache. Returns the
  /// input EUR value when rates haven't loaded yet — the caller
  /// (e.g. an inline string in a build method) can safely render
  /// without awaiting. Since we warm the cache on app boot the
  /// first-render EUR fallback is only ever visible for a split
  /// second on a cold launch.
  double convertFromEurSync(double eur, String targetCode) {
    if (targetCode == 'EUR') return eur;
    final rate = _memoryCache?[targetCode];
    if (rate == null) return eur;
    return eur * rate;
  }
}

/// Convenience: format an EUR amount as `"€89"` (or the user's
/// picked currency + symbol). Sync — uses the in-memory rate
/// cache. Meant for inline strings inside `Text('… ${formatMoney(
/// context, ref, eur)} …')` where a widget swap would break the
/// layout. `decimals` defaults to 0 (compact "€89"); pass 2 for
/// unit prices like "€1.75".
String formatMoney(
  double eur,
  String code, {
  int decimals = 0,
}) {
  final value = CurrencyService.instance.convertFromEurSync(eur, code);
  final symbol = currencySymbol(code);
  final text = value.toStringAsFixed(decimals);
  final symbolFirst = const {'€', '\$', '£'}.contains(symbol);
  return symbolFirst ? '$symbol$text' : '$text $symbol';
}

/// Currency codes MyTravelPal offers as display targets. Ordered
/// by relevance for European road-trippers.
const supportedCurrencyCodes = <String>[
  'EUR', 'GBP', 'CHF', 'SEK', 'NOK', 'DKK',
  'PLN', 'CZK', 'HUF', 'RON', 'BGN', 'HRK',
  'USD',
];

/// Human-readable label per currency.
String currencyLabel(String code) => switch (code) {
      'EUR' => 'Euro (€)',
      'GBP' => 'Libra esterlina (£)',
      'CHF' => 'Franco suizo (CHF)',
      'SEK' => 'Corona sueca (kr)',
      'NOK' => 'Corona noruega (kr)',
      'DKK' => 'Corona danesa (kr)',
      'PLN' => 'Zloty polaco (zł)',
      'CZK' => 'Corona checa (Kč)',
      'HUF' => 'Forinto húngaro (Ft)',
      'RON' => 'Leu rumano (lei)',
      'BGN' => 'Lev búlgaro (лв)',
      'HRK' => 'Kuna croata (kn)',
      'USD' => 'Dólar EEUU (\$)',
      _ => code,
    };

/// Currency symbol for compact display next to numbers.
String currencySymbol(String code) => switch (code) {
      'EUR' => '€',
      'GBP' => '£',
      'CHF' => 'CHF',
      'SEK' || 'NOK' || 'DKK' => 'kr',
      'PLN' => 'zł',
      'CZK' => 'Kč',
      'HUF' => 'Ft',
      'RON' => 'lei',
      'BGN' => 'лв',
      'HRK' => 'kn',
      'USD' => '\$',
      _ => code,
    };
