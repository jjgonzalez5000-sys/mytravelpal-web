import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../api/models.dart';
import '../design/components.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../storage/saved_trip.dart';
import '../widgets/skeleton.dart';
import 'login_screen.dart';

/// Personal dashboard: aggregates the user's saved trips into a small
/// set of headline stats + a most-visited-countries breakdown. Fully
/// client-side today — when trips move to the cloud, the same view
/// binds to a backend `/v1/dashboard` aggregate.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late Future<List<SavedTrip>> _trips;

  @override
  void initState() {
    super.initState();
    _trips = _loadAndSync();
  }

  Future<List<SavedTrip>> _loadAndSync() async {
    final storage = ref.read(tripStorageProvider);
    await storage.syncFromServer();
    return storage.list();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.dashboardTitle)),
      body: FutureBuilder<List<SavedTrip>>(
        future: _trips,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            // Skeleton dashboard — mimics the eventual header +
            // stat card + savings row + section headers, so the
            // real content lands into the same layout without a
            // jarring reflow.
            return const _DashboardSkeleton();
          }
          final trips = snapshot.data ?? const <SavedTrip>[];
          final stats = _Stats.from(trips);

          return ListView(
            padding: const EdgeInsets.all(Tokens.space20),
            children: [
              if (user != null) ...[
                Text(
                  l.dashboardGreeting(_shortName(user.displayName)),
                  style: t.displaySmall,
                )
                    .animate()
                    .fadeIn(duration: Tokens.motionBase)
                    .moveY(begin: 6, end: 0, curve: Tokens.curveOut),
                Text(
                  user.email,
                  style: t.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: Tokens.space24),
              ],
              SectionHeader(
                title: l.dashboardTravelSoFar,
                eyebrow: l.dashboardStatCards,
              ),
              SoftCard(
                padding: const EdgeInsets.all(Tokens.space20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StatTile(
                      label: l.dashboardTrips,
                      value: '${trips.length}',
                      emphasis: true,
                    ),
                    Builder(builder: (context) {
                      final fmt = ref.watch(unitFormatterProvider);
                      return StatTile(
                        label: l.dashboardDistance,
                        value: fmt.distance(stats.totalKm),
                      );
                    }),
                    StatTile(
                      label: l.dashboardHours,
                      value: stats.totalHours.toStringAsFixed(1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Tokens.space16),
              Row(
                children: [
                  Expanded(
                    child: _BigSavingsCard(
                      icon: Icons.access_time,
                      title: l.dashboardTimeSaved,
                      value: _fmtDuration(stats.savedMinutes),
                      subtitle: '×${stats.savingsFromCount}',
                      accent: scheme.primary,
                      background: scheme.primaryContainer,
                      onBackground: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: Tokens.space12),
                  Expanded(
                    child: _BigSavingsCard(
                      icon: Icons.euro,
                      title: l.dashboardMoneySaved,
                      value: '€${stats.savedEur.toStringAsFixed(0)}',
                      subtitle: l.resultTollAlternativeEyebrow.toLowerCase(),
                      accent: scheme.tertiary,
                      background: scheme.tertiaryContainer,
                      onBackground: scheme.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
              if (stats.totalFuelEur > 0) ...[
                const SizedBox(height: Tokens.space16),
                SoftCard(
                  padding: const EdgeInsets.all(Tokens.space20),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius:
                              BorderRadius.circular(Tokens.radiusMd),
                        ),
                        child: Icon(Icons.local_gas_station,
                            color: scheme.onSecondaryContainer),
                      ),
                      const SizedBox(width: Tokens.space16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.dashboardFuelBudget,
                                style: t.labelSmall?.copyWith(
                                  letterSpacing: 1.4,
                                  fontWeight: FontWeight.w700,
                                )),
                            const SizedBox(height: 2),
                            Text(
                              '€${stats.totalFuelEur.toStringAsFixed(0)}',
                              style: t.headlineMedium?.copyWith(
                                color: scheme.onSurface,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            Text('×${stats.fuelTripCount}',
                                style: t.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (stats.topSavers.isNotEmpty) ...[
                const SizedBox(height: Tokens.space24),
                SectionHeader(
                  title: l.dashboardTopSavers,
                  eyebrow: l.dashboardStatCards,
                ),
                SoftCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Tokens.space16, vertical: Tokens.space8,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < stats.topSavers.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, color: scheme.outlineVariant),
                        _TopSaverRow(rank: i + 1, trip: stats.topSavers[i]),
                      ],
                    ],
                  ),
                ),
              ],
              if (stats.countryTop.isNotEmpty) ...[
                const SizedBox(height: Tokens.space24),
                SectionHeader(
                  title: l.dashboardCountries,
                  eyebrow: l.dashboardStatCards,
                ),
                SoftCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Tokens.space16, vertical: Tokens.space8,
                  ),
                  child: Column(
                    children: [
                      for (final entry in stats.countryTop)
                        _CountryRow(
                          entry: entry,
                          total: trips.length,
                          savedEur: stats.perCountrySavedEur[entry.key] ?? 0,
                        ),
                    ],
                  ),
                ),
              ],
              if (stats.lastTrip != null) ...[
                const SizedBox(height: Tokens.space24),
                SectionHeader(
                  title: l.planTooltipSaved,
                  eyebrow: l.dashboardStatCards,
                ),
                SoftCard(
                  padding: const EdgeInsets.all(Tokens.space16),
                  child: Text(
                    '${_shortName(stats.lastTrip!.origin.displayName)} '
                    '→ ${_shortName(stats.lastTrip!.destination.displayName)} · '
                    '${DateFormat.yMMMd(l.localeName).format(stats.lastTrip!.savedAt)}',
                    style: t.bodyLarge,
                  ),
                ),
              ],
              if (trips.isEmpty) ...[
                const SizedBox(height: Tokens.space32),
                Text(
                  l.dashboardNoTripsYet,
                  textAlign: TextAlign.center,
                  style: t.bodyMedium,
                ),
              ],
              const SizedBox(height: Tokens.space32),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authProvider.notifier).signOut();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => const LoginScreen(),
                    ),
                    (_) => false,
                  );
                },
                icon: const Icon(Icons.logout, size: 18),
                label: Text(l.dashboardSignOut),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _shortName(String s) => s.split(',').first;

  static String _fmtDuration(double minutes) {
    final abs = minutes.abs();
    final hours = abs ~/ 60;
    final mins = (abs % 60).round();
    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }
}

class _BigSavingsCard extends StatelessWidget {
  const _BigSavingsCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
    required this.background,
    required this.onBackground,
  });
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color accent;
  final Color background;
  final Color onBackground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Tokens.space16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                title,
                style: t.labelSmall?.copyWith(
                  color: accent, letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space8),
          Text(
            value,
            style: t.displaySmall?.copyWith(
              color: onBackground,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: t.bodySmall?.copyWith(color: onBackground),
          ),
        ],
      ),
    );
  }
}

