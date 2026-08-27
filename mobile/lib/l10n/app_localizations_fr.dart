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
      'Incendies, grèves, météo, travaux — vous décidez quand elles apparaissent, et seulement quand elles touchent votre itinéraire.';

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
      'Incendies, grèves, météo, travaux, accidents, inondations, neige, manifestations — triées par gravité.';

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
  String get resultOptimized => 'Optimisé pour votre voyage';

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
  String get resultOptimizedEyebrow => 'Selon votre profil';

  @override
  String get resultOptimizedDescription =>
      'Repas, hébergement et carburant adaptés à votre profil.';

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
  String get planOptAlertsTitle => 'M\'alerter sur les événements';

  @override
  String get planOptAlertsSub =>
      'Incendies, grèves, météo, travaux et plus dans un rayon de 25 km.';

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
  String daySleepMarker(String time) {
    return 'Fin de la conduite vers $time';
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
      'Détection des incendies, travaux, météo, manifestations…';

  @override
  String get planLoadingStepTolls =>
      'Comparaison itinéraires péage vs. sans péage…';

  @override
  String get planLoadingStepAlmost => 'Presque terminé — assemblage en cours…';

  @override
  String get planLoadingHelper =>
      'Généralement 5 à 15 secondes. Vous pouvez ranger le téléphone.';

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
  String get emptyAlertsTitle => 'Itinéraire dégagé';

  @override
  String get emptyAlertsBody =>
      'Aucun incendie, travaux ou événement adverse signalé sur votre corridor. Bon voyage.';

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
      'Prix officiels par station en Espagne, France et Italie. Marques premium mélangées aux low-cost.';

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
  String get hotelFilterOtherTypes => 'Maisons d\'hôtes et plus';

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
}
