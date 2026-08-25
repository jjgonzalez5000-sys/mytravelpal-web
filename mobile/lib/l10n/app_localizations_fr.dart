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
  String get profileMealTimes => 'Heures des repas';

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
  String get resultRestStops => 'Pauses';

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
  String get eventSeverityWarning => 'Avertissement';

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
}
