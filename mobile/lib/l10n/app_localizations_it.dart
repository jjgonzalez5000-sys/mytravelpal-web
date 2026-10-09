// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appName => 'MyTravelPal';

  @override
  String get appTagline => 'Pianifica il viaggio, non solo la destinazione';

  @override
  String get onboardEyebrowKiller => 'IL COSTO REALE';

  @override
  String get onboardTitleKiller =>
      'Il GPS mostra la strada.\nNoi mostriamo il costo.';

  @override
  String get onboardBodyKiller =>
      'Pedaggi, carburante, hotel e pasti calcolati prima di partire. Nessuna sorpresa.';

  @override
  String get onboardEyebrowHonest => 'IL TUO PROFILO, IL TUO VIAGGIO';

  @override
  String get onboardTitleHonest =>
      '2 adulti, 1 figlio, cane.\nParcheggio. 3 stelle max €€.';

  @override
  String get onboardBodyHonest =>
      'Hotel e ristoranti filtrati per le tue vere preferenze. Non una lista generica — la tua.';

  @override
  String get onboardEyebrowAlerts => 'ALERT IN TEMPO REALE';

  @override
  String get onboardTitleAlerts => 'Incendio a 14 km\ndal tuo percorso.';

  @override
  String get onboardBodyAlerts =>
      'Incendi, tempeste, terremoti, chiusure stradali. Solo gli eventi che riguardano il tuo percorso specifico.';

  @override
  String get onboardCostFuel => 'Carburante';

  @override
  String get onboardCostTolls => 'Pedaggi';

  @override
  String get onboardCostMeals => 'Pasti';

  @override
  String get onboardCostHotel => 'Hotel';

  @override
  String get onboardCostTotal => 'TOTALE';

  @override
  String get onboardSavingsTitle => 'Risparmi rilevati';

  @override
  String get onboardSavingsToll => 'Alternativa pedaggi';

  @override
  String get onboardSavingsFuel => 'Stazione ottimale';

  @override
  String get onboardSavingsHotel => 'Hotel migliore';

  @override
  String get onboardSavingsTotal => 'TOTALE RISPARMIATO';

  @override
  String get onboardSkip => 'Salta';

  @override
  String get onboardContinue => 'Continua';

  @override
  String get onboardGetStarted => 'Inizia';

  @override
  String get onboardFooter =>
      'Gratis all\'inizio · Premium sblocca il racconto IA del viaggio';

  @override
  String get loginContinueApple => 'Continua con Apple';

  @override
  String get loginContinueGoogle => 'Continua con Google';

  @override
  String get loginContinueFacebook => 'Continua con Facebook';

  @override
  String get loginContinueDemo => 'Continua come demo';

  @override
  String get loginDivider => 'oppure';

  @override
  String get loginTerms =>
      'Continuando accetti i nostri termini e la politica sulla privacy.';

  @override
  String get loginBusy => 'Accesso in corso…';

  @override
  String get planTitle => 'Pianifica un viaggio';

  @override
  String get planEyebrow => 'IL PIANIFICATORE';

  @override
  String get planHero => 'Dove andiamo\noggi?';

  @override
  String planHeroPersonal(String name) {
    return 'Ciao $name, dove andiamo?';
  }

  @override
  String get planIntro =>
      'Scegli due punti e un\'ora. Al resto ci pensiamo noi.';

  @override
  String get planFrom => 'Da';

  @override
  String get planTo => 'A';

  @override
  String get planDesiredDeparture => 'Ora di partenza desiderata';

  @override
  String get planCta => 'Pianifica';

  @override
  String get planCtaBusy => 'Pianificazione in corso…';

  @override
  String get planCountriesNote =>
      'I paesi vengono rilevati automaticamente dal tuo percorso.';

  @override
  String get planSectionOptional => 'Lungo il percorso';

  @override
  String get planMoreOptions => 'Altre opzioni';

  @override
  String get planLessOptions => 'Meno opzioni';

  @override
  String get planRoundTripChip => 'Andata e ritorno';

  @override
  String get planLeaveNowFabTitle => 'Parti ora';

  @override
  String get leaveNowConfirmTitle => 'Parti ora verso';

  @override
  String leaveNowConfirmBody(Object name) {
    return 'Andiamo a $name?';
  }

  @override
  String get leaveNowConfirmCta => 'Andiamo';

  @override
  String get leaveNowConfirmChange => 'Cambia destinazione';

  @override
  String get settingsBiometric => 'Sblocco biometrico';

  @override
  String get settingsBiometricSub => 'Impronta o volto per aprire l\'app';

  @override
  String get settingsBiometricUnavailable =>
      'Non disponibile su questo dispositivo';

  @override
  String get settingsReplayTutorial => 'Ripeti tutorial';

  @override
  String get settingsReplayTutorialSub =>
      'Mostra di nuovo i coach-mark guidati';

  @override
  String get settingsReplayTutorialToast =>
      'Tutorial reimpostato. Riapri Pianifica.';

  @override
  String get settingsColorPreset => 'Palette colori';

  @override
  String get settingsPresetForest => 'Bosco';

  @override
  String get settingsPresetSunset => 'Tramonto';

  @override
  String get settingsPresetOcean => 'Oceano';

  @override
  String get settingsDynamicColor => 'Material You (dinamico)';

  @override
  String get settingsDynamicColorSub =>
      'Adatta i colori allo sfondo (Android 12+)';

  @override
  String get settingsOled => 'Nero puro (OLED)';

  @override
  String get settingsOledSub =>
      'Neri più profondi in modalità scura, risparmia batteria OLED';

  @override
  String get parkingSearchTitle => 'Cerca parcheggio';

  @override
  String get parkingSearchLabel => 'Dove vai?';

  @override
  String get parkingSearchHint =>
      'Scegli una destinazione per vedere i parcheggi vicini.';

  @override
  String get parkingRadiusLabel => 'Raggio';

  @override
  String get parkingNoResults => 'Nessun parcheggio in questo raggio.';

  @override
  String get parkingPriceUnknown => 'Prezzo ?';

  @override
  String get parkingCovered => 'Coperto';

  @override
  String get parkingFilterKids => 'Bambini';

  @override
  String get parkingFilterDogs => 'Cani';

  @override
  String get parkingFilterToilets => 'Bagni';

  @override
  String get parkingFilterFood => 'Cibo';

  @override
  String get parkingFilterShowers => 'Docce';

  @override
  String get parkingFilterEv => 'Colonnina EV';

  @override
  String get parkingFilterFuel => 'Distributore';

  @override
  String get parkingFilterWheelchair => 'Accessibile';

  @override
  String get parkingFilterRv => 'Camper';

  @override
  String get parkingFilterTruck => 'Camion';

  @override
  String get planFindParkingCta => 'Cerca parcheggio';

  @override
  String get poiFindParking => 'Parcheggio';

  @override
  String get parkingPrefTitle => 'Parcheggio';

  @override
  String get parkingPrefSub => 'Mostra parcheggi vicino alla destinazione.';

  @override
  String get parkingResultTitle => 'Parcheggi vicino alla destinazione';

  @override
  String get inspireTitle => 'Ispirazione viaggio';

  @override
  String get inspireHero => 'Descrivi il tuo road trip dei sogni';

  @override
  String get inspireSub =>
      'L\'IA propone un itinerario multi-giorno da trasformare in un piano reale con un tap.';

  @override
  String get inspireHint =>
      'es. Weekend romantico di 4 giorni tra i laghi italiani';

  @override
  String get inspireGenerate => 'Ispirami';

  @override
  String get inspireGenerating => 'Sto pensando al tuo viaggio…';

  @override
  String get inspireError => 'La musa è offline. Prova un altro testo.';

  @override
  String get inspireResultTitle => 'Itinerario proposto';

  @override
  String inspireDayLabel(Object n) {
    return 'Giorno $n';
  }

  @override
  String get inspireBudgetLabel => 'Budget stimato';

  @override
  String get inspireConvertToPlan => 'Trasforma in un piano vero';

  @override
  String get inspireSave => 'Salva';

  @override
  String get inspireSavedToast =>
      'Idea salvata. La trovi tra le tue ispirazioni.';

  @override
  String get inspireRecentTitle => 'Recenti';

  @override
  String get inspireHistoryTitle => 'I miei piani IA';

  @override
  String get inspireHistoryEmpty =>
      'Nessun piano IA. Generane uno dal tab Pianifica.';

  @override
  String get inspireHistoryDelete => 'Elimina';

  @override
  String get settingsMyAiPlans => 'I miei piani IA';

  @override
  String get settingsMyAiPlansSub => 'Cronologia Trip Inspiration';

  @override
  String get inspireChatTitle => 'Modifica l\'itinerario';

  @override
  String get inspireChatHint =>
      'Chiedi un cambio: \"togli Cremona\", \"parto venerdì sera\"…';

  @override
  String get inspireExamplesTitle => 'O parti da un\'idea';

  @override
  String get inspireExample1 => 'Weekend castelli della Loira';

  @override
  String get inspireExample2 => 'Costa Barcellona-Marsiglia';

  @override
  String get inspireExample3 => '5 giorni sulle Alpi da Milano';

  @override
  String get inspireExample4 => 'Nord Spagna in famiglia, senza autostrade';

  @override
  String get planOverrideForTrip => 'Sovrascrivi per questo viaggio';

  @override
  String get planOverrideActive => 'Sovrascrittura per questo viaggio';

  @override
  String get planOverrideClear => 'Cancella';

  @override
  String get planTooltipDashboard => 'Dashboard';

  @override
  String get planTooltipReport => 'Segnala un evento';

  @override
  String get planTooltipSaved => 'Viaggi salvati';

  @override
  String get tabPlan => 'Pianifica';

  @override
  String get tabCompanion => 'Copilota';

  @override
  String get tabMyTrips => 'I miei viaggi';

  @override
  String get companionHeroTitle => 'Il tuo copilota di viaggio';

  @override
  String get companionHeroBody =>
      'Imposta le tue condizioni e parti. L\'app ti accompagna e ti consiglia quando fermarti, dove mangiare e dove rifornire.';

  @override
  String get companionConfigSection => 'CONFIGURAZIONE';

  @override
  String get companionBreakInterval => 'Suggerisci una pausa ogni';

  @override
  String get companionSuggestBreak =>
      'Suggerisci una pausa in base al tempo di guida';

  @override
  String companionBreakHint(String hours) {
    return 'Consiglia una sosta ogni $hours h di guida';
  }

  @override
  String get companionFatigueStopExperimental =>
      'Suggerisci sosta per stanchezza (sperimentale)';

  @override
  String get companionFatigueStopHint =>
      'Solo timer — scatta anche con micro-pause.';

  @override
  String get companionAlerts => 'Tipi di avviso';

  @override
  String get companionAlertCriticalAdverse =>
      'Incidenti critici (incendi, alluvioni, terremoti)';

  @override
  String get companionAlertCriticalAdverseHint =>
      'Consigliato. Qualcosa di grave vicino — non solo meteo.';

  @override
  String get companionAlertWeather => 'Meteo in rotta';

  @override
  String get companionAlertFuel => 'Distributori più economici in rotta';

  @override
  String get companionAlertBorder => 'Info passaggio frontiera';

  @override
  String get companionAlertToll => 'Suggerimenti evitare pedaggi';

  @override
  String get companionAlertHotel => 'Hotel quando sei stanco';

  @override
  String get companionStart => 'Avvia copilota';

  @override
  String get companionComingSoon => 'Modalità copilota in arrivo!';

  @override
  String get companionDriveTitle => 'Compagno attivo';

  @override
  String get companionForegroundBody => 'MyTravelPal sta seguendo la tua guida';

  @override
  String get companionLocationDenied =>
      'Serve il permesso di posizione per il compagno.';

  @override
  String get companionDriving => 'in guida';

  @override
  String get companionAllGood => 'Nessun avviso — buon viaggio.';

  @override
  String get companionWeatherRowEmpty => 'Nessun avviso in vista';

  @override
  String get companionEndTitle => 'Terminare compagno?';

  @override
  String get companionEndBody =>
      'Il tracciamento si ferma e gli avvisi attivi saranno persi.';

  @override
  String get companionEndKeep => 'Continua';

  @override
  String get companionEndConfirm => 'Termina sessione';

  @override
  String get emergencyContactsTitle => 'Contatti di emergenza';

  @override
  String get emergencyContactsSubtitle => 'SMS in caso di impatto rilevato';

  @override
  String get emergencyContactsBody =>
      'Fino a 3 persone ricevono un SMS con la tua posizione se viene rilevato un impatto.';

  @override
  String get emergencyContactsEmpty => 'Nessun contatto aggiunto.';

  @override
  String get emergencyContactsAdd => 'Aggiungi contatto';

  @override
  String get emergencyContactsPickFromDevice => 'Scegli dai contatti';

  @override
  String get emergencyContactsPickSearch => 'Cerca contatti';

  @override
  String get emergencyContactsPermDenied =>
      'Permesso negato. Puoi aggiungere manualmente.';

  @override
  String get emergencyContactsNoDevice =>
      'Nessun contatto con numero sul dispositivo.';

  @override
  String get emergencyContactAddTitle => 'Aggiungi contatto di emergenza';

  @override
  String get emergencyContactName => 'Nome';

  @override
  String get emergencyContactNameRequired => 'Inserisci un nome';

  @override
  String get emergencyContactPhone => 'Telefono (E.164)';

  @override
  String get emergencyContactPhoneRequired => 'Inserisci un telefono';

  @override
  String get emergencyContactPhoneInvalid =>
      'Formato internazionale: +39331234567';

  @override
  String get cancel => 'Annulla';

  @override
  String get save => 'Salva';

  @override
  String get sosTitle => 'Possibile impatto rilevato';

  @override
  String sosBody(String g, String speed) {
    return 'Picco di impatto ${g}g · calo di velocità $speed km/h.';
  }

  @override
  String sosCountdown(int seconds) {
    return '${seconds}s';
  }

  @override
  String get sosImOk => 'Sto bene — annulla';

  @override
  String get sosCall112 => 'Chiama 112';

  @override
  String get sosCancelled => 'Allerta annullata.';

  @override
  String get sosClose => 'Chiudi';

  @override
  String get sosNoContacts =>
      'Nessun contatto configurato. Aggiungilo in Impostazioni.';

  @override
  String sosSmsDispatched(int count) {
    return 'SMS pronto per $count contatto/i.';
  }

  @override
  String get sosSmsFailed => 'SMS non aperto. Chiama manualmente sotto.';

  @override
  String get sosSmsPrefix =>
      'MyTravelPal — possibile impatto rilevato. La mia posizione:';

  @override
  String get weatherForecastTitle => 'Previsioni 7 giorni';

  @override
  String get weatherToday => 'Oggi';

  @override
  String get leaveNowTitle => 'Parti ora con compagno';

  @override
  String get leaveNowSubtitle =>
      'Scegli la destinazione e parti — ti seguiamo e ti guidiamo.';

  @override
  String get leaveNowSheetTitle => 'Dove vai?';

  @override
  String get leaveNowPremiumTitle => 'Funzione Premium';

  @override
  String get leaveNowPremiumBody =>
      '\'Parti ora\' unisce il piano completo al compagno di guida. Disponibile con MyTravelPal Premium.';

  @override
  String get leaveNowPremiumDismiss => 'Più tardi';

  @override
  String get leaveNowPremiumCta => 'Prova 7 giorni gratis';

  @override
  String get shareCardOption => 'Condividi come immagine';

  @override
  String get shareCardOptionSub =>
      'Perfetto per Instagram Stories, WhatsApp, X';

  @override
  String get shareLinkOption => 'Condividi come link';

  @override
  String get shareLinkOptionSub =>
      'Riepilogo testo + link per riaprire il piano';

  @override
  String get shareToSocial => 'Condividi';

  @override
  String get sharePlanTitle => 'Condividi link del viaggio';

  @override
  String get sharePlanSubtitle => 'QR code + link per riaprire questo piano';

  @override
  String get sharePlanCopy => 'Copia link';

  @override
  String get sharePlanCopied => 'Link copiato';

  @override
  String shareLiveHeadline(String city) {
    return 'In viaggio per $city';
  }

  @override
  String shareLiveCaption(String city) {
    return 'In viaggio per $city con MyTravelPal 🚗';
  }

  @override
  String get planAddStop => 'Aggiungi tappa';

  @override
  String get planStopDwellPassThrough => 'Solo di passaggio';

  @override
  String get planStopDwellOneNight => '1 notte';

  @override
  String planStopDwellNights(int n) {
    return '$n notti';
  }

  @override
  String planStopDwellHours(int n) {
    return '$n ore';
  }

  @override
  String planStopDwellTitle(Object name) {
    return 'Quanto tempo a $name?';
  }

  @override
  String get planAddStopTitle => 'Nuova tappa';

  @override
  String planStopLabel(int n) {
    return 'Tappa $n';
  }

  @override
  String get planStopRemove => 'Rimuovi';

  @override
  String get settingsCurrency => 'Valuta';

  @override
  String get planErrorPickEndpoints => 'Scegli un\'origine e una destinazione.';

  @override
  String get resultBestTimeToLeave => 'MIGLIOR ORA PER PARTIRE';

  @override
  String get resultTripSavings => 'I TUOI RISPARMI SU QUESTO VIAGGIO';

  @override
  String get resultSavingsDetected => 'Risparmi rilevati';

  @override
  String get resultTollSaving => 'Alternativa senza pedaggio';

  @override
  String get resultFuelSaving => 'Carburante';

  @override
  String get resultTimeSaving => 'Partenza ottimale';

  @override
  String get resultTotalSaving => 'RISPARMIO TOTALE';

  @override
  String resultSavingPct(String pct) {
    return '$pct% in meno';
  }

  @override
  String get resultSavingsSuggestionsTitle => 'Modi per risparmiare tempo';

  @override
  String get resultSavingsClaimedHint =>
      'Il risparmio comparirà dopo aver applicato la finestra consigliata.';

  @override
  String get resultTimeSavedLabel => 'tempo risparmiato';

  @override
  String get resultExtraTimeLabel => 'tempo extra';

  @override
  String get resultMoneySavedLabel => 'soldi risparmiati';

  @override
  String get resultDepartureWindowTitle => 'Finestra di partenza';

  @override
  String get resultDepartureWindowDesc =>
      'Minuti totali per ogni orario di partenza candidato.';

  @override
  String get resultCompareVariantsTitle => 'Confronta le opzioni';

  @override
  String get resultCompareVariantsEyebrow => 'Varianti di percorso';

  @override
  String get resultAlertsTitle => 'Allerte lungo il percorso';

  @override
  String get resultRestStopsTitle => 'Aree di sosta';

  @override
  String get resultHotelsTitle => 'Hotel';

  @override
  String get resultRestaurantsTitle => 'Ristoranti';

  @override
  String get resultFuelTitle => 'Carburante';

  @override
  String get resultTollAlternativeEyebrow => 'ALTERNATIVA SENZA PEDAGGI';

  @override
  String get resultTollAlternativeWorthIt => 'Ne vale la pena';

  @override
  String get resultTollAlternativeMarginal => 'Marginale';

  @override
  String get resultShareTooltip => 'Condividi questo viaggio';

  @override
  String get resultExplainTooltip => 'Spiega il mio viaggio (Premium)';

  @override
  String get resultSaveTooltip => 'Salva viaggio';

  @override
  String get resultSaveChangesTooltip => 'Salva modifiche';

  @override
  String get resultSavedTooltip => 'Salvato';

  @override
  String get resultTripSaved => 'Viaggio salvato';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String dashboardGreeting(String name) {
    return 'Ciao, $name';
  }

  @override
  String get dashboardTravelSoFar => 'I tuoi viaggi finora';

  @override
  String get dashboardTrips => 'Viaggi';

  @override
  String get dashboardDistance => 'Distanza';

  @override
  String get dashboardHours => 'Ore';

  @override
  String get dashboardTimeSaved => 'TEMPO RISPARMIATO';

  @override
  String get dashboardMoneySaved => 'SOLDI RISPARMIATI';

  @override
  String get dashboardFuelBudget => 'BUDGET CARBURANTE STIMATO';

  @override
  String get dashboardTopSavers => 'Miglior risparmio';

  @override
  String get dashboardSaved => 'risparmiato';

  @override
  String get dashboardCountries => 'Paesi';

  @override
  String get dashboardSignOut => 'Esci';

  @override
  String get profileTitle => 'Profilo viaggio';

  @override
  String get profileOverrideTitle => 'Sovrascrivi per questo viaggio';

  @override
  String get profileSave => 'Salva';

  @override
  String get profileUse => 'Usa';

  @override
  String get profileWhoTravelling => 'Chi viaggia';

  @override
  String get profileTravellers => 'Viaggiatori';

  @override
  String get profileHasKids => 'In viaggio con bambini';

  @override
  String get profileHasPets => 'In viaggio con animali';

  @override
  String get profileVehicle => 'Veicolo';

  @override
  String get profileMealTimes => 'Orari dei pasti';

  @override
  String get profileReminders => 'Promemoria';

  @override
  String get profilePremiumSection => 'Premium (demo)';

  @override
  String get profileClearProfile => 'Cancella profilo';

  @override
  String get commonRetry => 'Riprova';

  @override
  String get commonCancel => 'Annulla';

  @override
  String get commonClear => 'Cancella';

  @override
  String commonShowNMore(int n) {
    return 'Mostra altri $n';
  }

  @override
  String get commonShowLess => 'Mostra meno';

  @override
  String planLoadingElapsed(int seconds) {
    return '${seconds}s trascorsi';
  }

  @override
  String get planLoadingLongCrossingCountries =>
      'Controllo pedaggi nei paesi attraversati…';

  @override
  String get planLoadingLongScanningFuel =>
      'Analisi prezzi carburante europei lungo la tua rotta…';

  @override
  String get planLoadingLongBigTrip =>
      'I viaggi lunghi richiedono più tempo — caricamento hotel e soste extra.';

  @override
  String get planLoadingLongAlmostDone =>
      'Ci siamo quasi — ritocchi finali all\'itinerario.';

  @override
  String get commonSave => 'Salva';

  @override
  String get commonRemove => 'Rimuovi';

  @override
  String get searchPlaceholderLegacy => 'Cerca una città…';

  @override
  String get searchNoMatches => 'Nessun risultato.';

  @override
  String get searchStartTyping => 'Digita almeno 2 caratteri.';

  @override
  String get searchRecent => 'RECENTI';

  @override
  String get searchUseMyLocation => 'Usa la mia posizione';

  @override
  String get locationServiceOff =>
      'La localizzazione è disattivata su questo dispositivo.';

  @override
  String get locationPermissionDenied =>
      'Autorizzazione alla posizione negata.';

  @override
  String get locationUnavailable => 'Impossibile determinare la tua posizione.';

  @override
  String get favoritesTitle => 'Preferiti';

  @override
  String get favoritesEmptyHotels =>
      'Nessun hotel preferito. Tocca la stella su un hotel per salvarlo.';

  @override
  String get favoritesEmptyRestaurants =>
      'Nessun ristorante preferito. Tocca la stella su un ristorante per salvarlo.';

  @override
  String get favoritesTabHotels => 'Hotel';

  @override
  String get favoritesTabRestaurants => 'Ristoranti';

  @override
  String get favoritesTooltipAdd => 'Aggiungi ai preferiti';

  @override
  String get favoritesTooltipRemove => 'Rimuovi dai preferiti';

  @override
  String get planTooltipFavorites => 'Preferiti';

  @override
  String get resultBackToPlan => 'Torna al piano';

  @override
  String get alertsAlongYourRoute => 'Allerte lungo il percorso';

  @override
  String get alertsAlongYourRouteDesc =>
      'Incendi, alluvioni, maltempo estremo, neve, terremoti, frane — ordinate per gravità.';

  @override
  String get restStopsHint =>
      'Consigliato ogni 2 h di guida. Le brevi pause mantengono la lucidità nei viaggi lunghi.';

  @override
  String get fuelAlongTheRoute => 'Carburante lungo il percorso';

  @override
  String get hotelsNearYourRoute => 'Hotel vicino al percorso';

  @override
  String get restaurantsNearYourRoute => 'Ristoranti vicino al percorso';

  @override
  String get narrativeTitle => 'Racconto del viaggio';

  @override
  String get narrativeGenerating => 'Sto scrivendo il racconto…';

  @override
  String get narrativeFailed =>
      'Impossibile generare il racconto. Riprova tra poco.';

  @override
  String get narrativeFooter =>
      'Generato da Claude — potrebbe non riflettere cambiamenti in tempo reale.';

  @override
  String get narrativePremiumBadge => 'Premium';

  @override
  String get shareTripSubject => 'Il mio viaggio con MyTravelPal';

  @override
  String get shareFormatTitle => 'Condividi come…';

  @override
  String get shareFormatStory => 'Story · 9:16';

  @override
  String get shareFormatStorySub => 'Instagram / TikTok / WhatsApp Stories';

  @override
  String get shareFormatFeed => 'Quadrato · 1:1';

  @override
  String get shareFormatFeedSub => 'Feed Instagram, Facebook, LinkedIn';

  @override
  String get shareTitle => 'MyTravelPal — piano di viaggio';

  @override
  String shareRouteLine(String km, String hours, String tolls) {
    return '$km km · $hours h in flusso libero · pedaggi $tolls €';
  }

  @override
  String shareBestTime(String when, String minutes) {
    return 'Miglior orario di partenza: $when ($minutes min totali)';
  }

  @override
  String shareTollFreeAlt(String savings, String minutes) {
    return 'Alt. senza pedaggi: risparmi $savings € per +$minutes min';
  }

  @override
  String shareRefuelHint(
      String cheap, String price, String pricey, String savings) {
    return 'Fai rifornimento in $cheap (~$price€/L) prima di $pricey — risparmi ~$savings€/serbatoio';
  }

  @override
  String get shareHotelsHeader => 'Migliori hotel considerati:';

  @override
  String get shareRestaurantsHeader => 'Migliori ristoranti considerati:';

  @override
  String shareHotelLine(String name, String price, String km) {
    return '$name — $price €/notte · $km km fuori rotta';
  }

  @override
  String shareRestaurantLine(String name, String price, String km) {
    return '$name — $price €/pasto · $km km fuori rotta';
  }

  @override
  String get shareOpenInApp => 'Apri in MyTravelPal:';

  @override
  String get eventReport => 'Segnala un evento';

  @override
  String get eventDescription => 'Descrizione';

  @override
  String get eventType => 'Tipo';

  @override
  String get eventSeverity => 'Gravità';

  @override
  String get eventLocation => 'Posizione';

  @override
  String get eventSubmit => 'Invia';

  @override
  String get eventSubmitted => 'Segnalato.';

  @override
  String get resultStatDistance => 'Distanza';

  @override
  String get resultStatFreeFlow => 'Senza traffico';

  @override
  String get resultStatPlanned => 'Pianificato';

  @override
  String get resultStatTolls => 'Pedaggi';

  @override
  String get resultEyebrowNearRoute => 'Vicino al percorso';

  @override
  String get resultEyebrowAlongRoute => 'Lungo il percorso';

  @override
  String get resultAlerts => 'Allerte';

  @override
  String get resultRestStops => 'Soste consigliate';

  @override
  String get resultHotels => 'Hotel';

  @override
  String get resultRestaurants => 'Ristoranti';

  @override
  String get resultFuel => 'Carburante';

  @override
  String get resultOptimizedFuelBudget => 'Budget carburante stimato';

  @override
  String get resultCompareTitle => 'Confronta le opzioni';

  @override
  String get resultCompareStraightApprox => 'Approssim. linea retta.';

  @override
  String resultSleepAt(String when) {
    return 'Dormire · $when';
  }

  @override
  String get resultHourlyTollEyebrow => 'VERDETTO PEDAGGI PER ORA';

  @override
  String get resultSkipLabel => 'Salta';

  @override
  String get resultKeepLabel => 'Mantieni';

  @override
  String get resultSaveExactly => 'Risparmia ';

  @override
  String get notificationsLeaveSoonTitle => 'Ora di partire';

  @override
  String get localeSystem => 'Sistema';

  @override
  String get localeMenuTooltip => 'Lingua';

  @override
  String get dashboardCountry => 'Paese';

  @override
  String get dashboardNoTripsYet =>
      'Nessun viaggio salvato. Pianifica e salva un viaggio per vedere le statistiche.';

  @override
  String get dashboardStatCards => 'PANORAMICA';

  @override
  String get profileVehicleType => 'Tipo di veicolo';

  @override
  String get profileFuelType => 'Tipo di carburante';

  @override
  String get profileConsumption => 'Consumo';

  @override
  String get profileEvRange => 'Autonomia elettrica';

  @override
  String get profileFuelTank => 'Serbatoio';

  @override
  String get profileBreakfast => 'Colazione';

  @override
  String get profileLunch => 'Pranzo';

  @override
  String get profileDinner => 'Cena';

  @override
  String get mealSlotBreak => 'Sosta';

  @override
  String get profileStopMinutes => 'Durata tipica sosta';

  @override
  String get profileReminderMinutes => 'Promemoria prima della partenza';

  @override
  String get profilePremiumHint =>
      'Attiva per anteprima delle funzioni Premium in locale.';

  @override
  String get profileNoProfile => 'Nessun profilo salvato.';

  @override
  String get eventPlaceholderDescription =>
      'Breve descrizione di ciò che hai visto';

  @override
  String get eventCurrentLocation => 'Posizione attuale';

  @override
  String get eventPickOnMap => 'Scegli sulla mappa';

  @override
  String eventLocationCoords(String lat, String lon) {
    return 'Selezionato: $lat, $lon';
  }

  @override
  String get narrativeRegenerate => 'Rigenera';

  @override
  String get narrativeUpgrade => 'Sblocca il racconto IA con Premium.';

  @override
  String get compareVariantsRecommended => 'Consigliato';

  @override
  String get compareVariantsFastest => 'Più veloce';

  @override
  String get compareVariantsCheapest => 'Più economico';

  @override
  String get compareVariantsScenic => 'Panoramico';

  @override
  String get compareVariantsAvoidTolls => 'Senza pedaggi';

  @override
  String get compareVariantsAvoidMotorways => 'Senza autostrade';

  @override
  String get hourlyBestHours => 'Migliori ore per saltare i pedaggi';

  @override
  String get hourlyWorstHours => 'Peggiori ore per saltare i pedaggi';

  @override
  String get partialTollSkipsTitle =>
      'Pedagio per pedagio · Ottimizzazione Premium';

  @override
  String get partialTollSkipsEyebrow => 'Dettaglio';

  @override
  String get sleepEyebrow => 'PER LA NOTTE';

  @override
  String get sleepNoHotelSuggestion =>
      'Nessun hotel scelto — vedi la sezione Hotel.';

  @override
  String get lunchEyebrow => 'PAUSA PRANZO';

  @override
  String get dinnerEyebrow => 'PAUSA CENA';

  @override
  String get breakfastEyebrow => 'PAUSA COLAZIONE';

  @override
  String get resultCompareEyebrow => 'Varianti di percorso';

  @override
  String get resultCompareDescription =>
      'Stessa partenza e arrivo — priorità diverse. Tempi senza traffico.';

  @override
  String get resultVariantDashed => 'Tratteggiata sulla mappa sopra';

  @override
  String dayTollsHeader(Object amount, int count) {
    return 'Pedaggi di oggi · $amount € ($count)';
  }

  @override
  String dayTollsSavedSummary(Object amount, int count) {
    return 'Risparmi $amount € saltandone $count.';
  }

  @override
  String tollHourGoodToSkip(Object hh) {
    return 'Buon momento per saltarlo ($hh:00)';
  }

  @override
  String tollHourAvoidSkip(Object hh) {
    return 'Meglio pagarlo — picco $hh:00';
  }

  @override
  String get partialTollsPerDayHint =>
      'Puoi anche gestirli per giorno nell\'itinerario ↓';

  @override
  String resultCityHint(Object city) {
    return 'Vicino a $city';
  }

  @override
  String get resultSavingsShiftAndSkip =>
      'Spostando la partenza e saltando i pedaggi.';

  @override
  String get resultSavingsShift =>
      'Spostando la partenza alla finestra consigliata.';

  @override
  String get resultSavingsSkip => 'Prendendo l\'alternativa senza pedaggi.';

  @override
  String get resultSavingsNone =>
      'Nessun risparmio identificato per questo percorso.';

  @override
  String get resultBypassSavingsPrefix => 'Potresti risparmiare fino a';

  @override
  String resultBypassSavingsSuffix(String minutes) {
    return 'con +$minutes min in più';
  }

  @override
  String get resultArrival => 'ARRIVO';

  @override
  String get resultShift => 'SPOSTAMENTO';

  @override
  String get resultTraffic => 'TRAFFICO';

  @override
  String get resultTotal => 'TOTALE';

  @override
  String resultRestStopNoRestaurant(String km) {
    return 'Sosta al km $km — nessun ristorante compatibile.';
  }

  @override
  String resultNoHotelHere(String km) {
    return 'Buona sosta qui (~$km km). Nessun hotel compatibile.';
  }

  @override
  String get resultMealFallback => 'Pasto';

  @override
  String get resultHourlyExplainer =>
      'Comune in Francia e Italia: uscire prima di un pedaggio caro, prendere una strada parallela e rientrare — 15-40 min in più ma 5-15 € risparmiati.';

  @override
  String get profileSaved => 'Profilo salvato';

  @override
  String get profileWhoEyebrow => 'Persone';

  @override
  String get profileKidsSubtitle =>
      'Preferisce ristoranti e hotel adatti ai bambini.';

  @override
  String get profilePetsSubtitle =>
      'Preferisce luoghi pet-friendly, dà priorità al parcheggio.';

  @override
  String get profileVehicleEyebrow => 'Per costi e parcheggio';

  @override
  String get profileMealsEyebrow => 'Per allineare con le soste ristorante';

  @override
  String get profileRemindersEyebrow => 'Notifiche locali';

  @override
  String get profileNotifyBefore => 'Avvisami prima della partenza';

  @override
  String get profileNotifyOff => 'Disattivato — nessun promemoria programmato.';

  @override
  String profileNotifyMinutesBefore(int minutes) {
    return '$minutes minuti prima';
  }

  @override
  String get profilePremiumEyebrow => 'Toggle locale · nessun pagamento reale';

  @override
  String get profilePremiumBody =>
      'Il gating reale StoreKit / Play Billing arriverà più avanti. Per ora questo toggle abilita Premium localmente per l\'anteprima.';

  @override
  String get profileSimulatePremium => 'Simula Premium';

  @override
  String get profileSimulatePremiumSubtitle =>
      'Sblocca il racconto IA e l\'analisi oraria dei pedaggi.';

  @override
  String get profileOverrideHeroDesc =>
      'Cambia il tuo profilo solo per questo viaggio — veicolo, viaggiatori o orari pasti diversi senza toccare il profilo salvato.';

  @override
  String get profileGlobalHeroDesc =>
      'Impostalo una volta. Ogni piano lo usa per classificare hotel e ristoranti, stimare il carburante e allineare le soste pasto.';

  @override
  String get eventPickPlace => 'Scegli un luogo e descrivi cosa hai visto.';

  @override
  String get eventThankYou => 'Segnalazione inviata — grazie!';

  @override
  String eventCouldNotSubmit(String reason) {
    return 'Impossibile inviare: $reason';
  }

  @override
  String get eventIntro =>
      'Aiuta gli altri automobilisti. Le segnalazioni scadono dopo 24 ore per impostazione predefinita.';

  @override
  String get eventWhatHappened => 'Cos\'è successo';

  @override
  String get eventWhatHappenedEyebrow => 'Tipo';

  @override
  String get eventSeverityInfo => 'Info';

  @override
  String get eventSeverityWarning => 'Allerta';

  @override
  String get eventSeverityCritical => 'Critico';

  @override
  String get eventWhere => 'Dove';

  @override
  String get eventWhereEyebrow => 'Città più vicina';

  @override
  String get eventDescribeTitle => 'Descrivilo';

  @override
  String get eventDescribeEyebrow => 'Breve e utile';

  @override
  String get eventDescribeHint =>
      'es. Alberi caduti su A6 sud, 2 corsie chiuse';

  @override
  String get eventSubmitting => 'Invio…';

  @override
  String get eventSubmitReport => 'Invia segnalazione';

  @override
  String get narrativeBusy => 'Sto scrivendo il tuo racconto…';

  @override
  String get narrativeErrorTitle => 'Impossibile ottenere il racconto';

  @override
  String narrativeGeneratedAt(String when) {
    return 'Generato $when';
  }

  @override
  String get narrativeReadAloud => 'Leggi ad alta voce';

  @override
  String get narrativeStop => 'Ferma';

  @override
  String get historyTitle => 'Viaggi salvati';

  @override
  String get historyEmptyTitle => 'Nessun viaggio salvato';

  @override
  String get historyEmptyBody =>
      'Pianifica un viaggio e tocca il segnalibro per salvarlo qui.';

  @override
  String get historyPlanCta => 'Pianifica un viaggio';

  @override
  String historyDeleted(String trip) {
    return 'Eliminato $trip';
  }

  @override
  String historyReplanFailed(int status) {
    return 'Ripianificazione fallita: $status';
  }

  @override
  String get historyReplanNetworkError =>
      'La connessione è caduta durante la ripianificazione. Controlla il segnale e riprova.';

  @override
  String get retryLabel => 'Riprova';

  @override
  String get historyDeleteTooltip => 'Elimina';

  @override
  String get historyReopenCta => 'Vedi';

  @override
  String get historyRepeatCta => 'Ripeti';

  @override
  String historySavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count salvati',
      one: '1 salvato',
    );
    return '$_temp0';
  }

  @override
  String resultFuelCollapsedHint(int count) {
    return 'Mostra i $count distributori più economici della rotta';
  }

  @override
  String resultBestTimeVsFreeFlow(String delta) {
    return '$delta min vs flusso libero';
  }

  @override
  String resultBestTimeEarlier(int minutes) {
    return '$minutes min prima dell\'orario desiderato';
  }

  @override
  String resultBestTimeLater(int minutes) {
    return '$minutes min dopo l\'orario desiderato';
  }

  @override
  String resultHeroSavedBadge(String magnitude) {
    return '$magnitude risparmiati';
  }

  @override
  String get consistencyNeedsReview => 'Verifica il piano di viaggio';

  @override
  String consistencyNeedsReviewErrors(int errors) {
    return 'Verifica il piano · $errors errori';
  }

  @override
  String consistencyNeedsReviewMixed(int errors, int warnings) {
    return 'Verifica il piano · $errors errore/i, $warnings avviso/i';
  }

  @override
  String consistencyFuelNoStations(String km) {
    return 'Il viaggio è di $km km, ma al momento non vediamo distributori lungo il percorso. Prezzi e suggerimenti di rifornimento non sono disponibili per questa tratta.';
  }

  @override
  String get consistencyFuelNoStationsHint =>
      'I dati potrebbero essere ancora in caricamento. Riprova tra qualche minuto o aggiungi la tua sosta toccando la mappa.';

  @override
  String get consistencyFuelRangeExceeded =>
      'Il tuo veicolo non copre l\'intero percorso con un solo pieno o una sola carica — dovrai rifornirti o ricaricare durante il viaggio.';

  @override
  String consistencyMealBeforeDeparture(String slot, String km) {
    return '$slot è programmato al km $km prima della partenza. Regola l\'orario della sosta o della partenza.';
  }

  @override
  String consistencyMealAfterArrival(String slot, String km) {
    return '$slot è programmato al km $km dopo l\'arrivo. Regola l\'orario della sosta o il ritmo del viaggio.';
  }

  @override
  String consistencyMealImpossibleSpeed(String slot, String km, String kmh) {
    return 'Raggiungere $slot al km $km dalla partenza richiederebbe ~$kmh km/h — impossibile. Rivedi la sosta.';
  }

  @override
  String consistencyMealSuspiciousSpeed(String slot, String km, String kmh) {
    return 'Raggiungere $slot al km $km dalla partenza richiede ~$kmh km/h. Verifica se il ritmo è realistico.';
  }

  @override
  String consistencyMealTooCloseToArrival(String slot, String km, String mins) {
    return '$slot al km $km è molto vicino all\'arrivo ($mins min prima). Meglio mangiare a destinazione.';
  }

  @override
  String consistencySleepBeforeDeparture(String km) {
    return 'Il riposo notturno è programmato prima della partenza (km $km). Controlla l\'orario.';
  }

  @override
  String consistencySleepAfterArrival(String km) {
    return 'Il riposo notturno è programmato dopo l\'arrivo (km $km). Potrebbe non servire.';
  }

  @override
  String consistencySleepImpossibleSpeed(String km, String kmh) {
    return 'Raggiungere il riposo notturno al km $km richiede ~$kmh km/h — impossibile. Rivedi la tratta.';
  }

  @override
  String consistencySleepSuspiciousSpeed(String km, String kmh) {
    return 'Il riposo notturno al km $km implica ~$kmh km/h di media. Verifica il ritmo.';
  }

  @override
  String get mealSlotBreakfastCap => 'Colazione';

  @override
  String get mealSlotLunchCap => 'Pranzo';

  @override
  String get mealSlotDinnerCap => 'Cena';

  @override
  String get consistencyHeadsUp => 'Nota sul tuo piano';

  @override
  String consistencyHeadsUpWarnings(int warnings) {
    return 'Nota sul tuo piano · $warnings avvisi';
  }

  @override
  String consistencyMoreCount(int count) {
    return '+$count altre';
  }

  @override
  String get planProfileClearOverride => 'Annulla modifica';

  @override
  String get weatherSunny => 'Soleggiato';

  @override
  String get weatherPartlyCloudy => 'Parzialmente nuvoloso';

  @override
  String get weatherCloudy => 'Nuvoloso';

  @override
  String get weatherFog => 'Nebbia';

  @override
  String get weatherDrizzle => 'Pioviggine';

  @override
  String get weatherRain => 'Pioggia';

  @override
  String get weatherHeavyRain => 'Pioggia intensa';

  @override
  String get weatherSnow => 'Neve';

  @override
  String get weatherHeavySnow => 'Neve intensa';

  @override
  String get weatherThunderstorm => 'Temporale';

  @override
  String historyBestAt(String when) {
    return 'Ottimale $when';
  }

  @override
  String historyWantedAt(String when) {
    return 'Desiderato $when';
  }

  @override
  String get searchPlaceholder => 'Cerca città, museo, luogo…';

  @override
  String get placesSectionTitle => 'LUOGHI SALVATI';

  @override
  String get placeSaveAsTooltip => 'Salva come luogo';

  @override
  String get placeSaveDialogTitle => 'Salva come…';

  @override
  String get placeCustomLabel => 'Etichetta';

  @override
  String get placeCustomHint => 'Casa, Lavoro, Nonna…';

  @override
  String get placePresetHome => 'Casa';

  @override
  String get placePresetWork => 'Lavoro';

  @override
  String get placePresetSchool => 'Scuola';

  @override
  String get placePresetGym => 'Palestra';

  @override
  String placeSavedAs(String label) {
    return 'Salvato come $label';
  }

  @override
  String get favoritesTabPlaces => 'Luoghi';

  @override
  String get favoritesEmptyPlaces =>
      'Nessun luogo salvato. Tocca la stella su qualsiasi risultato per salvarlo.';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsSectionVehicle => 'Veicolo e percorso';

  @override
  String get settingsSectionAppearance => 'Aspetto';

  @override
  String get settingsSectionAI => 'Personalizzazione IA';

  @override
  String get notifSoundTitle => 'Suono avvisi';

  @override
  String get notifSoundDefault => 'Suono predefinito';

  @override
  String get notifSoundDefaultSub => 'Usa il suono di notifica del sistema';

  @override
  String get notifSoundSilent => 'Silenzioso';

  @override
  String get notifSoundSilentSub => 'Nessun suono per gli avvisi';

  @override
  String get settingsSectionSafety => 'Contatti e sicurezza';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsDensityLabel => 'Densità';

  @override
  String get settingsDensityComfortable => 'Comoda';

  @override
  String get settingsDensityCompact => 'Compatta';

  @override
  String get settingsLanguage => 'Lingua';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsSectionUnits => 'Unità';

  @override
  String get settingsUnitSystem => 'Sistema di unità';

  @override
  String get settingsUnitsMetric => 'Metrico';

  @override
  String get settingsUnitsImperial => 'Imperiale';

  @override
  String get settingsSectionTrip => 'Viaggio';

  @override
  String get settingsRadarAlerts => 'Avvisi autovelox';

  @override
  String get settingsRadarAlertsSubtitle =>
      'Vibrazione e banner quando un autovelox è entro 400 m (Essential+).';

  @override
  String get settingsSectionAbout => 'Info';

  @override
  String get settingsSectionData => 'I tuoi dati';

  @override
  String get settingsExportData => 'Scarica i miei dati';

  @override
  String get settingsExportDataSub =>
      'Ottieni un file JSON con tutto ciò che MyTravelPal detiene su di te.';

  @override
  String get settingsExportError =>
      'Esportazione fallita — controlla la connessione.';

  @override
  String get settingsDeleteAccount => 'Elimina account';

  @override
  String get settingsDeleteAccountSub =>
      'Rimuove profilo, viaggi salvati e preferenze in modo permanente.';

  @override
  String get settingsDeleteAccountConfirmTitle => 'Eliminare l\'account?';

  @override
  String get settingsDeleteAccountConfirmBody =>
      'Elimina il tuo profilo e tutti i viaggi salvati dai nostri server. Azione irreversibile.';

  @override
  String get settingsDeleteAccountCancel => 'Annulla';

  @override
  String get settingsDeleteAccountConfirm => 'Elimina definitivamente';

  @override
  String get settingsDeleteAccountPartial =>
      'Disconnesso localmente, ma il server potrebbe ancora avere dati. Riprova con connessione stabile.';

  @override
  String get settingsDeleteAccountDone => 'Account eliminato. Disconnesso.';

  @override
  String get settingsDeleteAccountInProgress => 'Eliminazione account…';

  @override
  String get settingsSupport => 'Supporto e contatti';

  @override
  String get settingsPrivacyPolicy => 'Informativa privacy';

  @override
  String get settingsTerms => 'Termini del servizio';

  @override
  String get settingsVersion => 'Versione';

  @override
  String get planTooltipSettings => 'Impostazioni';

  @override
  String get styleSectionTitle => 'Ritmo di guida';

  @override
  String get styleSectionEyebrow => 'Come organizzi le tue giornate di guida';

  @override
  String get stylePresetDirect => 'Diretto';

  @override
  String get stylePresetBalanced => 'Equilibrato';

  @override
  String get stylePresetSlow => 'Rilassato';

  @override
  String get stylePresetDirectHint =>
      'Tutto d\'un fiato, poche soste, mai pernottare.';

  @override
  String get stylePresetBalancedHint =>
      'Ritmo naturale, pause quando ha senso.';

  @override
  String get stylePresetSlowHint =>
      'Goditi il viaggio, soste generose, dividi i lunghi trasferimenti.';

  @override
  String get styleCustom => 'Personalizzato';

  @override
  String get styleAdvanced => 'Avanzato';

  @override
  String get stylePaceLabel => 'Ritmo';

  @override
  String get stylePacePush => 'Tirato';

  @override
  String get stylePaceSteady => 'Normale';

  @override
  String get stylePaceSavour => 'Con calma';

  @override
  String get styleOvernightLabel => 'Soste notturne';

  @override
  String get styleOvernightNever => 'Mai';

  @override
  String get styleOvernightIfNeeded => 'Se serve';

  @override
  String get styleOvernightAlwaysIfLong => 'Dividi i viaggi lunghi';

  @override
  String get styleDailyCapLabel => 'Max ore di guida al giorno';

  @override
  String get styleBedtimeLabel => 'Ora di dormire';

  @override
  String get styleWakeLabel => 'Ora di sveglia';

  @override
  String get styleDrivingStartLabel => 'Ora preferita per iniziare a guidare';

  @override
  String get drivingWindowNightStart => 'Guida notturna all\'inizio';

  @override
  String get drivingWindowNightEnd => 'Guida notturna alla fine';

  @override
  String get dayEditKmNoLimit => 'Km max: nessun limite';

  @override
  String dayEditKmCap(int km) {
    return 'Km max: $km km';
  }

  @override
  String dayEditSheetTitle(int day) {
    return 'Regola giorno $day';
  }

  @override
  String get dayEditStartHour => 'Ora di inizio guida';

  @override
  String dayEditMaxDriving(int hours) {
    return 'Ore massime alla guida: $hours h (pause incluse)';
  }

  @override
  String get dayExtendKmTitle => 'Hai più tempo disponibile';

  @override
  String dayExtendKmBody(String extraKm) {
    return 'Con questo orario potresti percorrere +$extraKm km in più. Estendere la giornata o mantenere il percorso attuale?';
  }

  @override
  String get dayExtendKmKeep => 'Mantieni percorso attuale';

  @override
  String dayExtendKmAdjust(String extraKm) {
    return 'Estendi la giornata (+$extraKm km)';
  }

  @override
  String get dayReduceKmTitle => 'Tempo di guida ridotto';

  @override
  String dayReduceKmBody(String reducedKm) {
    return 'Con questo orario raggiungerai circa $reducedKm km. Vuoi regolare il limite di km?';
  }

  @override
  String get dayReduceKmKeep => 'Mantieni km attuali';

  @override
  String dayReduceKmAdjust(String reducedKm) {
    return 'Regola a $reducedKm km';
  }

  @override
  String dayEditEndHour(String time) {
    return 'Fine guida alle $time';
  }

  @override
  String get dayEditPickTime => 'Scegli orario';

  @override
  String get dayEditEndTimePicker => 'Ora di fine guida';

  @override
  String get dayEditSave => 'Applica';

  @override
  String get dayEditCancel => 'Annulla';

  @override
  String get dayEditReset => 'Ripristina';

  @override
  String get resultReplanning => 'Ricalcolo in corso...';

  @override
  String get styleBreakLabel => 'Stile di sosta';

  @override
  String get styleBreakMinimal => 'Minimo';

  @override
  String get styleBreakScenic => 'Panoramico';

  @override
  String get styleBreakFoodie => 'Gastronomico';

  @override
  String planStyleChip(String preset, int hours) {
    return '$preset · ${hours}h/g';
  }

  @override
  String planStyleChipCustom(int hours) {
    return 'Personalizzato · ${hours}h/g';
  }

  @override
  String get planStyleOverrideTitle => 'Stile per questo viaggio';

  @override
  String get planStyleOverrideSubtitle =>
      'Sovrascrive il profilo salvato solo per questo piano.';

  @override
  String get planStyleUseSavedProfile => 'Usa il mio profilo salvato';

  @override
  String arrivalHintTitle(String hour) {
    return 'Arriveresti alle $hour:00';
  }

  @override
  String arrivalHintBody(String bedtime) {
    return 'Più tardi della tua ora di dormire ($bedtime:00). Considera una sosta notturna — hotel sotto.';
  }

  @override
  String get arrivalHintCta => 'Vedi hotel';

  @override
  String get vehicleTypeCar => 'Auto';

  @override
  String get vehicleTypeMotorbike => 'Moto';

  @override
  String get vehicleTypeVan => 'Furgone';

  @override
  String get vehicleTypeCamper => 'Camper';

  @override
  String get fuelTypePetrol => 'Benzina';

  @override
  String get fuelTypeDiesel => 'Diesel';

  @override
  String get fuelTypeHybrid => 'Ibrido';

  @override
  String get fuelTypeElectric => 'Elettrico';

  @override
  String get fuelTypeLpg => 'GPL';

  @override
  String get routeVariantFastest => 'Più veloce';

  @override
  String get routeVariantTollFree => 'Senza pedaggi';

  @override
  String get routeVariantScenic => 'Panoramico';

  @override
  String get eventTypeFire => 'Incendio';

  @override
  String get eventTypeStrike => 'Sciopero';

  @override
  String get eventTypeWeather => 'Maltempo';

  @override
  String get eventTypeAccident => 'Incidente';

  @override
  String get eventTypeRoadwork => 'Lavori in corso';

  @override
  String get eventTypeFlood => 'Alluvione';

  @override
  String get eventTypeSnow => 'Neve';

  @override
  String get eventTypeProtest => 'Manifestazione';

  @override
  String get eventTypeEarthquake => 'Terremoto';

  @override
  String get eventTypeLandslide => 'Frana';

  @override
  String get eventTypeAvalanche => 'Valanga';

  @override
  String get eventTypeClosure => 'Strada chiusa';

  @override
  String get eventTypeHeatwave => 'Ondata di calore';

  @override
  String get eventTypeHeavyRain => 'Pioggia forte';

  @override
  String get eventTypeHail => 'Grandine';

  @override
  String get eventTypeThunderstorm => 'Temporale';

  @override
  String get eventTypeHighWind => 'Vento forte';

  @override
  String get eventTypeDenseFog => 'Nebbia fitta';

  @override
  String get eventTypeFreezingRain => 'Pioggia gelata';

  @override
  String get eventTypeOther => 'Altro';

  @override
  String tollStretchLabel(int index, int total) {
    return 'Tratto a pedaggio $index / $total';
  }

  @override
  String tollBoothLabel(int index) {
    return 'Casello $index';
  }

  @override
  String get addedToRouteLabel => 'AGGIUNTO';

  @override
  String get replanWithStops => 'Ricalcola percorso con soste';

  @override
  String get addToRouteTooltip => 'Aggiungi al percorso';

  @override
  String get removeFromRouteTooltip => 'Rimuovi dal percorso';

  @override
  String addedStopsChip(int count, String minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count soste aggiunte · +$minutes min',
      one: '1 sosta aggiunta · +$minutes min',
    );
    return '$_temp0';
  }

  @override
  String get addedStopsClear => 'Rimuovi';

  @override
  String get settingsLicensesAndData => 'Licenze e fonti dati';

  @override
  String get settingsLicensesAndDataSub =>
      'Attribuzioni dei dati aperti e delle librerie';

  @override
  String get attributionsTitle => 'Licenze e dati';

  @override
  String get attributionsIntro =>
      'MyTravelPal si basa su dati aperti e librerie open-source. Questa schermata cita ogni fonte, rimanda alle licenze e copre gli obblighi di attribuzione.';

  @override
  String get attributionsSectionMap => 'Mappa e geodati';

  @override
  String get attributionsSectionFuel => 'Prezzi carburanti';

  @override
  String get attributionsSectionHazards => 'Eventi avversi';

  @override
  String get attributionsSectionWeather => 'Meteo';

  @override
  String get attributionsSectionSoftware => 'Librerie software';

  @override
  String get attributionsShowLicenses => 'Mostra licenze dei pacchetti';

  @override
  String get attributionsFailed =>
      'Impossibile caricare le attribuzioni. Riprova.';

  @override
  String get fuelPriceUnavailable => 'Prezzo non disponibile';

  @override
  String get fuelPriceUnavailableHint =>
      'Nessun feed pubblico di prezzi per questo paese al momento';

  @override
  String get planSectionOptionalEyebrow => 'Opzionale';

  @override
  String get planOptAlertsTitle => 'Avvisami di eventi critici sul percorso';

  @override
  String get planOptAlertsSub =>
      'Incendi, alluvioni, maltempo estremo e pericoli gravi entro 25 km dal percorso.';

  @override
  String get planOptTollFreeTitle => 'Mostra alternativa senza pedaggi';

  @override
  String get planOptTollFreeSub =>
      'Confronta un percorso senza pedaggi — soldi risparmiati vs. minuti aggiunti.';

  @override
  String get planOptHourlyTollTitle => 'Analisi oraria dei pedaggi';

  @override
  String get planOptHourlyTollSub =>
      'Quando durante la giornata evitare i pedaggi conviene davvero (traffico incluso).';

  @override
  String get planOptRouteVariantsTitle => 'Confronta varianti di percorso';

  @override
  String get planOptRouteVariantsSub =>
      'Più veloce vs. senza pedaggi vs. panoramico — tutti e tre affiancati.';

  @override
  String get planOptAvoidMotorwaysTitle => 'Evita autostrade';

  @override
  String get planOptAvoidMotorwaysSub =>
      'Più lento e più lungo, ma senza pedaggi e più tranquillo.';

  @override
  String get planOptPreferScenicTitle => 'Preferisci panoramico';

  @override
  String get planOptPreferScenicSub =>
      'Predilige strade più interessanti. Un po\' più lento.';

  @override
  String get planPremiumBadge => 'Premium';

  @override
  String planProfileTravellers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count viaggiatori',
      one: '1 viaggiatore',
    );
    return '$_temp0';
  }

  @override
  String get planProfileWithKids => 'bambini';

  @override
  String get planProfileWithPets => 'animali';

  @override
  String get planProfileOverrideActive => 'SOSTITUZIONE ATTIVA';

  @override
  String get planProfileOverride => 'Sostituisci per questo viaggio';

  @override
  String get planProfileOverriding => 'Sostituendo per questo viaggio';

  @override
  String get profilePromptSetup => 'Configura il tuo profilo di viaggio';

  @override
  String get hotelPrefTitle => 'Cerca hotel vicino alle soste';

  @override
  String get hotelPrefSubOn =>
      'Mostra opzioni di alloggio vicino a ogni punto di pernottamento';

  @override
  String get hotelPrefSubOff => 'Disattivato';

  @override
  String get restaurantPrefTitle => 'Aggiungi ristoranti lungo il percorso';

  @override
  String restaurantPrefSubEnabled(int minutes, String band) {
    return 'Fino a $minutes min di deviazione · $band';
  }

  @override
  String get restaurantPrefSubOff =>
      'Disattivato. Attiva per vedere ristoranti vicino al percorso.';

  @override
  String prefMaxDetour(int minutes) {
    return 'Deviazione max: $minutes min';
  }

  @override
  String get prefBandBudget => 'Economico';

  @override
  String get prefBandMid => 'Medio';

  @override
  String get prefBandLuxury => 'Lusso';

  @override
  String get prefBandAny => 'Tutti';

  @override
  String get mealSlotBreakfast => 'Consigliati per colazione';

  @override
  String get mealSlotLunch => 'Consigliati per pranzo';

  @override
  String get mealSlotDinner => 'Consigliati per cena';

  @override
  String get mealSlotOther => 'Altri ristoranti';

  @override
  String poiDistanceKm(String km, String minutes) {
    return '$km km · +$minutes min di deviazione';
  }

  @override
  String fuelSavingsChipCheap(String amount) {
    return '-$amount€/L vs media paese';
  }

  @override
  String fuelSavingsChipDear(String amount) {
    return '+$amount€/L vs media paese';
  }

  @override
  String get fuelArbitrageTitle => 'Rifornisci strategico su questo percorso';

  @override
  String fuelArbitrageBody(String cheap, String cheapPrice, String dear,
      String dearPrice, String savings) {
    return 'Il carburante in $cheap è a ~$cheapPrice€/L. In $dear sale a ~$dearPrice€/L. Fare il pieno in $cheap prima di attraversare fa risparmiare ~$savings€.';
  }

  @override
  String dayTabLabel(int index) {
    return 'Giorno $index';
  }

  @override
  String dayHeaderRange(int index, String fromKm, String toKm) {
    return 'Giorno $index · km $fromKm → $toKm';
  }

  @override
  String dayHeaderCity(int index, String from, String to) {
    return 'Giorno $index · $from → $to';
  }

  @override
  String dayArrivalMarker(String time) {
    return 'Arrivo a destinazione verso le $time';
  }

  @override
  String daySleepMarker(String time) {
    return 'Fine guida verso le $time';
  }

  @override
  String dayStartsAt(String time) {
    return 'Partenza alle $time';
  }

  @override
  String dayDriveWindow(String start, String end) {
    return '$start → $end';
  }

  @override
  String get restStopWhyTitle => 'Perché questa sosta?';

  @override
  String get restStopWhyKidFriendly => 'Area di servizio adatta ai bambini';

  @override
  String get restStopWhyPetFriendly => 'Zona per cani / animali vicina';

  @override
  String get restStopWhyRvFriendly =>
      'Compatibile con camper (sanitario / scarico)';

  @override
  String restStopWhySafety(String hours) {
    return 'Consigliata per la sicurezza stradale: guidi da ${hours}h. Il regolamento UE 561/2006 suggerisce una pausa di almeno 45 min dopo 4h30 alla guida.';
  }

  @override
  String get restStopWhyClose => 'Ho capito';

  @override
  String dayMealStopAt(String time, String name) {
    return '🍽 $time · $name';
  }

  @override
  String dayRestStopAt(String time, String label) {
    return '☕ $time · $label';
  }

  @override
  String get restStopFilterAll => 'Tutti';

  @override
  String get restStopFilterKidFriendly => 'Per famiglie';

  @override
  String get restStopFilterPetFriendly => 'Pet-friendly';

  @override
  String get restStopFilterRvFriendly => 'Camper';

  @override
  String dayHeaderDwell(int index, String place) {
    return 'Giorno $index · $place';
  }

  @override
  String daySleepStay(String place) {
    return 'Soggiorno a $place';
  }

  @override
  String get nextStopHeroLabel => 'Prossima sosta suggerita';

  @override
  String nextStopHeroBody(String slot, String name, String time) {
    return '$slot a $name · verso le $time';
  }

  @override
  String get daySleepHotelsLabel => 'Hotel vicino alla sosta notturna';

  @override
  String hotelDistFromStop(String km) {
    return '$km km dalla sosta';
  }

  @override
  String hotelDistFromDestination(String km) {
    return '$km km dalla destinazione';
  }

  @override
  String get daySleepHotelsLabelDestination => 'Hotel vicino alla destinazione';

  @override
  String get daySleepHotelsEmpty =>
      'Attiva gli hotel nelle preferenze per vedere opzioni di pernottamento.';

  @override
  String get daySleepHotelsNotFound =>
      'Nessun hotel trovato vicino a questo percorso con le tue preferenze attuali.';

  @override
  String get noHotelsAdjustPrefs => 'Modifica preferenze';

  @override
  String get noRestaurantsAdjustPrefs =>
      'Nessun ristorante trovato con le tue preferenze attuali.';

  @override
  String get companionAssistantTitle => 'Assistente companion';

  @override
  String get settingsAiPersonalisation => 'Personalizzazione IA';

  @override
  String get companionAskHint => 'Chiedi qualcosa…';

  @override
  String get companionSend => 'Invia';

  @override
  String get companionGroupJoin => 'Unisciti come passeggero';

  @override
  String get companionJoin => 'Unisciti';

  @override
  String get resultFuelSavingsTitle => 'Carburante economico sul percorso';

  @override
  String get daySleepHotelsSearching => 'Cerco hotel vicino alla tua sosta...';

  @override
  String get enrichmentLoadingTitle => 'Caricamento extra';

  @override
  String get enrichmentChipHotels => 'Hotel';

  @override
  String get enrichmentChipRestaurants => 'Ristoranti';

  @override
  String get enrichmentChipFuel => 'Stazioni di servizio';

  @override
  String get enrichmentChipWeather => 'Meteo';

  @override
  String get enrichmentChipAdverse => 'Avvisi';

  @override
  String get enrichPulseHeader => 'In questo momento…';

  @override
  String get enrichPulseHotels =>
      'Ricerca hotel col miglior rapporto prezzo/stelle';

  @override
  String get enrichPulseRestaurants =>
      'Filtro dei ristoranti in base alle tue preferenze';

  @override
  String get enrichPulseFuel => 'Localizzazione dei distributori più economici';

  @override
  String get enrichPulseTolls =>
      'Individuazione dei pedaggi evitabili senza deviazione';

  @override
  String get enrichPulseWindows => 'Confronto orari per traffico previsto';

  @override
  String get enrichPulseWeather => 'Previsione orario su 5 tratti della rotta';

  @override
  String get enrichPulseAdverse =>
      'Incroci con incendi e terremoti attivi sul tuo percorso';

  @override
  String get enrichPulseKids => 'Aree di sosta con parco giochi vicine';

  @override
  String get enrichPulsePets => 'Localizzazione aree cani e soste pet-friendly';

  @override
  String get enrichPulseCamper => 'Aree camper con scarico e servizi igienici';

  @override
  String enrichPulseVehicleEv(String vehicle, String tank) {
    return 'Pianificando le ricariche per la tua $vehicle ($tank kWh)';
  }

  @override
  String enrichPulseVehicle(String vehicle, String tank) {
    return 'Calcolo rifornimento per il tuo $vehicle ($tank L)';
  }

  @override
  String get restStopsWidenedHint =>
      'Nessuna sosta corrisponde al filtro; mostriamo le migliori sul tratto.';

  @override
  String get windowsSheetTitle => 'Finestre di partenza';

  @override
  String get windowsSheetHint =>
      'Tocca una scheda per ripianificare con quella partenza.';

  @override
  String get windowsSheetOpen => 'Dettaglio orario';

  @override
  String get windowsBadgeCurrent => 'Attuale';

  @override
  String get windowsBadgeRecommended => 'Consigliata';

  @override
  String get windowsMetaDuration => 'Durata';

  @override
  String get windowsMetaArrival => 'Arrivo';

  @override
  String get windowsMetaTraffic => 'Traffico';

  @override
  String get trafficLight => 'Leggero';

  @override
  String get trafficMedium => 'Moderato';

  @override
  String get trafficDense => 'Intenso';

  @override
  String get todEarlyMorning => 'Prima mattina';

  @override
  String get todMorning => 'Mattina';

  @override
  String get todNoon => 'Mezzogiorno';

  @override
  String get todAfternoon => 'Pomeriggio';

  @override
  String get todNight => 'Notte';

  @override
  String get restaurantPrefCuisinesLabel => 'Tipo di cucina';

  @override
  String get cuisineItalian => 'Italiana';

  @override
  String get cuisineSpanish => 'Spagnola';

  @override
  String get cuisineTapas => 'Tapas';

  @override
  String get cuisineFrench => 'Francese';

  @override
  String get cuisineMediterranean => 'Mediterranea';

  @override
  String get cuisineAsian => 'Asiatica';

  @override
  String get cuisineIndian => 'Indiana';

  @override
  String get cuisineBurger => 'Hamburger';

  @override
  String get cuisineSeafood => 'Pesce / frutti di mare';

  @override
  String get cuisineVegetarian => 'Vegetariana';

  @override
  String get cuisineBbq => 'Grigliate / BBQ';

  @override
  String get cuisineRegional => 'Regionale';

  @override
  String timeWindowSpanLabel(int hours) {
    return 'Mostra ±${hours}h';
  }

  @override
  String get timeWindowSpanHelper =>
      'Trascina per allargare la finestra e vedere se partire prima o dopo fa risparmiare più tempo.';

  @override
  String get timeWindowTapHint =>
      'Tocca una barra per ricalcolare con quell\'orario di partenza.';

  @override
  String get planLoadingRecalculating => 'Ricalcolo con le tue impostazioni...';

  @override
  String get planLoadingTitle => 'Sto preparando il tuo viaggio';

  @override
  String get planLoadingStepRouting => 'Calcolo del percorso più veloce…';

  @override
  String get planLoadingStepTraffic =>
      'Analisi del traffico per l\'ora di partenza migliore…';

  @override
  String get planLoadingStepFuel => 'Recupero prezzi reali del carburante…';

  @override
  String get planLoadingStepHotels => 'Cerco hotel vicino alle soste notturne…';

  @override
  String get planLoadingStepRestaurants =>
      'Ordino i ristoranti per fascia oraria e cucina…';

  @override
  String get planLoadingStepAlerts =>
      'Rilevo incendi, alluvioni, maltempo estremo e pericoli…';

  @override
  String get planLoadingStepTolls => 'Confronto percorsi con pedaggio e senza…';

  @override
  String get planLoadingStepAlmost => 'Quasi pronto — sto assemblando tutto…';

  @override
  String get planLoadingHelper =>
      'Può richiedere qualche minuto. Puoi mettere via il telefono.';

  @override
  String timeWindowApplyLabel(String time) {
    return 'Applica · partenza alle $time';
  }

  @override
  String get planErrorAuth => 'Sessione scaduta. Accedi di nuovo e riprova.';

  @override
  String get planErrorPremium =>
      'Questo percorso richiede Premium. Attivalo per includere l\'analisi pedaggi per ora.';

  @override
  String get planErrorRateLimit =>
      'Troppe richieste in poco tempo. Attendi qualche secondo e riprova.';

  @override
  String planErrorGeneric(int code) {
    return 'Qualcosa è andato storto durante la pianificazione (codice $code). Riprova o modifica i dati.';
  }

  @override
  String get planErrorNetwork =>
      'Non siamo riusciti a raggiungere il server. Controlla la connessione e riprova.';

  @override
  String get planErrorRetry => 'Riprova';

  @override
  String get emptyAlertsTitle => 'Nessun pericolo grave rilevato';

  @override
  String get emptyAlertsBody =>
      'Nessun incendio, alluvione o pericolo grave sul tuo corridoio. Buon viaggio.';

  @override
  String get emptyHotelsTitle => 'Nessun hotel vicino al percorso';

  @override
  String get emptyHotelsBody =>
      'Prova ad ampliare la deviazione massima o a cambiare fascia di prezzo.';

  @override
  String get emptyRestaurantsTitle => 'Nessun ristorante corrisponde';

  @override
  String get emptyRestaurantsBody =>
      'Amplia la deviazione massima o rimuovi i filtri di cucina.';

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
  String get onboardEyebrowFuel => 'PEDAGGI E CARBURANTE';

  @override
  String get onboardTitleFuel =>
      'Saltare questo pedaggio?\nFare il pieno prima della Francia?';

  @override
  String get onboardBodyFuel =>
      'Mostriamo quali pedaggi conviene evitare in base all\'ora, e quale stazione sul percorso ha il prezzo migliore adesso.';

  @override
  String get onboardEyebrowDriving => 'CO-PILOTA IA · PREMIUM';

  @override
  String get onboardTitleDriving => '\"Faccio il pieno\nqui o aspetto?\"';

  @override
  String get onboardBodyDriving =>
      'Conosce il percorso, il serbatoio e i prossimi prezzi. Risponde in secondi. Funziona con Android Auto. (Premium)';

  @override
  String get onboardEyebrowProfile => 'PERSONALIZZATO';

  @override
  String get onboardTitleProfile => 'Compila il tuo profilo';

  @override
  String get onboardBodyProfile =>
      'Senza profilo ottimizziamo solo il tempo. Con profilo calcoliamo carburante reale, hotel e pasti su misura.';

  @override
  String get onboardTollSkip => 'Evitarlo';

  @override
  String get onboardTollSavingsAmt => 'risparmia €8';

  @override
  String get onboardTollPay => 'Pagarlo';

  @override
  String get onboardTollPeakTime => 'Picco 08:00-10:00';

  @override
  String get onboardFuelStationsTitle => 'Stazioni di servizio sul percorso';

  @override
  String get onboardProfileGroup => '2 adulti + 1 bambino';

  @override
  String get onboardProfilePet => 'Cane';

  @override
  String get onboardProfileParking => 'Parking';

  @override
  String get onboardProfileStars => '3+ stelle';

  @override
  String get onboardProfileBudget => 'Max. €€';

  @override
  String get onboardCompanionNextStop => 'Prossima tappa';

  @override
  String get onboardCompanionTank => 'Serbatoio';

  @override
  String get onboardAlertFire =>
      'Incendio boschivo · km 214 · 14 km dal percorso';

  @override
  String get onboardAlertSevere => 'GRAVE';

  @override
  String get onboardAlertStorm => 'Tempesta forte · Girona · tra 2h';

  @override
  String get onboardAlertWarning => 'AVVISO';

  @override
  String get onboardCompanionQuestion => 'Mi fermo a fare benzina o aspetto?';

  @override
  String get onboardCompanionFuelStation => 'Eni · km 387 — 1.52 €/L';

  @override
  String get onboardCompanionFuelAdvice =>
      'La prossima stazione a 58 km costa 1,79 €/L.\nIl tuo serbatoio attuale è più che sufficiente.';

  @override
  String get onboardFuelStation1 => 'Eni · km 387';

  @override
  String get onboardFuelStation2 => 'IP Autostrada · km 412';

  @override
  String get onboardFuelStation3 => 'Shell A1 · km 445';

  @override
  String get onboardHotelName => 'Hotel Roma ★★★';

  @override
  String get onboardHotelMeta => '€85/notte · 0.8 km';

  @override
  String get onboardHotelAttrs => 'Parking ✓  Cani ✓';

  @override
  String get onboardRestaurantName => 'Il Vecchio Mulino';

  @override
  String get onboardRestaurantMeta => '€14/menù · 2 min';

  @override
  String get onboardRestaurantAttrs => 'Terrazza ✓  Cani ✓';

  @override
  String get multiDaySleepLabel => 'Dormirai a';

  @override
  String get multiDaySleepNoHotel => 'Sosta notte — nessun hotel disponibile';

  @override
  String get resumeTripTitle => 'Riprendere il viaggio?';

  @override
  String resumeTripBody(String origin, String destination) {
    return 'Abbiamo rilevato un viaggio $origin → $destination in corso. Riprendere da dove hai lasciato?';
  }

  @override
  String get resumeTripResume => 'Riprendi';

  @override
  String get resumeTripDismiss => 'Ignora';

  @override
  String get hotelPrefStarsLabel => 'Stelle';

  @override
  String get hotelPrefDestRadiusLabel => 'Raggio dalla destinazione';

  @override
  String get biometricPromptReason =>
      'Verifica l\'identità per aprire MyTravelPal';

  @override
  String get biometricPromptSettings =>
      'Conferma per attivare lo sblocco biometrico';

  @override
  String get planDepartureLabel => 'Partenza preferita';

  @override
  String get hotelPrefStarsAny => 'Tutte';

  @override
  String get hotelPrefParkingTitle => 'Con parcheggio';

  @override
  String get hotelPrefParkingSub =>
      'Solo hotel taggati con parcheggio. Quelli senza tag passano.';

  @override
  String get hotelFilterParking => 'Parcheggio';

  @override
  String get hotelFilterWifi => 'WiFi gratuito';

  @override
  String get hotelFilterAccessible => 'Accessibile';

  @override
  String get hotelFilterOtherTypes => 'Appartamenti, case e altro';

  @override
  String get restaurantFilterVegetarian => 'Vegetariano';

  @override
  String get restaurantFilterVegan => 'Vegano';

  @override
  String get restaurantFilterGlutenFree => 'Senza glutine';

  @override
  String get restaurantFilterHalal => 'Halal';

  @override
  String get restaurantFilterKosher => 'Kosher';

  @override
  String get restaurantDietaryLabel => 'Dieta';

  @override
  String get tollSkipSelectAll => 'Seleziona tutto';

  @override
  String get mapShowLabel => 'Mostra mappa';

  @override
  String get mapHideLabel => 'Nascondi mappa';

  @override
  String get tripCostTitle => 'COSTO TOTALE DEL VIAGGIO';

  @override
  String get tripCostFuel => 'Carburante';

  @override
  String get tripCostTolls => 'Pedaggi';

  @override
  String get tripCostMeals => 'Pasti';

  @override
  String get tripCostHotel => 'Hotel';

  @override
  String get tripCostTotal => 'Totale stimato';

  @override
  String tripCostPerPerson(String amount) {
    return '$amount / persona';
  }

  @override
  String tripCostPerDay(String amount) {
    return '$amount / giorno';
  }

  @override
  String get poiSpotlightRating => 'valutazione';

  @override
  String get poiSpotlightStars => 'stelle';

  @override
  String poiSpotlightReviews(String count) {
    return '$count recensioni';
  }

  @override
  String get poiSpotlightPricePerNight => 'a notte';

  @override
  String get poiSpotlightPricePerMeal => 'a pasto';

  @override
  String get poiSpotlightPricePerL => 'al litro';

  @override
  String get poiFeaturesHeading => 'Servizi';

  @override
  String get poiMoreInfoLabel => 'Altre info';

  @override
  String get poiMoreInfoHide => 'Nascondi';

  @override
  String get poiNoExtraInfo => 'Nessuna info OSM aggiuntiva per questo luogo.';

  @override
  String poiOpenError(String url) {
    return 'Impossibile aprire $url';
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
  String get poiCtaCall => 'Chiama';

  @override
  String get poiCtaWebsite => 'Sito web';

  @override
  String get poiContactAddress => 'Indirizzo';

  @override
  String get poiContactPhone => 'Telefono';

  @override
  String get poiContactWebsite => 'Sito web';

  @override
  String get poiContactHours => 'Orario';

  @override
  String get poiContactCheckin => 'Check-in';

  @override
  String get poiContactCheckout => 'Check-out';

  @override
  String get poiAttr_wifi => 'WiFi';

  @override
  String get poiAttr_parking => 'Parcheggio';

  @override
  String get poiAttr_pool => 'Piscina';

  @override
  String get poiAttr_airConditioning => 'Aria condizionata';

  @override
  String get poiAttr_breakfast => 'Colazione inclusa';

  @override
  String get poiAttr_petFriendly => 'Animali ammessi';

  @override
  String get poiAttr_childFriendly => 'Per bambini';

  @override
  String get poiAttr_wheelchairAccess => 'Accessibile sedia a rotelle';

  @override
  String get poiAttr_toilets => 'Toilette';

  @override
  String get poiAttr_restaurant => 'Ristorante';

  @override
  String get poiAttr_bar => 'Bar';

  @override
  String get poiAttr_shop => 'Negozio';

  @override
  String get poiAttr_outdoorSeating => 'Terrazza';

  @override
  String get poiAttr_takeaway => 'Da asporto';

  @override
  String get poiAttr_delivery => 'Consegna';

  @override
  String get poiAttr_creditCards => 'Carte accettate';

  @override
  String get poiAttr_carWash => 'Lavaggio auto';

  @override
  String get poiAttr_smoking => 'Area fumatori';

  @override
  String get poiAttr_nonSmoking => 'Non fumatori';

  @override
  String get poiAttr_elevator => 'Ascensore';

  @override
  String get poiAttr_checkIn => 'Check-in';

  @override
  String get poiAttr_checkOut => 'Check-out';

  @override
  String get poiAttr_dietVegetarian => 'Vegetariano';

  @override
  String get poiAttr_dietVegan => 'Vegano';

  @override
  String get poiAttr_dietHalal => 'Halal';

  @override
  String get poiAttr_dietKosher => 'Kosher';

  @override
  String get poiAttr_dietGlutenFree => 'Senza glutine';

  @override
  String get poiAttr_dog => 'Animali benvenuti';

  @override
  String get poiAttr_brand => 'Marca';

  @override
  String get poiAttr_city => 'Città';

  @override
  String get poiAttr_street => 'Via';

  @override
  String get poiAttr_address => 'Indirizzo';

  @override
  String get poiAttr_openingHours => 'Orari di apertura';

  @override
  String get poiAttr_name => 'Nome';

  @override
  String get poiAttr_phone => 'Telefono';

  @override
  String get poiAttr_stars => 'Stelle';

  @override
  String get poiAttr_website => 'Sito web';

  @override
  String get poiPickerChoose => 'Scegli';

  @override
  String get poiPickerSelected => 'Selezionato';

  @override
  String get poiPickerHotels => 'Vedi alternative';

  @override
  String get poiPickerRestaurants => 'Vedi ristoranti vicini';

  @override
  String get addToRouteLabel => 'Aggiungi al percorso';

  @override
  String get biometricSetupTitle => 'Attivare la biometria?';

  @override
  String get biometricSetupBody => 'Sblocca MyTravelPal con impronta o volto.';

  @override
  String get biometricSetupEnable => 'Attiva';

  @override
  String get biometricSetupSkip => 'Non ora';

  @override
  String get weatherAlongRouteTitle => 'METEO SUL TUO PERCORSO';

  @override
  String get weatherNoData =>
      'Nessun dato meteo disponibile per questo percorso';

  @override
  String get weatherAllClear => 'Nessun avviso';

  @override
  String get fuelNotificationTitle => 'Fai il pieno prima del confine!';

  @override
  String fuelNotificationBody(
      String cheap, String price, String pricey, String savings) {
    return 'Carburante in $cheap (~$price€/L) prima di $pricey — risparmi ~$savings€/serbatoio';
  }

  @override
  String get tutorialSkip => 'Salta';

  @override
  String get tutorialOriginTitle => 'Da dove parti?';

  @override
  String get tutorialOriginBody =>
      'Tocca qui per cercare una città o usa il pulsante di posizione per partire da dove sei.';

  @override
  String get tutorialDestinationTitle => 'Dove vai?';

  @override
  String get tutorialDestinationBody =>
      'Cerca la tua destinazione. Pianificheremo il percorso completo con soste, hotel e pedaggi.';

  @override
  String get tutorialPrefsTitle => 'Personalizza il tuo viaggio';

  @override
  String get tutorialPrefsBody =>
      'Attiva hotel, ristoranti e allerte. Imposta preferenze alimentari, stelle e altro.';

  @override
  String get tutorialTimeWindowTitle => 'Scegli la migliore ora di partenza';

  @override
  String get tutorialTimeWindowBody =>
      'Tocca una riga per ripianificare con quell\'orario. Il grafico mostra l\'impatto del traffico per ora.';

  @override
  String get tutorialTollTitle => 'Gestisci i pedaggi';

  @override
  String get tutorialTollBody =>
      'Attiva o disattiva i singoli tratti di pedaggio. Il risparmio totale si aggiorna in tempo reale.';

  @override
  String styleDailyCapRecommendedHint(int hours) {
    return 'Per questo ritmo consigliamo $hours h/giorno.';
  }

  @override
  String get aaCoachTitle => 'Come aprirla su Android Auto';

  @override
  String get aaCoachStep1 =>
      'Collega il telefono all\'auto via USB (o wireless se l\'auto lo supporta).';

  @override
  String get aaCoachStep2 =>
      'Nel launcher, passa alla categoria \'Point of Interest\' o \'App\'. NON appare accanto a Google Maps.';

  @override
  String get aaCoachStep3 =>
      'Tocca MyTravelPal. Il companion mostra prossima sosta, carburante più economico e arrivo.';

  @override
  String get aaCoachHint =>
      'Il primo avvio richiede qualche secondo. Parcheggia con vista libera al cielo per prendere il GPS.';

  @override
  String get aaCoachDontShowAgain => 'Non mostrare più';

  @override
  String get aaCoachDone => 'Capito';

  @override
  String get batteryWhitelistTitle => 'Evita che Android ci chiuda';

  @override
  String get batteryWhitelistBody =>
      'Xiaomi/MIUI, Samsung e altri produttori chiudono le app in background dopo alcuni minuti. Se stai navigando con Google Maps e MyTravelPal muore, perdi gli avvisi live.';

  @override
  String get batteryWhitelistSteps =>
      'Impostazioni → App → MyTravelPal → Batteria → Nessuna restrizione\n(o \'Non ottimizzare\' secondo il modello)';

  @override
  String get batteryWhitelistDontShowAgain => 'Non mostrare più';

  @override
  String get batteryWhitelistLater => 'Non ora';

  @override
  String get batteryWhitelistOpen => 'Apri guida';

  @override
  String get planRoundTripTitle => 'Andata e ritorno';

  @override
  String get planRoundTripSubtitle =>
      'Pianifichiamo il ritorno insieme con le stesse preferenze.';

  @override
  String get roundTripLegOutbound => 'ANDATA';

  @override
  String get roundTripLegReturn => 'RITORNO';

  @override
  String roundTripSwapTo(String leg) {
    return 'Vedi $leg';
  }

  @override
  String get resultStartTrip => 'Inizia il viaggio';

  @override
  String get resultStartCompanion => 'Avvia Assistente di guida (Premium)';

  @override
  String get companionPreflightTitle => 'Impostazioni pre-guida';

  @override
  String get companionPreflightMealWindows => 'Orari dei pasti';

  @override
  String get companionPreflightDetourTolerance => 'Deviazione max';

  @override
  String get companionPreflightMealBudget => 'Budget per pasto';

  @override
  String get companionPreflightHotelBudget => 'Budget per notte';

  @override
  String get companionPreflightSaveToProfile => 'Salva nel mio profilo';

  @override
  String get companionPreflightStart => 'Inizia a guidare';

  @override
  String get companionPreflightBreakfast => 'Colazione';

  @override
  String get companionPreflightLunch => 'Pranzo';

  @override
  String get companionPreflightDinner => 'Cena';

  @override
  String get navPickerTitle => 'Continua su…';

  @override
  String get tripDashboardTitle => 'In viaggio';

  @override
  String get tripDashboardCenterOnMe => 'Centra sulla mia posizione';

  @override
  String get tripDashboardOpenNav => 'Apri navigazione';

  @override
  String tripDashboardNextStopLabel(String slot) {
    return 'PROSSIMA $slot';
  }

  @override
  String tripDashboardInMinutes(int n) {
    return 'tra $n min';
  }

  @override
  String get tripDashboardPermissionDenied =>
      'Posizione negata. Concedi il permesso per vedere la tua posizione sul percorso.';

  @override
  String get tripDashboardServiceDisabled =>
      'GPS spento. Attivalo per seguire il tuo progresso.';

  @override
  String tripDashboardProgressLine(String done, String total) {
    return '$done / $total km';
  }

  @override
  String tripDashboardEta(String time) {
    return 'Arrivo $time';
  }

  @override
  String get tripDashboardActiveNotifTitle => 'Viaggio in corso';

  @override
  String get tripDashboardActiveNotifBody =>
      'MyTravelPal segue il tuo percorso in background.';

  @override
  String tripDashboardForegroundBodyBare(String done, String total) {
    return '$done / $total km percorsi';
  }

  @override
  String tripDashboardForegroundBodyWithStop(
      String done, String total, String name) {
    return '$done / $total km · prossima sosta: $name';
  }

  @override
  String get tripDashboardSleepStopLabel => 'hotel';

  @override
  String get alertApproachingStopTitle => 'Sosta in arrivo';

  @override
  String alertApproachingStopBody(String slot, String name, int mins) {
    return '$slot a $name tra circa $mins min. Preparati all\'uscita.';
  }

  @override
  String get alertNewAdverseAheadTitle => 'Nuovo avviso sul percorso';

  @override
  String alertNewAdverseAheadBody(String type, String km) {
    return '$type segnalato a $km km davanti.';
  }

  @override
  String get alertDriftDetectedTitle => 'Sei uscito dal percorso';

  @override
  String alertDriftDetectedBody(String off) {
    return 'Sei a $off m dal tracciato previsto. Ricalcolare?';
  }

  @override
  String get alertBehindScheduleTitle => 'Sei in ritardo';

  @override
  String alertBehindScheduleBody(int mins) {
    return 'Arriverai con $mins min di ritardo.';
  }

  @override
  String tripDashboardCheaperFuel(String brand, String km, String cts) {
    return '$brand tra $km km · risparmi $cts ct/L';
  }

  @override
  String get resultOptimalDeparture => 'Il tuo orario di partenza è ottimale';

  @override
  String shortLastDayWarning(String km) {
    return 'Ultima tappa breve ($km km) — potresti arrivare oggi se avanzi di più il giorno prima.';
  }

  @override
  String get prepareDepartureNow => 'Partire ora';

  @override
  String get replanNewDepartureTitle =>
      'Ricalcolo con il nuovo orario di partenza…';

  @override
  String get planStopReorderHint => 'Tieni premuta la maniglia per riordinare';

  @override
  String get planSwapOriginDestination => 'Inverti';

  @override
  String get planStopMoveUp => 'Sposta su';

  @override
  String get planStopMoveDown => 'Sposta giù';

  @override
  String get recentTripsTitle => 'Viaggi recenti';

  @override
  String recentTripsSubtitle(int count) {
    return '$count salvati — tocca per riutilizzare';
  }

  @override
  String recentTripsSeeAll(int n) {
    return 'Vedi i $n altri viaggi in I miei viaggi';
  }

  @override
  String get onRouteTitle => 'Lungo il percorso';

  @override
  String get onRouteEmpty => 'Tocca per scegliere le opzioni';

  @override
  String get exportShareTitle => 'Condividi il percorso';

  @override
  String get exportOpenInMaps => 'Apri in Google Maps';

  @override
  String get exportOpenInMapsSub => 'Con fermate e deviazioni aggiunte';

  @override
  String get exportCopyLink => 'Copia link';

  @override
  String get exportLinkCopied => 'Link copiato negli appunti';

  @override
  String get exportShareOs => 'Condividi…';

  @override
  String get exportShareSubject => 'Il mio percorso su MyTravelPal';

  @override
  String get importFromMaps => 'Importa da Maps';

  @override
  String get importFromMapsTitle => 'Importa un percorso da Google Maps';

  @override
  String get importFromMapsHint => 'Incolla qui il link di Google Maps';

  @override
  String get importFromMapsPaste => 'Incolla';

  @override
  String get importFromMapsImport => 'Importa';

  @override
  String get importFromMapsError => 'URL non riconosciuto';

  @override
  String get importFromMapsErrorMalformed =>
      'URL non valido — controlla il link e riprova';

  @override
  String get importFromMapsErrorShortlink =>
      'Impossibile espandere il link corto — aprilo in Maps e copia l\'URL completo';

  @override
  String get importFromMapsErrorGeocode =>
      'Impossibile localizzare i luoghi — prova con un percorso più breve o inseriscili a mano';

  @override
  String get importFromMapsLoading => 'Analisi del link in corso…';

  @override
  String adverseEventsBannerCount(int count) {
    return '$count avviso/i sul percorso';
  }

  @override
  String pricePerMeal(String price) {
    return '$price €/pasto';
  }

  @override
  String kmFromOrigin(String km) {
    return '$km km dall\'origine';
  }

  @override
  String get profileVehicleModel => 'Modello';

  @override
  String get profileVehicleModelHint => 'Scegli il tuo modello';

  @override
  String get profileVehicleModelClear => 'Rimuovi modello';

  @override
  String get profileTankLevel => 'Serbatoio attuale';

  @override
  String get vehiclePickerSearchHint => 'Cerca marca o modello';

  @override
  String get vehiclePickerEmpty => 'Nessun modello corrisponde';

  @override
  String get vehiclePickerLoadError =>
      'Impossibile caricare l\'elenco. Riprova più tardi.';

  @override
  String get vehiclePickerCustomOption => 'Veicolo personalizzato';

  @override
  String get vehiclePickerCustomOptionSubtitle =>
      'Inserisci serbatoio e consumo manualmente';

  @override
  String get vehicleCustomTitle => 'Veicolo personalizzato';

  @override
  String get vehicleCustomName => 'Nome del veicolo (opzionale)';

  @override
  String get vehicleCustomNameHint => 'es. Il mio SUV';

  @override
  String get vehicleCustomTank => 'Serbatoio (L)';

  @override
  String get vehicleCustomTankEv => 'Batteria (kWh)';

  @override
  String get vehicleCustomConsumption => 'Consumo (L/100 km)';

  @override
  String get vehicleCustomConsumptionEv => 'Consumo (kWh/100 km)';

  @override
  String get vehicleCustomSave => 'Usa personalizzato';

  @override
  String refuelWindowComfortable(String km) {
    return 'Rifornisci entro il km $km (comodo)';
  }

  @override
  String refuelWindowCritical(String km) {
    return 'Rifornisci entro il km $km (critico)';
  }

  @override
  String get refuelSuggestionTitle => 'Rifornisci qui per risparmiare';

  @override
  String refuelSuggestionBody(String station, String km, String price) {
    return '$station · km $km · €$price/L';
  }

  @override
  String refuelSuggestionSavings(String eur) {
    return 'Risparmi $eur €';
  }

  @override
  String savingsFuelRow(String eur) {
    return 'Carburante: $eur €';
  }

  @override
  String get garageTitle => 'Il mio garage';

  @override
  String get garageEmpty => 'Nessun veicolo — aggiungi il primo';

  @override
  String get garageAdd => 'Aggiungi veicolo';

  @override
  String get garageEdit => 'Modifica veicolo';

  @override
  String get garageDelete => 'Elimina';

  @override
  String get garageCancel => 'Annulla';

  @override
  String get garageSave => 'Salva';

  @override
  String get garageDefaultName => 'La mia auto';

  @override
  String get garageNameHint => 'Dagli un nome (es. La mia Golf)';

  @override
  String get garageDefaultTankLabel => 'Livello serbatoio predefinito';

  @override
  String get garageDefaultChargeLevelLabel => 'Livello di carica iniziale';

  @override
  String get garageAddError => 'Impossibile salvare. Riprova.';

  @override
  String get garageDeleteTitle => 'Eliminare il veicolo?';

  @override
  String garageDeleteBody(String name) {
    return '\"$name\" verrà rimosso dal tuo garage.';
  }

  @override
  String garageSettingsRow(int count) {
    return 'Il mio garage ($count)';
  }

  @override
  String planScreenGarageChip(String name, int pct) {
    return 'Auto: $name · $pct %';
  }

  @override
  String get planScreenGarageChooseVehicle =>
      'Scegli un veicolo per questo viaggio';

  @override
  String get hotelArbitrageTitle => 'Hotel più economici a fianco';

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
      other: '$nightsString notti',
      one: 'una notte',
    );
    return 'Questa notte cade in $dear, ~$dearPrice€/notte. In $cheap sono ~$cheapPrice€ ($pct% meno). Sposta $_temp0 e risparmi ~$savings€.';
  }

  @override
  String get hotelArbitrageMiniHint =>
      'Stesso risparmio se sposti anche questa notte a sud';

  @override
  String get whatsNewSheetTitle => 'Novità';

  @override
  String get whatsNewSheetDismiss => 'Ho capito';

  @override
  String get profileChipChangeVehicle => 'Cambia veicolo';

  @override
  String get profileChipEditProfile => 'Modifica profilo del viaggio';

  @override
  String get whatsNewSheetSuggest => 'Suggerisci';

  @override
  String get feedbackSheetTitle => 'Suggerimenti';

  @override
  String get feedbackSheetSubtitle =>
      'Dicci cosa migliorerebbe MyTravelPal per te. Leggiamo ogni messaggio.';

  @override
  String get feedbackBodyHint => 'Cosa cambieresti o aggiungeresti?';

  @override
  String get feedbackWantReply => 'Voglio una risposta';

  @override
  String get feedbackEmailHint => 'La tua email (opzionale)';

  @override
  String get feedbackSendButton => 'Invia';

  @override
  String get feedbackThanks => 'Grazie! Ricevuto.';

  @override
  String get feedbackErrorEmpty => 'Dicci qualcosa di più (min. 3 caratteri)';

  @override
  String get feedbackErrorEmail => 'Questa email non sembra valida';

  @override
  String get feedbackErrorSend =>
      'Impossibile inviare. Riprova tra un momento.';

  @override
  String get settingsSendFeedback => 'Invia un suggerimento';

  @override
  String get settingsSendFeedbackSubtitle => 'Dicci cosa costruire';

  @override
  String get enrichPulseRestStops => 'Cerco aree di sosta lungo il percorso';

  @override
  String get exitAppTitle => 'Chiudi MyTravelPal?';

  @override
  String get exitAppBody => 'Vuoi davvero chiudere l\'app?';

  @override
  String get exitAppBodyCompanionActive =>
      'La modalità Companion è attiva. Se esci ora, la sessione di guida continua in background. Fermala dalla scheda Companion per chiudere in modo pulito.';

  @override
  String get exitAppStay => 'Resta';

  @override
  String get exitAppLeave => 'Esci';

  @override
  String get enrichPulseChargers =>
      'Localizzo colonnine di ricarica lungo il percorso';

  @override
  String get advEventLabelSource => 'Fonte';

  @override
  String get advEventLabelReported => 'Rilevato';

  @override
  String get advEventLabelExpires => 'Valido fino a';

  @override
  String get advEventLabelDuration => 'Durata stimata';

  @override
  String get advEventSourceWeather => 'Previsioni meteo (Open-Meteo)';

  @override
  String get advEventSourceOfficial => 'Flusso ufficiale';

  @override
  String get advEventSourceEffis => 'Monitor incendi EFFIS';

  @override
  String get advEventSourceUsgs => 'Flusso sismico USGS';

  @override
  String get advEventSourceUser => 'Segnalazione utente';

  @override
  String get advEventSourceMock => 'Simulato (dev)';

  @override
  String advEventDurationHours(String h) {
    return '$h h';
  }

  @override
  String advEventDurationDays(String d, String h) {
    return '$d g $h h';
  }

  @override
  String get advEventDurationOngoing => 'In corso';

  @override
  String get exportShareMtp => 'Condividi con utenti MyTravelPal';

  @override
  String get exportShareMtpSubtitle =>
      'Si apre direttamente nell\'app — scelgono le proprie preferenze';

  @override
  String exportShareMtpSubject(String origin, String destination) {
    return '$origin → $destination | MyTravelPal';
  }

  @override
  String get resultFuelStationsOnRoute => 'Stazioni di servizio sul percorso';

  @override
  String get resultFuelSavingsAccordionTitle => 'Risparmio carburante';

  @override
  String get resultTimeSavingsOptimal => 'L\'orario di partenza è ottimale';

  @override
  String get hotelMapFullscreenTitle => 'Hotel nella zona';

  @override
  String get restaurantMapFullscreenTitle => 'Ristoranti nella zona';

  @override
  String get tollSummaryTitle => 'Pedaggi del percorso';

  @override
  String get tollSummaryMapButton => 'Vedi sulla mappa';

  @override
  String activitiesCtaTitle(Object city) {
    return 'Cosa fare a $city';
  }

  @override
  String get activitiesCtaSubtitle => 'Attività ed esperienze locali';

  @override
  String get planIncludeActivities => 'Attività a destinazione';

  @override
  String get planIncludeActivitiesHint =>
      'Suggerimenti GetYourGuide in ogni città';

  @override
  String get aiPrefScenicRoutes => 'Preferisco percorsi panoramici';

  @override
  String get aiPrefScenicRoutesSub =>
      'Consigliare deviazioni tramite belvederi e valichi';

  @override
  String get aiPrefEcoConscious => 'Guida eco-sostenibile';

  @override
  String get aiPrefEcoConsciousSub =>
      'Preferire veicoli elettrici, evitare autostrade quando possibile';

  @override
  String get aiPrefLocalFood => 'Cucina locale prima';

  @override
  String get aiPrefLocalFoodSub =>
      'Dare priorità ai ristoranti locali rispetto alle catene';

  @override
  String get aiPrefDepartureHour => 'Orario di partenza abituale';

  @override
  String get aiPrefDietary => 'RESTRIZIONI ALIMENTARI';

  @override
  String get aiPrefInterests => 'INTERESSI';

  @override
  String get aiDietVegetarian => 'Vegetariano';

  @override
  String get aiDietVegan => 'Vegano';

  @override
  String get aiDietGlutenFree => 'Senza glutine';

  @override
  String get aiDietHalal => 'Halal';

  @override
  String get aiInterestCulture => 'Cultura';

  @override
  String get aiInterestNature => 'Natura';

  @override
  String get aiInterestGastronomy => 'Gastronomia';

  @override
  String get aiInterestShopping => 'Shopping';

  @override
  String get aiInterestAdventure => 'Avventura';

  @override
  String get wizardSkip => 'Salta';

  @override
  String get wizardStart => 'Inizia';

  @override
  String get wizardBack => 'Indietro';

  @override
  String get wizardNext => 'Avanti';

  @override
  String get wizardTakesSeconds => 'Circa 30 secondi';

  @override
  String get wizardWelcomeTitle => 'Benvenuto su MyTravelPal';

  @override
  String get wizardWelcomeBody =>
      'Raccontaci dei tuoi viaggi e personalizzeremo tutto.';

  @override
  String get wizardWhoTitle => 'Con chi viaggi?';

  @override
  String get wizardWhoSubtitle =>
      'Seleziona tutto ciò che si applica. Modificabile in seguito.';

  @override
  String get wizardWhoKids => 'Viaggio con bambini';

  @override
  String get wizardWhoPets => 'Viaggio con animali';

  @override
  String get wizardWhoCamper => 'Viaggio in camper';

  @override
  String get wizardVehicleTitle => 'Il tuo veicolo';

  @override
  String get wizardVehicleSubtitle =>
      'Lo useremo per stimare il carburante e suggerire percorsi.';

  @override
  String get wizardVehicleType => 'Tipo di veicolo';

  @override
  String get wizardFuelType => 'Carburante';

  @override
  String get wizardRhythmTitle => 'Il tuo ritmo di guida';

  @override
  String get wizardRhythmSubtitle =>
      'Sono valori indicativi — modificabili viaggio per viaggio.';

  @override
  String wizardWakeHour(String h) {
    return 'Parto alle $h';
  }

  @override
  String wizardBreakEvery(String n) {
    return 'Mi fermo ogni ${n}h';
  }

  @override
  String wizardBedtime(String h) {
    return 'Arrivo in hotel alle $h';
  }

  @override
  String get wizardHotelBudget => 'Budget hotel / notte';

  @override
  String get wizardMealBudget => 'Budget pasto / pasto';

  @override
  String get wizardDoneTitle => 'Sei pronto!';

  @override
  String get wizardDoneSubtitle =>
      'Il tuo primo percorso sarà già personalizzato.';

  @override
  String get wizardTeaserTitle => 'Nelle Impostazioni puoi anche configurare:';

  @override
  String get wizardTeaserVehicleModel =>
      'Modello esatto del veicolo (consumo reale)';

  @override
  String get wizardTeaserRoute => 'Percorso preferito: autostrada o panoramica';

  @override
  String get wizardTeaserEmergency => 'Contatti di emergenza';

  @override
  String get wizardTeaserAlertSound => 'Suono avvisi Companion';

  @override
  String get wizardTeaserStars => 'Categoria minima hotel';

  @override
  String get wizardPlanFirstTrip => 'Pianifica il mio primo viaggio';

  @override
  String get priceBandBudget => 'Economico';

  @override
  String get priceBandMid => 'Standard';

  @override
  String get priceBandLux => 'Superior';

  @override
  String get wizardModelTitle => 'Il tuo modello di veicolo';

  @override
  String get wizardModelSubtitle =>
      'Dati reali per calcolare quando e dove fare rifornimento risparmiando.';

  @override
  String get wizardModelSearch => 'Cerca marca o modello...';

  @override
  String get wizardModelGeneric => 'Usa valori generici';

  @override
  String get wizardModelGenericSub =>
      'Stima standard per il tuo tipo di veicolo';

  @override
  String get wizardTollFreeDetour => 'Deviazione gratuita';

  @override
  String get wizardTollMotorway => 'Autostrada';

  @override
  String get wizardTollFaster => 'Più veloce';

  @override
  String get wizardTollTitle => 'Evitare i pedaggi?';

  @override
  String get wizardTollSubtitle =>
      'Analizziamo migliaia di percorsi per sapere quando la deviazione conviene.';

  @override
  String get wizardTollAvoid => 'Evitare quando possibile';

  @override
  String get wizardTollAvoidSub =>
      'Proponi alternative per impostazione predefinita';

  @override
  String get wizardTollPay => 'Preferire sempre l\'autostrada';

  @override
  String get wizardTollPaySub =>
      'Preferisci autostrada salvo risparmi molto chiari';

  @override
  String get wizardTollNote =>
      'Puoi modificarlo per ogni viaggio dalla schermata di pianificazione';

  @override
  String get wizardDrivingNow => 'Guida ora con l\'assistente';

  @override
  String get companionModeLabel => 'Assistente di guida';

  @override
  String get companionModeDesc =>
      'Co-pilota IA · Consiglia alternative ai pedaggi, ristoranti secondo i tuoi gusti e carburante economico in tempo reale · Premium';

  @override
  String get aiLearningTitle => 'L\'assistente ti conosce al';

  @override
  String get aiScoreExcellent =>
      'Eccellente · Le raccomandazioni sono molto precise';

  @override
  String get aiScoreGood =>
      'Bene · Puoi ancora migliorare la personalizzazione';

  @override
  String get aiScoreBasic =>
      'Base · Completa il profilo per risultati migliori';

  @override
  String get aiFactorVehicleModel => 'Modello di veicolo';

  @override
  String get aiFactorVehicleModelHint =>
      'Imposta il modello per calcoli carburante esatti';

  @override
  String aiFactorTrips(int count) {
    return '$count viaggi completati';
  }

  @override
  String get aiFactorTripsHint =>
      'Più viaggi = migliore comprensione dei tuoi percorsi';

  @override
  String get aiFactorHotelPrefs => 'Preferenze hotel';

  @override
  String get aiFactorHotelPrefsHint =>
      'Aggiungi stelle, parcheggio o wifi per filtrare meglio';

  @override
  String get aiFactorRestPrefs => 'Preferenze ristorante';

  @override
  String get aiFactorRestPrefsHint =>
      'Aggiungi tipi di cucina per suggerimenti migliori';

  @override
  String get aiFactorNick => 'Nick e paese configurati';

  @override
  String get aiFactorNickHint => 'Completa nome e paese nelle Impostazioni';

  @override
  String get aiFactorEmergency => 'Contatti di emergenza';

  @override
  String get aiFactorEmergencyHint =>
      'Aggiungi un contatto per il sistema di sicurezza';

  @override
  String get aiFactorProfile => 'Profilo di viaggio base';

  @override
  String get aiFactorProfileHint =>
      'Configura gli orari di guida nelle Impostazioni';

  @override
  String get tripQualityTitle => 'Qualità del viaggio';

  @override
  String get tripQualityExcellent => 'Eccellente';

  @override
  String get tripQualityGood => 'Buono';

  @override
  String get tripQualityFair => 'Accettabile';

  @override
  String get tripQualityPoor => 'Limitato';

  @override
  String get tripQualityFactorRoute => 'Percorso';

  @override
  String get tripQualityFactorFuel => 'Stazioni';

  @override
  String get tripQualityFactorHotels => 'Hotel';

  @override
  String get tripQualityFactorWeather => 'Meteo';

  @override
  String get tripQualityFactorAlerts => 'Avvisi';

  @override
  String get tripQualityFactorTolls => 'Pedaggi';

  @override
  String get tripQualityFactorStops => 'Soste';

  @override
  String get tripQualityExplainRoute =>
      'Misura se il percorso ha una geometria valida e se le soste obbligatorie sono pianificate (normativa UE: pausa ogni 4,5h).';

  @override
  String get tripQualityExplainFuel =>
      'Indica se i prezzi del carburante sono disponibili sul percorso e se hai aggiunto la stazione ottimale.';

  @override
  String get tripQualityExplainHotels =>
      'Valuta se sono disponibili hotel per le notti del viaggio e se hai selezionato dove dormire.';

  @override
  String get tripQualityExplainWeather =>
      'Analizza le condizioni meteorologiche lungo il percorso. Verde = favorevoli. Giallo = pioggia o nebbia. Rosso = tempesta o neve.';

  @override
  String get tripQualityExplainAlerts =>
      'Conta gli eventi avversi attivi sulla o vicino alla tua route: incendi, tempeste, terremoti, chiusure stradali.';

  @override
  String get tripQualityExplainTolls =>
      'Valuta se i dati sui pedaggi sono disponibili e se puoi ottimizzare quali pedaggi pagare o saltare.';

  @override
  String get tripQualityExplainStops =>
      'Misura se hai pianificato le soste per i pasti e il riposo. Per il ritmo \'savour\' o con bambini/animali, le soste sono importanti.';

  @override
  String get wizardModelConsumption => 'Consumo';

  @override
  String get wizardModelTank => 'Serbatoio';

  @override
  String get wizardRhythmNote =>
      'Modifica qualsiasi tappa direttamente nel risultato del viaggio.';

  @override
  String get wizardTollHowTitle => 'COME FUNZIONA';

  @override
  String get wizardTollHowBody =>
      'Per ogni viaggio analizziamo ogni pedaggio: se la deviazione fa risparmiare davvero e il tempo extra è minimo, lo proponiamo nella schermata dei risultati. Decidi tu, e puoi regolare esattamente quanti minuti extra sei disposto a perdere.';

  @override
  String get wizardTollPreference => 'Qual è il tuo punto di partenza?';

  @override
  String get resultStartCompanionNow => 'Parti ora! · Modalità Assistente';

  @override
  String get resultCompanionFarFromOrigin =>
      'Avvicinati al punto di partenza per attivare la modalità guida';

  @override
  String get resultReplanWithChanges => 'Ricalcola con le modifiche applicate';

  @override
  String get replanTipRoute => 'Ottimizzazione delle tappe giornaliere...';

  @override
  String get replanTipFuel => 'Ricerca delle migliori stazioni sul percorso...';

  @override
  String get replanTipStops =>
      'Adattamento delle soste e degli orari di arrivo...';

  @override
  String tripDayBarsCap(int n) {
    return 'Limite: ${n}h';
  }

  @override
  String tripDayBarsUnselected(int n) {
    return '$n sosta/e non aggiunte';
  }

  @override
  String get tripDayBarsHint => 'Tocca + per includerle nella durata totale';

  @override
  String get tripDayBarsCapLabel => 'Limite';

  @override
  String get tripDayBarsTitle => 'Distribuzione per tappe';

  @override
  String get wizardStepProfile => 'Profilo';

  @override
  String get wizardStepVehicle => 'Veicolo';

  @override
  String get wizardStepRhythm => 'Ritmo';

  @override
  String get wizardStepBudget => 'Budget';

  @override
  String wizardModelsAvailable(int count) {
    return '$count modelli disponibili';
  }

  @override
  String wizardModelsMore(int count) {
    return '+$count — cerca per nome';
  }

  @override
  String get wizardTollSavingsDemo => 'Risparmia €8';

  @override
  String companionNotifFuelBody(int km) {
    return 'A $km km · Tocca \"Deviazione\" per aggiungerlo al percorso';
  }

  @override
  String get companionDemoNotifFuel =>
      'A 3 km · Deviazione in Maps per fare rifornimento';

  @override
  String get companionDemoNotifRoute =>
      'A 18 km sul percorso · Considera la N-II · Deviazione in Maps';

  @override
  String get companionDemoNotifMeal =>
      'Menù €12 · A 4 km · Ci fermiamo a mangiare? Deviazione in Maps';

  @override
  String get companionDemoNotifEta =>
      'ETA tra 10 min · 12 km · Nessun incidente';

  @override
  String get companionOffRouteTitle => 'Fuori percorso?';

  @override
  String get companionOffRouteBody =>
      'La tua posizione è lontana dal percorso pianificato. In modalità libera l\'assistente rimane con te senza calcolare km.';

  @override
  String get companionOffRouteBack => 'Torna al percorso';

  @override
  String get companionFreeModeBtn => 'Modalità libera';

  @override
  String companionGroupSessionError(String error) {
    return 'Impossibile creare la sessione di gruppo: $error';
  }

  @override
  String get companionMealStopTitle => 'Cambia sosta pasto';

  @override
  String get companionMealStopDelayBody =>
      'Vuoi ritardare la sosta pasto? La sposteremo alla prossima area di servizio.';

  @override
  String get settingsLogoutStep3 => '3/4 · Disconnessione…';

  @override
  String get settingsLogoutStep4 => '4/4 · Ritorno all\'inizio…';

  @override
  String get settingsNickTaken => 'Già in uso';

  @override
  String get settingsNickHelper =>
      'Il tuo nome nella classifica dei percorsi. Scegli un nick e il tuo paese — visibile solo nell\'Hall of Fame.';

  @override
  String get settingsNickEmpty => 'Nessun nick ancora';

  @override
  String get settingsCountrySearch => 'Cerca paese...';

  @override
  String get settingsPremiumDevNote =>
      'Si attiverà tramite acquisto in produzione';

  @override
  String get settingsTierFeaturesPremium =>
      '✓ Companion IA · Pedaggi ottimizzati · Android Auto · Gruppi · Monitor viaggio';

  @override
  String get settingsTierFeaturesEssential =>
      '✓ Stazioni ottimali · Pedaggi base · Allerte avverse · Autovelox';

  @override
  String get settingsTierFeaturesFree =>
      'Solo pianificazione base · Senza ottimizzazione carburante o pedaggi';

  @override
  String resultStationAdded(String name) {
    return '$name aggiunta · stima del serbatoio aggiornata per i giorni successivi';
  }

  @override
  String get resultRestStopFallback => 'Area di sosta';

  @override
  String get resultTooltipProfile => 'Profilo e veicolo';

  @override
  String get resultRecalculating => 'Ricalcolo con le nuove impostazioni…';

  @override
  String resultPlanReady(int km, int h, int m) {
    return 'Piano pronto · $km km · ${h}h ${m}m';
  }

  @override
  String get resultGenericConsumptionHint =>
      'Calcolato con consumo generico. Configura il tuo veicolo per maggiore precisione.';

  @override
  String resultFuelSavingsPct(int pct) {
    return '$pct% del costo';
  }

  @override
  String get resultChartAdded => '  aggiunto';

  @override
  String get resultSettingsChangedBody =>
      'Le impostazioni sono cambiate. Ricalcolare con i nuovi valori?';

  @override
  String resultSummaryStops(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count soste',
      one: '$count sosta',
    );
    return '$_temp0';
  }

  @override
  String resultSummaryTolls(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pedaggi saltati',
      one: '$count pedaggio saltato',
    );
    return '$_temp0';
  }

  @override
  String resultSummaryHotels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hotel',
      one: '$count hotel',
    );
    return '$_temp0';
  }

  @override
  String get resultGyGError => 'Impossibile aprire GetYourGuide';

  @override
  String resultGyGActivities(String city) {
    return 'Vedi attività a $city';
  }
}
