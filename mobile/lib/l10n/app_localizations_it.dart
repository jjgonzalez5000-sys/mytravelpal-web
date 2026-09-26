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
  String get onboardEyebrowKiller => 'LA FUNZIONE MANCANTE';

  @override
  String get onboardTitleKiller => 'Parti all\'ora giusta';

  @override
  String get onboardBodyKiller =>
      'Analizziamo il traffico storico intorno all\'orario desiderato e ti mostriamo la finestra ideale — a volte partire 30 minuti prima ti fa risparmiare 90.';

  @override
  String get onboardEyebrowHonest => 'PIANIFICAZIONE ONESTA';

  @override
  String get onboardTitleHonest => 'Tutti i costi, in anticipo';

  @override
  String get onboardBodyHonest =>
      'Totali dei pedaggi, benzina e ricarica elettrica più economiche lungo il percorso, soste suggerite, hotel e ristoranti alla deviazione che ti puoi permettere.';

  @override
  String get onboardEyebrowAlerts => 'RIMANI INFORMATO';

  @override
  String get onboardTitleAlerts => 'Allerte che contano';

  @override
  String get onboardBodyAlerts =>
      'Incendi, alluvioni, maltempo estremo, terremoti — solo pericoli reali che toccano il tuo itinerario.';

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
  String get partialTollSkipsTitle => 'Casello per casello';

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
  String get historyDeleteTooltip => 'Elimina';

  @override
  String get historyReopenCta => 'Vedi';

  @override
  String get historyRepeatCta => 'Ripeti';

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
  String get settingsSectionAppearance => 'Aspetto';

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
  String get styleSectionTitle => 'Stile di viaggio';

  @override
  String get styleSectionEyebrow => 'Come ti piace guidare';

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
  String dayMealStopAt(String time, String name) {
    return '🍽 $time · $name';
  }

  @override
  String dayRestStopAt(String time, String label) {
    return '☕ $time · $label';
  }

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
  String get onboardEyebrowFuel => 'PREZZI REALI';

  @override
  String get onboardTitleFuel => 'Risparmia ad ogni rifornimento';

  @override
  String get onboardBodyFuel =>
      'Prezzi per stazione lungo la tua rotta in tutta Europa. Marche premium mischiate con le low-cost.';

  @override
  String get onboardEyebrowDriving => 'IN STRADA';

  @override
  String get onboardTitleDriving => 'Il tuo copilota intelligente';

  @override
  String get onboardBodyDriving =>
      'Dashboard live con prossima sosta, arrivo dinamico e nuovi avvisi. Compatibile con Android Auto.';

  @override
  String get onboardEyebrowProfile => 'PERSONALIZZATO';

  @override
  String get onboardTitleProfile => 'Compila il tuo profilo';

  @override
  String get onboardBodyProfile =>
      'Senza profilo ottimizziamo solo il tempo. Con profilo calcoliamo carburante reale, hotel e pasti su misura.';

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
  String get resultStartCompanion => 'Avvia modalità Companion';

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
  String get onRouteTitle => 'Lungo il percorso';

  @override
  String get onRouteEmpty => 'Tocca per scegliere le opzioni';

  @override
  String get exportShareTitle => 'Condividi il percorso';

  @override
  String get exportOpenInMaps => 'Apri in Google Maps';

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
  String refuelWindowComfortable(String km) {
    return 'Rifornisci entro il km $km (comodo)';
  }

  @override
  String refuelWindowCritical(String km) {
    return 'Rifornisci entro il km $km (critico)';
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
}
