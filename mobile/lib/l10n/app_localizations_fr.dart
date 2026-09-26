// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'MyTravelPal';

  @override
  String get appTagline => 'Planifiez le trajet, pas juste la destination';

  @override
  String get onboardEyebrowKiller => 'LA FONCTIONNALITÉ MANQUANTE';

  @override
  String get onboardTitleKiller => 'Partez à la bonne heure';

  @override
  String get onboardBodyKiller =>
      'Nous analysons le trafic historique autour de votre heure de départ souhaitée et vous montrons le moment idéal — parfois partir 30 minutes plus tôt vous fait gagner 90.';

  @override
  String get onboardEyebrowHonest => 'PLANIFICATION HONNÊTE';

  @override
  String get onboardTitleHonest => 'Tous les coûts, dès le départ';

  @override
  String get onboardBodyHonest =>
      'Totaux de péages, essence et recharge électrique moins chères sur la route, arrêts suggérés, hôtels et restaurants au détour que vous pouvez vous permettre.';

  @override
  String get onboardEyebrowAlerts => 'RESTEZ INFORMÉ';

  @override
  String get onboardTitleAlerts => 'Des alertes qui comptent';

  @override
  String get onboardBodyAlerts =>
      'Incendies, inondations, météo extrême, tremblements de terre — uniquement les dangers réels qui touchent votre itinéraire.';

  @override
  String get onboardSkip => 'Passer';

  @override
  String get onboardContinue => 'Continuer';

  @override
  String get onboardGetStarted => 'Commencer';

  @override
  String get onboardFooter =>
      'Gratuit · Premium débloque le récit IA du voyage';

  @override
  String get loginContinueApple => 'Continuer avec Apple';

  @override
  String get loginContinueGoogle => 'Continuer avec Google';

  @override
  String get loginContinueFacebook => 'Continuer avec Facebook';

  @override
  String get loginContinueDemo => 'Continuer en démo';

  @override
  String get loginDivider => 'ou';

  @override
  String get loginTerms =>
      'En continuant, vous acceptez nos conditions et politique de confidentialité.';

  @override
  String get loginBusy => 'Connexion en cours…';

  @override
  String get planTitle => 'Planifier un voyage';

  @override
  String get planEyebrow => 'LE PLANIFICATEUR';

  @override
  String get planHero => 'Où allons-nous\naujourd\'hui ?';

  @override
  String planHeroPersonal(String name) {
    return 'Salut $name, on va où ?';
  }

  @override
  String get planIntro =>
      'Choisissez deux points et une heure. Nous nous occupons du reste.';

  @override
  String get planFrom => 'De';

  @override
  String get planTo => 'À';

  @override
  String get planDesiredDeparture => 'Heure de départ souhaitée';

  @override
  String get planCta => 'Planifier';

  @override
  String get planCtaBusy => 'Planification en cours…';

  @override
  String get planCountriesNote =>
      'Les pays sont détectés automatiquement depuis votre itinéraire.';

  @override
  String get planSectionOptional => 'Sur l\'itinéraire';

  @override
  String get planMoreOptions => 'Plus d\'options';

  @override
  String get planLessOptions => 'Moins d\'options';

  @override
  String get planRoundTripChip => 'Aller-retour';

  @override
  String get planLeaveNowFabTitle => 'Partir maintenant';

  @override
  String get leaveNowConfirmTitle => 'Partir maintenant vers';

  @override
  String leaveNowConfirmBody(Object name) {
    return 'Direction $name ?';
  }

  @override
  String get leaveNowConfirmCta => 'C\'est parti';

  @override
  String get leaveNowConfirmChange => 'Changer de destination';

  @override
  String get settingsBiometric => 'Déverrouillage biométrique';

  @override
  String get settingsBiometricSub => 'Empreinte ou visage pour ouvrir l\'app';

  @override
  String get settingsBiometricUnavailable => 'Indisponible sur cet appareil';

  @override
  String get settingsReplayTutorial => 'Revoir le tutoriel';

  @override
  String get settingsReplayTutorialSub => 'Réafficher les repères guidés';

  @override
  String get settingsReplayTutorialToast =>
      'Tutoriel réinitialisé. Réouvre Plan.';

  @override
  String get settingsColorPreset => 'Palette de couleurs';

  @override
  String get settingsPresetForest => 'Forêt';

  @override
  String get settingsPresetSunset => 'Coucher de soleil';

  @override
  String get settingsPresetOcean => 'Océan';

  @override
  String get settingsDynamicColor => 'Material You (dynamique)';

  @override
  String get settingsDynamicColorSub =>
      'Adapter les couleurs à ton fond d\'écran (Android 12+)';

  @override
  String get settingsOled => 'Noir pur (OLED)';

  @override
  String get settingsOledSub =>
      'Noirs plus profonds en mode sombre, économise la batterie sur OLED';

  @override
  String get parkingSearchTitle => 'Trouver un parking';

  @override
  String get parkingSearchLabel => 'Où vas-tu ?';

  @override
  String get parkingSearchHint =>
      'Choisis une destination pour voir les parkings.';

  @override
  String get parkingRadiusLabel => 'Rayon';

  @override
  String get parkingNoResults => 'Aucun parking dans ce rayon.';

  @override
  String get parkingPriceUnknown => 'Prix ?';

  @override
  String get parkingCovered => 'Couvert';

  @override
  String get parkingFilterKids => 'Enfants';

  @override
  String get parkingFilterDogs => 'Chiens';

  @override
  String get parkingFilterToilets => 'WC';

  @override
  String get parkingFilterFood => 'Restauration';

  @override
  String get parkingFilterShowers => 'Douches';

  @override
  String get parkingFilterEv => 'Borne EV';

  @override
  String get parkingFilterFuel => 'Station-service';

  @override
  String get parkingFilterWheelchair => 'PMR';

  @override
  String get parkingFilterRv => 'Camping-car';

  @override
  String get parkingFilterTruck => 'Poids lourd';

  @override
  String get planFindParkingCta => 'Trouver un parking';

  @override
  String get poiFindParking => 'Parking';

  @override
  String get parkingPrefTitle => 'Parking';

  @override
  String get parkingPrefSub => 'Afficher les parkings près de la destination.';

  @override
  String get parkingResultTitle => 'Parkings près de la destination';

  @override
  String get inspireTitle => 'Inspiration voyage';

  @override
  String get inspireHero => 'Décrivez le road trip de vos rêves';

  @override
  String get inspireSub =>
      'L\'IA propose un itinéraire multi-jours convertible en plan réel en un tap.';

  @override
  String get inspireHint =>
      'ex. Escapade romantique de 4 jours dans les lacs italiens';

  @override
  String get inspireGenerate => 'Inspirez-moi';

  @override
  String get inspireGenerating => 'On imagine votre voyage…';

  @override
  String get inspireError => 'La muse est hors ligne. Essayez un autre texte.';

  @override
  String get inspireResultTitle => 'Itinéraire proposé';

  @override
  String inspireDayLabel(Object n) {
    return 'Jour $n';
  }

  @override
  String get inspireBudgetLabel => 'Budget estimé';

  @override
  String get inspireConvertToPlan => 'Transformer en vrai plan';

  @override
  String get inspireSave => 'Enregistrer';

  @override
  String get inspireSavedToast =>
      'Idée enregistrée. Retrouve-la dans tes inspirations.';

  @override
  String get inspireRecentTitle => 'Récentes';

  @override
  String get inspireHistoryTitle => 'Mes plans IA';

  @override
  String get inspireHistoryEmpty =>
      'Pas encore de plans IA. Génère-en un depuis l\'onglet Planifier.';

  @override
  String get inspireHistoryDelete => 'Supprimer';

  @override
  String get settingsMyAiPlans => 'Mes plans IA';

  @override
  String get settingsMyAiPlansSub => 'Historique Trip Inspiration';

  @override
  String get inspireChatTitle => 'Ajuste l\'itinéraire';

  @override
  String get inspireChatHint =>
      'Demande un changement : \"enlève Crémone\", \"pars vendredi soir\"…';

  @override
  String get inspireExamplesTitle => 'Ou partez d\'une idée';

  @override
  String get inspireExample1 => 'Week-end châteaux de la Loire';

  @override
  String get inspireExample2 => 'Route côtière Barcelone-Marseille';

  @override
  String get inspireExample3 => '5 jours dans les Alpes depuis Milan';

  @override
  String get inspireExample4 => 'Nord de l\'Espagne en famille, sans autoroute';

  @override
  String get planOverrideForTrip => 'Modifier pour ce voyage';

  @override
  String get planOverrideActive => 'Modifié pour ce voyage';

  @override
  String get planOverrideClear => 'Effacer';

  @override
  String get planTooltipDashboard => 'Tableau de bord';

  @override
  String get planTooltipReport => 'Signaler un événement';

  @override
  String get planTooltipSaved => 'Voyages enregistrés';

  @override
  String get tabPlan => 'Planifier';

  @override
  String get tabCompanion => 'Copilote';

  @override
  String get tabMyTrips => 'Mes voyages';

  @override
  String get companionHeroTitle => 'Votre copilote de route';

  @override
  String get companionHeroBody =>
      'Configurez vos conditions, puis démarrez. L\'app vous accompagne et recommande quand s\'arrêter, où manger et où faire le plein.';

  @override
  String get companionConfigSection => 'CONFIGURATION';

  @override
  String get companionBreakInterval => 'Suggestions de pause';

  @override
  String get companionSuggestBreak =>
      'Suggérer une pause selon le temps de conduite';

  @override
  String companionBreakHint(String hours) {
    return 'Recommander un arrêt toutes les $hours h de conduite';
  }

  @override
  String get companionFatigueStopExperimental =>
      'Suggérer de s\'arrêter en cas de fatigue (expérimental)';

  @override
  String get companionFatigueStopHint =>
      'Signal basé sur le temps — se déclenche même avec des micro-pauses.';

  @override
  String get companionAlerts => 'Types d\'alertes';

  @override
  String get companionAlertCriticalAdverse =>
      'Incidents critiques (incendies, inondations, séismes)';

  @override
  String get companionAlertCriticalAdverseHint =>
      'Recommandé. Événement grave à proximité — pas juste la météo.';

  @override
  String get companionAlertWeather => 'Météo en route';

  @override
  String get companionAlertFuel => 'Stations les moins chères en route';

  @override
  String get companionAlertBorder => 'Info passage de frontière';

  @override
  String get companionAlertToll => 'Suggestions d\'évitement de péages';

  @override
  String get companionAlertHotel => 'Hôtels quand vous êtes fatigué';

  @override
  String get companionStart => 'Démarrer le copilote';

  @override
  String get companionComingSoon => 'Mode copilote bientôt disponible !';

  @override
  String get companionDriveTitle => 'Compagnon actif';

  @override
  String get companionForegroundBody => 'MyTravelPal suit votre conduite';

  @override
  String get companionLocationDenied =>
      'Autorisation de localisation requise pour le compagnon.';

  @override
  String get companionDriving => 'en route';

  @override
  String get companionAllGood => 'Aucune alerte — bonne route.';

  @override
  String get companionEndTitle => 'Terminer le compagnon ?';

  @override
  String get companionEndBody =>
      'Le suivi s\'arrête et les alertes actives seront perdues.';

  @override
  String get companionEndKeep => 'Continuer';

  @override
  String get companionEndConfirm => 'Terminer la session';

  @override
  String get emergencyContactsTitle => 'Contacts d\'urgence';

  @override
  String get emergencyContactsSubtitle => 'SMS envoyé en cas d\'impact détecté';

  @override
  String get emergencyContactsBody =>
      'Jusqu\'à 3 personnes reçoivent un SMS avec votre localisation en cas d\'impact détecté.';

  @override
  String get emergencyContactsEmpty => 'Aucun contact ajouté.';

  @override
  String get emergencyContactsAdd => 'Ajouter un contact';

  @override
  String get emergencyContactsPickFromDevice => 'Choisir dans les contacts';

  @override
  String get emergencyContactsPickSearch => 'Rechercher un contact';

  @override
  String get emergencyContactsPermDenied =>
      'Autorisation refusée. Ajout manuel possible.';

  @override
  String get emergencyContactsNoDevice =>
      'Aucun contact avec numéro sur l\'appareil.';

  @override
  String get emergencyContactAddTitle => 'Ajouter un contact d\'urgence';

  @override
  String get emergencyContactName => 'Nom';

  @override
  String get emergencyContactNameRequired => 'Saisissez un nom';

  @override
  String get emergencyContactPhone => 'Téléphone (E.164)';

  @override
  String get emergencyContactPhoneRequired => 'Saisissez un téléphone';

  @override
  String get emergencyContactPhoneInvalid =>
      'Format international : +33612345678';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get sosTitle => 'Impact possible détecté';

  @override
  String sosBody(String g, String speed) {
    return 'Pic d\'impact ${g}g · chute de vitesse $speed km/h.';
  }

  @override
  String sosCountdown(int seconds) {
    return '${seconds}s';
  }

  @override
  String get sosImOk => 'Je vais bien — annuler';

  @override
  String get sosCall112 => 'Appeler 112';

  @override
  String get sosCancelled => 'Alerte annulée.';

  @override
  String get sosClose => 'Fermer';

  @override
  String get sosNoContacts =>
      'Aucun contact configuré. Ajoutez-en un dans Réglages.';

  @override
  String sosSmsDispatched(int count) {
    return 'SMS préparé pour $count contact(s).';
  }

  @override
  String get sosSmsFailed => 'SMS impossible. Appelez manuellement ci-dessous.';

  @override
  String get sosSmsPrefix =>
      'MyTravelPal — impact possible détecté. Ma localisation :';

  @override
  String get weatherForecastTitle => 'Prévisions 7 jours';

  @override
  String get weatherToday => 'Aujourd\'hui';

  @override
  String get leaveNowTitle => 'Partir maintenant avec compagnon';

  @override
  String get leaveNowSubtitle =>
      'Choisis la destination et roule — on te suit et te guide.';

  @override
  String get leaveNowSheetTitle => 'Où vas-tu ?';

  @override
  String get leaveNowPremiumTitle => 'Fonction Premium';

  @override
  String get leaveNowPremiumBody =>
      '\'Partir maintenant\' combine le plan complet et le compagnon de conduite. Disponible avec MyTravelPal Premium.';

  @override
  String get leaveNowPremiumDismiss => 'Plus tard';

  @override
  String get leaveNowPremiumCta => 'Essayer 7 jours gratuits';

  @override
  String get shareCardOption => 'Partager en image';

  @override
  String get shareCardOptionSub =>
      'Parfait pour Instagram Stories, WhatsApp, X';

  @override
  String get shareLinkOption => 'Partager par lien';

  @override
  String get shareLinkOptionSub => 'Résumé texte + lien pour rouvrir le plan';

  @override
  String shareLiveHeadline(String city) {
    return 'En route à travers $city';
  }

  @override
  String shareLiveCaption(String city) {
    return 'Sur la route à $city avec MyTravelPal 🚗';
  }

  @override
  String get planAddStop => 'Ajouter une étape';

  @override
  String get planStopDwellPassThrough => 'Juste de passage';

  @override
  String get planStopDwellOneNight => '1 nuit';

  @override
  String planStopDwellNights(int n) {
    return '$n nuits';
  }

  @override
  String planStopDwellHours(int n) {
    return '$n heures';
  }

  @override
  String planStopDwellTitle(Object name) {
    return 'Combien de temps à $name ?';
  }

  @override
  String get planAddStopTitle => 'Nouvelle étape';

  @override
  String planStopLabel(int n) {
    return 'Étape $n';
  }

  @override
  String get planStopRemove => 'Supprimer';

  @override
  String get settingsCurrency => 'Devise';

  @override
  String get planErrorPickEndpoints =>
      'Choisissez un point de départ et une destination.';

  @override
  String get resultBestTimeToLeave => 'MEILLEURE HEURE POUR PARTIR';

  @override
  String get resultTripSavings => 'VOS ÉCONOMIES SUR CE VOYAGE';

  @override
  String get resultTimeSavedLabel => 'temps économisé';

  @override
  String get resultExtraTimeLabel => 'temps supplémentaire';

  @override
  String get resultMoneySavedLabel => 'argent économisé';

  @override
  String get resultDepartureWindowTitle => 'Fenêtre de départ';

  @override
  String get resultDepartureWindowDesc =>
      'Minutes totales à chaque heure de départ candidate.';

  @override
  String get resultCompareVariantsTitle => 'Comparez vos options';

  @override
  String get resultCompareVariantsEyebrow => 'Variantes d\'itinéraire';

  @override
  String get resultAlertsTitle => 'Alertes sur votre itinéraire';

  @override
  String get resultRestStopsTitle => 'Aires de repos';

  @override
  String get resultHotelsTitle => 'Hôtels';

  @override
  String get resultRestaurantsTitle => 'Restaurants';

  @override
  String get resultFuelTitle => 'Carburant';

  @override
  String get resultTollAlternativeEyebrow => 'ALTERNATIVE SANS PÉAGE';

  @override
  String get resultTollAlternativeWorthIt => 'Vaut la peine';

  @override
  String get resultTollAlternativeMarginal => 'Marginal';

  @override
  String get resultShareTooltip => 'Partager ce voyage';

  @override
  String get resultExplainTooltip => 'Expliquer mon voyage (Premium)';

  @override
  String get resultSaveTooltip => 'Enregistrer';

  @override
  String get resultSavedTooltip => 'Enregistré';

  @override
  String get resultTripSaved => 'Voyage enregistré';

  @override
  String get dashboardTitle => 'Tableau de bord';

  @override
  String dashboardGreeting(String name) {
    return 'Bonjour, $name';
  }

  @override
  String get dashboardTravelSoFar => 'Vos voyages jusqu\'ici';

  @override
  String get dashboardTrips => 'Voyages';

  @override
  String get dashboardDistance => 'Distance';

  @override
  String get dashboardHours => 'Heures';

  @override
  String get dashboardTimeSaved => 'TEMPS ÉCONOMISÉ';

  @override
  String get dashboardMoneySaved => 'ARGENT ÉCONOMISÉ';

  @override
  String get dashboardFuelBudget => 'BUDGET CARBURANT ESTIMÉ';

  @override
  String get dashboardTopSavers => 'Meilleures économies';

  @override
  String get dashboardCountries => 'Pays';

  @override
  String get dashboardSignOut => 'Se déconnecter';

  @override
  String get profileTitle => 'Profil de voyage';

  @override
  String get profileOverrideTitle => 'Modifier pour ce voyage';

  @override
  String get profileSave => 'Enregistrer';

  @override
  String get profileUse => 'Utiliser';

  @override
  String get profileWhoTravelling => 'Qui voyage';

  @override
  String get profileTravellers => 'Voyageurs';

  @override
  String get profileHasKids => 'Voyage avec enfants';

  @override
  String get profileHasPets => 'Voyage avec animaux';

  @override
  String get profileVehicle => 'Véhicule';

  @override
  String get profileMealTimes => 'Horaires des repas';

  @override
  String get profileReminders => 'Rappels';

  @override
  String get profilePremiumSection => 'Premium (démo)';

  @override
  String get profileClearProfile => 'Effacer le profil';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonClear => 'Effacer';

  @override
  String commonShowNMore(int n) {
    return 'Voir $n de plus';
  }

  @override
  String get commonShowLess => 'Voir moins';

  @override
  String planLoadingElapsed(int seconds) {
    return '${seconds}s écoulées';
  }

  @override
  String get planLoadingLongCrossingCountries =>
      'Vérification des péages dans les pays traversés…';

  @override
  String get planLoadingLongScanningFuel =>
      'Analyse des prix carburant européens le long de ta route…';

  @override
  String get planLoadingLongBigTrip =>
      'Les longs trajets prennent un peu plus — chargement d\'hôtels et pauses supplémentaires.';

  @override
  String get planLoadingLongAlmostDone =>
      'Presque fini — dernières touches à l\'itinéraire.';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonRemove => 'Retirer';

  @override
  String get searchPlaceholderLegacy => 'Rechercher une ville…';

  @override
  String get searchNoMatches => 'Aucun résultat.';

  @override
  String get searchStartTyping => 'Tapez au moins 2 caractères.';

  @override
  String get searchRecent => 'RÉCENTS';

  @override
  String get searchUseMyLocation => 'Utiliser ma position';

  @override
  String get locationServiceOff =>
      'La localisation est désactivée sur cet appareil.';

  @override
  String get locationPermissionDenied =>
      'Autorisation de localisation refusée.';

  @override
  String get locationUnavailable => 'Impossible de déterminer votre position.';

  @override
  String get favoritesTitle => 'Favoris';

  @override
  String get favoritesEmptyHotels =>
      'Aucun hôtel favori. Touchez l\'étoile sur un hôtel pour l\'enregistrer.';

  @override
  String get favoritesEmptyRestaurants =>
      'Aucun restaurant favori. Touchez l\'étoile sur un restaurant pour l\'enregistrer.';

  @override
  String get favoritesTabHotels => 'Hôtels';

  @override
  String get favoritesTabRestaurants => 'Restaurants';

  @override
  String get favoritesTooltipAdd => 'Ajouter aux favoris';

  @override
  String get favoritesTooltipRemove => 'Retirer des favoris';

  @override
  String get planTooltipFavorites => 'Favoris';

  @override
  String get resultBackToPlan => 'Retour au plan';

  @override
  String get alertsAlongYourRoute => 'Alertes sur votre itinéraire';

  @override
  String get alertsAlongYourRouteDesc =>
      'Incendies, inondations, météo extrême, neige, séismes, glissements — triés par gravité.';

  @override
  String get restStopsHint =>
      'Recommandé toutes les 2 h de conduite. De courtes pauses maintiennent votre vigilance.';

  @override
  String get fuelAlongTheRoute => 'Carburant sur l\'itinéraire';

  @override
  String get hotelsNearYourRoute => 'Hôtels près de votre itinéraire';

  @override
  String get restaurantsNearYourRoute => 'Restaurants près de votre itinéraire';

  @override
  String get narrativeTitle => 'Résumé du voyage';

  @override
  String get narrativeGenerating => 'Rédaction du résumé…';

  @override
  String get narrativeFailed =>
      'Impossible de générer le résumé. Réessayez dans un instant.';

  @override
  String get narrativeFooter =>
      'Généré par Claude — peut ne pas refléter les changements en temps réel.';

  @override
  String get narrativePremiumBadge => 'Premium';

  @override
  String get shareTripSubject => 'Mon voyage avec MyTravelPal';

  @override
  String get shareFormatTitle => 'Partager en…';

  @override
  String get shareFormatStory => 'Story · 9:16';

  @override
  String get shareFormatStorySub => 'Instagram / TikTok / WhatsApp Stories';

  @override
  String get shareFormatFeed => 'Carré · 1:1';

  @override
  String get shareFormatFeedSub => 'Fil Instagram, Facebook, LinkedIn';

  @override
  String get shareTitle => 'MyTravelPal — plan de road trip';

  @override
  String shareRouteLine(String km, String hours, String tolls) {
    return '$km km · $hours h en flux libre · péages $tolls €';
  }

  @override
  String shareBestTime(String when, String minutes) {
    return 'Meilleure heure de départ : $when ($minutes min au total)';
  }

  @override
  String shareTollFreeAlt(String savings, String minutes) {
    return 'Alt. sans péages : $savings € économisés pour +$minutes min';
  }

  @override
  String shareRefuelHint(
      String cheap, String price, String pricey, String savings) {
    return 'Faire le plein en $cheap (~$price€/L) avant $pricey — $savings€ économisés/réservoir';
  }

  @override
  String get shareHotelsHeader => 'Meilleurs hôtels envisagés :';

  @override
  String get shareRestaurantsHeader => 'Meilleurs restaurants envisagés :';

  @override
  String shareHotelLine(String name, String price, String km) {
    return '$name — $price €/nuit · $km km hors route';
  }

  @override
  String shareRestaurantLine(String name, String price, String km) {
    return '$name — $price €/repas · $km km hors route';
  }

  @override
  String get shareOpenInApp => 'Ouvrir dans MyTravelPal :';

  @override
  String get eventReport => 'Signaler un événement';

  @override
  String get eventDescription => 'Description';

  @override
  String get eventType => 'Type';

  @override
  String get eventSeverity => 'Gravité';

  @override
  String get eventLocation => 'Emplacement';

  @override
  String get eventSubmit => 'Envoyer';

  @override
  String get eventSubmitted => 'Signalé.';

  @override
  String get resultStatDistance => 'Distance';

  @override
  String get resultStatFreeFlow => 'Sans trafic';

  @override
  String get resultStatTolls => 'Péages';

  @override
  String get resultEyebrowNearRoute => 'Près de votre itinéraire';

  @override
  String get resultEyebrowAlongRoute => 'Sur l\'itinéraire';

  @override
  String get resultAlerts => 'Alertes';

  @override
  String get resultRestStops => 'Arrêts recommandés';

  @override
  String get resultHotels => 'Hôtels';

  @override
  String get resultRestaurants => 'Restaurants';

  @override
  String get resultFuel => 'Carburant';

  @override
  String get resultOptimizedFuelBudget => 'Budget carburant estimé';

  @override
  String get resultCompareTitle => 'Comparez vos options';

  @override
  String get resultCompareStraightApprox => 'Approx. ligne droite.';

  @override
  String resultSleepAt(String when) {
    return 'Dormir · $when';
  }

  @override
  String get resultHourlyTollEyebrow => 'VERDICT PÉAGES PAR HEURE';

  @override
  String get resultSkipLabel => 'Éviter';

  @override
  String get resultKeepLabel => 'Garder';

  @override
  String get resultSaveExactly => 'Économisez ';

  @override
  String get notificationsLeaveSoonTitle => 'Il est temps de partir';

  @override
  String get localeSystem => 'Système';

  @override
  String get localeMenuTooltip => 'Langue';

  @override
  String get dashboardCountry => 'Pays';

  @override
  String get dashboardNoTripsYet =>
      'Aucun voyage enregistré. Planifiez et enregistrez-en un pour voir les statistiques.';

  @override
  String get dashboardStatCards => 'APERÇU';

  @override
  String get profileVehicleType => 'Type de véhicule';

  @override
  String get profileFuelType => 'Type de carburant';

  @override
  String get profileConsumption => 'Consommation';

  @override
  String get profileEvRange => 'Autonomie électrique';

  @override
  String get profileFuelTank => 'Réservoir';

  @override
  String get profileBreakfast => 'Petit-déjeuner';

  @override
  String get profileLunch => 'Déjeuner';

  @override
  String get profileDinner => 'Dîner';

  @override
  String get profileStopMinutes => 'Durée typique d\'arrêt';

  @override
  String get profileReminderMinutes => 'Rappel avant départ';

  @override
  String get profilePremiumHint =>
      'Activez pour prévisualiser les fonctions Premium en local.';

  @override
  String get profileNoProfile => 'Aucun profil enregistré.';

  @override
  String get eventPlaceholderDescription =>
      'Brève description de ce que vous avez vu';

  @override
  String get eventCurrentLocation => 'Position actuelle';

  @override
  String get eventPickOnMap => 'Choisir sur la carte';

  @override
  String eventLocationCoords(String lat, String lon) {
    return 'Sélectionné : $lat, $lon';
  }

  @override
  String get narrativeRegenerate => 'Regénérer';

  @override
  String get narrativeUpgrade => 'Débloquez le résumé IA avec Premium.';

  @override
  String get compareVariantsRecommended => 'Recommandé';

  @override
  String get compareVariantsFastest => 'Plus rapide';

  @override
  String get compareVariantsCheapest => 'Moins cher';

  @override
  String get compareVariantsScenic => 'Panoramique';

  @override
  String get compareVariantsAvoidTolls => 'Sans péages';

  @override
  String get compareVariantsAvoidMotorways => 'Sans autoroute';

  @override
  String get hourlyBestHours => 'Meilleures heures pour éviter les péages';

  @override
  String get hourlyWorstHours => 'Pires heures pour éviter les péages';

  @override
  String get partialTollSkipsTitle => 'Péage par péage';

  @override
  String get partialTollSkipsEyebrow => 'Détail';

  @override
  String get sleepEyebrow => 'POUR DORMIR';

  @override
  String get sleepNoHotelSuggestion =>
      'Aucun hôtel choisi — voir la section Hôtels.';

  @override
  String get lunchEyebrow => 'PAUSE DÉJEUNER';

  @override
  String get dinnerEyebrow => 'PAUSE DÎNER';

  @override
  String get breakfastEyebrow => 'PAUSE PETIT-DÉJEUNER';

  @override
  String get resultCompareEyebrow => 'Variantes d\'itinéraire';

  @override
  String get resultCompareDescription =>
      'Même départ et arrivée — priorités différentes. Temps sans trafic.';

  @override
  String get resultVariantDashed => 'Pointillé sur la carte ci-dessus';

  @override
  String dayTollsHeader(Object amount, int count) {
    return 'Péages du jour · $amount € ($count)';
  }

  @override
  String dayTollsSavedSummary(Object amount, int count) {
    return 'Tu économises $amount € en sautant $count.';
  }

  @override
  String tollHourGoodToSkip(Object hh) {
    return 'Bon moment pour sauter ($hh:00)';
  }

  @override
  String tollHourAvoidSkip(Object hh) {
    return 'Évite de sauter — pic à $hh:00';
  }

  @override
  String get partialTollsPerDayHint =>
      'Tu peux aussi les gérer par étape dans le résumé ↓';

  @override
  String resultCityHint(Object city) {
    return 'Près de $city';
  }

  @override
  String get resultSavingsShiftAndSkip =>
      'En décalant le départ et en évitant les péages.';

  @override
  String get resultSavingsShift =>
      'En décalant le départ à la fenêtre recommandée.';

  @override
  String get resultSavingsSkip => 'En prenant l\'alternative sans péage.';

  @override
  String get resultSavingsNone =>
      'Aucune économie identifiée pour cet itinéraire.';

  @override
  String get resultBypassSavingsPrefix => 'Vous pourriez économiser jusqu\'à';

  @override
  String resultBypassSavingsSuffix(String minutes) {
    return 'avec +$minutes min de plus';
  }

  @override
  String get resultArrival => 'ARRIVÉE';

  @override
  String get resultShift => 'DÉCALAGE';

  @override
  String get resultTraffic => 'TRAFIC';

  @override
  String get resultTotal => 'TOTAL';

  @override
  String resultRestStopNoRestaurant(String km) {
    return 'Pause au km $km — pas de restaurant compatible.';
  }

  @override
  String resultNoHotelHere(String km) {
    return 'Bonne pause ici (~$km km). Pas d\'hôtel compatible.';
  }

  @override
  String get resultMealFallback => 'Repas';

  @override
  String get resultHourlyExplainer =>
      'Fréquent en France et Italie : sortir avant un péage cher, prendre une route parallèle un moment puis rentrer — 15 à 40 min de plus mais 5-15 € économisés.';

  @override
  String get profileSaved => 'Profil enregistré';

  @override
  String get profileWhoEyebrow => 'Personnes';

  @override
  String get profileKidsSubtitle =>
      'Priorité aux restaurants et hôtels adaptés aux enfants.';

  @override
  String get profilePetsSubtitle =>
      'Priorité aux lieux acceptant les animaux, avec parking.';

  @override
  String get profileVehicleEyebrow => 'Coût et stationnement';

  @override
  String get profileMealsEyebrow => 'Pour caler les pauses restaurant';

  @override
  String get profileRemindersEyebrow => 'Notifications locales';

  @override
  String get profileNotifyBefore => 'Notifier avant le départ';

  @override
  String get profileNotifyOff => 'Désactivé — aucun rappel programmé.';

  @override
  String profileNotifyMinutesBefore(int minutes) {
    return '$minutes minutes avant';
  }

  @override
  String get profilePremiumEyebrow => 'Toggle local · sans paiement réel';

  @override
  String get profilePremiumBody =>
      'Le vrai contrôle StoreKit / Play Billing arrivera plus tard. Pour l\'instant, ce toggle active Premium localement pour prévisualiser ces fonctions.';

  @override
  String get profileSimulatePremium => 'Simuler Premium';

  @override
  String get profileSimulatePremiumSubtitle =>
      'Débloque le résumé IA et l\'analyse des péages par heure.';

  @override
  String get profileOverrideHeroDesc =>
      'Change votre profil pour ce voyage uniquement — véhicule, voyageurs ou horaires de repas différents sans toucher au profil enregistré.';

  @override
  String get profileGlobalHeroDesc =>
      'Réglez-le une fois. Chaque plan l\'utilise pour classer hôtels et restaurants, estimer le carburant et caler les pauses repas.';

  @override
  String get eventPickPlace =>
      'Choisissez un lieu et décrivez ce que vous avez vu.';

  @override
  String get eventThankYou => 'Signalement envoyé — merci !';

  @override
  String eventCouldNotSubmit(String reason) {
    return 'Envoi impossible : $reason';
  }

  @override
  String get eventIntro =>
      'Aidez d\'autres conducteurs. Les signalements expirent après 24 heures par défaut.';

  @override
  String get eventWhatHappened => 'Ce qui s\'est passé';

  @override
  String get eventWhatHappenedEyebrow => 'Type';

  @override
  String get eventSeverityInfo => 'Info';

  @override
  String get eventSeverityWarning => 'Alerte';

  @override
  String get eventSeverityCritical => 'Critique';

  @override
  String get eventWhere => 'Où';

  @override
  String get eventWhereEyebrow => 'Ville la plus proche';

  @override
  String get eventDescribeTitle => 'Décrivez-le';

  @override
  String get eventDescribeEyebrow => 'Court et utile';

  @override
  String get eventDescribeHint =>
      'ex. Arbres tombés sur A6 sud, 2 voies fermées';

  @override
  String get eventSubmitting => 'Envoi…';

  @override
  String get eventSubmitReport => 'Envoyer le signalement';

  @override
  String get narrativeBusy => 'Rédaction de votre résumé…';

  @override
  String get narrativeErrorTitle => 'Impossible d\'obtenir le résumé';

  @override
  String narrativeGeneratedAt(String when) {
    return 'Généré $when';
  }

  @override
  String get narrativeReadAloud => 'Lecture à voix haute';

  @override
  String get narrativeStop => 'Arrêter';

  @override
  String get historyTitle => 'Voyages enregistrés';

  @override
  String get historyEmptyTitle => 'Aucun voyage enregistré';

  @override
  String get historyEmptyBody =>
      'Planifiez un voyage et touchez le marque-page pour le conserver ici.';

  @override
  String get historyPlanCta => 'Planifier un voyage';

  @override
  String historyDeleted(String trip) {
    return 'Supprimé $trip';
  }

  @override
  String historyReplanFailed(int status) {
    return 'Échec de la re-planification : $status';
  }

  @override
  String get historyDeleteTooltip => 'Supprimer';

  @override
  String get historyReopenCta => 'Voir';

  @override
  String get historyRepeatCta => 'Répéter';

  @override
  String resultFuelCollapsedHint(int count) {
    return 'Afficher les $count stations les moins chères de la route';
  }

  @override
  String resultBestTimeVsFreeFlow(String delta) {
    return '$delta min vs flux libre';
  }

  @override
  String resultBestTimeEarlier(int minutes) {
    return '$minutes min avant votre heure cible';
  }

  @override
  String resultBestTimeLater(int minutes) {
    return '$minutes min après votre heure cible';
  }

  @override
  String resultHeroSavedBadge(String magnitude) {
    return '$magnitude économisées';
  }

  @override
  String get consistencyNeedsReview => 'Vérifiez votre plan de voyage';

  @override
  String consistencyNeedsReviewErrors(int errors) {
    return 'Vérifiez votre plan · $errors erreurs';
  }

  @override
  String consistencyNeedsReviewMixed(int errors, int warnings) {
    return 'Vérifiez votre plan · $errors erreur(s), $warnings avertissement(s)';
  }

  @override
  String get consistencyHeadsUp => 'Info sur votre plan';

  @override
  String consistencyHeadsUpWarnings(int warnings) {
    return 'Info sur votre plan · $warnings avertissements';
  }

  @override
  String consistencyMoreCount(int count) {
    return '+$count de plus';
  }

  @override
  String get planProfileClearOverride => 'Annuler l\'ajustement';

  @override
  String get weatherSunny => 'Ensoleillé';

  @override
  String get weatherPartlyCloudy => 'Partiellement nuageux';

  @override
  String get weatherCloudy => 'Nuageux';

  @override
  String get weatherFog => 'Brouillard';

  @override
  String get weatherDrizzle => 'Bruine';

  @override
  String get weatherRain => 'Pluie';

  @override
  String get weatherHeavyRain => 'Fortes pluies';

  @override
  String get weatherSnow => 'Neige';

  @override
  String get weatherHeavySnow => 'Fortes chutes de neige';

  @override
  String get weatherThunderstorm => 'Orage';

  @override
  String historyBestAt(String when) {
    return 'Optimal $when';
  }

  @override
  String historyWantedAt(String when) {
    return 'Souhaité $when';
  }

  @override
  String get searchPlaceholder => 'Rechercher une ville, musée, lieu…';

  @override
  String get placesSectionTitle => 'LIEUX ENREGISTRÉS';

  @override
  String get placeSaveAsTooltip => 'Enregistrer comme lieu';

  @override
  String get placeSaveDialogTitle => 'Enregistrer comme…';

  @override
  String get placeCustomLabel => 'Étiquette';

  @override
  String get placeCustomHint => 'Maison, Travail, Mamie…';

  @override
  String get placePresetHome => 'Maison';

  @override
  String get placePresetWork => 'Travail';

  @override
  String get placePresetSchool => 'École';

  @override
  String get placePresetGym => 'Gym';

  @override
  String placeSavedAs(String label) {
    return 'Enregistré comme $label';
  }

  @override
  String get favoritesTabPlaces => 'Lieux';

  @override
  String get favoritesEmptyPlaces =>
      'Aucun lieu enregistré. Touchez l\'étoile sur un résultat pour l\'enregistrer.';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsSectionAppearance => 'Apparence';

  @override
  String get settingsDensityLabel => 'Densité';

  @override
  String get settingsDensityComfortable => 'Confortable';

  @override
  String get settingsDensityCompact => 'Compacte';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get settingsSectionUnits => 'Unités';

  @override
  String get settingsUnitSystem => 'Système d\'unités';

  @override
  String get settingsUnitsMetric => 'Métrique';

  @override
  String get settingsUnitsImperial => 'Impérial';

  @override
  String get settingsSectionTrip => 'Voyage';

  @override
  String get settingsSectionAbout => 'À propos';

  @override
  String get settingsSectionData => 'Vos données';

  @override
  String get settingsExportData => 'Télécharger mes données';

  @override
  String get settingsExportDataSub =>
      'Obtenez un fichier JSON avec tout ce que MyTravelPal détient sur vous.';

  @override
  String get settingsExportError =>
      'Échec de l\'export — vérifiez votre connexion.';

  @override
  String get settingsDeleteAccount => 'Supprimer mon compte';

  @override
  String get settingsDeleteAccountSub =>
      'Supprime votre profil, voyages enregistrés et préférences définitivement.';

  @override
  String get settingsDeleteAccountConfirmTitle => 'Supprimer le compte ?';

  @override
  String get settingsDeleteAccountConfirmBody =>
      'Cela supprime votre profil et tous les voyages enregistrés de nos serveurs. Action irréversible.';

  @override
  String get settingsDeleteAccountCancel => 'Annuler';

  @override
  String get settingsDeleteAccountConfirm => 'Supprimer définitivement';

  @override
  String get settingsDeleteAccountPartial =>
      'Déconnecté localement, mais le serveur peut encore avoir des données. Réessayez avec une connexion stable.';

  @override
  String get settingsDeleteAccountDone => 'Compte supprimé. Déconnecté.';

  @override
  String get settingsDeleteAccountInProgress => 'Suppression du compte…';

  @override
  String get settingsSupport => 'Support et contact';

  @override
  String get settingsPrivacyPolicy => 'Politique de confidentialité';

  @override
  String get settingsTerms => 'Conditions d\'utilisation';

  @override
  String get settingsVersion => 'Version';

  @override
  String get planTooltipSettings => 'Paramètres';

  @override
  String get styleSectionTitle => 'Style de voyage';

  @override
  String get styleSectionEyebrow => 'Comment vous aimez conduire';

  @override
  String get stylePresetDirect => 'Direct';

  @override
  String get stylePresetBalanced => 'Équilibré';

  @override
  String get stylePresetSlow => 'Tranquille';

  @override
  String get stylePresetDirectHint =>
      'D\'une traite, arrêts minimums, jamais de nuit.';

  @override
  String get stylePresetBalancedHint =>
      'Rythme naturel, pauses quand ça a du sens.';

  @override
  String get stylePresetSlowHint =>
      'Savourez la route, pauses généreuses, coupez les longs trajets.';

  @override
  String get styleCustom => 'Personnalisé';

  @override
  String get styleAdvanced => 'Avancé';

  @override
  String get stylePaceLabel => 'Allure';

  @override
  String get stylePacePush => 'D\'une traite';

  @override
  String get stylePaceSteady => 'Normale';

  @override
  String get stylePaceSavour => 'Tranquille';

  @override
  String get styleOvernightLabel => 'Arrêts nuit';

  @override
  String get styleOvernightNever => 'Jamais';

  @override
  String get styleOvernightIfNeeded => 'Si nécessaire';

  @override
  String get styleOvernightAlwaysIfLong => 'Diviser les longs trajets';

  @override
  String get styleDailyCapLabel => 'Heures max de conduite par jour';

  @override
  String get styleBedtimeLabel => 'Heure du coucher';

  @override
  String get styleWakeLabel => 'Heure du réveil';

  @override
  String get styleBreakLabel => 'Style de pause';

  @override
  String get styleBreakMinimal => 'Minimum';

  @override
  String get styleBreakScenic => 'Panoramique';

  @override
  String get styleBreakFoodie => 'Gastronomique';

  @override
  String planStyleChip(String preset, int hours) {
    return '$preset · ${hours}h/jour';
  }

  @override
  String planStyleChipCustom(int hours) {
    return 'Personnalisé · ${hours}h/jour';
  }

  @override
  String get planStyleOverrideTitle => 'Style pour ce voyage';

  @override
  String get planStyleOverrideSubtitle =>
      'Modifie votre profil enregistré uniquement pour ce plan.';

  @override
  String get planStyleUseSavedProfile => 'Utiliser mon profil enregistré';

  @override
  String arrivalHintTitle(String hour) {
    return 'Vous arriveriez à ${hour}h';
  }

  @override
  String arrivalHintBody(String bedtime) {
    return 'Plus tard que votre heure de coucher (${bedtime}h). Envisagez une nuit d\'étape — hôtels ci-dessous.';
  }

  @override
  String get arrivalHintCta => 'Voir les hôtels';

  @override
  String get vehicleTypeCar => 'Voiture';

  @override
  String get vehicleTypeMotorbike => 'Moto';

  @override
  String get vehicleTypeVan => 'Fourgonnette';

  @override
  String get vehicleTypeCamper => 'Camping-car';

  @override
  String get fuelTypePetrol => 'Essence';

  @override
  String get fuelTypeDiesel => 'Diesel';

  @override
  String get fuelTypeHybrid => 'Hybride';

  @override
  String get fuelTypeElectric => 'Électrique';

  @override
  String get fuelTypeLpg => 'GPL';

  @override
  String get routeVariantFastest => 'Plus rapide';

  @override
  String get routeVariantTollFree => 'Sans péage';

  @override
  String get routeVariantScenic => 'Panoramique';

  @override
  String get eventTypeFire => 'Incendie';

  @override
  String get eventTypeStrike => 'Grève';

  @override
  String get eventTypeWeather => 'Météo défavorable';

  @override
  String get eventTypeAccident => 'Accident';

  @override
  String get eventTypeRoadwork => 'Travaux';

  @override
  String get eventTypeFlood => 'Inondation';

  @override
  String get eventTypeSnow => 'Neige';

  @override
  String get eventTypeProtest => 'Manifestation';

  @override
  String get eventTypeEarthquake => 'Séisme';

  @override
  String get eventTypeLandslide => 'Glissement de terrain';

  @override
  String get eventTypeAvalanche => 'Avalanche';

  @override
  String get eventTypeClosure => 'Route coupée';

  @override
  String get eventTypeHeatwave => 'Canicule';

  @override
  String get eventTypeHeavyRain => 'Pluie forte';

  @override
  String get eventTypeHail => 'Grêle';

  @override
  String get eventTypeThunderstorm => 'Orage';

  @override
  String get eventTypeHighWind => 'Vent fort';

  @override
  String get eventTypeDenseFog => 'Brouillard dense';

  @override
  String get eventTypeFreezingRain => 'Pluie verglaçante';

  @override
  String get eventTypeOther => 'Autre';

  @override
  String tollStretchLabel(int index, int total) {
    return 'Section à péage $index / $total';
  }

  @override
  String tollBoothLabel(int index) {
    return 'Péage $index';
  }

  @override
  String get addedToRouteLabel => 'AJOUTÉ';

  @override
  String get replanWithStops => 'Recalculer l\'itinéraire avec les arrêts';

  @override
  String get addToRouteTooltip => 'Ajouter à l\'itinéraire';

  @override
  String get removeFromRouteTooltip => 'Retirer de l\'itinéraire';

  @override
  String addedStopsChip(int count, String minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arrêts ajoutés · +$minutes min',
      one: '1 arrêt ajouté · +$minutes min',
    );
    return '$_temp0';
  }

  @override
  String get addedStopsClear => 'Effacer';

  @override
  String get settingsLicensesAndData => 'Licences et sources de données';

  @override
  String get settingsLicensesAndDataSub =>
      'Attributions des données ouvertes et bibliothèques';

  @override
  String get attributionsTitle => 'Licences et données';

  @override
  String get attributionsIntro =>
      'MyTravelPal s\'appuie sur des données ouvertes et des bibliothèques open-source. Cet écran crédite chaque source, renvoie vers les licences sous-jacentes et couvre nos obligations d\'attribution.';

  @override
  String get attributionsSectionMap => 'Carte et géodonnées';

  @override
  String get attributionsSectionFuel => 'Prix des carburants';

  @override
  String get attributionsSectionHazards => 'Événements';

  @override
  String get attributionsSectionWeather => 'Météo';

  @override
  String get attributionsSectionSoftware => 'Bibliothèques logicielles';

  @override
  String get attributionsShowLicenses => 'Voir les licences des paquets';

  @override
  String get attributionsFailed =>
      'Impossible de charger les attributions. Réessayez.';

  @override
  String get fuelPriceUnavailable => 'Prix non disponible';

  @override
  String get fuelPriceUnavailableHint =>
      'Aucun flux public de prix pour ce pays pour l\'instant';

  @override
  String get planSectionOptionalEyebrow => 'Optionnel';

  @override
  String get planOptAlertsTitle =>
      'M\'alerter sur les événements critiques de l\'itinéraire';

  @override
  String get planOptAlertsSub =>
      'Incendies, inondations, météo extrême et dangers graves dans un rayon de 25 km.';

  @override
  String get planOptTollFreeTitle => 'Afficher l\'alternative sans péage';

  @override
  String get planOptTollFreeSub =>
      'Compare un itinéraire sans péage — argent économisé vs. minutes ajoutées.';

  @override
  String get planOptHourlyTollTitle => 'Analyse horaire des péages';

  @override
  String get planOptHourlyTollSub =>
      'Quand éviter les péages vaut vraiment le coup (selon le trafic).';

  @override
  String get planOptRouteVariantsTitle => 'Comparer les variantes';

  @override
  String get planOptRouteVariantsSub =>
      'Rapide vs. sans péage vs. panoramique — les trois côte à côte.';

  @override
  String get planOptAvoidMotorwaysTitle => 'Éviter les autoroutes';

  @override
  String get planOptAvoidMotorwaysSub =>
      'Plus long et plus lent, mais sans péage et plus calme.';

  @override
  String get planOptPreferScenicTitle => 'Préférer panoramique';

  @override
  String get planOptPreferScenicSub =>
      'Favorise les routes plus intéressantes. Un peu plus lent.';

  @override
  String get planPremiumBadge => 'Premium';

  @override
  String planProfileTravellers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voyageurs',
      one: '1 voyageur',
    );
    return '$_temp0';
  }

  @override
  String get planProfileWithKids => 'enfants';

  @override
  String get planProfileWithPets => 'animaux';

  @override
  String get planProfileOverrideActive => 'REMPLACEMENT ACTIF';

  @override
  String get planProfileOverride => 'Remplacer pour ce trajet';

  @override
  String get planProfileOverriding => 'Remplacé pour ce trajet';

  @override
  String get profilePromptSetup => 'Configurez votre profil de voyage';

  @override
  String get hotelPrefTitle => 'Trouver des hôtels près des arrêts';

  @override
  String get hotelPrefSubOn =>
      'Affiche les hébergements près de chaque point de nuit';

  @override
  String get hotelPrefSubOff => 'Désactivé';

  @override
  String get restaurantPrefTitle => 'Ajouter des restaurants sur l\'itinéraire';

  @override
  String restaurantPrefSubEnabled(int minutes, String band) {
    return 'Jusqu\'à $minutes min de détour · $band';
  }

  @override
  String get restaurantPrefSubOff =>
      'Désactivé. Activez pour voir les restaurants près de l\'itinéraire.';

  @override
  String prefMaxDetour(int minutes) {
    return 'Détour max : $minutes min';
  }

  @override
  String get prefBandBudget => 'Économique';

  @override
  String get prefBandMid => 'Moyen';

  @override
  String get prefBandLuxury => 'Luxe';

  @override
  String get prefBandAny => 'Tous';

  @override
  String get mealSlotBreakfast => 'Suggérés pour le petit-déjeuner';

  @override
  String get mealSlotLunch => 'Suggérés pour le déjeuner';

  @override
  String get mealSlotDinner => 'Suggérés pour le dîner';

  @override
  String get mealSlotOther => 'Autres restaurants';

  @override
  String poiDistanceKm(String km, String minutes) {
    return '$km km · +$minutes min de détour';
  }

  @override
  String fuelSavingsChipCheap(String amount) {
    return '-$amount€/L vs moyenne pays';
  }

  @override
  String fuelSavingsChipDear(String amount) {
    return '+$amount€/L vs moyenne pays';
  }

  @override
  String get fuelArbitrageTitle => 'Faites le plein malin sur ce trajet';

  @override
  String fuelArbitrageBody(String cheap, String cheapPrice, String dear,
      String dearPrice, String savings) {
    return 'Le carburant en $cheap est à ~$cheapPrice€/L. En $dear il monte à ~$dearPrice€/L. Faire le plein en $cheap avant de traverser fait économiser ~$savings€.';
  }

  @override
  String dayTabLabel(int index) {
    return 'Jour $index';
  }

  @override
  String dayHeaderRange(int index, String fromKm, String toKm) {
    return 'Jour $index · km $fromKm → $toKm';
  }

  @override
  String dayHeaderCity(int index, String from, String to) {
    return 'Jour $index · $from → $to';
  }

  @override
  String dayArrivalMarker(String time) {
    return 'Arrivée à destination vers $time';
  }

  @override
  String daySleepMarker(String time) {
    return 'Fin de la conduite vers $time';
  }

  @override
  String dayStartsAt(String time) {
    return 'Départ à $time';
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
    return 'Jour $index · $place';
  }

  @override
  String daySleepStay(String place) {
    return 'Séjour à $place';
  }

  @override
  String get nextStopHeroLabel => 'Prochain arrêt suggéré';

  @override
  String nextStopHeroBody(String slot, String name, String time) {
    return '$slot à $name · vers $time';
  }

  @override
  String get daySleepHotelsLabel => 'Hôtels près de votre nuit';

  @override
  String hotelDistFromStop(String km) {
    return '$km km de l\'arrêt';
  }

  @override
  String hotelDistFromDestination(String km) {
    return '$km km de la destination';
  }

  @override
  String get daySleepHotelsLabelDestination => 'Hôtels près de la destination';

  @override
  String get daySleepHotelsEmpty =>
      'Activez les hôtels dans les préférences pour voir les options de nuit.';

  @override
  String get restaurantPrefCuisinesLabel => 'Type de cuisine';

  @override
  String get cuisineItalian => 'Italienne';

  @override
  String get cuisineSpanish => 'Espagnole';

  @override
  String get cuisineTapas => 'Tapas';

  @override
  String get cuisineFrench => 'Française';

  @override
  String get cuisineMediterranean => 'Méditerranéenne';

  @override
  String get cuisineAsian => 'Asiatique';

  @override
  String get cuisineIndian => 'Indienne';

  @override
  String get cuisineBurger => 'Burgers';

  @override
  String get cuisineSeafood => 'Poissons / fruits de mer';

  @override
  String get cuisineVegetarian => 'Végétarienne';

  @override
  String get cuisineBbq => 'Grillades / BBQ';

  @override
  String get cuisineRegional => 'Régionale';

  @override
  String timeWindowSpanLabel(int hours) {
    return 'Afficher ±${hours}h';
  }

  @override
  String get timeWindowSpanHelper =>
      'Faites glisser pour élargir la fenêtre et voir si partir plus tôt ou plus tard fait gagner plus de temps.';

  @override
  String get timeWindowTapHint =>
      'Appuyez sur une barre pour recalculer avec cet horaire de départ.';

  @override
  String get planLoadingTitle => 'Préparation de votre trajet';

  @override
  String get planLoadingStepRouting =>
      'Calcul de l\'itinéraire le plus rapide…';

  @override
  String get planLoadingStepTraffic =>
      'Analyse du trafic pour choisir la meilleure heure de départ…';

  @override
  String get planLoadingStepFuel =>
      'Récupération des prix réels des carburants…';

  @override
  String get planLoadingStepHotels =>
      'Recherche d\'hôtels près des étapes de nuit…';

  @override
  String get planLoadingStepRestaurants =>
      'Tri des restaurants par créneau et type de cuisine…';

  @override
  String get planLoadingStepAlerts =>
      'Détection des incendies, inondations, météo extrême et dangers…';

  @override
  String get planLoadingStepTolls =>
      'Comparaison itinéraires péage vs. sans péage…';

  @override
  String get planLoadingStepAlmost => 'Presque terminé — assemblage en cours…';

  @override
  String get planLoadingHelper =>
      'Peut prendre quelques minutes. Vous pouvez ranger le téléphone.';

  @override
  String timeWindowApplyLabel(String time) {
    return 'Appliquer · départ à $time';
  }

  @override
  String get planErrorAuth => 'Session expirée. Reconnectez-vous et réessayez.';

  @override
  String get planErrorPremium =>
      'Ce trajet nécessite Premium. Activez-le pour inclure l\'analyse des péages par heure.';

  @override
  String get planErrorRateLimit =>
      'Trop de requêtes en peu de temps. Attendez quelques secondes puis réessayez.';

  @override
  String planErrorGeneric(int code) {
    return 'Un problème est survenu lors de la planification (code $code). Réessayez ou modifiez les entrées.';
  }

  @override
  String get planErrorNetwork =>
      'Impossible de joindre le serveur. Vérifiez votre connexion et réessayez.';

  @override
  String get planErrorRetry => 'Réessayer';

  @override
  String get emptyAlertsTitle => 'Aucun danger grave détecté';

  @override
  String get emptyAlertsBody =>
      'Aucun incendie, inondation ou danger grave signalé sur votre corridor. Bon voyage.';

  @override
  String get emptyHotelsTitle => 'Aucun hôtel près de l\'itinéraire';

  @override
  String get emptyHotelsBody =>
      'Essayez d\'élargir le détour max ou de changer la gamme de prix.';

  @override
  String get emptyRestaurantsTitle => 'Aucun restaurant ne correspond';

  @override
  String get emptyRestaurantsBody =>
      'Élargissez le détour max ou retirez les filtres de cuisine.';

  @override
  String get onboardEyebrowFuel => 'PRIX RÉELS';

  @override
  String get onboardTitleFuel => 'Économisez à chaque plein';

  @override
  String get onboardBodyFuel =>
      'Prix par station le long de ta route à travers l\'Europe. Marques premium mélangées aux low-cost.';

  @override
  String get onboardEyebrowDriving => 'SUR LA ROUTE';

  @override
  String get onboardTitleDriving => 'Votre copilote intelligent';

  @override
  String get onboardBodyDriving =>
      'Tableau de bord en direct avec prochain arrêt, arrivée dynamique et nouvelles alertes. Compatible Android Auto.';

  @override
  String get onboardEyebrowProfile => 'PERSONNALISÉ';

  @override
  String get onboardTitleProfile => 'Remplissez votre profil';

  @override
  String get onboardBodyProfile =>
      'Sans profil nous optimisons juste le temps. Avec profil nous calculons carburant réel, hôtels et repas adaptés.';

  @override
  String get multiDaySleepLabel => 'Vous dormirez à';

  @override
  String get multiDaySleepNoHotel => 'Étape nuit — aucun hôtel disponible';

  @override
  String get resumeTripTitle => 'Reprendre votre trajet ?';

  @override
  String resumeTripBody(String origin, String destination) {
    return 'Nous avons détecté un trajet $origin → $destination en cours. Reprendre où vous en étiez ?';
  }

  @override
  String get resumeTripResume => 'Reprendre';

  @override
  String get resumeTripDismiss => 'Ignorer';

  @override
  String get hotelPrefStarsLabel => 'Étoiles';

  @override
  String get hotelPrefDestRadiusLabel => 'Rayon depuis la destination';

  @override
  String get biometricPromptReason =>
      'Vérifiez votre identité pour ouvrir MyTravelPal';

  @override
  String get biometricPromptSettings =>
      'Confirme l\'activation du déverrouillage biométrique';

  @override
  String get planDepartureLabel => 'Départ souhaité';

  @override
  String get hotelPrefStarsAny => 'Toutes';

  @override
  String get hotelPrefParkingTitle => 'Avec parking';

  @override
  String get hotelPrefParkingSub =>
      'Seulement les hôtels tagués avec parking. Ceux sans étiquette passent aussi.';

  @override
  String get hotelFilterParking => 'Parking';

  @override
  String get hotelFilterWifi => 'WiFi gratuit';

  @override
  String get hotelFilterAccessible => 'Accessible';

  @override
  String get hotelFilterOtherTypes => 'Apparts, maisons et plus';

  @override
  String get restaurantFilterVegetarian => 'Végétarien';

  @override
  String get restaurantFilterVegan => 'Végan';

  @override
  String get restaurantFilterGlutenFree => 'Sans gluten';

  @override
  String get restaurantFilterHalal => 'Halal';

  @override
  String get restaurantFilterKosher => 'Casher';

  @override
  String get restaurantDietaryLabel => 'Régime';

  @override
  String get tollSkipSelectAll => 'Tout sélectionner';

  @override
  String get mapShowLabel => 'Afficher la carte';

  @override
  String get mapHideLabel => 'Masquer la carte';

  @override
  String get tripCostTitle => 'COÛT TOTAL DU VOYAGE';

  @override
  String get tripCostFuel => 'Carburant';

  @override
  String get tripCostTolls => 'Péages';

  @override
  String get tripCostMeals => 'Repas';

  @override
  String get tripCostHotel => 'Hôtel';

  @override
  String get tripCostTotal => 'Total estimé';

  @override
  String get addToRouteLabel => 'Ajouter à l\'itinéraire';

  @override
  String get biometricSetupTitle => 'Activer la biométrie ?';

  @override
  String get biometricSetupBody =>
      'Utilisez votre empreinte ou visage pour déverrouiller MyTravelPal.';

  @override
  String get biometricSetupEnable => 'Activer';

  @override
  String get biometricSetupSkip => 'Pas maintenant';

  @override
  String get weatherAlongRouteTitle => 'MÉTÉO SUR VOTRE ITINÉRAIRE';

  @override
  String get fuelNotificationTitle => 'Faites le plein avant la frontière !';

  @override
  String fuelNotificationBody(
      String cheap, String price, String pricey, String savings) {
    return 'Carburant en $cheap (~$price€/L) avant de passer en $pricey — économisez ~$savings€/réservoir';
  }

  @override
  String get tutorialSkip => 'Passer';

  @override
  String get tutorialOriginTitle => 'D\'où partez-vous ?';

  @override
  String get tutorialOriginBody =>
      'Touchez ici pour chercher une ville ou utilisez le bouton de localisation pour partir de votre position actuelle.';

  @override
  String get tutorialDestinationTitle => 'Où allez-vous ?';

  @override
  String get tutorialDestinationBody =>
      'Cherchez votre destination. Nous planifierons l\'itinéraire complet avec arrêts, hôtels et péages.';

  @override
  String get tutorialPrefsTitle => 'Personnalisez votre voyage';

  @override
  String get tutorialPrefsBody =>
      'Activez hôtels, restaurants et alertes. Configurez préférences alimentaires, étoiles et plus.';

  @override
  String get tutorialTimeWindowTitle =>
      'Choisissez la meilleure heure de départ';

  @override
  String get tutorialTimeWindowBody =>
      'Touchez une tranche pour replanifier avec cette heure. Le graphique montre l\'impact du trafic à chaque heure.';

  @override
  String get tutorialTollTitle => 'Gérez les péages';

  @override
  String get tutorialTollBody =>
      'Activez ou désactivez chaque tronçon de péage. L\'économie totale se met à jour en temps réel.';

  @override
  String styleDailyCapRecommendedHint(int hours) {
    return 'Pour ce rythme nous suggérons $hours h/jour.';
  }

  @override
  String get aaCoachTitle => 'Comment l\'ouvrir sur Android Auto';

  @override
  String get aaCoachStep1 =>
      'Connectez le téléphone à la voiture en USB (ou sans fil si votre autoradio le permet).';

  @override
  String get aaCoachStep2 =>
      'Dans le lanceur, passez à la catégorie \'Point of Interest\' ou \'Apps\'. Elle N\'apparaît PAS à côté de Google Maps.';

  @override
  String get aaCoachStep3 =>
      'Touchez MyTravelPal. Le companion affiche prochain arrêt, carburant moins cher et arrivée.';

  @override
  String get aaCoachHint =>
      'Le premier lancement prend quelques secondes. Garez-vous avec vue dégagée pour capter le GPS.';

  @override
  String get aaCoachDontShowAgain => 'Ne plus afficher';

  @override
  String get aaCoachDone => 'Compris';

  @override
  String get batteryWhitelistTitle => 'Empêchez Android de nous fermer';

  @override
  String get batteryWhitelistBody =>
      'Xiaomi/MIUI, Samsung et autres constructeurs ferment les apps en arrière-plan après quelques minutes. Si vous naviguez avec Google Maps et que MyTravelPal meurt, vous perdez les alertes en direct.';

  @override
  String get batteryWhitelistSteps =>
      'Paramètres → Apps → MyTravelPal → Batterie → Aucune restriction\n(ou \'Ne pas optimiser\' selon le modèle)';

  @override
  String get batteryWhitelistDontShowAgain => 'Ne plus afficher';

  @override
  String get batteryWhitelistLater => 'Pas maintenant';

  @override
  String get batteryWhitelistOpen => 'Ouvrir l\'aide';

  @override
  String get planRoundTripTitle => 'Aller-retour';

  @override
  String get planRoundTripSubtitle =>
      'Nous planifions le retour en même temps avec les mêmes préférences.';

  @override
  String get roundTripLegOutbound => 'ALLER';

  @override
  String get roundTripLegReturn => 'RETOUR';

  @override
  String roundTripSwapTo(String leg) {
    return 'Voir $leg';
  }

  @override
  String get resultStartTrip => 'Démarrer le trajet';

  @override
  String get resultStartCompanion => 'Démarrer le mode Compagnon';

  @override
  String get companionPreflightTitle => 'Réglages avant conduite';

  @override
  String get companionPreflightMealWindows => 'Horaires des repas';

  @override
  String get companionPreflightDetourTolerance => 'Détour max';

  @override
  String get companionPreflightMealBudget => 'Budget par repas';

  @override
  String get companionPreflightHotelBudget => 'Budget par nuit';

  @override
  String get companionPreflightSaveToProfile => 'Enregistrer dans mon profil';

  @override
  String get companionPreflightStart => 'Commencer à conduire';

  @override
  String get companionPreflightBreakfast => 'Petit-déjeuner';

  @override
  String get companionPreflightLunch => 'Déjeuner';

  @override
  String get companionPreflightDinner => 'Dîner';

  @override
  String get navPickerTitle => 'Continuer dans…';

  @override
  String get tripDashboardTitle => 'En route';

  @override
  String get tripDashboardCenterOnMe => 'Centrer sur ma position';

  @override
  String get tripDashboardOpenNav => 'Ouvrir la navigation';

  @override
  String tripDashboardNextStopLabel(String slot) {
    return 'PROCHAIN $slot';
  }

  @override
  String tripDashboardInMinutes(int n) {
    return 'dans $n min';
  }

  @override
  String get tripDashboardPermissionDenied =>
      'Localisation refusée. Autorisez-la pour voir votre position sur l\'itinéraire.';

  @override
  String get tripDashboardServiceDisabled =>
      'GPS désactivé. Activez-le pour suivre votre progression.';

  @override
  String tripDashboardProgressLine(String done, String total) {
    return '$done / $total km';
  }

  @override
  String tripDashboardEta(String time) {
    return 'Arrivée $time';
  }

  @override
  String get tripDashboardActiveNotifTitle => 'Trajet en cours';

  @override
  String get tripDashboardActiveNotifBody =>
      'MyTravelPal suit votre itinéraire en arrière-plan.';

  @override
  String tripDashboardForegroundBodyBare(String done, String total) {
    return '$done / $total km parcourus';
  }

  @override
  String tripDashboardForegroundBodyWithStop(
      String done, String total, String name) {
    return '$done / $total km · prochain arrêt : $name';
  }

  @override
  String get tripDashboardSleepStopLabel => 'hôtel';

  @override
  String get alertApproachingStopTitle => 'Arrêt proche';

  @override
  String alertApproachingStopBody(String slot, String name, int mins) {
    return '$slot à $name dans environ $mins min. Préparez la sortie.';
  }

  @override
  String get alertNewAdverseAheadTitle => 'Nouvelle alerte sur la route';

  @override
  String alertNewAdverseAheadBody(String type, String km) {
    return '$type signalé à $km km devant.';
  }

  @override
  String get alertDriftDetectedTitle => 'Vous avez quitté l\'itinéraire';

  @override
  String alertDriftDetectedBody(String off) {
    return 'Vous êtes à $off m du tracé prévu. Recalculer ?';
  }

  @override
  String get alertBehindScheduleTitle => 'En retard';

  @override
  String alertBehindScheduleBody(int mins) {
    return 'Vous arriverez avec $mins min de retard.';
  }

  @override
  String tripDashboardCheaperFuel(String brand, String km, String cts) {
    return '$brand dans $km km · économisez $cts ct/L';
  }

  @override
  String get resultOptimalDeparture => 'Votre heure de départ est optimale';

  @override
  String shortLastDayWarning(String km) {
    return 'Dernière étape courte ($km km) — vous pourriez arriver aujourd\'hui en allant plus loin la veille.';
  }

  @override
  String get prepareDepartureNow => 'Partir maintenant';

  @override
  String get replanNewDepartureTitle =>
      'Recalcul avec le nouvel horaire de départ…';

  @override
  String get planStopReorderHint => 'Maintiens la poignée pour réorganiser';

  @override
  String get planSwapOriginDestination => 'Inverser';

  @override
  String get planStopMoveUp => 'Monter';

  @override
  String get planStopMoveDown => 'Descendre';

  @override
  String get recentTripsTitle => 'Trajets récents';

  @override
  String recentTripsSubtitle(int count) {
    return '$count enregistrés — tape pour réutiliser';
  }

  @override
  String get onRouteTitle => 'Sur l\'itinéraire';

  @override
  String get onRouteEmpty => 'Tape pour choisir des options';

  @override
  String get exportShareTitle => 'Partager l\'itinéraire';

  @override
  String get exportOpenInMaps => 'Ouvrir dans Google Maps';

  @override
  String get exportCopyLink => 'Copier le lien';

  @override
  String get exportLinkCopied => 'Lien copié dans le presse-papiers';

  @override
  String get exportShareOs => 'Partager…';

  @override
  String get exportShareSubject => 'Mon itinéraire sur MyTravelPal';

  @override
  String get importFromMaps => 'Importer depuis Maps';

  @override
  String get importFromMapsTitle => 'Importer un itinéraire Google Maps';

  @override
  String get importFromMapsHint => 'Colle un lien Google Maps ici';

  @override
  String get importFromMapsPaste => 'Coller';

  @override
  String get importFromMapsImport => 'Importer';

  @override
  String get importFromMapsError => 'URL non reconnue';

  @override
  String get importFromMapsErrorMalformed =>
      'URL invalide — vérifie le lien et réessaie';

  @override
  String get importFromMapsErrorShortlink =>
      'Impossible d\'étendre le lien court — ouvre-le dans Maps et copie l\'URL complète';

  @override
  String get importFromMapsErrorGeocode =>
      'Impossible de localiser les lieux — essaie un trajet plus court ou saisis-les manuellement';

  @override
  String get importFromMapsLoading => 'Analyse du lien…';

  @override
  String adverseEventsBannerCount(int count) {
    return '$count alerte(s) sur votre trajet';
  }

  @override
  String pricePerMeal(String price) {
    return '$price €/repas';
  }

  @override
  String kmFromOrigin(String km) {
    return '$km km depuis l\'origine';
  }

  @override
  String get profileVehicleModel => 'Modèle';

  @override
  String get profileVehicleModelHint => 'Choisissez votre modèle';

  @override
  String get profileVehicleModelClear => 'Retirer le modèle';

  @override
  String get profileTankLevel => 'Réservoir actuel';

  @override
  String get vehiclePickerSearchHint => 'Rechercher marque ou modèle';

  @override
  String get vehiclePickerEmpty => 'Aucun modèle ne correspond';

  @override
  String get vehiclePickerLoadError =>
      'Impossible de charger la liste. Réessayez plus tard.';

  @override
  String refuelWindowComfortable(String km) {
    return 'Faites le plein avant le km $km (confortable)';
  }

  @override
  String refuelWindowCritical(String km) {
    return 'Faites le plein avant le km $km (critique)';
  }
}
