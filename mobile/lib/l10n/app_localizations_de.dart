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
  String get onboardEyebrowKiller => 'DIE ECHTEN KOSTEN';

  @override
  String get onboardTitleKiller =>
      'Ihr GPS zeigt den Weg.\nWir zeigen die Kosten.';

  @override
  String get onboardBodyKiller =>
      'Maut, Kraftstoff, Hotels und Mahlzeiten berechnet, bevor Sie starten. Keine Überraschungen.';

  @override
  String get onboardEyebrowHonest => 'IHR PROFIL, IHRE REISE';

  @override
  String get onboardTitleHonest =>
      '2 Erwachsene, 1 Kind, Hund.\nParkplatz. 3 Sterne max €€.';

  @override
  String get onboardBodyHonest =>
      'Hotels und Restaurants nach Ihren echten Vorlieben gefiltert. Keine generische Liste — Ihre.';

  @override
  String get onboardEyebrowAlerts => 'ECHTZEIT-WARNUNGEN';

  @override
  String get onboardTitleAlerts => 'Waldbrand 14 km\nvon Ihrer Route.';

  @override
  String get onboardBodyAlerts =>
      'Brände, Stürme, Erdbeben, Straßensperrungen. Nur Ereignisse, die Ihre konkrete Route betreffen.';

  @override
  String get onboardCostFuel => 'Kraftstoff';

  @override
  String get onboardCostTolls => 'Maut';

  @override
  String get onboardCostMeals => 'Mahlzeiten';

  @override
  String get onboardCostHotel => 'Hotel';

  @override
  String get onboardCostTotal => 'GESAMT';

  @override
  String get onboardSavingsTitle => 'Erkannte Einsparungen';

  @override
  String get onboardSavingsToll => 'Mautalternative';

  @override
  String get onboardSavingsFuel => 'Optimale Tankstelle';

  @override
  String get onboardSavingsHotel => 'Bestes Hotel';

  @override
  String get onboardSavingsTotal => 'GESAMT GESPART';

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
  String planHeroPersonal(String name) {
    return 'Hi $name, wohin geht\'s?';
  }

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
  String get planMoreOptions => 'Mehr Optionen';

  @override
  String get planLessOptions => 'Weniger Optionen';

  @override
  String get planRoundTripChip => 'Hin und zurück';

  @override
  String get planLeaveNowFabTitle => 'Jetzt losfahren';

  @override
  String get leaveNowConfirmTitle => 'Jetzt losfahren nach';

  @override
  String leaveNowConfirmBody(Object name) {
    return 'Auf nach $name?';
  }

  @override
  String get leaveNowConfirmCta => 'Los';

  @override
  String get leaveNowConfirmChange => 'Ziel ändern';

  @override
  String get settingsBiometric => 'Biometrische Entsperrung';

  @override
  String get settingsBiometricSub => 'Fingerabdruck oder Gesicht zum Öffnen';

  @override
  String get settingsBiometricUnavailable => 'Auf diesem Gerät nicht verfügbar';

  @override
  String get settingsReplayTutorial => 'Tutorial wiederholen';

  @override
  String get settingsReplayTutorialSub => 'Die Coach-Marks erneut anzeigen';

  @override
  String get settingsReplayTutorialToast =>
      'Tutorial zurückgesetzt. Öffne Plan erneut.';

  @override
  String get settingsColorPreset => 'Farbschema';

  @override
  String get settingsPresetForest => 'Wald';

  @override
  String get settingsPresetSunset => 'Sonnenuntergang';

  @override
  String get settingsPresetOcean => 'Ozean';

  @override
  String get settingsDynamicColor => 'Material You (dynamisch)';

  @override
  String get settingsDynamicColorSub =>
      'Farben ans Hintergrundbild anpassen (Android 12+)';

  @override
  String get settingsOled => 'Reines Schwarz (OLED)';

  @override
  String get settingsOledSub =>
      'Tieferes Schwarz im Dark Mode, spart OLED-Akku';

  @override
  String get parkingSearchTitle => 'Parkplatz finden';

  @override
  String get parkingSearchLabel => 'Wohin gehst du?';

  @override
  String get parkingSearchHint =>
      'Wähle ein Ziel, um Parkplätze in der Nähe zu sehen.';

  @override
  String get parkingRadiusLabel => 'Radius';

  @override
  String get parkingNoResults => 'Keine Parkplätze in diesem Radius.';

  @override
  String get parkingPriceUnknown => 'Preis ?';

  @override
  String get parkingCovered => 'Überdacht';

  @override
  String get parkingFilterKids => 'Kinder';

  @override
  String get parkingFilterDogs => 'Hunde';

  @override
  String get parkingFilterToilets => 'WC';

  @override
  String get parkingFilterFood => 'Essen';

  @override
  String get parkingFilterShowers => 'Duschen';

  @override
  String get parkingFilterEv => 'E-Ladestation';

  @override
  String get parkingFilterFuel => 'Tankstelle';

  @override
  String get parkingFilterWheelchair => 'Barrierefrei';

  @override
  String get parkingFilterRv => 'Wohnmobil';

  @override
  String get parkingFilterTruck => 'LKW';

  @override
  String get planFindParkingCta => 'Parkplatz finden';

  @override
  String get poiFindParking => 'Parkplatz';

  @override
  String get parkingPrefTitle => 'Parkplatz';

  @override
  String get parkingPrefSub => 'Parkplätze in der Nähe des Ziels anzeigen.';

  @override
  String get parkingResultTitle => 'Parkplätze am Ziel';

  @override
  String get inspireTitle => 'Reise-Inspiration';

  @override
  String get inspireHero => 'Beschreib deinen Traum-Roadtrip';

  @override
  String get inspireSub =>
      'Die KI entwirft einen mehrtägigen Plan, den du mit einem Tap in eine echte Route umwandelst.';

  @override
  String get inspireHint =>
      'z. B. Romantische 4-Tage-Fahrt durch die italienischen Seen';

  @override
  String get inspireGenerate => 'Inspiriere mich';

  @override
  String get inspireGenerating => 'Deine Reise entsteht…';

  @override
  String get inspireError =>
      'Die Muse ist offline. Versuch einen anderen Text.';

  @override
  String get inspireResultTitle => 'Vorgeschlagener Itinerar';

  @override
  String inspireDayLabel(Object n) {
    return 'Tag $n';
  }

  @override
  String get inspireBudgetLabel => 'Geschätztes Budget';

  @override
  String get inspireConvertToPlan => 'In echten Plan verwandeln';

  @override
  String get inspireSave => 'Speichern';

  @override
  String get inspireSavedToast =>
      'Idee gespeichert. Findest du unter deinen Inspirationen.';

  @override
  String get inspireRecentTitle => 'Zuletzt';

  @override
  String get inspireHistoryTitle => 'Meine KI-Pläne';

  @override
  String get inspireHistoryEmpty =>
      'Noch keine KI-Pläne. Erstelle einen über den Tab Planen.';

  @override
  String get inspireHistoryDelete => 'Löschen';

  @override
  String get settingsMyAiPlans => 'Meine KI-Pläne';

  @override
  String get settingsMyAiPlansSub => 'Verlauf Trip Inspiration';

  @override
  String get inspireChatTitle => 'Passe den Plan an';

  @override
  String get inspireChatHint =>
      'Ändere etwas: \"Cremona entfernen\", \"Freitagabend losfahren\"…';

  @override
  String get inspireExamplesTitle => 'Oder starte mit einer Idee';

  @override
  String get inspireExample1 => 'Wochenende Loire-Schlösser';

  @override
  String get inspireExample2 => 'Küstenroute Barcelona-Marseille';

  @override
  String get inspireExample3 => '5 Tage Alpen ab Mailand';

  @override
  String get inspireExample4 => 'Nordspanien mit Kindern, keine Autobahn';

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
  String get tabPlan => 'Planen';

  @override
  String get tabCompanion => 'Begleiter';

  @override
  String get tabMyTrips => 'Meine Reisen';

  @override
  String get companionHeroTitle => 'Dein Reisebegleiter';

  @override
  String get companionHeroBody =>
      'Lege deine Bedingungen fest und starte. Die App begleitet dich und empfiehlt Pausen, Essen und Tanken.';

  @override
  String get companionConfigSection => 'KONFIGURATION';

  @override
  String get companionBreakInterval => 'Pausenvorschläge';

  @override
  String get companionSuggestBreak => 'Pause je nach Fahrzeit vorschlagen';

  @override
  String companionBreakHint(String hours) {
    return 'Stopp empfehlen alle $hours h Fahrzeit';
  }

  @override
  String get companionFatigueStopExperimental =>
      'Bei Müdigkeit anhalten (experimentell)';

  @override
  String get companionFatigueStopHint =>
      'Aktuell nur Timer-Signal — löst auch bei Mikro-Pausen aus.';

  @override
  String get companionAlerts => 'Alarmtypen';

  @override
  String get companionAlertCriticalAdverse =>
      'Kritische Vorfälle (Brände, Hochwasser, Beben)';

  @override
  String get companionAlertCriticalAdverseHint =>
      'Empfohlen. Etwas Ernstes in der Nähe — nicht nur Wetter.';

  @override
  String get companionAlertWeather => 'Wetter voraus';

  @override
  String get companionAlertFuel => 'Günstigste Tankstellen entlang der Route';

  @override
  String get companionAlertBorder => 'Grenzüberquerung Info';

  @override
  String get companionAlertToll => 'Maut-Spar-Vorschläge';

  @override
  String get companionAlertHotel => 'Hotels bei Müdigkeit';

  @override
  String get companionStart => 'Begleiter starten';

  @override
  String get companionComingSoon => 'Begleiter-Modus kommt bald!';

  @override
  String get companionDriveTitle => 'Begleiter aktiv';

  @override
  String get companionForegroundBody => 'MyTravelPal verfolgt Ihre Fahrt';

  @override
  String get companionLocationDenied =>
      'Standortberechtigung für den Begleiter erforderlich.';

  @override
  String get companionDriving => 'unterwegs';

  @override
  String get companionAllGood => 'Keine Meldungen — gute Fahrt.';

  @override
  String get companionWeatherRowEmpty => 'Keine Warnungen voraus';

  @override
  String get companionEndTitle => 'Begleiter beenden?';

  @override
  String get companionEndBody =>
      'Die Verfolgung stoppt und aktive Meldungen gehen verloren.';

  @override
  String get companionEndKeep => 'Weiterfahren';

  @override
  String get companionEndConfirm => 'Sitzung beenden';

  @override
  String get emergencyContactsTitle => 'Notfallkontakte';

  @override
  String get emergencyContactsSubtitle => 'SMS bei erkanntem Aufprall';

  @override
  String get emergencyContactsBody =>
      'Bis zu 3 Personen erhalten eine SMS mit deinem Standort, wenn ein Aufprall erkannt wird.';

  @override
  String get emergencyContactsEmpty => 'Noch keine Kontakte.';

  @override
  String get emergencyContactsAdd => 'Kontakt hinzufügen';

  @override
  String get emergencyContactsPickFromDevice => 'Aus Kontakten wählen';

  @override
  String get emergencyContactsPickSearch => 'Kontakte durchsuchen';

  @override
  String get emergencyContactsPermDenied =>
      'Berechtigung verweigert. Manuell hinzufügen möglich.';

  @override
  String get emergencyContactsNoDevice => 'Keine Kontakte mit Telefonnummer.';

  @override
  String get emergencyContactAddTitle => 'Notfallkontakt hinzufügen';

  @override
  String get emergencyContactName => 'Name';

  @override
  String get emergencyContactNameRequired => 'Namen eingeben';

  @override
  String get emergencyContactPhone => 'Telefon (E.164)';

  @override
  String get emergencyContactPhoneRequired => 'Telefon eingeben';

  @override
  String get emergencyContactPhoneInvalid =>
      'Internationales Format: +49171234567';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get sosTitle => 'Möglicher Aufprall erkannt';

  @override
  String sosBody(String g, String speed) {
    return 'Aufprall-Peak ${g}g · Geschwindigkeitsabfall $speed km/h.';
  }

  @override
  String sosCountdown(int seconds) {
    return '${seconds}s';
  }

  @override
  String get sosImOk => 'Mir geht es gut — abbrechen';

  @override
  String get sosCall112 => '112 anrufen';

  @override
  String get sosCancelled => 'Alarm abgebrochen.';

  @override
  String get sosClose => 'Schließen';

  @override
  String get sosNoContacts =>
      'Keine Kontakte konfiguriert. In Einstellungen hinzufügen.';

  @override
  String sosSmsDispatched(int count) {
    return 'SMS bereit für $count Kontakt(e).';
  }

  @override
  String get sosSmsFailed =>
      'SMS konnte nicht geöffnet werden. Rufen Sie manuell an.';

  @override
  String get sosSmsPrefix =>
      'MyTravelPal — möglicher Aufprall erkannt. Mein Standort:';

  @override
  String get weatherForecastTitle => '7-Tage-Vorhersage';

  @override
  String get weatherToday => 'Heute';

  @override
  String get leaveNowTitle => 'Jetzt losfahren mit Begleiter';

  @override
  String get leaveNowSubtitle =>
      'Ziel wählen und los — wir verfolgen und leiten dich.';

  @override
  String get leaveNowSheetTitle => 'Wohin geht\'s?';

  @override
  String get leaveNowPremiumTitle => 'Premium-Funktion';

  @override
  String get leaveNowPremiumBody =>
      '\'Jetzt losfahren\' bündelt den vollständigen Plan mit dem Fahrbegleiter. Verfügbar mit MyTravelPal Premium.';

  @override
  String get leaveNowPremiumDismiss => 'Später';

  @override
  String get leaveNowPremiumCta => '7 Tage kostenlos testen';

  @override
  String get shareCardOption => 'Als Bild teilen';

  @override
  String get shareCardOptionSub => 'Perfekt für Instagram Stories, WhatsApp, X';

  @override
  String get shareLinkOption => 'Als Link teilen';

  @override
  String get shareLinkOptionSub =>
      'Textzusammenfassung + Link zum Wiederöffnen';

  @override
  String get shareToSocial => 'Teilen';

  @override
  String get sharePlanTitle => 'Reise-Link teilen';

  @override
  String get sharePlanSubtitle => 'QR-Code + Link zum Wiedereröffnen des Plans';

  @override
  String get sharePlanCopy => 'Link kopieren';

  @override
  String get sharePlanCopied => 'Link kopiert';

  @override
  String shareLiveHeadline(String city) {
    return 'Unterwegs durch $city';
  }

  @override
  String shareLiveCaption(String city) {
    return 'Unterwegs durch $city mit MyTravelPal 🚗';
  }

  @override
  String get planAddStop => 'Zwischenstopp';

  @override
  String get planStopDwellPassThrough => 'Nur durchfahren';

  @override
  String get planStopDwellOneNight => '1 Nacht';

  @override
  String planStopDwellNights(int n) {
    return '$n Nächte';
  }

  @override
  String planStopDwellHours(int n) {
    return '$n Stunden';
  }

  @override
  String planStopDwellTitle(Object name) {
    return 'Wie lange in $name?';
  }

  @override
  String get planAddStopTitle => 'Neuer Stopp';

  @override
  String planStopLabel(int n) {
    return 'Stopp $n';
  }

  @override
  String get planStopRemove => 'Entfernen';

  @override
  String get settingsCurrency => 'Währung';

  @override
  String get planErrorPickEndpoints => 'Wähle einen Startpunkt und ein Ziel.';

  @override
  String get resultBestTimeToLeave => 'BESTE ABFAHRTSZEIT';

  @override
  String get resultTripSavings => 'DEINE ERSPARNIS AUF DIESER REISE';

  @override
  String get resultSavingsDetected => 'Erkannte Einsparungen';

  @override
  String get resultTollSaving => 'Mautfreie Alternative';

  @override
  String get resultFuelSaving => 'Kraftstoff';

  @override
  String get resultTimeSaving => 'Optimale Abfahrt';

  @override
  String get resultTotalSaving => 'GESAMTERSPARNIS';

  @override
  String resultSavingPct(String pct) {
    return '$pct% weniger';
  }

  @override
  String get resultSavingsSuggestionsTitle => 'Zeit sparen mit diesen Tipps';

  @override
  String get resultSavingsClaimedHint =>
      'Ersparnis erscheint, sobald du das empfohlene Zeitfenster anwendest.';

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
  String get resultSaveChangesTooltip => 'Änderungen speichern';

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
  String get dashboardSaved => 'gespart';

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
  String get profileMealTimes => 'Mahlzeitenplan';

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
  String commonShowNMore(int n) {
    return '$n weitere anzeigen';
  }

  @override
  String get commonShowLess => 'Weniger anzeigen';

  @override
  String planLoadingElapsed(int seconds) {
    return '${seconds}s vergangen';
  }

  @override
  String get planLoadingLongCrossingCountries =>
      'Mautgebühren in den überquerten Ländern werden geprüft…';

  @override
  String get planLoadingLongScanningFuel =>
      'Europäische Kraftstoffpreise entlang deiner Route werden gescannt…';

  @override
  String get planLoadingLongBigTrip =>
      'Lange Fahrten dauern etwas länger — extra Hotel- und Pausendaten werden geladen.';

  @override
  String get planLoadingLongAlmostDone =>
      'Fast fertig — letzter Feinschliff am Itinerar.';

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
      'Brände, Überschwemmungen, Extremwetter, Schnee, Erdbeben, Erdrutsche — nach Schwere sortiert.';

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
  String get shareFormatTitle => 'Teilen als…';

  @override
  String get shareFormatStory => 'Story · 9:16';

  @override
  String get shareFormatStorySub => 'Instagram / TikTok / WhatsApp Stories';

  @override
  String get shareFormatFeed => 'Quadratisch · 1:1';

  @override
  String get shareFormatFeedSub => 'Instagram-Feed, Facebook, LinkedIn';

  @override
  String get shareTitle => 'MyTravelPal — Reiseplan';

  @override
  String shareRouteLine(String km, String hours, String tolls) {
    return '$km km · $hours h freier Fluss · Maut $tolls €';
  }

  @override
  String shareBestTime(String when, String minutes) {
    return 'Beste Abfahrtszeit: $when (insgesamt $minutes min)';
  }

  @override
  String shareTollFreeAlt(String savings, String minutes) {
    return 'Mautfreie Alt.: $savings € gespart für +$minutes min';
  }

  @override
  String shareRefuelHint(
      String cheap, String price, String pricey, String savings) {
    return 'In $cheap tanken (~$price€/L) vor $pricey — ~$savings€/Tank sparen';
  }

  @override
  String get shareHotelsHeader => 'Top-Hotels in Betracht gezogen:';

  @override
  String get shareRestaurantsHeader => 'Top-Restaurants in Betracht gezogen:';

  @override
  String shareHotelLine(String name, String price, String km) {
    return '$name — $price €/Nacht · $km km abseits der Route';
  }

  @override
  String shareRestaurantLine(String name, String price, String km) {
    return '$name — $price €/Mahlzeit · $km km abseits der Route';
  }

  @override
  String get shareOpenInApp => 'In MyTravelPal öffnen:';

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
  String get resultStatPlanned => 'Geplant';

  @override
  String get resultStatTolls => 'Maut';

  @override
  String get resultEyebrowNearRoute => 'Nahe deiner Route';

  @override
  String get resultEyebrowAlongRoute => 'Entlang der Route';

  @override
  String get resultAlerts => 'Warnungen';

  @override
  String get resultRestStops => 'Empfohlene Pausen';

  @override
  String get resultHotels => 'Hotels';

  @override
  String get resultRestaurants => 'Restaurants';

  @override
  String get resultFuel => 'Kraftstoff';

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
  String get mealSlotBreak => 'Pause';

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
  String get partialTollSkipsTitle => 'Maut für Maut · Premium-Optimierung';

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
  String dayTollsHeader(Object amount, int count) {
    return 'Maut heute · $amount € ($count)';
  }

  @override
  String dayTollsSavedSummary(Object amount, int count) {
    return 'Du sparst $amount € beim Auslassen von $count.';
  }

  @override
  String tollHourGoodToSkip(Object hh) {
    return 'Gute Zeit zum Umfahren ($hh:00)';
  }

  @override
  String tollHourAvoidSkip(Object hh) {
    return 'Nicht umfahren — Peak $hh:00';
  }

  @override
  String get partialTollsPerDayHint =>
      'Du kannst sie auch pro Tag im Itinerar wählen ↓';

  @override
  String resultCityHint(Object city) {
    return 'In der Nähe von $city';
  }

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
  String get resultBypassSavingsPrefix => 'Du könntest bis zu';

  @override
  String resultBypassSavingsSuffix(String minutes) {
    return 'mit +$minutes Min. extra sparen';
  }

  @override
  String get resultArrival => 'ANKUNFT';

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
  String get historyReplanNetworkError =>
      'Die Verbindung wurde während der Neuplanung getrennt. Überprüfen Sie das Signal und versuchen Sie es erneut.';

  @override
  String get retryLabel => 'Erneut versuchen';

  @override
  String get historyDeleteTooltip => 'Löschen';

  @override
  String get historyReopenCta => 'Ansehen';

  @override
  String get historyRepeatCta => 'Wiederholen';

  @override
  String historySavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gespeichert',
      one: '1 gespeichert',
    );
    return '$_temp0';
  }

  @override
  String resultFuelCollapsedHint(int count) {
    return 'Die $count günstigsten Tankstellen der Route anzeigen';
  }

  @override
  String resultBestTimeVsFreeFlow(String delta) {
    return '$delta min ggü. freiem Fluss';
  }

  @override
  String resultBestTimeEarlier(int minutes) {
    return '$minutes min früher als Ziel';
  }

  @override
  String resultBestTimeLater(int minutes) {
    return '$minutes min später als Ziel';
  }

  @override
  String resultHeroSavedBadge(String magnitude) {
    return '$magnitude gespart';
  }

  @override
  String get consistencyNeedsReview => 'Reiseplan prüfen';

  @override
  String consistencyNeedsReviewErrors(int errors) {
    return 'Reiseplan prüfen · $errors Fehler';
  }

  @override
  String consistencyNeedsReviewMixed(int errors, int warnings) {
    return 'Reiseplan prüfen · $errors Fehler, $warnings Warnung(en)';
  }

  @override
  String consistencyFuelNoStations(String km) {
    return 'Die Reise ist $km km lang, aber wir sehen momentan keine Tankstellen entlang der Route. Preise und Tank-Vorschläge sind für diesen Abschnitt nicht verfügbar.';
  }

  @override
  String get consistencyFuelNoStationsHint =>
      'Die Daten werden möglicherweise noch geladen. Versuche es in ein paar Minuten erneut oder füge deinen eigenen Stopp per Karten-Tipp hinzu.';

  @override
  String get consistencyFuelRangeExceeded =>
      'Dein Fahrzeug schafft die Strecke nicht mit einer Tankfüllung / Ladung — du musst unterwegs tanken oder laden.';

  @override
  String consistencyMealBeforeDeparture(String slot, String km) {
    return '$slot ist bei km $km vor Reisebeginn geplant. Passe die Zeit der Pause oder der Abfahrt an.';
  }

  @override
  String consistencyMealAfterArrival(String slot, String km) {
    return '$slot ist bei km $km nach der Ankunft geplant. Passe die Zeit der Pause oder das Tempo an.';
  }

  @override
  String consistencyMealImpossibleSpeed(String slot, String km, String kmh) {
    return 'Um $slot bei km $km zu erreichen bräuchte man ~$kmh km/h — unmöglich. Prüfe die Pause.';
  }

  @override
  String consistencyMealSuspiciousSpeed(String slot, String km, String kmh) {
    return 'Um $slot bei km $km zu erreichen sind ~$kmh km/h nötig. Prüfe, ob das realistisch ist.';
  }

  @override
  String consistencyMealTooCloseToArrival(String slot, String km, String mins) {
    return '$slot bei km $km liegt sehr nah an der Ankunft ($mins min davor). Vielleicht besser am Ziel essen.';
  }

  @override
  String consistencySleepBeforeDeparture(String km) {
    return 'Die Übernachtung ist vor der Abfahrt geplant (km $km). Prüfe die Zeit.';
  }

  @override
  String consistencySleepAfterArrival(String km) {
    return 'Die Übernachtung ist nach der Ankunft geplant (km $km). Sie könnte überflüssig sein.';
  }

  @override
  String consistencySleepImpossibleSpeed(String km, String kmh) {
    return 'Die Übernachtung bei km $km erfordert ~$kmh km/h — unmöglich. Prüfe die Etappe.';
  }

  @override
  String consistencySleepSuspiciousSpeed(String km, String kmh) {
    return 'Die Übernachtung bei km $km bedeutet ~$kmh km/h im Schnitt. Prüfe das Tempo.';
  }

  @override
  String get mealSlotBreakfastCap => 'Frühstück';

  @override
  String get mealSlotLunchCap => 'Mittagessen';

  @override
  String get mealSlotDinnerCap => 'Abendessen';

  @override
  String get consistencyHeadsUp => 'Hinweis zu deinem Plan';

  @override
  String consistencyHeadsUpWarnings(int warnings) {
    return 'Hinweis · $warnings Warnungen';
  }

  @override
  String consistencyMoreCount(int count) {
    return '+$count weitere';
  }

  @override
  String get planProfileClearOverride => 'Anpassung zurücksetzen';

  @override
  String get weatherSunny => 'Sonnig';

  @override
  String get weatherPartlyCloudy => 'Teilweise bewölkt';

  @override
  String get weatherCloudy => 'Bewölkt';

  @override
  String get weatherFog => 'Nebel';

  @override
  String get weatherDrizzle => 'Nieselregen';

  @override
  String get weatherRain => 'Regen';

  @override
  String get weatherHeavyRain => 'Starker Regen';

  @override
  String get weatherSnow => 'Schnee';

  @override
  String get weatherHeavySnow => 'Starker Schneefall';

  @override
  String get weatherThunderstorm => 'Gewitter';

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
  String get settingsSectionVehicle => 'Fahrzeug & Route';

  @override
  String get settingsSectionAppearance => 'Darstellung';

  @override
  String get settingsSectionAI => 'KI-Personalisierung';

  @override
  String get notifSoundTitle => 'Alarm-Ton';

  @override
  String get notifSoundDefault => 'Standardton';

  @override
  String get notifSoundDefaultSub =>
      'Verwendet den System-Benachrichtigungston';

  @override
  String get notifSoundSilent => 'Lautlos';

  @override
  String get notifSoundSilentSub => 'Keine Töne für Alarme';

  @override
  String get settingsSectionSafety => 'Kontakte & Sicherheit';

  @override
  String get settingsSectionAccount => 'Konto';

  @override
  String get settingsDensityLabel => 'Dichte';

  @override
  String get settingsDensityComfortable => 'Komfortabel';

  @override
  String get settingsDensityCompact => 'Kompakt';

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
  String get settingsRadarAlerts => 'Blitzerwarnung';

  @override
  String get settingsRadarAlertsSubtitle =>
      'Vibration und Banner, wenn ein Blitzer weniger als 400 m entfernt ist (Essential+).';

  @override
  String get settingsSectionAbout => 'Info';

  @override
  String get settingsSectionData => 'Deine Daten';

  @override
  String get settingsExportData => 'Meine Daten herunterladen';

  @override
  String get settingsExportDataSub =>
      'Erhalte eine JSON-Datei mit allem, was MyTravelPal über dich speichert.';

  @override
  String get settingsExportError =>
      'Export fehlgeschlagen — prüfe deine Verbindung.';

  @override
  String get settingsDeleteAccount => 'Konto löschen';

  @override
  String get settingsDeleteAccountSub =>
      'Entfernt dein Profil, gespeicherte Reisen und Einstellungen dauerhaft.';

  @override
  String get settingsDeleteAccountConfirmTitle => 'Konto löschen?';

  @override
  String get settingsDeleteAccountConfirmBody =>
      'Dies löscht dein Profil und alle gespeicherten Reisen von unseren Servern. Nicht rückgängig zu machen.';

  @override
  String get settingsDeleteAccountCancel => 'Abbrechen';

  @override
  String get settingsDeleteAccountConfirm => 'Endgültig löschen';

  @override
  String get settingsDeleteAccountPartial =>
      'Lokal abgemeldet, aber der Server hat möglicherweise noch Daten. Bei stabiler Verbindung erneut versuchen.';

  @override
  String get settingsDeleteAccountDone => 'Konto gelöscht. Abgemeldet.';

  @override
  String get settingsDeleteAccountInProgress => 'Konto wird gelöscht…';

  @override
  String get settingsSupport => 'Support & Kontakt';

  @override
  String get settingsPrivacyPolicy => 'Datenschutz';

  @override
  String get settingsTerms => 'Nutzungsbedingungen';

  @override
  String get settingsVersion => 'Version';

  @override
  String get planTooltipSettings => 'Einstellungen';

  @override
  String get styleSectionTitle => 'Fahrrhythmus';

  @override
  String get styleSectionEyebrow => 'Wie Sie Ihre Fahrtage organisieren';

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
  String get styleDrivingStartLabel => 'Bevorzugte Startzeit für die Fahrt';

  @override
  String get drivingWindowNightStart => 'Nachtfahrt am Anfang';

  @override
  String get drivingWindowNightEnd => 'Nachtfahrt am Ende';

  @override
  String get dayEditKmNoLimit => 'Max. km: unbegrenzt';

  @override
  String dayEditKmCap(int km) {
    return 'Max. km: $km km';
  }

  @override
  String dayEditSheetTitle(int day) {
    return 'Tag $day anpassen';
  }

  @override
  String get dayEditStartHour => 'Startzeit am Steuer';

  @override
  String dayEditMaxDriving(int hours) {
    return 'Max. Fahrzeit: $hours h (inkl. Pausen)';
  }

  @override
  String get dayExtendKmTitle => 'Sie haben mehr Zeit zur Verfügung';

  @override
  String dayExtendKmBody(String extraKm) {
    return 'Mit diesem Zeitplan könnten Sie +$extraKm km mehr fahren. Tag verlängern oder aktuelle Route behalten?';
  }

  @override
  String get dayExtendKmKeep => 'Aktuelle Route behalten';

  @override
  String dayExtendKmAdjust(String extraKm) {
    return 'Tag verlängern (+$extraKm km)';
  }

  @override
  String get dayReduceKmTitle => 'Fahrzeit reduziert';

  @override
  String dayReduceKmBody(String reducedKm) {
    return 'Mit diesem Zeitplan erreichen Sie ca. $reducedKm km. Möchten Sie das km-Limit anpassen?';
  }

  @override
  String get dayReduceKmKeep => 'Aktuelle km behalten';

  @override
  String dayReduceKmAdjust(String reducedKm) {
    return 'Auf $reducedKm km anpassen';
  }

  @override
  String dayEditEndHour(String time) {
    return 'Fahren endet um $time';
  }

  @override
  String get dayEditPickTime => 'Zeit wählen';

  @override
  String get dayEditEndTimePicker => 'Fahrende um';

  @override
  String get dayEditSave => 'Übernehmen';

  @override
  String get dayEditCancel => 'Abbrechen';

  @override
  String get dayEditReset => 'Zurücksetzen';

  @override
  String get resultReplanning => 'Neu berechnen...';

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

  @override
  String get routeVariantFastest => 'Am schnellsten';

  @override
  String get routeVariantTollFree => 'Mautfrei';

  @override
  String get routeVariantScenic => 'Landschaftlich';

  @override
  String get eventTypeFire => 'Brand';

  @override
  String get eventTypeStrike => 'Streik';

  @override
  String get eventTypeWeather => 'Schlechtes Wetter';

  @override
  String get eventTypeAccident => 'Unfall';

  @override
  String get eventTypeRoadwork => 'Baustelle';

  @override
  String get eventTypeFlood => 'Überschwemmung';

  @override
  String get eventTypeSnow => 'Schnee';

  @override
  String get eventTypeProtest => 'Demonstration';

  @override
  String get eventTypeEarthquake => 'Erdbeben';

  @override
  String get eventTypeLandslide => 'Erdrutsch';

  @override
  String get eventTypeAvalanche => 'Lawine';

  @override
  String get eventTypeClosure => 'Straßensperrung';

  @override
  String get eventTypeHeatwave => 'Hitzewelle';

  @override
  String get eventTypeHeavyRain => 'Starkregen';

  @override
  String get eventTypeHail => 'Hagel';

  @override
  String get eventTypeThunderstorm => 'Gewitter';

  @override
  String get eventTypeHighWind => 'Starker Wind';

  @override
  String get eventTypeDenseFog => 'Dichter Nebel';

  @override
  String get eventTypeFreezingRain => 'Gefrierender Regen';

  @override
  String get eventTypeOther => 'Sonstiges';

  @override
  String tollStretchLabel(int index, int total) {
    return 'Mautabschnitt $index / $total';
  }

  @override
  String tollBoothLabel(int index) {
    return 'Mautstelle $index';
  }

  @override
  String get addedToRouteLabel => 'HINZUGEFÜGT';

  @override
  String get replanWithStops => 'Route mit Stopps neu berechnen';

  @override
  String get addToRouteTooltip => 'Zur Route hinzufügen';

  @override
  String get removeFromRouteTooltip => 'Aus Route entfernen';

  @override
  String addedStopsChip(int count, String minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stopps hinzugefügt · +$minutes Min',
      one: '1 Stopp hinzugefügt · +$minutes Min',
    );
    return '$_temp0';
  }

  @override
  String get addedStopsClear => 'Löschen';

  @override
  String get settingsLicensesAndData => 'Lizenzen & Datenquellen';

  @override
  String get settingsLicensesAndDataSub =>
      'Nennung offener Daten und Bibliotheken';

  @override
  String get attributionsTitle => 'Lizenzen & Daten';

  @override
  String get attributionsIntro =>
      'MyTravelPal nutzt offene Datenquellen und Open-Source-Bibliotheken. Diese Seite nennt jede Quelle, verweist auf die Lizenzen und erfüllt unsere Nennungspflichten.';

  @override
  String get attributionsSectionMap => 'Karte & Geodaten';

  @override
  String get attributionsSectionFuel => 'Kraftstoffpreise';

  @override
  String get attributionsSectionHazards => 'Ereignisse';

  @override
  String get attributionsSectionWeather => 'Wetter';

  @override
  String get attributionsSectionSoftware => 'Softwarebibliotheken';

  @override
  String get attributionsShowLicenses => 'Paket-Lizenzen anzeigen';

  @override
  String get attributionsFailed =>
      'Nennungen konnten nicht geladen werden. Bitte erneut versuchen.';

  @override
  String get fuelPriceUnavailable => 'Preis nicht verfügbar';

  @override
  String get fuelPriceUnavailableHint =>
      'Für dieses Land gibt es noch keinen öffentlichen Preisdatensatz';

  @override
  String get planSectionOptionalEyebrow => 'Optional';

  @override
  String get planOptAlertsTitle =>
      'Bei kritischen Ereignissen auf der Route benachrichtigen';

  @override
  String get planOptAlertsSub =>
      'Brände, Überschwemmungen, Extremwetter und ernste Gefahren im Umkreis von 25 km.';

  @override
  String get planOptTollFreeTitle => 'Mautfreie Alternative zeigen';

  @override
  String get planOptTollFreeSub =>
      'Vergleicht eine Route ohne Maut — gespartes Geld vs. zusätzliche Minuten.';

  @override
  String get planOptHourlyTollTitle => 'Stündliche Maut-Analyse';

  @override
  String get planOptHourlyTollSub =>
      'Wann am Tag es sich wirklich lohnt, Maut zu umgehen (verkehrsabhängig).';

  @override
  String get planOptRouteVariantsTitle => 'Routenvarianten vergleichen';

  @override
  String get planOptRouteVariantsSub =>
      'Am schnellsten vs. mautfrei vs. landschaftlich — alle drei nebeneinander.';

  @override
  String get planOptAvoidMotorwaysTitle => 'Autobahnen vermeiden';

  @override
  String get planOptAvoidMotorwaysSub =>
      'Langsamer und länger, aber ohne Maut und ruhiger.';

  @override
  String get planOptPreferScenicTitle => 'Landschaftlich bevorzugen';

  @override
  String get planOptPreferScenicSub =>
      'Bevorzugt interessantere Straßen. Etwas langsamer.';

  @override
  String get planPremiumBadge => 'Premium';

  @override
  String planProfileTravellers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Reisende',
      one: '1 Reisender',
    );
    return '$_temp0';
  }

  @override
  String get planProfileWithKids => 'Kinder';

  @override
  String get planProfileWithPets => 'Haustiere';

  @override
  String get planProfileOverrideActive => 'ÜBERSCHREIBUNG AKTIV';

  @override
  String get planProfileOverride => 'Für diese Reise überschreiben';

  @override
  String get planProfileOverriding => 'Für diese Reise überschrieben';

  @override
  String get profilePromptSetup => 'Reiseprofil einrichten';

  @override
  String get hotelPrefTitle => 'Hotels in der Nähe der Stopps suchen';

  @override
  String get hotelPrefSubOn =>
      'Zeigt Unterkunftsoptionen in der Nähe jedes Übernachtungspunkts';

  @override
  String get hotelPrefSubOff => 'Aus';

  @override
  String get restaurantPrefTitle => 'Restaurants entlang der Route';

  @override
  String restaurantPrefSubEnabled(int minutes, String band) {
    return 'Bis zu $minutes Min Umweg · $band';
  }

  @override
  String get restaurantPrefSubOff =>
      'Aus. Einschalten, um Restaurants in der Nähe zu sehen.';

  @override
  String prefMaxDetour(int minutes) {
    return 'Max Umweg: $minutes Min';
  }

  @override
  String get prefBandBudget => 'Günstig';

  @override
  String get prefBandMid => 'Mittel';

  @override
  String get prefBandLuxury => 'Luxus';

  @override
  String get prefBandAny => 'Alle';

  @override
  String get mealSlotBreakfast => 'Fürs Frühstück empfohlen';

  @override
  String get mealSlotLunch => 'Fürs Mittagessen empfohlen';

  @override
  String get mealSlotDinner => 'Fürs Abendessen empfohlen';

  @override
  String get mealSlotOther => 'Weitere Restaurants';

  @override
  String poiDistanceKm(String km, String minutes) {
    return '$km km · +$minutes Min Umweg';
  }

  @override
  String fuelSavingsChipCheap(String amount) {
    return '-$amount€/L vs Landesdurchschnitt';
  }

  @override
  String fuelSavingsChipDear(String amount) {
    return '+$amount€/L vs Landesdurchschnitt';
  }

  @override
  String get fuelArbitrageTitle => 'Auf dieser Route smart tanken';

  @override
  String fuelArbitrageBody(String cheap, String cheapPrice, String dear,
      String dearPrice, String savings) {
    return 'Kraftstoff in $cheap kostet ca. $cheapPrice€/L. In $dear sind es ca. $dearPrice€/L. In $cheap volltanken vor der Grenze spart ca. $savings€.';
  }

  @override
  String dayTabLabel(int index) {
    return 'Tag $index';
  }

  @override
  String dayHeaderRange(int index, String fromKm, String toKm) {
    return 'Tag $index · km $fromKm → $toKm';
  }

  @override
  String dayHeaderCity(int index, String from, String to) {
    return 'Tag $index · $from → $to';
  }

  @override
  String dayArrivalMarker(String time) {
    return 'Ankunft am Ziel gegen $time';
  }

  @override
  String daySleepMarker(String time) {
    return 'Fahrtende gegen $time';
  }

  @override
  String dayStartsAt(String time) {
    return 'Abfahrt um $time';
  }

  @override
  String dayDriveWindow(String start, String end) {
    return '$start → $end';
  }

  @override
  String get restStopWhyTitle => 'Warum dieser Halt?';

  @override
  String get restStopWhyKidFriendly => 'Rastplatz mit Kinderbereich';

  @override
  String get restStopWhyPetFriendly => 'Hunde- / Haustierbereich in der Nähe';

  @override
  String get restStopWhyRvFriendly =>
      'Wohnmobil-kompatibel (Sanitär / Entsorgung)';

  @override
  String restStopWhySafety(String hours) {
    return 'Für die Verkehrssicherheit empfohlen: du fährst seit ${hours}h. Die EU-Verordnung 561/2006 empfiehlt eine Pause von mindestens 45 Min nach 4h30 am Steuer.';
  }

  @override
  String get restStopWhyClose => 'Verstanden';

  @override
  String dayMealStopAt(String time, String name) {
    return '🍽 $time · $name';
  }

  @override
  String dayRestStopAt(String time, String label) {
    return '☕ $time · $label';
  }

  @override
  String get restStopFilterAll => 'Alle';

  @override
  String get restStopFilterKidFriendly => 'Kinderfreundlich';

  @override
  String get restStopFilterPetFriendly => 'Haustierfreundlich';

  @override
  String get restStopFilterRvFriendly => 'Wohnmobil';

  @override
  String dayHeaderDwell(int index, String place) {
    return 'Tag $index · $place';
  }

  @override
  String daySleepStay(String place) {
    return 'Aufenthalt in $place';
  }

  @override
  String get nextStopHeroLabel => 'Nächster empfohlener Stopp';

  @override
  String nextStopHeroBody(String slot, String name, String time) {
    return '$slot in $name · gegen $time';
  }

  @override
  String get daySleepHotelsLabel =>
      'Hotels in der Nähe des Übernachtungsstopps';

  @override
  String hotelDistFromStop(String km) {
    return '$km km vom Stopp';
  }

  @override
  String hotelDistFromDestination(String km) {
    return '$km km vom Ziel';
  }

  @override
  String get daySleepHotelsLabelDestination => 'Hotels in der Nähe des Ziels';

  @override
  String get daySleepHotelsEmpty =>
      'Hotels in den Präferenzen aktivieren, um Übernachtungsoptionen zu sehen.';

  @override
  String get daySleepHotelsNotFound =>
      'Keine Hotels in der Nähe dieser Route mit Ihren aktuellen Einstellungen gefunden.';

  @override
  String get noHotelsAdjustPrefs => 'Einstellungen anpassen';

  @override
  String get noRestaurantsAdjustPrefs =>
      'Keine Restaurants mit Ihren aktuellen Einstellungen gefunden.';

  @override
  String get companionAssistantTitle => 'Companion-Assistent';

  @override
  String get settingsAiPersonalisation => 'KI-Personalisierung';

  @override
  String get companionAskHint => 'Etwas fragen…';

  @override
  String get companionSend => 'Senden';

  @override
  String get companionGroupJoin => 'Als Mitfahrer beitreten';

  @override
  String get companionJoin => 'Beitreten';

  @override
  String get resultFuelSavingsTitle => 'Günstiger Kraftstoff auf Ihrer Route';

  @override
  String get daySleepHotelsSearching =>
      'Suche Hotels in der Nähe deines Stopps...';

  @override
  String get enrichmentLoadingTitle => 'Zusatzdaten werden geladen';

  @override
  String get enrichmentChipHotels => 'Hotels';

  @override
  String get enrichmentChipRestaurants => 'Restaurants';

  @override
  String get enrichmentChipFuel => 'Tankstellen';

  @override
  String get enrichmentChipWeather => 'Wetter';

  @override
  String get enrichmentChipAdverse => 'Warnungen';

  @override
  String get enrichPulseHeader => 'Gerade jetzt…';

  @override
  String get enrichPulseHotels =>
      'Suche nach Hotels mit bestem Preis-Stern-Verhältnis';

  @override
  String get enrichPulseRestaurants =>
      'Restaurants nach deinen Vorlieben filtern';

  @override
  String get enrichPulseFuel =>
      'Suche nach den günstigsten Tankstellen auf der Route';

  @override
  String get enrichPulseTolls =>
      'Erkennung vermeidbarer Mautstellen ohne Umweg';

  @override
  String get enrichPulseWindows => 'Vergleich von Abfahrtszeiten nach Verkehr';

  @override
  String get enrichPulseWeather =>
      'Stündliche Vorhersage für 5 Streckenabschnitte';

  @override
  String get enrichPulseAdverse =>
      'Abgleich mit aktiven Bränden und Erdbeben auf deiner Route';

  @override
  String get enrichPulseKids => 'Rastplätze mit Spielplatz in der Nähe';

  @override
  String get enrichPulsePets =>
      'Suche nach Hundeauslauf und tierfreundlichen Stopps';

  @override
  String get enrichPulseCamper =>
      'Wohnmobilstellplätze mit Entsorgung und Sanitär';

  @override
  String enrichPulseVehicleEv(String vehicle, String tank) {
    return 'Ladestopps planen für dein $vehicle ($tank kWh)';
  }

  @override
  String enrichPulseVehicle(String vehicle, String tank) {
    return 'Tank-Plan angepasst an deinen $vehicle ($tank L)';
  }

  @override
  String get restStopsWidenedHint =>
      'Keine Stopps passen zum Filter; wir zeigen die besten dieses Abschnitts.';

  @override
  String get windowsSheetTitle => 'Abfahrtsfenster';

  @override
  String get windowsSheetHint =>
      'Tippe eine Karte, um mit dieser Abfahrt neu zu planen.';

  @override
  String get windowsSheetOpen => 'Stunde für Stunde ansehen';

  @override
  String get windowsBadgeCurrent => 'Aktuell';

  @override
  String get windowsBadgeRecommended => 'Empfohlen';

  @override
  String get windowsMetaDuration => 'Dauer';

  @override
  String get windowsMetaArrival => 'Ankunft';

  @override
  String get windowsMetaTraffic => 'Verkehr';

  @override
  String get trafficLight => 'Leicht';

  @override
  String get trafficMedium => 'Moderat';

  @override
  String get trafficDense => 'Dicht';

  @override
  String get todEarlyMorning => 'Früher Morgen';

  @override
  String get todMorning => 'Morgen';

  @override
  String get todNoon => 'Mittag';

  @override
  String get todAfternoon => 'Nachmittag';

  @override
  String get todNight => 'Nacht';

  @override
  String get restaurantPrefCuisinesLabel => 'Küche';

  @override
  String get cuisineItalian => 'Italienisch';

  @override
  String get cuisineSpanish => 'Spanisch';

  @override
  String get cuisineTapas => 'Tapas';

  @override
  String get cuisineFrench => 'Französisch';

  @override
  String get cuisineMediterranean => 'Mediterran';

  @override
  String get cuisineAsian => 'Asiatisch';

  @override
  String get cuisineIndian => 'Indisch';

  @override
  String get cuisineBurger => 'Burger';

  @override
  String get cuisineSeafood => 'Fisch / Meeresfrüchte';

  @override
  String get cuisineVegetarian => 'Vegetarisch';

  @override
  String get cuisineBbq => 'Grill / BBQ';

  @override
  String get cuisineRegional => 'Regional';

  @override
  String timeWindowSpanLabel(int hours) {
    return '±${hours}h anzeigen';
  }

  @override
  String get timeWindowSpanHelper =>
      'Ziehen, um das Fenster zu erweitern und zu sehen, ob früher oder später fahren mehr Zeit spart.';

  @override
  String get timeWindowTapHint =>
      'Tippe auf einen Balken, um mit dieser Abfahrtszeit neu zu planen.';

  @override
  String get planLoadingRecalculating =>
      'Neuberechnung mit deinen Einstellungen...';

  @override
  String get planLoadingTitle => 'Deine Reise wird geplant';

  @override
  String get planLoadingStepRouting => 'Schnellste Route berechnen…';

  @override
  String get planLoadingStepTraffic =>
      'Verkehr auswerten für die beste Abfahrtszeit…';

  @override
  String get planLoadingStepFuel => 'Aktuelle Kraftstoffpreise abrufen…';

  @override
  String get planLoadingStepHotels =>
      'Hotels in der Nähe der Übernachtungsstopps suchen…';

  @override
  String get planLoadingStepRestaurants =>
      'Restaurants nach Uhrzeit und Küche sortieren…';

  @override
  String get planLoadingStepAlerts =>
      'Brände, Überschwemmungen, Extremwetter und Gefahren scannen…';

  @override
  String get planLoadingStepTolls =>
      'Mautrouten mit mautfreien Alternativen vergleichen…';

  @override
  String get planLoadingStepAlmost =>
      'Fast fertig — alles wird zusammengestellt…';

  @override
  String get planLoadingHelper =>
      'Kann einige Minuten dauern. Handy kann in die Tasche.';

  @override
  String timeWindowApplyLabel(String time) {
    return 'Anwenden · Abfahrt um $time';
  }

  @override
  String get planErrorAuth =>
      'Sitzung abgelaufen. Melde dich erneut an und versuche es nochmal.';

  @override
  String get planErrorPremium =>
      'Diese Route benötigt Premium. Aktiviere es für die stündliche Mautanalyse.';

  @override
  String get planErrorRateLimit =>
      'Zu viele Anfragen in kurzer Zeit. Warte ein paar Sekunden und versuche es erneut.';

  @override
  String planErrorGeneric(int code) {
    return 'Beim Planen ist etwas schiefgelaufen (Code $code). Versuche es erneut oder ändere die Eingaben.';
  }

  @override
  String get planErrorNetwork =>
      'Wir konnten den Server nicht erreichen. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get planErrorRetry => 'Nochmal versuchen';

  @override
  String get emptyAlertsTitle => 'Keine ernsten Gefahren erkannt';

  @override
  String get emptyAlertsBody =>
      'Keine Brände, Überschwemmungen oder ernsten Gefahren auf deinem Korridor gemeldet. Gute Fahrt.';

  @override
  String get emptyHotelsTitle => 'Keine Hotels in Routennähe';

  @override
  String get emptyHotelsBody =>
      'Erweitere den maximalen Umweg oder ändere die Preisklasse.';

  @override
  String get emptyRestaurantsTitle => 'Keine passenden Restaurants';

  @override
  String get emptyRestaurantsBody =>
      'Erweitere den maximalen Umweg oder entferne Küchen-Filter.';

  @override
  String get emptyRestaurantsNotFoundTitle =>
      'No restaurants close to the route';

  @override
  String get emptyRestaurantsNotFoundBody =>
      'The search returned no options. Try widening the max detour in Preferences.';

  @override
  String get emptyFuelNotFoundTitle => 'No fuel data in this area';

  @override
  String get emptyFuelNotFoundBody =>
      'Providers don\'t cover this route. Live prices will appear in areas with official data.';

  @override
  String get onboardEyebrowFuel => 'MAUT UND KRAFTSTOFF';

  @override
  String get onboardTitleFuel => 'Diese Maut umfahren?\nVor Frankreich tanken?';

  @override
  String get onboardBodyFuel =>
      'Wir zeigen, welche Mautstellen nach Uhrzeit das Umfahren lohnen, und welche Station auf Ihrer Route jetzt am günstigsten ist.';

  @override
  String get onboardEyebrowDriving => 'KI-COPILOT · PREMIUM';

  @override
  String get onboardTitleDriving => '\"Hier tanken\noder weiterfahren?\"';

  @override
  String get onboardBodyDriving =>
      'Kennt Ihre Route, Ihren Tank und die nächsten Preise. Antwortet in Sekunden. Funktioniert mit Android Auto. (Premium)';

  @override
  String get onboardEyebrowProfile => 'PERSÖNLICH';

  @override
  String get onboardTitleProfile => 'Fülle dein Profil aus';

  @override
  String get onboardBodyProfile =>
      'Ohne Profil optimieren wir nur die Zeit. Mit Profil berechnen wir echten Sprit, Hotels und Mahlzeiten für dich.';

  @override
  String get onboardTollSkip => 'Umfahren';

  @override
  String get onboardTollSavingsAmt => 'spart €8';

  @override
  String get onboardTollPay => 'Bezahlen';

  @override
  String get onboardTollPeakTime => 'Stoßzeit 08:00-10:00';

  @override
  String get onboardFuelStationsTitle => 'Tankstellen auf deiner Route';

  @override
  String get onboardProfileGroup => '2 Erwachsene + 1 Kind';

  @override
  String get onboardProfilePet => 'Hund';

  @override
  String get onboardProfileParking => 'Parking';

  @override
  String get onboardProfileStars => '3+ Sterne';

  @override
  String get onboardProfileBudget => 'Max. €€';

  @override
  String get onboardCompanionNextStop => 'Nächster Halt';

  @override
  String get onboardCompanionTank => 'Tank';

  @override
  String get onboardAlertFire => 'Waldbrand · km 214 · 14 km von Ihrer Route';

  @override
  String get onboardAlertSevere => 'SCHWER';

  @override
  String get onboardAlertStorm => 'Schweres Unwetter · Girona · in 2 Std.';

  @override
  String get onboardAlertWarning => 'WARNUNG';

  @override
  String get onboardCompanionQuestion => 'Hier tanken oder weiterfahren?';

  @override
  String get onboardCompanionFuelStation => 'Aral · km 387 — 1.52 €/L';

  @override
  String get onboardCompanionFuelAdvice =>
      'Die nächste Station in 58 km kostet 1,79 €/L.\nMit Ihrem aktuellen Tank kommen Sie problemlos hin.';

  @override
  String get onboardFuelStation1 => 'Aral · km 387';

  @override
  String get onboardFuelStation2 => 'BP Autobahn · km 412';

  @override
  String get onboardFuelStation3 => 'Shell A1 · km 445';

  @override
  String get onboardHotelName => 'Hotel Adler ★★★';

  @override
  String get onboardHotelMeta => '€85/Nacht · 0.8 km';

  @override
  String get onboardHotelAttrs => 'Parking ✓  Hunde ✓';

  @override
  String get onboardRestaurantName => 'Zur alten Mühle';

  @override
  String get onboardRestaurantMeta => '€14/Menü · 2 min';

  @override
  String get onboardRestaurantAttrs => 'Terrasse ✓  Hunde ✓';

  @override
  String get multiDaySleepLabel => 'Du übernachtest in';

  @override
  String get multiDaySleepNoHotel =>
      'Übernachtungsstopp — kein Hotel verfügbar';

  @override
  String get resumeTripTitle => 'Fahrt fortsetzen?';

  @override
  String resumeTripBody(String origin, String destination) {
    return 'Wir haben eine laufende Fahrt $origin → $destination erkannt. Dort fortsetzen, wo du aufgehört hast?';
  }

  @override
  String get resumeTripResume => 'Fortsetzen';

  @override
  String get resumeTripDismiss => 'Verwerfen';

  @override
  String get hotelPrefStarsLabel => 'Sterne';

  @override
  String get hotelPrefDestRadiusLabel => 'Radius ab Ziel';

  @override
  String get biometricPromptReason =>
      'Identität bestätigen, um MyTravelPal zu öffnen';

  @override
  String get biometricPromptSettings =>
      'Bestätige, um die biometrische Entsperrung zu aktivieren';

  @override
  String get planDepartureLabel => 'Gewünschte Abfahrt';

  @override
  String get hotelPrefStarsAny => 'Alle';

  @override
  String get hotelPrefParkingTitle => 'Mit Parkplatz';

  @override
  String get hotelPrefParkingSub =>
      'Nur Hotels mit Parkplatz-Tag. Hotels ohne Tag werden ebenfalls angezeigt.';

  @override
  String get hotelFilterParking => 'Parkplatz';

  @override
  String get hotelFilterWifi => 'Gratis-WLAN';

  @override
  String get hotelFilterAccessible => 'Barrierefrei';

  @override
  String get hotelFilterOtherTypes => 'Apartments, Häuser & mehr';

  @override
  String get restaurantFilterVegetarian => 'Vegetarisch';

  @override
  String get restaurantFilterVegan => 'Vegan';

  @override
  String get restaurantFilterGlutenFree => 'Glutenfrei';

  @override
  String get restaurantFilterHalal => 'Halal';

  @override
  String get restaurantFilterKosher => 'Koscher';

  @override
  String get restaurantDietaryLabel => 'Ernährung';

  @override
  String get tollSkipSelectAll => 'Alle auswählen';

  @override
  String get mapShowLabel => 'Karte anzeigen';

  @override
  String get mapHideLabel => 'Karte ausblenden';

  @override
  String get tripCostTitle => 'GESAMTKOSTEN DER REISE';

  @override
  String get tripCostFuel => 'Kraftstoff';

  @override
  String get tripCostTolls => 'Maut';

  @override
  String get tripCostMeals => 'Mahlzeiten';

  @override
  String get tripCostHotel => 'Hotel';

  @override
  String get tripCostTotal => 'Geschätzte Gesamtkosten';

  @override
  String get tripCostNoExpense => 'Keine Ausgaben';

  @override
  String tripCostPerPerson(String amount) {
    return '$amount / Person';
  }

  @override
  String tripCostPerDay(String amount) {
    return '$amount / Tag';
  }

  @override
  String get poiSpotlightRating => 'Bewertung';

  @override
  String get poiSpotlightStars => 'Sterne';

  @override
  String poiSpotlightReviews(String count) {
    return '$count Bewertungen';
  }

  @override
  String get poiSpotlightPricePerNight => 'pro Nacht';

  @override
  String get poiSpotlightPricePerMeal => 'pro Mahlzeit';

  @override
  String get poiSpotlightPricePerL => 'pro Liter';

  @override
  String get poiFeaturesHeading => 'Ausstattung';

  @override
  String get poiMoreInfoLabel => 'Mehr Infos';

  @override
  String get poiMoreInfoHide => 'Ausblenden';

  @override
  String get poiNoExtraInfo =>
      'Keine weiteren OSM-Informationen für diesen Ort.';

  @override
  String poiOpenError(String url) {
    return 'Konnte $url nicht öffnen';
  }

  @override
  String get poiCtaGoogleMaps => 'Google Maps';

  @override
  String get poiCtaTheFork => 'TheFork';

  @override
  String get poiCtaBooking => 'Booking';

  @override
  String get poiCtaAirbnb => 'Airbnb';

  @override
  String get poiCtaCall => 'Anrufen';

  @override
  String get poiCtaWebsite => 'Website';

  @override
  String get poiContactAddress => 'Adresse';

  @override
  String get poiContactPhone => 'Telefon';

  @override
  String get poiContactWebsite => 'Website';

  @override
  String get poiContactHours => 'Öffnungszeiten';

  @override
  String get poiContactCheckin => 'Check-in';

  @override
  String get poiContactCheckout => 'Check-out';

  @override
  String get poiAttr_wifi => 'WLAN';

  @override
  String get poiAttr_parking => 'Parking';

  @override
  String get poiAttr_pool => 'Pool';

  @override
  String get poiAttr_airConditioning => 'Klimaanlage';

  @override
  String get poiAttr_breakfast => 'Frühstück inbegriffen';

  @override
  String get poiAttr_petFriendly => 'Haustiere erlaubt';

  @override
  String get poiAttr_childFriendly => 'Kinderfreundlich';

  @override
  String get poiAttr_wheelchairAccess => 'Rollstuhlgerecht';

  @override
  String get poiAttr_toilets => 'Toiletten';

  @override
  String get poiAttr_restaurant => 'Restaurant';

  @override
  String get poiAttr_bar => 'Bar';

  @override
  String get poiAttr_shop => 'Shop';

  @override
  String get poiAttr_outdoorSeating => 'Außenbereich';

  @override
  String get poiAttr_takeaway => 'Zum Mitnehmen';

  @override
  String get poiAttr_delivery => 'Lieferung';

  @override
  String get poiAttr_creditCards => 'Karten akzeptiert';

  @override
  String get poiAttr_carWash => 'Autowäsche';

  @override
  String get poiAttr_smoking => 'Raucherbereich';

  @override
  String get poiAttr_nonSmoking => 'Nichtraucher';

  @override
  String get poiAttr_elevator => 'Aufzug';

  @override
  String get poiAttr_checkIn => 'Check-in';

  @override
  String get poiAttr_checkOut => 'Check-out';

  @override
  String get poiAttr_dietVegetarian => 'Vegetarisch';

  @override
  String get poiAttr_dietVegan => 'Vegan';

  @override
  String get poiAttr_dietHalal => 'Halal';

  @override
  String get poiAttr_dietKosher => 'Koscher';

  @override
  String get poiAttr_dietGlutenFree => 'Glutenfrei';

  @override
  String get poiAttr_dog => 'Haustiere willkommen';

  @override
  String get poiAttr_brand => 'Marke';

  @override
  String get poiAttr_city => 'Stadt';

  @override
  String get poiAttr_street => 'Straße';

  @override
  String get poiAttr_address => 'Adresse';

  @override
  String get poiAttr_openingHours => 'Öffnungszeiten';

  @override
  String get poiAttr_name => 'Name';

  @override
  String get poiAttr_phone => 'Telefon';

  @override
  String get poiAttr_stars => 'Sterne';

  @override
  String get poiAttr_website => 'Website';

  @override
  String get poiPickerChoose => 'Auswählen';

  @override
  String get poiPickerSelected => 'Ausgewählt';

  @override
  String get poiPickerHotels => 'Alternativen anzeigen';

  @override
  String get poiPickerRestaurants => 'Nahe Restaurants anzeigen';

  @override
  String get addToRouteLabel => 'Zur Route hinzufügen';

  @override
  String get biometricSetupTitle => 'Biometrie aktivieren?';

  @override
  String get biometricSetupBody =>
      'Entsperren Sie MyTravelPal per Fingerabdruck oder Gesicht.';

  @override
  String get biometricSetupEnable => 'Aktivieren';

  @override
  String get biometricSetupSkip => 'Nicht jetzt';

  @override
  String get weatherAlongRouteTitle => 'WETTER AUF IHRER ROUTE';

  @override
  String get weatherNoData => 'Keine Wetterdaten für diese Route verfügbar';

  @override
  String get weatherAllClear => 'Keine Warnungen';

  @override
  String get fuelNotificationTitle => 'Vor der Grenze tanken!';

  @override
  String fuelNotificationBody(
      String cheap, String price, String pricey, String savings) {
    return 'Kraftstoff in $cheap (~$price€/L) vor $pricey — sparen Sie ~$savings€/Tank';
  }

  @override
  String get tutorialSkip => 'Überspringen';

  @override
  String get tutorialOriginTitle => 'Wo starten Sie?';

  @override
  String get tutorialOriginBody =>
      'Tippen Sie hier, um eine Stadt zu suchen, oder verwenden Sie die Standort-Taste, um von Ihrer Position zu starten.';

  @override
  String get tutorialDestinationTitle => 'Wohin geht es?';

  @override
  String get tutorialDestinationBody =>
      'Suchen Sie Ihr Ziel. Wir planen die komplette Route mit Stopps, Hotels und Maut.';

  @override
  String get tutorialPrefsTitle => 'Passen Sie Ihre Reise an';

  @override
  String get tutorialPrefsBody =>
      'Aktivieren Sie Hotels, Restaurants und Warnungen. Legen Sie Ernährung, Sterne und mehr fest.';

  @override
  String get tutorialTimeWindowTitle => 'Wählen Sie die beste Abfahrtszeit';

  @override
  String get tutorialTimeWindowBody =>
      'Tippen Sie auf eine Zeile, um mit dieser Abfahrtszeit neu zu planen. Das Diagramm zeigt den Verkehr pro Stunde.';

  @override
  String get tutorialTollTitle => 'Mautkosten verwalten';

  @override
  String get tutorialTollBody =>
      'Schalten Sie einzelne Mautabschnitte ein oder aus. Die Gesamtersparnis aktualisiert sich in Echtzeit.';

  @override
  String styleDailyCapRecommendedHint(int hours) {
    return 'Für dieses Tempo empfehlen wir $hours h/Tag.';
  }

  @override
  String get aaCoachTitle => 'So öffnest du sie in Android Auto';

  @override
  String get aaCoachStep1 =>
      'Verbinde das Handy per USB mit dem Auto (oder drahtlos, wenn das Autoradio es unterstützt).';

  @override
  String get aaCoachStep2 =>
      'Im Launcher wechsle zur Kategorie \'Point of Interest\' oder \'Apps\'. Sie erscheint NICHT neben Google Maps.';

  @override
  String get aaCoachStep3 =>
      'Tippe auf MyTravelPal. Der Companion zeigt nächsten Stopp, günstigeren Sprit und Ankunft.';

  @override
  String get aaCoachHint =>
      'Beim ersten Start dauert es einige Sekunden. Parke mit freier Sicht zum Himmel für GPS-Empfang.';

  @override
  String get aaCoachDontShowAgain => 'Nicht mehr zeigen';

  @override
  String get aaCoachDone => 'Verstanden';

  @override
  String get batteryWhitelistTitle => 'Verhindere dass Android uns schließt';

  @override
  String get batteryWhitelistBody =>
      'Xiaomi/MIUI, Samsung und andere Hersteller schließen Hintergrund-Apps nach einigen Minuten. Wenn du mit Google Maps navigierst und MyTravelPal beendet wird, verlierst du die Live-Warnungen.';

  @override
  String get batteryWhitelistSteps =>
      'Einstellungen → Apps → MyTravelPal → Akku → Keine Einschränkungen\n(oder \'Nicht optimieren\' je nach Modell)';

  @override
  String get batteryWhitelistDontShowAgain => 'Nicht mehr zeigen';

  @override
  String get batteryWhitelistLater => 'Später';

  @override
  String get batteryWhitelistOpen => 'Hilfe öffnen';

  @override
  String get planRoundTripTitle => 'Hin- und Rückfahrt';

  @override
  String get planRoundTripSubtitle =>
      'Wir planen die Rückfahrt gleichzeitig mit denselben Präferenzen.';

  @override
  String get roundTripLegOutbound => 'HINFAHRT';

  @override
  String get roundTripLegReturn => 'RÜCKFAHRT';

  @override
  String roundTripSwapTo(String leg) {
    return '$leg anzeigen';
  }

  @override
  String get resultStartTrip => 'Fahrt starten';

  @override
  String get resultStartCompanion => 'Fahrbegleiter starten (Premium)';

  @override
  String get companionPreflightTitle => 'Fahrvorbereitung';

  @override
  String get companionPreflightMealWindows => 'Essenszeiten';

  @override
  String get companionPreflightDetourTolerance => 'Max. Umweg';

  @override
  String get companionPreflightMealBudget => 'Essensbudget';

  @override
  String get companionPreflightHotelBudget => 'Übernachtungsbudget';

  @override
  String get companionPreflightSaveToProfile => 'In meinem Profil speichern';

  @override
  String get companionPreflightStart => 'Losfahren';

  @override
  String get companionPreflightBreakfast => 'Frühstück';

  @override
  String get companionPreflightLunch => 'Mittagessen';

  @override
  String get companionPreflightDinner => 'Abendessen';

  @override
  String get navPickerTitle => 'Weiter mit…';

  @override
  String get tripDashboardTitle => 'Unterwegs';

  @override
  String get tripDashboardCenterOnMe => 'Auf meiner Position zentrieren';

  @override
  String get tripDashboardOpenNav => 'Navigation öffnen';

  @override
  String tripDashboardNextStopLabel(String slot) {
    return 'NÄCHSTE $slot';
  }

  @override
  String tripDashboardInMinutes(int n) {
    return 'in $n Min.';
  }

  @override
  String get tripDashboardPermissionDenied =>
      'Standort verweigert. Erteile die Berechtigung, um deine Position auf der Route zu sehen.';

  @override
  String get tripDashboardServiceDisabled =>
      'GPS ist aus. Schalte es ein, um deinen Fortschritt zu verfolgen.';

  @override
  String tripDashboardProgressLine(String done, String total) {
    return '$done / $total km';
  }

  @override
  String tripDashboardEta(String time) {
    return 'Ankunft $time';
  }

  @override
  String get tripDashboardActiveNotifTitle => 'Fahrt läuft';

  @override
  String get tripDashboardActiveNotifBody =>
      'MyTravelPal verfolgt deine Route im Hintergrund.';

  @override
  String tripDashboardForegroundBodyBare(String done, String total) {
    return '$done / $total km gefahren';
  }

  @override
  String tripDashboardForegroundBodyWithStop(
      String done, String total, String name) {
    return '$done / $total km · nächster Stopp: $name';
  }

  @override
  String get tripDashboardSleepStopLabel => 'Hotel';

  @override
  String get alertApproachingStopTitle => 'Stopp naht';

  @override
  String alertApproachingStopBody(String slot, String name, int mins) {
    return '$slot bei $name in etwa $mins Min. Bereite die Ausfahrt vor.';
  }

  @override
  String get alertNewAdverseAheadTitle => 'Neue Meldung auf deiner Route';

  @override
  String alertNewAdverseAheadBody(String type, String km) {
    return '$type in $km km vor dir gemeldet.';
  }

  @override
  String get alertDriftDetectedTitle => 'Du hast die Route verlassen';

  @override
  String alertDriftDetectedBody(String off) {
    return 'Du bist $off m von der geplanten Strecke entfernt. Neu berechnen?';
  }

  @override
  String get alertBehindScheduleTitle => 'Du liegst zurück';

  @override
  String alertBehindScheduleBody(int mins) {
    return 'Du kommst $mins Min. später an als geplant.';
  }

  @override
  String tripDashboardCheaperFuel(String brand, String km, String cts) {
    return '$brand in $km km · spare $cts ct/L';
  }

  @override
  String get resultOptimalDeparture => 'Ihre Abfahrtszeit ist optimal';

  @override
  String shortLastDayWarning(String km) {
    return 'Kurze letzte Etappe ($km km) — Sie könnten heute ankommen, wenn Sie am Vortag weiterfahren.';
  }

  @override
  String get prepareDepartureNow => 'Jetzt losfahren';

  @override
  String get replanNewDepartureTitle => 'Neue Abfahrtszeit wird berechnet…';

  @override
  String get planStopReorderHint => 'Griff halten, um umzuordnen';

  @override
  String get planSwapOriginDestination => 'Umkehren';

  @override
  String get planStopMoveUp => 'Nach oben';

  @override
  String get planStopMoveDown => 'Nach unten';

  @override
  String get recentTripsTitle => 'Letzte Fahrten';

  @override
  String recentTripsSubtitle(int count) {
    return '$count gespeichert — tippen zum Wiederverwenden';
  }

  @override
  String recentTripsSeeAll(int n) {
    return 'Weitere $n Reisen in Meine Reisen anzeigen';
  }

  @override
  String get onRouteTitle => 'Entlang der Route';

  @override
  String get onRouteEmpty => 'Tippen, um Optionen zu wählen';

  @override
  String get exportShareTitle => 'Route teilen';

  @override
  String get exportOpenInMaps => 'In Google Maps öffnen';

  @override
  String get exportOpenInMapsSub => 'Mit hinzugefügten Stopps und Umwegen';

  @override
  String get exportCopyLink => 'Link kopieren';

  @override
  String get exportLinkCopied => 'Link in Zwischenablage kopiert';

  @override
  String get exportShareOs => 'Teilen…';

  @override
  String get exportShareSubject => 'Meine Route auf MyTravelPal';

  @override
  String get importFromMaps => 'Aus Maps importieren';

  @override
  String get importFromMapsTitle => 'Google-Maps-Route importieren';

  @override
  String get importFromMapsHint => 'Google-Maps-Link hier einfügen';

  @override
  String get importFromMapsPaste => 'Einfügen';

  @override
  String get importFromMapsImport => 'Importieren';

  @override
  String get importFromMapsError => 'URL nicht erkannt';

  @override
  String get importFromMapsErrorMalformed =>
      'Ungültige URL — prüfe den Link und versuche es erneut';

  @override
  String get importFromMapsErrorShortlink =>
      'Kurzlink konnte nicht aufgelöst werden — öffne ihn in Maps und kopiere die vollständige URL';

  @override
  String get importFromMapsErrorGeocode =>
      'Orte konnten nicht gefunden werden — versuche eine kürzere Route oder tippe sie manuell ein';

  @override
  String get importFromMapsLoading => 'Link wird analysiert…';

  @override
  String adverseEventsBannerCount(int count) {
    return '$count Warnung(en) auf Ihrer Route';
  }

  @override
  String pricePerMeal(String price) {
    return '$price €/Mahlzeit';
  }

  @override
  String kmFromOrigin(String km) {
    return '$km km vom Start';
  }

  @override
  String get profileVehicleModel => 'Modell';

  @override
  String get profileVehicleModelHint => 'Fahrzeugmodell auswählen';

  @override
  String get profileVehicleModelClear => 'Modell entfernen';

  @override
  String get profileTankLevel => 'Aktueller Tankstand';

  @override
  String get vehiclePickerSearchHint => 'Marke oder Modell suchen';

  @override
  String get vehiclePickerEmpty => 'Kein passendes Modell gefunden';

  @override
  String get vehiclePickerLoadError =>
      'Liste konnte nicht geladen werden. Später erneut versuchen.';

  @override
  String get vehiclePickerCustomOption => 'Benutzerdefiniertes Fahrzeug';

  @override
  String get vehiclePickerCustomOptionSubtitle =>
      'Tankgröße und Verbrauch manuell eingeben';

  @override
  String get vehicleCustomTitle => 'Benutzerdefiniertes Fahrzeug';

  @override
  String get vehicleCustomName => 'Fahrzeugname (optional)';

  @override
  String get vehicleCustomNameHint => 'z.B. Mein SUV';

  @override
  String get vehicleCustomTank => 'Tank (L)';

  @override
  String get vehicleCustomTankEv => 'Akku (kWh)';

  @override
  String get vehicleCustomConsumption => 'Verbrauch (L/100 km)';

  @override
  String get vehicleCustomConsumptionEv => 'Verbrauch (kWh/100 km)';

  @override
  String get vehicleCustomSave => 'Benutzerdefiniert verwenden';

  @override
  String refuelWindowComfortable(String km) {
    return 'Bis km $km tanken (komfortabel)';
  }

  @override
  String refuelWindowCritical(String km) {
    return 'Bis km $km tanken (kritisch)';
  }

  @override
  String get refuelSuggestionTitle => 'Hier tanken und sparen';

  @override
  String refuelSuggestionBody(String station, String km, String price) {
    return '$station · km $km · €$price/L';
  }

  @override
  String refuelSuggestionSavings(String eur) {
    return 'Du sparst $eur €';
  }

  @override
  String savingsFuelRow(String eur) {
    return 'Kraftstoff: $eur €';
  }

  @override
  String get garageTitle => 'Meine Garage';

  @override
  String get garageEmpty => 'Noch keine Fahrzeuge — füge dein erstes hinzu';

  @override
  String get garageAdd => 'Fahrzeug hinzufügen';

  @override
  String get garageEdit => 'Fahrzeug bearbeiten';

  @override
  String get garageDelete => 'Löschen';

  @override
  String get garageCancel => 'Abbrechen';

  @override
  String get garageSave => 'Speichern';

  @override
  String get garageDefaultName => 'Mein Auto';

  @override
  String get garageNameHint => 'Gib ihm einen Namen (z. B. Mein Golf)';

  @override
  String get garageDefaultTankLabel => 'Standard-Tankfüllung';

  @override
  String get garageDefaultChargeLevelLabel => 'Anfänglicher Ladestand';

  @override
  String get garageAddError => 'Speichern fehlgeschlagen. Nochmal versuchen.';

  @override
  String get garageDeleteTitle => 'Fahrzeug löschen?';

  @override
  String garageDeleteBody(String name) {
    return '\"$name\" wird aus deiner Garage entfernt.';
  }

  @override
  String garageSettingsRow(int count) {
    return 'Meine Garage ($count)';
  }

  @override
  String planScreenGarageChip(String name, int pct) {
    return 'Auto: $name · $pct %';
  }

  @override
  String get planScreenGarageChooseVehicle => 'Fahrzeug für diese Fahrt wählen';

  @override
  String get hotelArbitrageTitle => 'Hotels günstiger nebenan';

  @override
  String hotelArbitrageBody(String cheap, String cheapPrice, String dear,
      String dearPrice, String pct, int nights, String savings) {
    final intl.NumberFormat nightsNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String nightsString = nightsNumberFormat.format(nights);

    String _temp0 = intl.Intl.pluralLogic(
      nights,
      locale: localeName,
      other: '$nightsString Nächte',
      one: 'Eine Nacht',
    );
    return 'Diese Nacht liegt in $dear, ~$dearPrice€/Nacht. In $cheap sind es ~$cheapPrice€ ($pct% weniger). $_temp0 verschieben und ~$savings€ sparen.';
  }

  @override
  String get hotelArbitrageMiniHint =>
      'Gleiche Ersparnis, wenn Sie auch diese Nacht nach Süden verschieben';

  @override
  String get whatsNewSheetTitle => 'Neuigkeiten';

  @override
  String get whatsNewSheetDismiss => 'Verstanden';

  @override
  String get profileChipChangeVehicle => 'Fahrzeug ändern';

  @override
  String get profileChipEditProfile => 'Reiseprofil bearbeiten';

  @override
  String get whatsNewSheetSuggest => 'Vorschlag machen';

  @override
  String get feedbackSheetTitle => 'Vorschläge';

  @override
  String get feedbackSheetSubtitle =>
      'Sag uns, was MyTravelPal für dich besser machen würde. Wir lesen alles.';

  @override
  String get feedbackBodyHint => 'Was würdest du ändern oder ergänzen?';

  @override
  String get feedbackWantReply => 'Ich möchte eine Antwort';

  @override
  String get feedbackEmailHint => 'Deine E-Mail (optional)';

  @override
  String get feedbackSendButton => 'Senden';

  @override
  String get feedbackThanks => 'Danke! Angekommen.';

  @override
  String get feedbackErrorEmpty => 'Ein bisschen mehr bitte (mind. 3 Zeichen)';

  @override
  String get feedbackErrorEmail => 'Diese E-Mail sieht nicht gültig aus';

  @override
  String get feedbackErrorSend =>
      'Konnte nicht gesendet werden. Bitte erneut versuchen.';

  @override
  String get settingsSendFeedback => 'Vorschlag senden';

  @override
  String get settingsSendFeedbackSubtitle =>
      'Sag uns, was als nächstes gebaut wird';

  @override
  String get enrichPulseRestStops => 'Suche Rastplätze entlang der Route';

  @override
  String get exitAppTitle => 'MyTravelPal verlassen?';

  @override
  String get exitAppBody => 'Möchten Sie die App wirklich schließen?';

  @override
  String get exitAppBodyCompanionActive =>
      'Der Companion-Modus läuft. Wenn Sie jetzt gehen, läuft die Fahrsitzung im Hintergrund weiter. Stoppen Sie sie im Companion-Tab, um sauber zu schließen.';

  @override
  String get exitAppStay => 'Bleiben';

  @override
  String get exitAppLeave => 'Verlassen';

  @override
  String get enrichPulseChargers => 'Suche Ladestationen entlang der Route';

  @override
  String get advEventLabelSource => 'Quelle';

  @override
  String get advEventLabelReported => 'Erkannt';

  @override
  String get advEventLabelExpires => 'Gültig bis';

  @override
  String get advEventLabelDuration => 'Geschätzte Dauer';

  @override
  String get advEventSourceWeather => 'Wettervorhersage (Open-Meteo)';

  @override
  String get advEventSourceOfficial => 'Offizieller Feed';

  @override
  String get advEventSourceEffis => 'EFFIS-Waldbrandmonitor';

  @override
  String get advEventSourceUsgs => 'USGS-Erdbebenfeed';

  @override
  String get advEventSourceUser => 'Community-Meldung';

  @override
  String get advEventSourceMock => 'Simuliert (Dev)';

  @override
  String advEventDurationHours(String h) {
    return '$h h';
  }

  @override
  String advEventDurationDays(String d, String h) {
    return '$d T $h h';
  }

  @override
  String get advEventDurationOngoing => 'Laufend';

  @override
  String get exportShareMtp => 'Mit MyTravelPal-Nutzern teilen';

  @override
  String get exportShareMtpSubtitle =>
      'Öffnet direkt in der App — sie wählen ihre eigenen Präferenzen';

  @override
  String exportShareMtpSubject(String origin, String destination) {
    return '$origin → $destination | MyTravelPal';
  }

  @override
  String get resultFuelStationsOnRoute => 'Tankstellen auf der Route';

  @override
  String get resultFuelSavingsAccordionTitle => 'Kraftstoffersparnis';

  @override
  String get resultTimeSavingsOptimal => 'Ihre Abfahrtszeit ist optimal';

  @override
  String get hotelMapFullscreenTitle => 'Hotels in der Umgebung';

  @override
  String get restaurantMapFullscreenTitle => 'Restaurants in der Umgebung';

  @override
  String get tollSummaryTitle => 'Mautgebühren';

  @override
  String get tollSummaryMapButton => 'Auf Karte anzeigen';

  @override
  String activitiesCtaTitle(Object city) {
    return 'Aktivitäten in $city';
  }

  @override
  String get activitiesCtaSubtitle => 'Lokale Aktivitäten und Erlebnisse';

  @override
  String get planIncludeActivities => 'Aktivitäten am Ziel';

  @override
  String get planIncludeActivitiesHint =>
      'GetYourGuide-Vorschläge in jeder Stadt';

  @override
  String get aiPrefScenicRoutes => 'Landschaftliche Routen bevorzugen';

  @override
  String get aiPrefScenicRoutesSub =>
      'Umwege über Aussichtspunkte und Pässe empfehlen';

  @override
  String get aiPrefEcoConscious => 'Umweltbewusstes Fahren';

  @override
  String get aiPrefEcoConsciousSub =>
      'E-Autos bevorzugen, Autobahnen wenn möglich meiden';

  @override
  String get aiPrefLocalFood => 'Lokale Küche zuerst';

  @override
  String get aiPrefLocalFoodSub =>
      'Lokale Restaurants gegenüber Ketten bevorzugen';

  @override
  String get aiPrefDepartureHour => 'Übliche Abfahrtszeit';

  @override
  String get aiPrefDietary => 'ERNÄHRUNGSEINSCHRÄNKUNGEN';

  @override
  String get aiPrefInterests => 'INTERESSEN';

  @override
  String get aiDietVegetarian => 'Vegetarisch';

  @override
  String get aiDietVegan => 'Vegan';

  @override
  String get aiDietGlutenFree => 'Glutenfrei';

  @override
  String get aiDietHalal => 'Halal';

  @override
  String get aiInterestCulture => 'Kultur';

  @override
  String get aiInterestNature => 'Natur';

  @override
  String get aiInterestGastronomy => 'Gastronomie';

  @override
  String get aiInterestShopping => 'Einkaufen';

  @override
  String get aiInterestAdventure => 'Abenteuer';

  @override
  String get wizardSkip => 'Überspringen';

  @override
  String get wizardStart => 'Loslegen';

  @override
  String get wizardBack => 'Zurück';

  @override
  String get wizardNext => 'Weiter';

  @override
  String get wizardTakesSeconds => 'Dauert ca. 30 Sekunden';

  @override
  String get wizardWelcomeTitle => 'Willkommen bei MyTravelPal';

  @override
  String get wizardWelcomeBody =>
      'Erzählen Sie uns von Ihren Reisen und wir personalisieren alles.';

  @override
  String get wizardWhoTitle => 'Mit wem reisen Sie?';

  @override
  String get wizardWhoSubtitle =>
      'Wählen Sie alles Zutreffende. Später änderbar.';

  @override
  String get wizardWhoKids => 'Mit Kindern unterwegs';

  @override
  String get wizardWhoPets => 'Mit Haustieren unterwegs';

  @override
  String get wizardWhoCamper => 'Mit dem Wohnmobil unterwegs';

  @override
  String get wizardVehicleTitle => 'Ihr Fahrzeug';

  @override
  String get wizardVehicleSubtitle =>
      'Wir nutzen dies für Kraftstoffschätzungen und Routenvorschläge.';

  @override
  String get wizardVehicleType => 'Fahrzeugtyp';

  @override
  String get wizardFuelType => 'Kraftstoff';

  @override
  String get wizardRhythmTitle => 'Ihr Fahrtrhythmus';

  @override
  String get wizardRhythmSubtitle =>
      'Das sind Richtwerte — für jede Reise anpassbar.';

  @override
  String wizardWakeHour(String h) {
    return 'Ich fahre um $h los';
  }

  @override
  String wizardBreakEvery(String n) {
    return 'Pause alle $n';
  }

  @override
  String wizardBedtime(String h) {
    return 'Ankunft im Hotel um $h';
  }

  @override
  String get wizardHotelBudget => 'Hotelbudget / Nacht';

  @override
  String get wizardMealBudget => 'Mahlzeitenbudget / Mahlzeit';

  @override
  String get wizardDoneTitle => 'Alles bereit!';

  @override
  String get wizardDoneSubtitle =>
      'Ihre erste Route ist bereits personalisiert.';

  @override
  String get wizardTeaserTitle =>
      'In den Einstellungen können Sie auch konfigurieren:';

  @override
  String get wizardTeaserVehicleModel =>
      'Genaues Fahrzeugmodell (realer Verbrauch)';

  @override
  String get wizardTeaserRoute =>
      'Bevorzugte Route: Autobahn oder landschaftlich';

  @override
  String get wizardTeaserEmergency => 'Notfallkontakte';

  @override
  String get wizardTeaserAlertSound => 'Companion-Alarmton';

  @override
  String get wizardTeaserStars => 'Mindest-Hotelkategorie';

  @override
  String get wizardPlanFirstTrip => 'Meine erste Reise planen';

  @override
  String get priceBandBudget => 'Günstig';

  @override
  String get priceBandMid => 'Standard';

  @override
  String get priceBandLux => 'Gehoben';

  @override
  String get wizardModelTitle => 'Ihr Fahrzeugmodell';

  @override
  String get wizardModelSubtitle =>
      'Mit echten Daten berechnen wir, wann und wo Tanken am günstigsten ist.';

  @override
  String get wizardModelSearch => 'Marke oder Modell suchen...';

  @override
  String get wizardModelGeneric => 'Standardwerte verwenden';

  @override
  String get wizardModelGenericSub => 'Standardschätzung für Ihren Fahrzeugtyp';

  @override
  String get wizardTollFreeDetour => 'Kostenloser Umweg';

  @override
  String get wizardTollMotorway => 'Autobahn';

  @override
  String get wizardTollFaster => 'Schneller';

  @override
  String get wizardTollTitle => 'Maut vermeiden?';

  @override
  String get wizardTollSubtitle =>
      'Wir analysieren tausende Routen, um zu wissen, ob ein Umweg lohnt.';

  @override
  String get wizardTollAvoid => 'Wenn möglich vermeiden';

  @override
  String get wizardTollAvoidSub => 'Alternativen standardmäßig vorschlagen';

  @override
  String get wizardTollPay => 'Immer Autobahn bevorzugen';

  @override
  String get wizardTollPaySub =>
      'Autobahn bevorzugen, außer bei sehr klaren Einsparungen';

  @override
  String get wizardTollNote =>
      'Sie können dies für jede Reise im Planungsbildschirm ändern';

  @override
  String get wizardDrivingNow => 'Jetzt mit dem Fahrbegleiter fahren';

  @override
  String get companionModeLabel => 'Fahrbegleiter';

  @override
  String get companionModeDesc =>
      'KI-Copilot · Empfiehlt Maut-Alternativen, Restaurants nach Ihrem Geschmack und günstige Tankstellen in Echtzeit · Premium';

  @override
  String get aiLearningTitle => 'Der Assistent kennt Sie zu';

  @override
  String get aiScoreExcellent =>
      'Ausgezeichnet · Empfehlungen sind sehr präzise';

  @override
  String get aiScoreGood =>
      'Gut · Personalisierung kann noch verbessert werden';

  @override
  String get aiScoreBasic =>
      'Grundlegend · Profil vervollständigen für bessere Ergebnisse';

  @override
  String get aiFactorVehicleModel => 'Fahrzeugmodell';

  @override
  String get aiFactorVehicleModelHint =>
      'Modell einstellen für genaue Kraftstoffberechnungen';

  @override
  String aiFactorTrips(int count) {
    return '$count Reisen abgeschlossen';
  }

  @override
  String get aiFactorTripsHint =>
      'Mehr Reisen = besseres Verständnis Ihrer üblichen Routen';

  @override
  String get aiFactorHotelPrefs => 'Hotelpräferenzen';

  @override
  String get aiFactorHotelPrefsHint => 'Sterne, Parkplatz oder WLAN hinzufügen';

  @override
  String get aiFactorRestPrefs => 'Restaurantpräferenzen';

  @override
  String get aiFactorRestPrefsHint =>
      'Küchen hinzufügen für genauere Vorschläge';

  @override
  String get aiFactorNick => 'Spitzname und Land eingestellt';

  @override
  String get aiFactorNickHint =>
      'Name und Land in Einstellungen vervollständigen';

  @override
  String get aiFactorEmergency => 'Notfallkontakte';

  @override
  String get aiFactorEmergencyHint =>
      'Kontakt für das Sicherheitssystem hinzufügen';

  @override
  String get aiFactorProfile => 'Grundlegendes Reiseprofil';

  @override
  String get aiFactorProfileHint =>
      'Fahrzeiten in den Einstellungen konfigurieren';

  @override
  String get tripQualityTitle => 'Reisequalität';

  @override
  String get tripQualityExcellent => 'Ausgezeichnet';

  @override
  String get tripQualityGood => 'Gut';

  @override
  String get tripQualityFair => 'Akzeptabel';

  @override
  String get tripQualityPoor => 'Begrenzt';

  @override
  String get tripQualityFactorRoute => 'Route';

  @override
  String get tripQualityFactorFuel => 'Tankstellen';

  @override
  String get tripQualityFactorHotels => 'Hotels';

  @override
  String get tripQualityFactorWeather => 'Wetter';

  @override
  String get tripQualityFactorAlerts => 'Warnungen';

  @override
  String get tripQualityFactorTolls => 'Maut';

  @override
  String get tripQualityFactorStops => 'Stopps';

  @override
  String get tripQualityExplainRoute =>
      'Misst, ob die Route eine gültige Geometrie hat und ob Pflichtpausen geplant wurden (EU-Vorschrift: Pause alle 4,5h).';

  @override
  String get tripQualityExplainFuel =>
      'Zeigt ob Kraftstoffpreise auf deiner Route verfügbar sind und ob du die optimale Station hinzugefügt hast.';

  @override
  String get tripQualityExplainHotels =>
      'Bewertet ob Hotels für Übernachtungen verfügbar sind und ob du ausgewählt hast wo du schläfst.';

  @override
  String get tripQualityExplainWeather =>
      'Analysiert die Wetterbedingungen entlang der Route. Grün = günstig. Gelb = Regen oder Nebel. Rot = Sturm oder Schnee.';

  @override
  String get tripQualityExplainAlerts =>
      'Zählt aktive Ereignisse auf oder nahe deiner Route: Brände, Stürme, Erdbeben, Straßensperrungen. Null Warnungen = Höchstpunktzahl.';

  @override
  String get tripQualityExplainTolls =>
      'Bewertet ob Mautdaten für deine Route verfügbar sind und ob du optimieren kannst welche Maut du zahlst oder überspringst.';

  @override
  String get tripQualityExplainStops =>
      'Misst ob du Pausen für Mahlzeiten und Ruhe geplant hast. Für \'entspanntes\' Tempo oder mit Kindern/Tieren sind Pausen wichtig.';

  @override
  String get wizardModelConsumption => 'Verbrauch';

  @override
  String get wizardModelTank => 'Tankgröße';

  @override
  String get wizardRhythmNote =>
      'Passen Sie jeden Tag direkt im Reiseergebnis über das ⚙-Symbol an.';

  @override
  String get wizardTollHowTitle => 'SO FUNKTIONIERT ES';

  @override
  String get wizardTollHowBody =>
      'Bei jeder Reise analysieren wir jede Maut einzeln: Wenn der Umweg echtes Geld spart und die Extrazeit minimal ist, schlagen wir ihn im Ergebnisbildschirm vor. Sie entscheiden und können genau einstellen, wie viele Minuten Sie bereit sind zu investieren.';

  @override
  String get wizardTollPreference => 'Was ist Ihr Ausgangspunkt?';

  @override
  String get resultStartCompanionNow => 'Jetzt losfahren! · Begleiter-Modus';

  @override
  String get resultCompanionFarFromOrigin =>
      'Nähern Sie sich dem Startpunkt, um den Fahrmodus zu aktivieren';

  @override
  String get resultReplanWithChanges => 'Mit Änderungen neu berechnen';

  @override
  String get replanTipRoute => 'Tagesetappen werden optimiert...';

  @override
  String get replanTipFuel =>
      'Beste Tankstellen auf der Route werden gesucht...';

  @override
  String get replanTipStops => 'Stopps und Ankunftszeiten werden angepasst...';

  @override
  String tripDayBarsCap(int n) {
    return 'Limit: ${n}h';
  }

  @override
  String tripDayBarsUnselected(int n) {
    return '$n Halt(e) nicht hinzugefügt';
  }

  @override
  String get tripDayBarsHint =>
      'Tippe +, um sie in die Gesamtdauer einzuschließen';

  @override
  String get tripDayBarsCapLabel => 'Limit';

  @override
  String get tripDayBarsTitle => 'Tagesverteilung';

  @override
  String get wizardStepProfile => 'Profil';

  @override
  String get wizardStepVehicle => 'Fahrzeug';

  @override
  String get wizardStepRhythm => 'Rhythmus';

  @override
  String get wizardStepBudget => 'Budget';

  @override
  String wizardModelsAvailable(int count) {
    return '$count Modelle verfügbar';
  }

  @override
  String wizardModelsMore(int count) {
    return '+$count — nach Name suchen';
  }

  @override
  String get wizardTollSavingsDemo => 'Spart €8';

  @override
  String companionNotifFuelBody(int km) {
    return '$km km entfernt · Tippe \"Umweg\" um es zur Route hinzuzufügen';
  }

  @override
  String get companionDemoNotifFuel =>
      '3 km entfernt · Umweg in Maps zum Tanken';

  @override
  String get companionDemoNotifRoute =>
      '18 km auf deiner Route · N-II in Betracht ziehen · Umweg in Maps';

  @override
  String get companionDemoNotifMeal =>
      'Menü €12 · 4 km entfernt · Essen pause? Umweg in Maps';

  @override
  String get companionDemoNotifEta =>
      'Ankunft in 10 min · 12 km · Keine Vorfälle';

  @override
  String get companionOffRouteTitle => 'Außerhalb der Route?';

  @override
  String get companionOffRouteBody =>
      'Deine Position ist weit von der geplanten Route entfernt. Im freien Modus bleibt der Assistent bei dir ohne km zu berechnen.';

  @override
  String get companionOffRouteBack => 'Zurück zur Route';

  @override
  String get companionFreeModeBtn => 'Freier Modus';

  @override
  String companionGroupSessionError(String error) {
    return 'Gruppensitzung konnte nicht erstellt werden: $error';
  }

  @override
  String get companionMealStopTitle => 'Mahlzeitenstopp ändern';

  @override
  String get companionMealStopDelayBody =>
      'Möchtest du den Mahlzeitenstopp verschieben? Wir verschieben ihn zum nächsten Rastplatz.';

  @override
  String get settingsLogoutStep3 => '3/4 · Abmelden…';

  @override
  String get settingsLogoutStep4 => '4/4 · Zurück zum Start…';

  @override
  String get settingsNickTaken => 'Bereits vergeben';

  @override
  String get settingsNickHelper =>
      'Dein Name im Strecken-Ranking. Wähle einen Nick und dein Land — nur im Hall of Fame sichtbar.';

  @override
  String get settingsNickEmpty => 'Noch kein Nick';

  @override
  String get settingsCountrySearch => 'Land suchen...';

  @override
  String get settingsPremiumDevNote => 'Wird per Kauf in Produktion aktiviert';

  @override
  String get settingsTierFeaturesPremium =>
      '✓ KI-Companion · Optimierte Maut · Android Auto · Gruppen · Reisemonitor';

  @override
  String get settingsTierFeaturesEssential =>
      '✓ Optimale Tankstellen · Basismaut · Unwetterwarnungen · Blitzer';

  @override
  String get settingsTierFeaturesFree =>
      'Nur Basisplanung · Keine Kraftstoff- oder Mautoptimierung';

  @override
  String resultStationAdded(String name) {
    return '$name hinzugefügt · Tankschätzung für die nächsten Tage aktualisiert';
  }

  @override
  String get resultRestStopFallback => 'Rastplatz';

  @override
  String get resultTooltipProfile => 'Profil & Fahrzeug';

  @override
  String get resultRecalculating =>
      'Neuberechnung mit deinen neuen Einstellungen…';

  @override
  String resultPlanReady(int km, int h, int m) {
    return 'Plan fertig · $km km · ${h}h ${m}m';
  }

  @override
  String get resultGenericConsumptionHint =>
      'Berechnung mit generischem Verbrauch. Fahrzeug einrichten für mehr Genauigkeit.';

  @override
  String resultFuelSavingsPct(int pct) {
    return '$pct% der Kosten';
  }

  @override
  String get resultChartAdded => '  hinzugefügt';

  @override
  String get resultSettingsChangedBody =>
      'Deine Einstellungen haben sich geändert. Mit neuen Werten neu berechnen?';

  @override
  String resultSummaryStops(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Pausen',
      one: '$count Pause',
    );
    return '$_temp0';
  }

  @override
  String resultFuelStationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tankstellen',
      one: '$count Tankstelle',
    );
    return '$_temp0';
  }

  @override
  String resultSummaryTolls(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mauten übersprungen',
      one: '$count Maut übersprungen',
    );
    return '$_temp0';
  }

  @override
  String resultSummaryHotels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Hotels',
      one: '$count Hotel',
    );
    return '$_temp0';
  }

  @override
  String get resultGyGError => 'GetYourGuide konnte nicht geöffnet werden';

  @override
  String resultGyGActivities(String city) {
    return 'Aktivitäten in $city';
  }
}
