// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'MyTravelPal';

  @override
  String get appTagline => 'Plane die Fahrt, nicht nur das Ziel';

  @override
  String get onboardEyebrowKiller => 'DAS FEHLENDE FEATURE';

  @override
  String get onboardTitleKiller => 'Fahre zur richtigen Zeit los';

  @override
  String get onboardBodyKiller =>
      'Wir analysieren den historischen Verkehr rund um deine gewünschte Abfahrtszeit und zeigen dir das ideale Zeitfenster — manchmal spart 30 Minuten früher fahren 90 Minuten.';

  @override
  String get onboardEyebrowHonest => 'EHRLICHE PLANUNG';

  @override
  String get onboardTitleHonest => 'Alle Kosten im Voraus';

  @override
  String get onboardBodyHonest =>
      'Mautkosten, günstigster Kraftstoff und Ladepunkte entlang der Route, empfohlene Stopps, Hotels und Restaurants im leistbaren Umweg.';

  @override
  String get onboardEyebrowAlerts => 'BLEIB INFORMIERT';

  @override
  String get onboardTitleAlerts => 'Wichtige Warnmeldungen';

  @override
  String get onboardBodyAlerts =>
      'Brände, Streiks, Unwetter, Baustellen — du entscheidest, wann sie erscheinen, und nur wenn sie deine Route betreffen.';

  @override
  String get onboardSkip => 'Überspringen';

  @override
  String get onboardContinue => 'Weiter';

  @override
  String get onboardGetStarted => 'Loslegen';

  @override
  String get onboardFooter =>
      'Kostenlos starten · Premium schaltet den KI-Reiseüberblick frei';

  @override
  String get loginContinueApple => 'Mit Apple fortfahren';

  @override
  String get loginContinueGoogle => 'Mit Google fortfahren';

  @override
  String get loginContinueFacebook => 'Mit Facebook fortfahren';

  @override
  String get loginContinueDemo => 'Als Demo fortfahren';

  @override
  String get loginDivider => 'oder';

  @override
  String get loginTerms =>
      'Indem du fortfährst, akzeptierst du unsere Bedingungen und Datenschutzrichtlinie.';

  @override
  String get loginBusy => 'Anmeldung läuft…';

  @override
  String get planTitle => 'Straßenreise planen';

  @override
  String get planEyebrow => 'DER PLANER';

  @override
  String get planHero => 'Wohin fahren wir\nheute?';

  @override
  String get planIntro =>
      'Wähle zwei Punkte und eine Uhrzeit. Um den Rest kümmern wir uns.';

  @override
  String get planFrom => 'Von';

  @override
  String get planTo => 'Nach';

  @override
  String get planDesiredDeparture => 'Gewünschte Abfahrt';

  @override
  String get planCta => 'Reise planen';

  @override
  String get planCtaBusy => 'Reise wird geplant…';

  @override
  String get planCountriesNote =>
      'Länder werden automatisch aus deiner Route erkannt.';

  @override
  String get planSectionOptional => 'Entlang der Route';

  @override
  String get planOverrideForTrip => 'Für diese Reise überschreiben';

  @override
  String get planOverrideActive => 'Überschreibung aktiv';

  @override
  String get planOverrideClear => 'Zurücksetzen';

  @override
  String get planTooltipDashboard => 'Dashboard';

  @override
  String get planTooltipReport => 'Ereignis melden';

  @override
  String get planTooltipSaved => 'Gespeicherte Reisen';

  @override
  String get planErrorPickEndpoints => 'Wähle einen Startpunkt und ein Ziel.';

  @override
  String get resultBestTimeToLeave => 'BESTE ABFAHRTSZEIT';

  @override
  String get resultTripSavings => 'DEINE ERSPARNIS AUF DIESER REISE';

  @override
  String get resultTimeSavedLabel => 'Zeit gespart';

  @override
  String get resultExtraTimeLabel => 'zusätzliche Zeit';

  @override
  String get resultMoneySavedLabel => 'Geld gespart';

  @override
  String get resultDepartureWindowTitle => 'Abfahrtsfenster';

  @override
  String get resultDepartureWindowDesc =>
      'Gesamtminuten pro möglicher Abfahrtszeit.';

  @override
  String get resultCompareVariantsTitle => 'Vergleiche deine Optionen';

  @override
  String get resultCompareVariantsEyebrow => 'Routenvarianten';

  @override
  String get resultAlertsTitle => 'Meldungen auf deiner Route';

  @override
  String get resultRestStopsTitle => 'Rastplätze';

  @override
  String get resultHotelsTitle => 'Hotels';

  @override
  String get resultRestaurantsTitle => 'Restaurants';

  @override
  String get resultFuelTitle => 'Kraftstoff';

  @override
  String get resultTollAlternativeEyebrow => 'MAUTFREIE ALTERNATIVE';

  @override
  String get resultTollAlternativeWorthIt => 'Lohnt sich';

  @override
  String get resultTollAlternativeMarginal => 'Grenzfall';

  @override
  String get resultShareTooltip => 'Diese Reise teilen';

  @override
  String get resultExplainTooltip => 'Meine Reise erklären (Premium)';

  @override
  String get resultSaveTooltip => 'Reise speichern';

  @override
  String get resultSavedTooltip => 'Gespeichert';

  @override
  String get resultTripSaved => 'Reise gespeichert';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String dashboardGreeting(String name) {
    return 'Hallo, $name';
  }

  @override
  String get dashboardTravelSoFar => 'Deine bisherigen Reisen';

  @override
  String get dashboardTrips => 'Reisen';

  @override
  String get dashboardDistance => 'Distanz';

  @override
  String get dashboardHours => 'Stunden';

  @override
  String get dashboardTimeSaved => 'ZEIT GESPART';

  @override
  String get dashboardMoneySaved => 'GELD GESPART';

  @override
  String get dashboardFuelBudget => 'GESCHÄTZTES KRAFTSTOFFBUDGET';

  @override
  String get dashboardTopSavers => 'Beste Ersparnisse';

  @override
  String get dashboardCountries => 'Länder';

  @override
  String get dashboardSignOut => 'Abmelden';

  @override
  String get profileTitle => 'Reiseprofil';

  @override
  String get profileOverrideTitle => 'Für diese Reise überschreiben';

  @override
  String get profileSave => 'Speichern';

  @override
  String get profileUse => 'Verwenden';

  @override
  String get profileWhoTravelling => 'Wer reist';

  @override
  String get profileTravellers => 'Reisende';

  @override
  String get profileHasKids => 'Mit Kindern';

  @override
  String get profileHasPets => 'Mit Haustieren';

  @override
  String get profileVehicle => 'Fahrzeug';

  @override
  String get profileMealTimes => 'Essenszeiten';

  @override
  String get profileReminders => 'Erinnerungen';

  @override
  String get profilePremiumSection => 'Premium (Demo)';

  @override
  String get profileClearProfile => 'Profil löschen';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonClear => 'Löschen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonRemove => 'Entfernen';

  @override
  String get searchPlaceholderLegacy => 'Stadt suchen…';

  @override
  String get searchNoMatches => 'Keine Treffer.';

  @override
  String get searchStartTyping => 'Mindestens 2 Zeichen eingeben.';

  @override
  String get searchRecent => 'ZULETZT';

  @override
  String get searchUseMyLocation => 'Meinen Standort verwenden';

  @override
  String get locationServiceOff =>
      'Ortungsdienste sind auf diesem Gerät deaktiviert.';

  @override
  String get locationPermissionDenied => 'Standortberechtigung verweigert.';

  @override
  String get locationUnavailable => 'Standort konnte nicht ermittelt werden.';

  @override
  String get favoritesTitle => 'Favoriten';

  @override
  String get favoritesEmptyHotels =>
      'Noch keine Favoriten. Tippe auf den Stern, um ein Hotel zu speichern.';

  @override
  String get favoritesEmptyRestaurants =>
      'Noch keine Favoriten. Tippe auf den Stern, um ein Restaurant zu speichern.';

  @override
  String get favoritesTabHotels => 'Hotels';

  @override
  String get favoritesTabRestaurants => 'Restaurants';

  @override
  String get favoritesTooltipAdd => 'Zu Favoriten hinzufügen';

  @override
  String get favoritesTooltipRemove => 'Aus Favoriten entfernen';

  @override
  String get planTooltipFavorites => 'Favoriten';

  @override
  String get resultBackToPlan => 'Zurück zur Planung';

  @override
  String get alertsAlongYourRoute => 'Warnungen entlang deiner Route';

  @override
  String get alertsAlongYourRouteDesc =>
      'Brände, Streiks, Unwetter, Baustellen, Unfälle, Überschwemmungen, Schnee, Proteste — nach Schwere sortiert.';

  @override
  String get restStopsHint =>
      'Empfohlen alle 2 Std. Fahrt. Kurze Pausen halten dich auf langen Strecken wach.';

  @override
  String get fuelAlongTheRoute => 'Kraftstoff entlang der Route';

  @override
  String get hotelsNearYourRoute => 'Hotels in der Nähe deiner Route';

  @override
  String get restaurantsNearYourRoute => 'Restaurants in der Nähe deiner Route';

  @override
  String get narrativeTitle => 'Reise-Briefing';

  @override
  String get narrativeGenerating => 'Schreibe dein Briefing…';

  @override
  String get narrativeFailed =>
      'Briefing konnte nicht erstellt werden. Versuche es später erneut.';

  @override
  String get narrativeFooter =>
      'Erstellt von Claude — spiegelt möglicherweise keine Echtzeit-Änderungen wider.';

  @override
  String get narrativePremiumBadge => 'Premium';

  @override
  String get shareTripSubject => 'Meine Reise mit MyTravelPal';

  @override
  String get eventReport => 'Ereignis melden';

  @override
  String get eventDescription => 'Beschreibung';

  @override
  String get eventType => 'Typ';

  @override
  String get eventSeverity => 'Schwere';

  @override
  String get eventLocation => 'Ort';

  @override
  String get eventSubmit => 'Senden';

  @override
  String get eventSubmitted => 'Gemeldet.';

  @override
  String get resultStatDistance => 'Distanz';

  @override
  String get resultStatFreeFlow => 'Ohne Stau';

  @override
  String get resultStatTolls => 'Maut';

  @override
  String get resultEyebrowNearRoute => 'Nahe deiner Route';

  @override
  String get resultEyebrowAlongRoute => 'Entlang der Route';

  @override
  String get resultAlerts => 'Warnungen';

  @override
  String get resultRestStops => 'Pausen';

  @override
  String get resultHotels => 'Hotels';

  @override
  String get resultRestaurants => 'Restaurants';

  @override
  String get resultFuel => 'Kraftstoff';

  @override
  String get resultOptimized => 'Für deine Reise optimiert';

  @override
  String get resultOptimizedFuelBudget => 'Geschätzter Kraftstoffbedarf';

  @override
  String get resultCompareTitle => 'Vergleiche deine Optionen';

  @override
  String get resultCompareStraightApprox => 'Luftlinien-Näherung.';

  @override
  String resultSleepAt(String when) {
    return 'Schlafen · $when';
  }

  @override
  String get resultHourlyTollEyebrow => 'STÜNDLICHES MAUT-VERDIKT';

  @override
  String get resultSkipLabel => 'Umfahren';

  @override
  String get resultKeepLabel => 'Benutzen';

  @override
  String get resultSaveExactly => 'Spare ';

  @override
  String get notificationsLeaveSoonTitle => 'Bald losfahren';

  @override
  String get localeSystem => 'System';

  @override
  String get localeMenuTooltip => 'Sprache';

  @override
  String get dashboardCountry => 'Land';

  @override
  String get dashboardNoTripsYet =>
      'Noch keine gespeicherten Reisen. Plane und speichere eine Reise, um Statistiken zu sehen.';

  @override
  String get dashboardStatCards => 'ÜBERSICHT';

  @override
  String get profileVehicleType => 'Fahrzeugtyp';

  @override
  String get profileFuelType => 'Kraftstoffart';

  @override
  String get profileConsumption => 'Verbrauch';

  @override
  String get profileEvRange => 'Elektrische Reichweite';

  @override
  String get profileFuelTank => 'Tank';

  @override
  String get profileBreakfast => 'Frühstück';

  @override
  String get profileLunch => 'Mittagessen';

  @override
  String get profileDinner => 'Abendessen';

  @override
  String get profileStopMinutes => 'Typische Pausendauer';

  @override
  String get profileReminderMinutes => 'Erinnerung vor Abfahrt';

  @override
  String get profilePremiumHint =>
      'Aktiviere, um Premium-Funktionen lokal zu testen.';

  @override
  String get profileNoProfile => 'Noch kein Profil gespeichert.';

  @override
  String get eventPlaceholderDescription =>
      'Kurze Beschreibung dessen, was du gesehen hast';

  @override
  String get eventCurrentLocation => 'Aktueller Standort';

  @override
  String get eventPickOnMap => 'Auf der Karte wählen';

  @override
  String eventLocationCoords(String lat, String lon) {
    return 'Ausgewählt: $lat, $lon';
  }

  @override
  String get narrativeRegenerate => 'Neu generieren';

  @override
  String get narrativeUpgrade => 'Schalte das KI-Briefing mit Premium frei.';

  @override
  String get compareVariantsRecommended => 'Empfohlen';

  @override
  String get compareVariantsFastest => 'Schnellste';

  @override
  String get compareVariantsCheapest => 'Günstigste';

  @override
  String get compareVariantsScenic => 'Landschaftlich';

  @override
  String get compareVariantsAvoidTolls => 'Ohne Maut';

  @override
  String get compareVariantsAvoidMotorways => 'Ohne Autobahn';

  @override
  String get hourlyBestHours => 'Beste Stunden zum Umfahren der Maut';

  @override
  String get hourlyWorstHours => 'Schlechteste Stunden zum Umfahren der Maut';

  @override
  String get partialTollSkipsTitle => 'Mautstelle für Mautstelle';

  @override
  String get partialTollSkipsEyebrow => 'Detail';

  @override
  String get sleepEyebrow => 'ÜBERNACHTUNG';

  @override
  String get sleepNoHotelSuggestion =>
      'Kein Hotel gewählt — siehe Abschnitt Hotels.';

  @override
  String get lunchEyebrow => 'MITTAGSPAUSE';

  @override
  String get dinnerEyebrow => 'ABENDPAUSE';

  @override
  String get breakfastEyebrow => 'FRÜHSTÜCKSPAUSE';

  @override
  String get resultCompareEyebrow => 'Routen-Varianten';

  @override
  String get resultCompareDescription =>
      'Gleicher Start und Ziel — andere Prioritäten. Zeiten ohne Stau.';

  @override
  String get resultVariantDashed => 'Gestrichelt auf der Karte oben';

  @override
  String get resultOptimizedEyebrow => 'Nach deinem Profil';

  @override
  String get resultOptimizedDescription =>
      'Mahlzeiten, Übernachtung und Kraftstoff passend zu deinem Profil.';

  @override
  String get resultSavingsShiftAndSkip =>
      'Durch Abfahrtsverschiebung und Umgehung der Maut.';

  @override
  String get resultSavingsShift =>
      'Durch Verschieben der Abfahrt ins empfohlene Fenster.';

  @override
  String get resultSavingsSkip => 'Durch die mautfreie Alternative.';

  @override
  String get resultSavingsNone =>
      'Noch keine Einsparungen für diese Route identifiziert.';

  @override
  String get resultShift => 'VERSCHIEBUNG';

  @override
  String get resultTraffic => 'VERKEHR';

  @override
  String get resultTotal => 'GESAMT';

  @override
  String resultRestStopNoRestaurant(String km) {
    return 'Pause bei km $km — kein passendes Restaurant.';
  }

  @override
  String resultNoHotelHere(String km) {
    return 'Guter Halt hier (~$km km). Kein passendes Hotel.';
  }

  @override
  String get resultMealFallback => 'Mahlzeit';

  @override
  String get resultHourlyExplainer =>
      'Häufig in Frankreich & Italien: vor einer teuren Mautstelle ausfahren, eine Parallelstraße nehmen, später wieder auffahren — 15-40 min mehr, aber 5-15 € gespart.';

  @override
  String get profileSaved => 'Profil gespeichert';

  @override
  String get profileWhoEyebrow => 'Personen';

  @override
  String get profileKidsSubtitle =>
      'Bevorzugt kinderfreundliche Restaurants und Hotels.';

  @override
  String get profilePetsSubtitle =>
      'Bevorzugt haustierfreundliche Orte, priorisiert Parkplätze.';

  @override
  String get profileVehicleEyebrow => 'Kosten und Parkhinweise';

  @override
  String get profileMealsEyebrow => 'Um Restaurant-Pausen abzugleichen';

  @override
  String get profileRemindersEyebrow => 'Lokale Benachrichtigungen';

  @override
  String get profileNotifyBefore => 'Vor Abfahrt benachrichtigen';

  @override
  String get profileNotifyOff => 'Aus — keine Erinnerung geplant.';

  @override
  String profileNotifyMinutesBefore(int minutes) {
    return '$minutes Minuten vorher';
  }

  @override
  String get profilePremiumEyebrow => 'Lokaler Schalter · keine echte Zahlung';

  @override
  String get profilePremiumBody =>
      'Echtes StoreKit / Play Billing kommt später. Aktiviert Premium vorläufig lokal zur Vorschau.';

  @override
  String get profileSimulatePremium => 'Premium simulieren';

  @override
  String get profileSimulatePremiumSubtitle =>
      'Schaltet KI-Briefing und stündliche Maut-Analyse frei.';

  @override
  String get profileOverrideHeroDesc =>
      'Ändere dein Profil nur für diese Reise — anderes Fahrzeug, andere Reisende oder Essenszeiten, ohne dein gespeichertes Profil zu ändern.';

  @override
  String get profileGlobalHeroDesc =>
      'Einmal einstellen. Jeder Plan nutzt es, um Hotels und Restaurants zu ranken, Kraftstoff zu schätzen und Pausen zu timen.';

  @override
  String get eventPickPlace =>
      'Wähle einen Ort und beschreibe, was du gesehen hast.';

  @override
  String get eventThankYou => 'Meldung gesendet — danke!';

  @override
  String eventCouldNotSubmit(String reason) {
    return 'Konnte nicht senden: $reason';
  }

  @override
  String get eventIntro =>
      'Hilf anderen Fahrern. Meldungen laufen standardmäßig nach 24 Stunden ab.';

  @override
  String get eventWhatHappened => 'Was ist passiert';

  @override
  String get eventWhatHappenedEyebrow => 'Typ';

  @override
  String get eventSeverityInfo => 'Info';

  @override
  String get eventSeverityWarning => 'Warnung';

  @override
  String get eventSeverityCritical => 'Kritisch';

  @override
  String get eventWhere => 'Wo';

  @override
  String get eventWhereEyebrow => 'Nächste Stadt';

  @override
  String get eventDescribeTitle => 'Beschreibe es';

  @override
  String get eventDescribeEyebrow => 'Kurz und nützlich';

  @override
  String get eventDescribeHint => 'z. B. Bäume auf A6 Süd, 2 Spuren gesperrt';

  @override
  String get eventSubmitting => 'Sende…';

  @override
  String get eventSubmitReport => 'Meldung senden';

  @override
  String get narrativeBusy => 'Erstelle dein Briefing…';

  @override
  String get narrativeErrorTitle => 'Konnte Briefing nicht laden';

  @override
  String narrativeGeneratedAt(String when) {
    return 'Erstellt $when';
  }

  @override
  String get narrativeReadAloud => 'Vorlesen';

  @override
  String get narrativeStop => 'Stopp';

  @override
  String get historyTitle => 'Gespeicherte Reisen';

  @override
  String get historyEmptyTitle => 'Noch keine gespeicherten Reisen';

  @override
  String get historyEmptyBody =>
      'Plane eine Reise und tippe auf das Lesezeichen, um sie hier zu speichern.';

  @override
  String get historyPlanCta => 'Reise planen';

  @override
  String historyDeleted(String trip) {
    return 'Gelöscht $trip';
  }

  @override
  String historyReplanFailed(int status) {
    return 'Neu-Planung fehlgeschlagen: $status';
  }

  @override
  String get historyDeleteTooltip => 'Löschen';

  @override
  String historyBestAt(String when) {
    return 'Beste $when';
  }

  @override
  String historyWantedAt(String when) {
    return 'Gewünscht $when';
  }

  @override
  String get searchPlaceholder => 'Stadt, Museum, Ort suchen…';

  @override
  String get placesSectionTitle => 'GESPEICHERTE ORTE';

  @override
  String get placeSaveAsTooltip => 'Als Ort speichern';

  @override
  String get placeSaveDialogTitle => 'Speichern als…';

  @override
  String get placeCustomLabel => 'Bezeichnung';

  @override
  String get placeCustomHint => 'Zuhause, Arbeit, Oma…';

  @override
  String get placePresetHome => 'Zuhause';

  @override
  String get placePresetWork => 'Arbeit';

  @override
  String get placePresetSchool => 'Schule';

  @override
  String get placePresetGym => 'Gym';

  @override
  String placeSavedAs(String label) {
    return 'Als $label gespeichert';
  }

  @override
  String get favoritesTabPlaces => 'Orte';

  @override
  String get favoritesEmptyPlaces =>
      'Noch keine gespeicherten Orte. Tippe auf den Stern eines Ergebnisses zum Speichern.';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsSectionAppearance => 'Darstellung';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsTheme => 'Design';

  @override
  String get settingsSectionUnits => 'Einheiten';

  @override
  String get settingsUnitSystem => 'Einheitensystem';

  @override
  String get settingsUnitsMetric => 'Metrisch';

  @override
  String get settingsUnitsImperial => 'Imperial';

  @override
  String get settingsSectionTrip => 'Reise';

  @override
  String get settingsSectionAbout => 'Info';

  @override
  String get settingsVersion => 'Version';

  @override
  String get planTooltipSettings => 'Einstellungen';

  @override
  String get styleSectionTitle => 'Reisestil';

  @override
  String get styleSectionEyebrow => 'Wie du gerne fährst';

  @override
  String get stylePresetDirect => 'Direkt';

  @override
  String get stylePresetBalanced => 'Ausgewogen';

  @override
  String get stylePresetSlow => 'Gemütlich';

  @override
  String get stylePresetDirectHint =>
      'Durchziehen, kaum Pausen, nie übernachten.';

  @override
  String get stylePresetBalancedHint =>
      'Natürliches Tempo, Pausen wenn es passt.';

  @override
  String get stylePresetSlowHint =>
      'Genieße die Fahrt, großzügige Pausen, teile lange Strecken.';

  @override
  String get styleCustom => 'Benutzerdefiniert';

  @override
  String get styleAdvanced => 'Erweitert';

  @override
  String get stylePaceLabel => 'Tempo';

  @override
  String get stylePacePush => 'Durchziehen';

  @override
  String get stylePaceSteady => 'Normal';

  @override
  String get stylePaceSavour => 'Genießen';

  @override
  String get styleOvernightLabel => 'Übernachtung';

  @override
  String get styleOvernightNever => 'Nie';

  @override
  String get styleOvernightIfNeeded => 'Wenn nötig';

  @override
  String get styleOvernightAlwaysIfLong => 'Lange Reisen teilen';

  @override
  String get styleDailyCapLabel => 'Max. Fahrstunden pro Tag';

  @override
  String get styleBedtimeLabel => 'Schlafenszeit';

  @override
  String get styleWakeLabel => 'Aufstehzeit';

  @override
  String get styleBreakLabel => 'Pausenstil';

  @override
  String get styleBreakMinimal => 'Minimal';

  @override
  String get styleBreakScenic => 'Landschaftlich';

  @override
  String get styleBreakFoodie => 'Kulinarisch';

  @override
  String planStyleChip(String preset, int hours) {
    return '$preset · ${hours}h/Tag';
  }

  @override
  String planStyleChipCustom(int hours) {
    return 'Benutzerdefiniert · ${hours}h/Tag';
  }

  @override
  String get planStyleOverrideTitle => 'Stil für diese Reise';

  @override
  String get planStyleOverrideSubtitle =>
      'Überschreibt dein gespeichertes Profil nur für diesen Plan.';

  @override
  String get planStyleUseSavedProfile => 'Gespeichertes Profil verwenden';

  @override
  String arrivalHintTitle(String hour) {
    return 'Du würdest um $hour:00 ankommen';
  }

  @override
  String arrivalHintBody(String bedtime) {
    return 'Später als deine Schlafenszeit ($bedtime:00). Erwäge eine Übernachtung — Hotels unten.';
  }

  @override
  String get arrivalHintCta => 'Hotels anzeigen';

  @override
  String get vehicleTypeCar => 'Auto';

  @override
  String get vehicleTypeMotorbike => 'Motorrad';

  @override
  String get vehicleTypeVan => 'Transporter';

  @override
  String get vehicleTypeCamper => 'Wohnmobil';

  @override
  String get fuelTypePetrol => 'Benzin';

  @override
  String get fuelTypeDiesel => 'Diesel';

  @override
  String get fuelTypeHybrid => 'Hybrid';

  @override
  String get fuelTypeElectric => 'Elektro';

  @override
  String get fuelTypeLpg => 'Autogas';
}