/// Pure aggregation over the list of saved trips. Every stat is a real
/// sum of persisted values (see `SavedTrip`).
class _Stats {
  const _Stats({
    required this.totalKm,
    required this.totalHours,
    required this.savedMinutes,
    required this.savedEur,
    required this.totalFuelEur,
    required this.fuelTripCount,
    required this.savingsFromCount,
    required this.countryTop,
    required this.perCountrySavedEur,
    required this.topSavers,
    required this.lastTrip,
  });

  final double totalKm;
  final double totalHours;
  final double savedMinutes;
  final double savedEur;
  final double totalFuelEur;
  final int fuelTripCount;
  final int savingsFromCount;
  final List<MapEntry<Country, int>> countryTop;
  final Map<Country, double> perCountrySavedEur;
  final List<SavedTrip> topSavers;
  final SavedTrip? lastTrip;

  factory _Stats.from(List<SavedTrip> trips) {
    var km = 0.0;
    var estimated = 0.0;
    var savedMin = 0.0;
    var savedEur = 0.0;
    var fuel = 0.0;
    var fuelCount = 0;
    var savingsCount = 0;
    final counts = <Country, int>{};
    final savedPerCountry = <Country, double>{};
    for (final t in trips) {
      km += t.distanceKm;
      estimated += t.recommendedMinutes;
      savedMin += t.savedMinutesVsDesired;
      savedEur += t.savedEurVsTolls;
      if (t.fuelCostEur > 0) {
        fuel += t.fuelCostEur;
        fuelCount += 1;
      }
      if (t.savedMinutesVsDesired > 0 || t.savedEurVsTolls > 0) {
        savingsCount += 1;
      }
      for (final c in t.countriesCrossed) {
        counts[c] = (counts[c] ?? 0) + 1;
        // Divide toll savings equally across countries crossed — coarse
        // but honest without booth-level attribution.
        savedPerCountry[c] = (savedPerCountry[c] ?? 0) +
            (t.savedEurVsTolls / t.countriesCrossed.length);
      }
    }
    final top = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final lastTrip = trips.isEmpty
        ? null
        : (trips.reduce(
            (a, b) => a.savedAt.isAfter(b.savedAt) ? a : b,
          ));
    // Combined saver score: value both dimensions on the same scale — a
    // minute is worth ~€0.10 (a common time-value-of-money heuristic).
    final topSavers = trips.toList()
      ..sort((a, b) {
        final scoreA = a.savedEurVsTolls + a.savedMinutesVsDesired * 0.1;
        final scoreB = b.savedEurVsTolls + b.savedMinutesVsDesired * 0.1;
        return scoreB.compareTo(scoreA);
      });
    return _Stats(
      totalKm: km,
      totalHours: estimated / 60.0,
      savedMinutes: savedMin,
      savedEur: savedEur,
      totalFuelEur: fuel,
      fuelTripCount: fuelCount,
      savingsFromCount: savingsCount,
      countryTop: top.take(5).toList(),
      perCountrySavedEur: savedPerCountry,
      topSavers:
          topSavers.where((t) => t.savedMinutesVsDesired > 0
              || t.savedEurVsTolls > 0).take(5).toList(),
      lastTrip: lastTrip,
    );
  }
}

class _TopSaverRow extends StatelessWidget {
  const _TopSaverRow({required this.rank, required this.trip});
  final int rank;
  final SavedTrip trip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final origin = trip.origin.displayName.split(',').first;
    final destination = trip.destination.displayName.split(',').first;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.space12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: scheme.primary,
            child: Text('$rank',
                style: t.labelMedium?.copyWith(
                  color: scheme.onPrimary, fontWeight: FontWeight.w700,
                )),
          ),
          const SizedBox(width: Tokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$origin → $destination', style: t.titleSmall),
                Text(
                  '${trip.savedMinutesVsDesired.toStringAsFixed(0)} min · '
                  '€${trip.savedEurVsTolls.toStringAsFixed(0)} ${l.dashboardSaved}',
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Returns the localized country name for the given language code.
/// Falls back to the English `Country.displayName` for unrecognised locales.
String _localizedCountryName(Country c, String languageCode) {
  const Map<String, Map<Country, String>> names = {
    'es': {
      Country.ch: 'Suiza',        Country.fr: 'Francia',       Country.it: 'Italia',
      Country.es: 'España',       Country.no: 'Noruega',       Country.se: 'Suecia',
      Country.dk: 'Dinamarca',    Country.fi: 'Finlandia',     Country.is_: 'Islandia',
      Country.de: 'Alemania',     Country.at: 'Austria',       Country.be: 'Bélgica',
      Country.nl: 'Países Bajos', Country.lu: 'Luxemburgo',    Country.ie: 'Irlanda',
      Country.gb: 'Reino Unido',  Country.pt: 'Portugal',      Country.gr: 'Grecia',
      Country.mt: 'Malta',        Country.cy: 'Chipre',        Country.pl: 'Polonia',
      Country.cz: 'Chequia',      Country.sk: 'Eslovaquia',    Country.hu: 'Hungría',
      Country.si: 'Eslovenia',    Country.hr: 'Croacia',       Country.ro: 'Rumanía',
      Country.bg: 'Bulgaria',     Country.ee: 'Estonia',       Country.lv: 'Letonia',
      Country.lt: 'Lituania',
    },
    'fr': {
      Country.ch: 'Suisse',       Country.fr: 'France',        Country.it: 'Italie',
      Country.es: 'Espagne',      Country.no: 'Norvège',       Country.se: 'Suède',
      Country.dk: 'Danemark',     Country.fi: 'Finlande',      Country.is_: 'Islande',
      Country.de: 'Allemagne',    Country.at: 'Autriche',      Country.be: 'Belgique',
      Country.nl: 'Pays-Bas',     Country.lu: 'Luxembourg',    Country.ie: 'Irlande',
      Country.gb: 'Royaume-Uni',  Country.pt: 'Portugal',      Country.gr: 'Grèce',
      Country.mt: 'Malte',        Country.cy: 'Chypre',        Country.pl: 'Pologne',
      Country.cz: 'Tchéquie',     Country.sk: 'Slovaquie',     Country.hu: 'Hongrie',
      Country.si: 'Slovénie',     Country.hr: 'Croatie',       Country.ro: 'Roumanie',
      Country.bg: 'Bulgarie',     Country.ee: 'Estonie',       Country.lv: 'Lettonie',
      Country.lt: 'Lituanie',
    },
    'de': {
      Country.ch: 'Schweiz',      Country.fr: 'Frankreich',    Country.it: 'Italien',
      Country.es: 'Spanien',      Country.no: 'Norwegen',      Country.se: 'Schweden',
      Country.dk: 'Dänemark',     Country.fi: 'Finnland',      Country.is_: 'Island',
      Country.de: 'Deutschland',  Country.at: 'Österreich',    Country.be: 'Belgien',
      Country.nl: 'Niederlande',  Country.lu: 'Luxemburg',     Country.ie: 'Irland',
      Country.gb: 'Vereinigtes Königreich', Country.pt: 'Portugal', Country.gr: 'Griechenland',
      Country.mt: 'Malta',        Country.cy: 'Zypern',        Country.pl: 'Polen',
      Country.cz: 'Tschechien',   Country.sk: 'Slowakei',      Country.hu: 'Ungarn',
      Country.si: 'Slowenien',    Country.hr: 'Kroatien',      Country.ro: 'Rumänien',
      Country.bg: 'Bulgarien',    Country.ee: 'Estland',       Country.lv: 'Lettland',
      Country.lt: 'Litauen',
    },
    'it': {
      Country.ch: 'Svizzera',     Country.fr: 'Francia',       Country.it: 'Italia',
      Country.es: 'Spagna',       Country.no: 'Norvegia',      Country.se: 'Svezia',
      Country.dk: 'Danimarca',    Country.fi: 'Finlandia',     Country.is_: 'Islanda',
      Country.de: 'Germania',     Country.at: 'Austria',       Country.be: 'Belgio',
      Country.nl: 'Paesi Bassi',  Country.lu: 'Lussemburgo',   Country.ie: 'Irlanda',
      Country.gb: 'Regno Unito',  Country.pt: 'Portogallo',    Country.gr: 'Grecia',
      Country.mt: 'Malta',        Country.cy: 'Cipro',         Country.pl: 'Polonia',
      Country.cz: 'Repubblica Ceca', Country.sk: 'Slovacchia', Country.hu: 'Ungheria',
      Country.si: 'Slovenia',     Country.hr: 'Croazia',       Country.ro: 'Romania',
      Country.bg: 'Bulgaria',     Country.ee: 'Estonia',       Country.lv: 'Lettonia',
      Country.lt: 'Lituania',
    },
    'pt': {
      Country.ch: 'Suíça',        Country.fr: 'França',        Country.it: 'Itália',
      Country.es: 'Espanha',      Country.no: 'Noruega',       Country.se: 'Suécia',
      Country.dk: 'Dinamarca',    Country.fi: 'Finlândia',     Country.is_: 'Islândia',
      Country.de: 'Alemanha',     Country.at: 'Áustria',       Country.be: 'Bélgica',
      Country.nl: 'Países Baixos',Country.lu: 'Luxemburgo',    Country.ie: 'Irlanda',
      Country.gb: 'Reino Unido',  Country.pt: 'Portugal',      Country.gr: 'Grécia',
      Country.mt: 'Malta',        Country.cy: 'Chipre',        Country.pl: 'Polónia',
      Country.cz: 'Chéquia',      Country.sk: 'Eslováquia',    Country.hu: 'Hungria',
      Country.si: 'Eslovénia',    Country.hr: 'Croácia',       Country.ro: 'Roménia',
      Country.bg: 'Bulgária',     Country.ee: 'Estónia',       Country.lv: 'Letónia',
      Country.lt: 'Lituânia',
    },
    'ca': {
      Country.ch: 'Suïssa',       Country.fr: 'França',        Country.it: 'Itàlia',
      Country.es: 'Espanya',      Country.no: 'Noruega',       Country.se: 'Suècia',
      Country.dk: 'Dinamarca',    Country.fi: 'Finlàndia',     Country.is_: 'Islàndia',
      Country.de: 'Alemanya',     Country.at: 'Àustria',       Country.be: 'Bèlgica',
      Country.nl: 'Països Baixos',Country.lu: 'Luxemburg',     Country.ie: 'Irlanda',
      Country.gb: 'Regne Unit',   Country.pt: 'Portugal',      Country.gr: 'Grècia',
      Country.mt: 'Malta',        Country.cy: 'Xipre',         Country.pl: 'Polònia',
      Country.cz: 'Txèquia',      Country.sk: 'Eslovàquia',    Country.hu: 'Hongria',
      Country.si: 'Eslovènia',    Country.hr: 'Croàcia',       Country.ro: 'Romania',
      Country.bg: 'Bulgària',     Country.ee: 'Estònia',       Country.lv: 'Letònia',
      Country.lt: 'Lituània',
    },
  };
  return names[languageCode]?[c] ?? c.displayName;
}

class _CountryRow extends StatelessWidget {
  const _CountryRow({
    required this.entry,
    required this.total,
    required this.savedEur,
  });
  final MapEntry<Country, int> entry;
  final int total;
  final double savedEur;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final fraction = total > 0 ? entry.value / total : 0.0;
    final langCode = Localizations.localeOf(context).languageCode;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.space8),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              _localizedCountryName(entry.key, langCode),
              style: t.titleSmall,
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Tokens.radiusPill),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            ),
          ),
          const SizedBox(width: Tokens.space12),
          SizedBox(
            width: 40,
            child: Text(
              '${entry.value}',
              textAlign: TextAlign.right,
              style: t.bodyMedium,
            ),
          ),
          const SizedBox(width: Tokens.space8),
          SizedBox(
            width: 56,
            child: Text(
              savedEur > 0 ? '€${savedEur.toStringAsFixed(0)}' : '',
              textAlign: TextAlign.right,
              style: t.labelMedium?.copyWith(
                color: scheme.tertiary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder that mimics the shape of the settled dashboard so
/// the eventual FutureBuilder swap doesn't cause a layout jump.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Tokens.space20),
      children: [
        // Greeting line.
        Skeleton(
          width: 220, height: 28,
          borderRadius: BorderRadius.circular(6),
        ),
        const SizedBox(height: 6),
        Skeleton(
          width: 160, height: 14,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: Tokens.space24),
        // Section header.
        Skeleton(
          width: 180, height: 20,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: Tokens.space12),
        // Stat card row.
        Skeleton(
          width: double.infinity, height: 92,
          borderRadius: BorderRadius.circular(Tokens.radiusLg),
        ),
        const SizedBox(height: Tokens.space16),
        // Savings cards row.
        Row(
          children: [
            Expanded(
              child: Skeleton(
                width: double.infinity, height: 120,
                borderRadius: BorderRadius.circular(Tokens.radiusLg),
              ),
            ),
            const SizedBox(width: Tokens.space12),
            Expanded(
              child: Skeleton(
                width: double.infinity, height: 120,
                borderRadius: BorderRadius.circular(Tokens.radiusLg),
              ),
            ),
          ],
        ),
        const SizedBox(height: Tokens.space24),
        // Second section header.
        Skeleton(
          width: 200, height: 20,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: Tokens.space12),
        for (var i = 0; i < 4; i++) ...[
          Row(
            children: [
              const Skeleton(width: 40, height: 40),
              const SizedBox(width: Tokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(
                      width: 200, height: 12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 6),
                    Skeleton(
                      width: 120, height: 10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space12),
        ],
      ],
    );
  }
}
