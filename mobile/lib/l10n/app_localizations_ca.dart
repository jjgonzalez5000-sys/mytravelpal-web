// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Catalan Valencian (`ca`).
class AppLocalizationsCa extends AppLocalizations {
  AppLocalizationsCa([String locale = 'ca']) : super(locale);

  @override
  String get appName => 'MyTravelPal';

  @override
  String get appTagline => 'Planifica el viatge, no només el destí';

  @override
  String get onboardEyebrowKiller => 'THE REAL COST';

  @override
  String get onboardTitleKiller =>
      'Your GPS shows the way.\nWe show what it costs.';

  @override
  String get onboardBodyKiller =>
      'Tolls, fuel, hotels and meals — all calculated before you leave. No surprises.';

  @override
  String get onboardEyebrowHonest => 'YOUR PROFILE, YOUR TRIP';

  @override
  String get onboardTitleHonest =>
      '2 adults, 1 kid, dog.\nParking. 3 stars max €€.';

  @override
  String get onboardBodyHonest =>
      'Hotels and restaurants filtered by your actual preferences. Not a generic list — yours.';

  @override
  String get onboardEyebrowAlerts => 'REAL-TIME ALERTS';

  @override
  String get onboardTitleAlerts => 'Wildfire 14 km\nfrom your route.';

  @override
  String get onboardBodyAlerts =>
      'Fires, storms, earthquakes, road closures. Only events that affect your specific route, before you reach them.';

  @override
  String get onboardCostFuel => 'Combustible';

  @override
  String get onboardCostTolls => 'Peatges';

  @override
  String get onboardCostMeals => 'Menjars';

  @override
  String get onboardCostHotel => 'Hotel';

  @override
  String get onboardCostTotal => 'TOTAL';

  @override
  String get onboardSavingsTitle => 'Estalvis detectats';

  @override
  String get onboardSavingsToll => 'Peatge alternatiu';

  @override
  String get onboardSavingsFuel => 'Gasolinera òptima';

  @override
  String get onboardSavingsHotel => 'Millor hotel';

  @override
  String get onboardSavingsTotal => 'TOTAL ESTALVIAT';

  @override
  String get onboardSkip => 'Skip';

  @override
  String get onboardContinue => 'Continue';

  @override
  String get onboardGetStarted => 'Get started';

  @override
  String get onboardFooter =>
      'Free to start · Premium unlocks the AI trip briefing';

  @override
  String get loginContinueApple => 'Continue with Apple';

  @override
  String get loginContinueGoogle => 'Continue with Google';

  @override
  String get loginContinueFacebook => 'Continue with Facebook';

  @override
  String get loginContinueDemo => 'Continue as demo';

  @override
  String get loginDivider => 'or';

  @override
  String get loginTerms =>
      'By continuing you accept our terms and privacy policy.';

  @override
  String get loginBusy => 'Signing you in…';

  @override
  String get planTitle => 'Plan a road trip';

  @override
  String get planEyebrow => 'EL PLANIFICADOR';

  @override
  String get planHero => 'On anem\navui?';

  @override
  String planHeroPersonal(String name) {
    return 'On anem,\n$name?';
  }

  @override
  String get planIntro =>
      'Tria dos punts i una hora. De la resta ens n\'encarreguem nosaltres.';

  @override
  String get planFrom => 'Des de';

  @override
  String get planTo => 'Fins a';

  @override
  String get planDesiredDeparture => 'Desired departure';

  @override
  String get planCta => 'Plan trip';

  @override
  String get planCtaBusy => 'Planning your trip…';

  @override
  String get planCountriesNote =>
      'Countries are detected automatically from your route.';

  @override
  String get planSectionOptional => 'Along the route';

  @override
  String get planMoreOptions => 'More options';

  @override
  String get planLessOptions => 'Fewer options';

  @override
  String get planRoundTripChip => 'Round trip';

  @override
  String get planLeaveNowFabTitle => 'Leave now';

  @override
  String get leaveNowConfirmTitle => 'Leave now to';

  @override
  String leaveNowConfirmBody(Object name) {
    return 'Head to $name?';
  }

  @override
  String get leaveNowConfirmCta => 'Let\'s go';

  @override
  String get leaveNowConfirmChange => 'Change destination';

  @override
  String get settingsBiometric => 'Biometric unlock';

  @override
  String get settingsBiometricSub => 'Use fingerprint or face to open the app';

  @override
  String get settingsBiometricUnavailable => 'Not available on this device';

  @override
  String get settingsReplayTutorial => 'Replay tutorial';

  @override
  String get settingsReplayTutorialSub => 'Show the guided coach-marks again';

  @override
  String get settingsReplayTutorialToast =>
      'Tutorial reset. Reopen Plan to see it.';

  @override
  String get settingsColorPreset => 'Colour preset';

  @override
  String get settingsPresetForest => 'Forest';

  @override
  String get settingsPresetSunset => 'Sunset';

  @override
  String get settingsPresetOcean => 'Ocean';

  @override
  String get settingsDynamicColor => 'Material You (dynamic)';

  @override
  String get settingsDynamicColorSub =>
      'Match colours to your wallpaper (Android 12+)';

  @override
  String get settingsOled => 'Pure black (OLED)';

  @override
  String get settingsOledSub =>
      'Deeper blacks in dark mode, saves battery on OLED screens';

  @override
  String get parkingSearchTitle => 'Find parking';

  @override
  String get parkingSearchLabel => 'Where are you going?';

  @override
  String get parkingSearchHint => 'Pick a destination and see parking nearby.';

  @override
  String get parkingRadiusLabel => 'Radius';

  @override
  String get parkingNoResults => 'No parking found within radius.';

  @override
  String get parkingPriceUnknown => 'Price ?';

  @override
  String get parkingCovered => 'Covered';

  @override
  String get parkingFilterKids => 'Kids';

  @override
  String get parkingFilterDogs => 'Dogs';

  @override
  String get parkingFilterToilets => 'Toilets';

  @override
  String get parkingFilterFood => 'Food';

  @override
  String get parkingFilterShowers => 'Showers';

  @override
  String get parkingFilterEv => 'EV charger';

  @override
  String get parkingFilterFuel => 'Fuel';

  @override
  String get parkingFilterWheelchair => 'Wheelchair';

  @override
  String get parkingFilterRv => 'RV / camper';

  @override
  String get parkingFilterTruck => 'Truck';

  @override
  String get planFindParkingCta => 'Find parking';

  @override
  String get poiFindParking => 'Parking';

  @override
  String get parkingPrefTitle => 'Parking';

  @override
  String get parkingPrefSub => 'Show parkings near the destination.';

  @override
  String get parkingResultTitle => 'Parking near destination';

  @override
  String get inspireTitle => 'Trip Inspiration';

  @override
  String get inspireHero => 'Describe your dream road trip';

  @override
  String get inspireSub =>
      'AI drafts a multi-day itinerary you can turn into a real plan in one tap.';

  @override
  String get inspireHint => 'e.g. Romantic 4-day drive through Italian lakes';

  @override
  String get inspireGenerate => 'Inspire me';

  @override
  String get inspireGenerating => 'Thinking up your trip…';

  @override
  String get inspireError =>
      'The muse is offline. Try a different prompt or try again.';

  @override
  String get inspireResultTitle => 'Your proposed itinerary';

  @override
  String inspireDayLabel(Object n) {
    return 'Day $n';
  }

  @override
  String get inspireBudgetLabel => 'Estimated budget';

  @override
  String get inspireConvertToPlan => 'Turn into a real plan';

  @override
  String get inspireSave => 'Save';

  @override
  String get inspireSavedToast =>
      'Idea saved. Find it in your saved inspirations.';

  @override
  String get inspireRecentTitle => 'Recent inspirations';

  @override
  String get inspireHistoryTitle => 'My AI plans';

  @override
  String get inspireHistoryEmpty =>
      'No AI plans yet. Generate one from the Plan tab.';

  @override
  String get inspireHistoryDelete => 'Delete';

  @override
  String get settingsMyAiPlans => 'My AI plans';

  @override
  String get settingsMyAiPlansSub => 'History of Trip Inspiration results';

  @override
  String get inspireChatTitle => 'Refine the itinerary';

  @override
  String get inspireChatHint =>
      'Change something: \"remove Cremona\", \"leave Friday evening\"…';

  @override
  String get inspireExamplesTitle => 'Or start from an idea';

  @override
  String get inspireExample1 => 'Weekend of castles in the Loire Valley';

  @override
  String get inspireExample2 => 'Coastal drive Barcelona to Marseille';

  @override
  String get inspireExample3 => '5-day Alpine loop from Milan';

  @override
  String get inspireExample4 => 'Northern Spain with kids, no highways';

  @override
  String get planOverrideForTrip => 'Override for this trip';

  @override
  String get planOverrideActive => 'Overriding for this trip';

  @override
  String get planOverrideClear => 'Clear override';

  @override
  String get planTooltipDashboard => 'Panell';

  @override
  String get planTooltipReport => 'Informar d\'un esdeveniment';

  @override
  String get planTooltipSaved => 'Viatges desats';

  @override
  String get tabPlan => 'Planificar';

  @override
  String get tabCompanion => 'Acompanyant';

  @override
  String get tabMyTrips => 'Els meus viatges';

  @override
  String get companionHeroTitle => 'El teu acompanyant de viatge';

  @override
  String get companionHeroBody =>
      'Marca les teves condicions i arrenca. L\'app segueix la teva conducció i recomana quan parar, on menjar i on repostar.';

  @override
  String get companionConfigSection => 'CONFIGURACIÓ';

  @override
  String get companionBreakInterval => 'Suggerir descans cada';

  @override
  String get companionSuggestBreak => 'Suggest a rest based on drive time';

  @override
  String companionBreakHint(String hours) {
    return 'Recomanar parada cada $hours h de conducció';
  }

  @override
  String get companionFatigueStopExperimental =>
      'Suggest pulling over on fatigue (experimental)';

  @override
  String get companionFatigueStopHint =>
      'Timer-only signal today — over-eager for short micro-pauses.';

  @override
  String get companionAlerts => 'Tipus d\'avís';

  @override
  String get companionAlertCriticalAdverse =>
      'Critical incidents (fires, floods, quakes)';

  @override
  String get companionAlertCriticalAdverseHint =>
      'Recommended. Something serious happening near you — not just weather.';

  @override
  String get companionAlertWeather => 'Meteo per endavant';

  @override
  String get companionAlertFuel => 'Oportunitats de combustible';

  @override
  String get companionAlertBorder => 'Avís en creuar fronteres';

  @override
  String get companionAlertToll => 'Suggeriments per saltar peatges';

  @override
  String get companionAlertHotel =>
      'Suggeriments d\'hotel quan estiguis cansat';

  @override
  String get companionStart => 'Iniciar acompanyant';

  @override
  String get companionComingSoon => 'Mode acompanyant properament';

  @override
  String get companionDriveTitle => 'Acompanyant actiu';

  @override
  String get companionForegroundBody =>
      'MyTravelPal està seguint la teva conducció';

  @override
  String get companionLocationDenied =>
      'Cal permís d\'ubicació per a l\'acompanyant.';

  @override
  String get companionDriving => 'conduint';

  @override
  String get companionAllGood => 'Sense avisos — bon viatge.';

  @override
  String get companionWeatherRowEmpty => 'Sense avisos propers';

  @override
  String get companionEndTitle => 'Acabar acompanyant?';

  @override
  String get companionEndBody =>
      'El seguiment s\'aturarà i els avisos actius es perdran.';

  @override
  String get companionEndKeep => 'Continuar';

  @override
  String get companionEndConfirm => 'Acabar sessió';

  @override
  String get emergencyContactsTitle => 'Contactes d\'emergència';

  @override
  String get emergencyContactsSubtitle => 'Reben SMS si es detecta un impacte';

  @override
  String get emergencyContactsBody =>
      'Fins a 3 persones reben un SMS amb la teva ubicació si l\'acompanyant detecta un impacte.';

  @override
  String get emergencyContactsEmpty => 'Encara no hi ha contactes.';

  @override
  String get emergencyContactsAdd => 'Afegir contacte';

  @override
  String get emergencyContactsPickFromDevice => 'Pick from contacts';

  @override
  String get emergencyContactsPickSearch => 'Search contacts';

  @override
  String get emergencyContactsPermDenied =>
      'Contacts permission denied. You can still add manually.';

  @override
  String get emergencyContactsNoDevice =>
      'No contacts with a phone number on this device.';

  @override
  String get emergencyContactAddTitle => 'Afegir contacte d\'emergència';

  @override
  String get emergencyContactName => 'Nom';

  @override
  String get emergencyContactNameRequired => 'Escriu un nom';

  @override
  String get emergencyContactPhone => 'Telèfon (E.164)';

  @override
  String get emergencyContactPhoneRequired => 'Escriu un telèfon';

  @override
  String get emergencyContactPhoneInvalid =>
      'Format internacional: +34612345678';

  @override
  String get cancel => 'Cancel·lar';

  @override
  String get save => 'Desar';

  @override
  String get sosTitle => 'Possible impacte detectat';

  @override
  String sosBody(String g, String speed) {
    return 'Pic d\'impacte ${g}g · caiguda de velocitat $speed km/h.';
  }

  @override
  String sosCountdown(int seconds) {
    return '${seconds}s';
  }

  @override
  String get sosImOk => 'Estic bé — cancel·lar';

  @override
  String get sosCall112 => 'Trucar 112';

  @override
  String get sosCancelled => 'Alerta cancel·lada.';

  @override
  String get sosClose => 'Tancar';

  @override
  String get sosNoContacts =>
      'Cap contacte configurat. Afegeix-ne un a Configuració.';

  @override
  String sosSmsDispatched(int count) {
    return 'SMS preparat per a $count contacte(s).';
  }

  @override
  String get sosSmsFailed =>
      'No s\'ha pogut obrir SMS. Truca manualment a baix.';

  @override
  String get sosSmsPrefix =>
      'MyTravelPal — possible impacte detectat. La meva ubicació:';

  @override
  String get weatherForecastTitle => 'Previsió 7 dies';

  @override
  String get weatherToday => 'Avui';

  @override
  String get leaveNowTitle => 'Sortir ja amb acompanyant';

  @override
  String get leaveNowSubtitle =>
      'Tria destinació i arrenca — et seguim i et guiem.';

  @override
  String get leaveNowSheetTitle => 'On vas?';

  @override
  String get leaveNowPremiumTitle => 'Funció Premium';

  @override
  String get leaveNowPremiumBody =>
      '\'Sortir ja\' combina el pla complet amb l\'acompanyant durant la conducció. Disponible amb MyTravelPal Premium.';

  @override
  String get leaveNowPremiumDismiss => 'Més tard';

  @override
  String get leaveNowPremiumCta => 'Prova 7 dies gratis';

  @override
  String get shareCardOption => 'Compartir com a imatge';

  @override
  String get shareCardOptionSub =>
      'Perfecte per a Instagram Stories, WhatsApp, X';

  @override
  String get shareLinkOption => 'Compartir com a enllaç';

  @override
  String get shareLinkOptionSub => 'Resum en text + enllaç per reobrir el pla';

  @override
  String get shareToSocial => 'Share to social';

  @override
  String get sharePlanTitle => 'Share trip link';

  @override
  String get sharePlanSubtitle => 'QR code + link to reopen this plan';

  @override
  String get sharePlanCopy => 'Copy link';

  @override
  String get sharePlanCopied => 'Link copied';

  @override
  String shareLiveHeadline(String city) {
    return 'Conduint per $city';
  }

  @override
  String shareLiveCaption(String city) {
    return 'Conduint per $city amb MyTravelPal 🚗';
  }

  @override
  String get planAddStop => 'Add stop';

  @override
  String get planStopDwellPassThrough => 'Just passing through';

  @override
  String get planStopDwellOneNight => '1 night';

  @override
  String planStopDwellNights(int n) {
    return '$n nights';
  }

  @override
  String planStopDwellHours(int n) {
    return '$n hores';
  }

  @override
  String planStopDwellTitle(Object name) {
    return 'How long at $name?';
  }

  @override
  String get planAddStopTitle => 'New stop';

  @override
  String planStopLabel(int n) {
    return 'Stop $n';
  }

  @override
  String get planStopRemove => 'Remove stop';

  @override
  String get settingsCurrency => 'Currency';

  @override
  String get planErrorPickEndpoints => 'Pick an origin and a destination.';

  @override
  String get resultBestTimeToLeave => 'BEST TIME TO LEAVE';

  @override
  String get resultTripSavings => 'YOUR SAVINGS ON THIS TRIP';

  @override
  String get resultSavingsDetected => 'Detected savings';

  @override
  String get resultTollSaving => 'Toll alternative';

  @override
  String get resultFuelSaving => 'Fuel';

  @override
  String get resultTimeSaving => 'Optimal departure';

  @override
  String get resultTotalSaving => 'TOTAL SAVINGS';

  @override
  String resultSavingPct(String pct) {
    return '$pct% less';
  }

  @override
  String get resultSavingsSuggestionsTitle => 'Ways to save time';

  @override
  String get resultSavingsClaimedHint =>
      'Savings will show once you apply the recommended window.';

  @override
  String get resultTimeSavedLabel => 'time saved';

  @override
  String get resultExtraTimeLabel => 'extra time';

  @override
  String get resultMoneySavedLabel => 'money saved';

  @override
  String get resultDepartureWindowTitle => 'Departure window';

  @override
  String get resultDepartureWindowDesc =>
      'Total minutes at each candidate departure time.';

  @override
  String get resultCompareVariantsTitle => 'Compare your options';

  @override
  String get resultCompareVariantsEyebrow => 'Route variants';

  @override
  String get resultAlertsTitle => 'Alerts along your route';

  @override
  String get resultRestStopsTitle => 'Rest stops';

  @override
  String get resultHotelsTitle => 'Hotels';

  @override
  String get resultRestaurantsTitle => 'Restaurants';

  @override
  String get resultFuelTitle => 'Fuel';

  @override
  String get resultTollAlternativeEyebrow => 'TOLL-FREE ALTERNATIVE';

  @override
  String get resultTollAlternativeWorthIt => 'Worth it';

  @override
  String get resultTollAlternativeMarginal => 'Marginal';

  @override
  String get resultShareTooltip => 'Share this trip';

  @override
  String get resultExplainTooltip => 'Explain my trip (Premium)';

  @override
  String get resultSaveTooltip => 'Save trip';

  @override
  String get resultSaveChangesTooltip => 'Save changes';

  @override
  String get resultSavedTooltip => 'Saved';

  @override
  String get resultTripSaved => 'Trip saved';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String dashboardGreeting(String name) {
    return 'Hi, $name';
  }

  @override
  String get dashboardTravelSoFar => 'Your travel so far';

  @override
  String get dashboardTrips => 'Trips';

  @override
  String get dashboardDistance => 'Distance';

  @override
  String get dashboardHours => 'Hours';

  @override
  String get dashboardTimeSaved => 'TIME SAVED';

  @override
  String get dashboardMoneySaved => 'MONEY SAVED';

  @override
  String get dashboardFuelBudget => 'ESTIMATED FUEL BUDGET';

  @override
  String get dashboardTopSavers => 'Top savers';

  @override
  String get dashboardSaved => 'estalviat';

  @override
  String get dashboardCountries => 'Countries';

  @override
  String get dashboardSignOut => 'Tancar sessió';

  @override
  String get profileTitle => 'Perfil del viatge';

  @override
  String get profileOverrideTitle => 'Override for this trip';

  @override
  String get profileSave => 'Save';

  @override
  String get profileUse => 'Use';

  @override
  String get profileWhoTravelling => 'Who is travelling';

  @override
  String get profileTravellers => 'Travellers';

  @override
  String get profileHasKids => 'Travelling with kids';

  @override
  String get profileHasPets => 'Travelling with pets';

  @override
  String get profileVehicle => 'Vehicle';

  @override
  String get profileMealTimes => 'Meal schedule';

  @override
  String get profileReminders => 'Reminders';

  @override
  String get profilePremiumSection => 'Premium (demo)';

  @override
  String get profileClearProfile => 'Clear profile';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClear => 'Clear';

  @override
  String commonShowNMore(int n) {
    return 'Show $n more';
  }

  @override
  String get commonShowLess => 'Show less';

  @override
  String planLoadingElapsed(int seconds) {
    return '${seconds}s elapsed';
  }

  @override
  String get planLoadingLongCrossingCountries =>
      'Cross-checking tolls across the countries you\'re crossing…';

  @override
  String get planLoadingLongScanningFuel =>
      'Scanning European fuel-price feeds along the route…';

  @override
  String get planLoadingLongBigTrip =>
      'Long trips take a bit more — pulling extra hotel and rest data.';

  @override
  String get planLoadingLongAlmostDone =>
      'Almost there — final touches on the itinerary.';

  @override
  String get commonSave => 'Save';

  @override
  String get commonRemove => 'Remove';

  @override
  String get searchPlaceholderLegacy => 'Search a city…';

  @override
  String get searchNoMatches => 'No matches.';

  @override
  String get searchStartTyping => 'Type at least 2 characters.';

  @override
  String get searchRecent => 'RECENT';

  @override
  String get searchUseMyLocation => 'Use my location';

  @override
  String get locationServiceOff => 'Location services are off on this device.';

  @override
  String get locationPermissionDenied => 'Location permission denied.';

  @override
  String get locationUnavailable => 'Couldn\'t determine your location.';

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get favoritesEmptyHotels =>
      'No favorite hotels yet. Tap the star on any hotel to save it.';

  @override
  String get favoritesEmptyRestaurants =>
      'No favorite restaurants yet. Tap the star on any restaurant to save it.';

  @override
  String get favoritesTabHotels => 'Hotels';

  @override
  String get favoritesTabRestaurants => 'Restaurants';

  @override
  String get favoritesTooltipAdd => 'Add to favorites';

  @override
  String get favoritesTooltipRemove => 'Remove from favorites';

  @override
  String get planTooltipFavorites => 'Preferits';

  @override
  String get resultBackToPlan => 'Back to plan';

  @override
  String get alertsAlongYourRoute => 'Alerts along your route';

  @override
  String get alertsAlongYourRouteDesc =>
      'Fires, floods, severe weather, snow, earthquakes, landslides — sorted by severity.';

  @override
  String get restStopsHint =>
      'Recommended every 2 h of driving. Short breaks keep you sharp on long trips.';

  @override
  String get fuelAlongTheRoute => 'Fuel along the route';

  @override
  String get hotelsNearYourRoute => 'Hotels near your route';

  @override
  String get restaurantsNearYourRoute => 'Restaurants near your route';

  @override
  String get narrativeTitle => 'Trip briefing';

  @override
  String get narrativeGenerating => 'Writing your briefing…';

  @override
  String get narrativeFailed =>
      'Couldn\'t generate the briefing. Try again in a bit.';

  @override
  String get narrativeFooter =>
      'Generated by Claude — content may miss real-time changes.';

  @override
  String get narrativePremiumBadge => 'Premium';

  @override
  String get shareTripSubject => 'My road trip via MyTravelPal';

  @override
  String get shareFormatTitle => 'Share as…';

  @override
  String get shareFormatStory => 'Story · 9:16';

  @override
  String get shareFormatStorySub => 'Instagram / TikTok / WhatsApp Stories';

  @override
  String get shareFormatFeed => 'Square · 1:1';

  @override
  String get shareFormatFeedSub => 'Instagram feed, Facebook, LinkedIn';

  @override
  String get shareTitle => 'MyTravelPal — road trip plan';

  @override
  String shareRouteLine(String km, String hours, String tolls) {
    return '$km km · $hours h free flow · tolls $tolls €';
  }

  @override
  String shareBestTime(String when, String minutes) {
    return 'Best time to leave: $when ($minutes min total)';
  }

  @override
  String shareTollFreeAlt(String savings, String minutes) {
    return 'Toll-free alt: save €$savings for +$minutes min';
  }

  @override
  String shareRefuelHint(
      String cheap, String price, String pricey, String savings) {
    return 'Refuel in $cheap (~$price€/L) before $pricey — save ~$savings€/tank';
  }

  @override
  String get shareHotelsHeader => 'Top hotels considered:';

  @override
  String get shareRestaurantsHeader => 'Top restaurants considered:';

  @override
  String shareHotelLine(String name, String price, String km) {
    return '$name — $price €/night · $km km off route';
  }

  @override
  String shareRestaurantLine(String name, String price, String km) {
    return '$name — $price €/meal · $km km off route';
  }

  @override
  String get shareOpenInApp => 'Open in MyTravelPal:';

  @override
  String get eventReport => 'Report an event';

  @override
  String get eventDescription => 'Description';

  @override
  String get eventType => 'Type';

  @override
  String get eventSeverity => 'Severity';

  @override
  String get eventLocation => 'Location';

  @override
  String get eventSubmit => 'Submit';

  @override
  String get eventSubmitted => 'Reported.';

  @override
  String get resultStatDistance => 'Distance';

  @override
  String get resultStatFreeFlow => 'Free flow';

  @override
  String get resultStatPlanned => 'Planificat';

  @override
  String get resultStatTolls => 'Tolls';

  @override
  String get resultEyebrowNearRoute => 'Near your route';

  @override
  String get resultEyebrowAlongRoute => 'Along the route';

  @override
  String get resultAlerts => 'Alerts';

  @override
  String get resultRestStops => 'Recommended stops';

  @override
  String get resultHotels => 'Hotels';

  @override
  String get resultRestaurants => 'Restaurants';

  @override
  String get resultFuel => 'Fuel';

  @override
  String get resultOptimizedFuelBudget => 'Estimated fuel budget';

  @override
  String get resultCompareTitle => 'Compare your options';

  @override
  String get resultCompareStraightApprox => 'Straight-line approx.';

  @override
  String resultSleepAt(String when) {
    return 'Sleep · $when';
  }

  @override
  String get resultHourlyTollEyebrow => 'HOURLY TOLL VERDICT';

  @override
  String get resultSkipLabel => 'Skip';

  @override
  String get resultKeepLabel => 'Keep';

  @override
  String get resultSaveExactly => 'Save ';

  @override
  String get notificationsLeaveSoonTitle => 'Time to leave soon';

  @override
  String get localeSystem => 'Sistema';

  @override
  String get localeMenuTooltip => 'Language';

  @override
  String get dashboardCountry => 'Country';

  @override
  String get dashboardNoTripsYet =>
      'No saved trips yet. Plan and save one to see stats.';

  @override
  String get dashboardStatCards => 'OVERVIEW';

  @override
  String get profileVehicleType => 'Vehicle type';

  @override
  String get profileFuelType => 'Fuel type';

  @override
  String get profileConsumption => 'Consumption';

  @override
  String get profileEvRange => 'EV range';

  @override
  String get profileFuelTank => 'Fuel tank';

  @override
  String get profileBreakfast => 'Breakfast';

  @override
  String get profileLunch => 'Lunch';

  @override
  String get profileDinner => 'Dinner';

  @override
  String get mealSlotBreak => 'Break';

  @override
  String get profileStopMinutes => 'Typical stop minutes';

  @override
  String get profileReminderMinutes => 'Reminder before departure';

  @override
  String get profilePremiumHint =>
      'Toggle to preview Premium features locally.';

  @override
  String get profileNoProfile => 'No profile saved yet.';

  @override
  String get eventPlaceholderDescription => 'Short description of what you saw';

  @override
  String get eventCurrentLocation => 'Current location';

  @override
  String get eventPickOnMap => 'Pick on map';

  @override
  String eventLocationCoords(String lat, String lon) {
    return 'Selected: $lat, $lon';
  }

  @override
  String get narrativeRegenerate => 'Regenerate';

  @override
  String get narrativeUpgrade => 'Unlock the AI briefing with Premium.';

  @override
  String get compareVariantsRecommended => 'Recommended';

  @override
  String get compareVariantsFastest => 'Fastest';

  @override
  String get compareVariantsCheapest => 'Cheapest';

  @override
  String get compareVariantsScenic => 'Scenic';

  @override
  String get compareVariantsAvoidTolls => 'No tolls';

  @override
  String get compareVariantsAvoidMotorways => 'No motorways';

  @override
  String get hourlyBestHours => 'Best hours to skip tolls';

  @override
  String get hourlyWorstHours => 'Worst hours to skip tolls';

  @override
  String get partialTollSkipsTitle => 'Peaje a peaje · Optimización Premium';

  @override
  String get partialTollSkipsEyebrow => 'Zoom in';

  @override
  String get sleepEyebrow => 'OVERNIGHT';

  @override
  String get sleepNoHotelSuggestion =>
      'No hotel picked yet — see the Hotels section.';

  @override
  String get lunchEyebrow => 'LUNCH STOP';

  @override
  String get dinnerEyebrow => 'DINNER STOP';

  @override
  String get breakfastEyebrow => 'BREAKFAST STOP';

  @override
  String get resultCompareEyebrow => 'Route variants';

  @override
  String get resultCompareDescription =>
      'Same start and end — different priorities. Numbers are free-flow.';

  @override
  String get resultVariantDashed => 'Dashed on the map above';

  @override
  String dayTollsHeader(Object amount, int count) {
    return 'Tolls today · $amount € ($count)';
  }

  @override
  String dayTollsSavedSummary(Object amount, int count) {
    return 'You\'ll save $amount € by skipping $count.';
  }

  @override
  String tollHourGoodToSkip(Object hh) {
    return 'Good hour to skip ($hh:00)';
  }

  @override
  String tollHourAvoidSkip(Object hh) {
    return 'Avoid skipping — peak at $hh:00';
  }

  @override
  String get partialTollsPerDayHint =>
      'You can also toggle these per day in the itinerary below ↓';

  @override
  String resultCityHint(Object city) {
    return 'Near $city';
  }

  @override
  String get resultSavingsShiftAndSkip =>
      'By shifting your departure and skipping tolls.';

  @override
  String get resultSavingsShift =>
      'By shifting your departure to the recommended window.';

  @override
  String get resultSavingsSkip => 'By taking the toll-free alternative.';

  @override
  String get resultSavingsNone => 'No savings identified for this route yet.';

  @override
  String get resultBypassSavingsPrefix => 'You could save up to';

  @override
  String resultBypassSavingsSuffix(String minutes) {
    return 'with +$minutes min extra';
  }

  @override
  String get resultArrival => 'ARRIVAL';

  @override
  String get resultShift => 'SHIFT';

  @override
  String get resultTraffic => 'TRAFFIC';

  @override
  String get resultTotal => 'TOTAL';

  @override
  String resultRestStopNoRestaurant(String km) {
    return 'Rest stop at $km km — no matching restaurant found.';
  }

  @override
  String resultNoHotelHere(String km) {
    return 'You should stop around here (~$km km). No matching hotel found.';
  }

  @override
  String get resultMealFallback => 'Meal';

  @override
  String get resultHourlyExplainer =>
      'Common in France & Italy: exit before an expensive toll, take a parallel road for a stretch, re-enter later — often 15-40 min but saves €5-15.';

  @override
  String get profileSaved => 'Profile saved';

  @override
  String get profileWhoEyebrow => 'People';

  @override
  String get profileKidsSubtitle =>
      'Prefers kid-friendly restaurants and hotels.';

  @override
  String get profilePetsSubtitle =>
      'Prefers pet-friendly places, prioritises parking.';

  @override
  String get profileVehicleEyebrow => 'For cost + parking hints';

  @override
  String get profileMealsEyebrow => 'To match restaurant stops';

  @override
  String get profileRemindersEyebrow => 'Local notifications';

  @override
  String get profileNotifyBefore => 'Notify me before departure';

  @override
  String get profileNotifyOff => 'Off — no reminder will be scheduled.';

  @override
  String profileNotifyMinutesBefore(int minutes) {
    return '$minutes minutes before';
  }

  @override
  String get profilePremiumEyebrow => 'Local toggle · no real payment';

  @override
  String get profilePremiumBody =>
      'Real StoreKit / Play Billing gating comes later. For now this toggle enables Premium locally so you can preview those features.';

  @override
  String get profileSimulatePremium => 'Simulate Premium';

  @override
  String get profileSimulatePremiumSubtitle =>
      'Unlocks the AI trip briefing and hourly toll analysis.';

  @override
  String get profileOverrideHeroDesc =>
      'Change your profile just for this trip — different vehicle, travellers or meal times without touching your saved profile.';

  @override
  String get profileGlobalHeroDesc =>
      'Set this once. Every plan uses it to rank hotels and restaurants, estimate fuel, and time meal stops.';

  @override
  String get eventPickPlace => 'Pick a place and describe what you saw.';

  @override
  String get eventThankYou => 'Report submitted — thank you!';

  @override
  String eventCouldNotSubmit(String reason) {
    return 'Could not submit: $reason';
  }

  @override
  String get eventIntro =>
      'Help other drivers know what you saw. Reports expire after 24 hours by default.';

  @override
  String get eventWhatHappened => 'What happened';

  @override
  String get eventWhatHappenedEyebrow => 'Type';

  @override
  String get eventSeverityInfo => 'Info';

  @override
  String get eventSeverityWarning => 'Warning';

  @override
  String get eventSeverityCritical => 'Critical';

  @override
  String get eventWhere => 'Where';

  @override
  String get eventWhereEyebrow => 'Nearest city';

  @override
  String get eventDescribeTitle => 'Describe it';

  @override
  String get eventDescribeEyebrow => 'Short & useful';

  @override
  String get eventDescribeHint =>
      'e.g. Trees down on A6 southbound, 2 lanes closed';

  @override
  String get eventSubmitting => 'Submitting…';

  @override
  String get eventSubmitReport => 'Submit report';

  @override
  String get narrativeBusy => 'Composing your trip briefing…';

  @override
  String get narrativeErrorTitle => 'Could not fetch the briefing';

  @override
  String narrativeGeneratedAt(String when) {
    return 'Generated $when';
  }

  @override
  String get narrativeReadAloud => 'Read aloud';

  @override
  String get narrativeStop => 'Stop';

  @override
  String get historyTitle => 'Saved trips';

  @override
  String get historyEmptyTitle => 'No saved trips yet';

  @override
  String get historyEmptyBody =>
      'Plan a trip and tap the bookmark to keep it here for later.';

  @override
  String get historyPlanCta => 'Plan a trip';

  @override
  String historyDeleted(String trip) {
    return 'Deleted $trip';
  }

  @override
  String historyReplanFailed(int status) {
    return 'Re-plan failed: $status';
  }

  @override
  String get historyReplanNetworkError =>
      'La connexió s\'ha tallat durant el recàlcul. Comprova el senyal i torna a intentar-ho.';

  @override
  String get retryLabel => 'Torna-ho a intentar';

  @override
  String get historyDeleteTooltip => 'Delete';

  @override
  String get historyReopenCta => 'Reopen';

  @override
  String get historyRepeatCta => 'Repeat';

  @override
  String historySavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count desats',
      one: '1 desat',
    );
    return '$_temp0';
  }

  @override
  String resultFuelCollapsedHint(int count) {
    return 'Show the $count cheapest stations along the route';
  }

  @override
  String resultBestTimeVsFreeFlow(String delta) {
    return '$delta min vs free flow';
  }

  @override
  String resultBestTimeEarlier(int minutes) {
    return '$minutes min earlier than your target';
  }

  @override
  String resultBestTimeLater(int minutes) {
    return '$minutes min later than your target';
  }

  @override
  String resultHeroSavedBadge(String magnitude) {
    return '$magnitude saved';
  }

  @override
  String get consistencyNeedsReview => 'Trip plan needs review';

  @override
  String consistencyNeedsReviewErrors(int errors) {
    return 'Trip plan needs review · $errors errors';
  }

  @override
  String consistencyNeedsReviewMixed(int errors, int warnings) {
    return 'Trip plan needs review · $errors error(s), $warnings warning(s)';
  }

  @override
  String consistencyFuelNoStations(String km) {
    return 'Trip is $km km, but we can\'t see any gas stations along the route right now. Pricing and refuel picks are unavailable for this leg.';
  }

  @override
  String get consistencyFuelNoStationsHint =>
      'Data may still be loading — try refreshing in a couple of minutes, or add your own stop by tapping the map.';

  @override
  String get consistencyFuelRangeExceeded =>
      'Your vehicle can\'t cover the route on a single tank/charge — you\'ll need to refuel or recharge during the trip.';

  @override
  String consistencyMealBeforeDeparture(String slot, String km) {
    return '$slot is scheduled at km $km before the trip departs. Adjust the stop time or the departure hour.';
  }

  @override
  String consistencyMealAfterArrival(String slot, String km) {
    return '$slot is scheduled at km $km after the trip already ends. Adjust the stop time or the trip pace.';
  }

  @override
  String consistencyMealImpossibleSpeed(String slot, String km, String kmh) {
    return 'Reaching $slot at km $km from departure would need ~$kmh km/h — not possible. Review the stop.';
  }

  @override
  String consistencyMealSuspiciousSpeed(String slot, String km, String kmh) {
    return 'Reaching $slot at km $km from departure would need ~$kmh km/h. Check if that pace is realistic.';
  }

  @override
  String consistencyMealTooCloseToArrival(String slot, String km, String mins) {
    return '$slot at km $km is very close to arrival ($mins min before). You might as well eat at the destination.';
  }

  @override
  String consistencySleepBeforeDeparture(String km) {
    return 'Overnight rest is scheduled before departure (km $km). Check the time.';
  }

  @override
  String consistencySleepAfterArrival(String km) {
    return 'Overnight rest is scheduled after arrival (km $km). It may not be needed.';
  }

  @override
  String consistencySleepImpossibleSpeed(String km, String kmh) {
    return 'Reaching the overnight rest at km $km needs ~$kmh km/h — impossible. Review the leg.';
  }

  @override
  String consistencySleepSuspiciousSpeed(String km, String kmh) {
    return 'The overnight rest at km $km implies ~$kmh km/h average. Check the pace.';
  }

  @override
  String get mealSlotBreakfastCap => 'Breakfast';

  @override
  String get mealSlotLunchCap => 'Lunch';

  @override
  String get mealSlotDinnerCap => 'Dinner';

  @override
  String get consistencyHeadsUp => 'Heads-up on your trip plan';

  @override
  String consistencyHeadsUpWarnings(int warnings) {
    return 'Heads-up on your trip plan · $warnings warnings';
  }

  @override
  String consistencyMoreCount(int count) {
    return '+$count more';
  }

  @override
  String get planProfileClearOverride => 'Clear override';

  @override
  String get weatherSunny => 'Assolellat';

  @override
  String get weatherPartlyCloudy => 'Parcialment ennuvolat';

  @override
  String get weatherCloudy => 'Ennuvolat';

  @override
  String get weatherFog => 'Boira';

  @override
  String get weatherDrizzle => 'Plugim';

  @override
  String get weatherRain => 'Pluja';

  @override
  String get weatherHeavyRain => 'Pluja intensa';

  @override
  String get weatherSnow => 'Neu';

  @override
  String get weatherHeavySnow => 'Nevada intensa';

  @override
  String get weatherThunderstorm => 'Tempesta';

  @override
  String historyBestAt(String when) {
    return 'Best $when';
  }

  @override
  String historyWantedAt(String when) {
    return 'Wanted $when';
  }

  @override
  String get searchPlaceholder => 'Search a city, museum, place…';

  @override
  String get placesSectionTitle => 'SAVED PLACES';

  @override
  String get placeSaveAsTooltip => 'Save as place';

  @override
  String get placeSaveDialogTitle => 'Save as…';

  @override
  String get placeCustomLabel => 'Label';

  @override
  String get placeCustomHint => 'Home, Work, Grandma…';

  @override
  String get placePresetHome => 'Home';

  @override
  String get placePresetWork => 'Work';

  @override
  String get placePresetSchool => 'School';

  @override
  String get placePresetGym => 'Gym';

  @override
  String placeSavedAs(String label) {
    return 'Saved as $label';
  }

  @override
  String get favoritesTabPlaces => 'Places';

  @override
  String get favoritesEmptyPlaces =>
      'No saved places yet. Tap the star on any search result to save it.';

  @override
  String get settingsTitle => 'Configuració';

  @override
  String get settingsSectionVehicle => 'Vehicle i ruta';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionAI => 'Personalització IA';

  @override
  String get notifSoundTitle => 'So d\'alertes';

  @override
  String get notifSoundDefault => 'So predeterminat';

  @override
  String get notifSoundDefaultSub => 'Usa el so de notificació del sistema';

  @override
  String get notifSoundSilent => 'Silenci';

  @override
  String get notifSoundSilentSub => 'Sense so per a les alertes';

  @override
  String get settingsSectionSafety => 'Contactes i seguretat';

  @override
  String get settingsSectionAccount => 'Compte';

  @override
  String get settingsDensityLabel => 'Densitat';

  @override
  String get settingsDensityComfortable => 'Còmoda';

  @override
  String get settingsDensityCompact => 'Compacta';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsSectionUnits => 'Units';

  @override
  String get settingsUnitSystem => 'Unit system';

  @override
  String get settingsUnitsMetric => 'Metric';

  @override
  String get settingsUnitsImperial => 'Imperial';

  @override
  String get settingsSectionTrip => 'Trip';

  @override
  String get settingsRadarAlerts => 'Speed camera alerts';

  @override
  String get settingsRadarAlertsSubtitle =>
      'Vibrate and show a banner when a speed camera is within 400 m (Essential+).';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsSectionData => 'Your data';

  @override
  String get settingsExportData => 'Download my data';

  @override
  String get settingsExportDataSub =>
      'Get a JSON file with everything MyTravelPal holds about you.';

  @override
  String get settingsExportError =>
      'Couldn\'t export data — check your connection.';

  @override
  String get settingsDeleteAccount => 'Delete my account';

  @override
  String get settingsDeleteAccountSub =>
      'Removes your profile, saved trips and preferences permanently.';

  @override
  String get settingsDeleteAccountConfirmTitle => 'Delete account?';

  @override
  String get settingsDeleteAccountConfirmBody =>
      'This deletes your profile and every saved trip from our servers. This action cannot be undone.';

  @override
  String get settingsDeleteAccountCancel => 'Cancel';

  @override
  String get settingsDeleteAccountConfirm => 'Delete forever';

  @override
  String get settingsDeleteAccountPartial =>
      'Signed out locally, but the server may still hold data. Try again from a stable connection.';

  @override
  String get settingsDeleteAccountDone => 'Account deleted. Signed out.';

  @override
  String get settingsDeleteAccountInProgress => 'Deleting account…';

  @override
  String get settingsSupport => 'Support & contact';

  @override
  String get settingsPrivacyPolicy => 'Privacy Policy';

  @override
  String get settingsTerms => 'Terms of Service';

  @override
  String get settingsVersion => 'Version';

  @override
  String get planTooltipSettings => 'Configuració';

  @override
  String get styleSectionTitle => 'Ritmo de conducción';

  @override
  String get styleSectionEyebrow => 'Cómo organizas tus jornadas';

  @override
  String get stylePresetDirect => 'Direct';

  @override
  String get stylePresetBalanced => 'Balanced';

  @override
  String get stylePresetSlow => 'Slow';

  @override
  String get stylePresetDirectHint =>
      'Push through, minimal stops, never overnight.';

  @override
  String get stylePresetBalancedHint =>
      'Steady pace, breaks when it makes sense.';

  @override
  String get stylePresetSlowHint =>
      'Savour the drive, generous stops, split long trips.';

  @override
  String get styleCustom => 'Custom';

  @override
  String get styleAdvanced => 'Advanced';

  @override
  String get stylePaceLabel => 'Pace';

  @override
  String get stylePacePush => 'Push';

  @override
  String get stylePaceSteady => 'Steady';

  @override
  String get stylePaceSavour => 'Savour';

  @override
  String get styleOvernightLabel => 'Overnight stops';

  @override
  String get styleOvernightNever => 'Never';

  @override
  String get styleOvernightIfNeeded => 'If needed';

  @override
  String get styleOvernightAlwaysIfLong => 'Split long trips';

  @override
  String get styleDailyCapLabel => 'Max hours driving per day';

  @override
  String get styleBedtimeLabel => 'Bedtime';

  @override
  String get styleWakeLabel => 'Wake time';

  @override
  String get styleDrivingStartLabel => 'Preferred time to start driving';

  @override
  String get drivingWindowNightStart => 'Conducció nocturna a l\'inici';

  @override
  String get drivingWindowNightEnd => 'Conducció nocturna al final';

  @override
  String get dayEditKmNoLimit => 'Màx. km: sense límit';

  @override
  String dayEditKmCap(int km) {
    return 'Màx. km: $km km';
  }

  @override
  String dayEditSheetTitle(int day) {
    return 'Adjust day $day';
  }

  @override
  String get dayEditStartHour => 'Start driving hour';

  @override
  String dayEditMaxDriving(int hours) {
    return 'Max driving hours: $hours h (includes breaks)';
  }

  @override
  String get dayExtendKmTitle => 'Tienes más tiempo disponible';

  @override
  String dayExtendKmBody(String extraKm) {
    return 'Con este horario podrías recorrer +$extraKm km más. ¿Quieres extender el día o mantener la ruta actual?';
  }

  @override
  String get dayExtendKmKeep => 'Mantener ruta actual';

  @override
  String dayExtendKmAdjust(String extraKm) {
    return 'Extender el día (+$extraKm km)';
  }

  @override
  String get dayReduceKmTitle => 'Temps de conducció reduït';

  @override
  String dayReduceKmBody(String reducedKm) {
    return 'Amb aquest horari arribaràs fins a aprox. $reducedKm km. Vols ajustar el límit de quilòmetres?';
  }

  @override
  String get dayReduceKmKeep => 'Mantenir km actuals';

  @override
  String dayReduceKmAdjust(String reducedKm) {
    return 'Ajustar a $reducedKm km';
  }

  @override
  String dayEditEndHour(String time) {
    return 'Stop driving at $time';
  }

  @override
  String get dayEditPickTime => 'Pick time';

  @override
  String get dayEditEndTimePicker => 'Stop driving at';

  @override
  String get dayEditSave => 'Apply';

  @override
  String get dayEditCancel => 'Cancel';

  @override
  String get dayEditReset => 'Reset';

  @override
  String get resultReplanning => 'Recalculating...';

  @override
  String get styleBreakLabel => 'Break style';

  @override
  String get styleBreakMinimal => 'Minimal';

  @override
  String get styleBreakScenic => 'Scenic';

  @override
  String get styleBreakFoodie => 'Foodie';

  @override
  String planStyleChip(String preset, int hours) {
    return '$preset · ${hours}h/day';
  }

  @override
  String planStyleChipCustom(int hours) {
    return 'Custom · ${hours}h/day';
  }

  @override
  String get planStyleOverrideTitle => 'Style for this trip';

  @override
  String get planStyleOverrideSubtitle =>
      'Overrides your saved profile only for this plan.';

  @override
  String get planStyleUseSavedProfile => 'Use my saved profile';

  @override
  String arrivalHintTitle(String hour) {
    return 'You\'d arrive at $hour:00';
  }

  @override
  String arrivalHintBody(String bedtime) {
    return 'Later than your bedtime ($bedtime:00). Consider stopping overnight — hotels are ready below.';
  }

  @override
  String get arrivalHintCta => 'See hotels';

  @override
  String get vehicleTypeCar => 'Car';

  @override
  String get vehicleTypeMotorbike => 'Motorbike';

  @override
  String get vehicleTypeVan => 'Van';

  @override
  String get vehicleTypeCamper => 'Camper';

  @override
  String get fuelTypePetrol => 'Petrol';

  @override
  String get fuelTypeDiesel => 'Diesel';

  @override
  String get fuelTypeHybrid => 'Hybrid';

  @override
  String get fuelTypeElectric => 'Electric';

  @override
  String get fuelTypeLpg => 'LPG';

  @override
  String get routeVariantFastest => 'Fastest';

  @override
  String get routeVariantTollFree => 'Toll-free';

  @override
  String get routeVariantScenic => 'Scenic';

  @override
  String get eventTypeFire => 'Fire';

  @override
  String get eventTypeStrike => 'Strike';

  @override
  String get eventTypeWeather => 'Adverse weather';

  @override
  String get eventTypeAccident => 'Accident';

  @override
  String get eventTypeRoadwork => 'Roadwork';

  @override
  String get eventTypeFlood => 'Flood';

  @override
  String get eventTypeSnow => 'Snow';

  @override
  String get eventTypeProtest => 'Protest';

  @override
  String get eventTypeEarthquake => 'Terratrèmol';

  @override
  String get eventTypeLandslide => 'Esllavissada';

  @override
  String get eventTypeAvalanche => 'Allau';

  @override
  String get eventTypeClosure => 'Carretera tallada';

  @override
  String get eventTypeHeatwave => 'Onada de calor';

  @override
  String get eventTypeHeavyRain => 'Pluja forta';

  @override
  String get eventTypeHail => 'Calamarsa';

  @override
  String get eventTypeThunderstorm => 'Tempesta elèctrica';

  @override
  String get eventTypeHighWind => 'Vent fort';

  @override
  String get eventTypeDenseFog => 'Boira densa';

  @override
  String get eventTypeFreezingRain => 'Pluja gelada';

  @override
  String get eventTypeOther => 'Other';

  @override
  String tollStretchLabel(int index, int total) {
    return 'Toll stretch $index / $total';
  }

  @override
  String tollBoothLabel(int index) {
    return 'Toll booth $index';
  }

  @override
  String get addedToRouteLabel => 'ADDED';

  @override
  String get replanWithStops => 'Recalculate route with stops';

  @override
  String get addToRouteTooltip => 'Add to route';

  @override
  String get removeFromRouteTooltip => 'Remove from route';

  @override
  String addedStopsChip(int count, String minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stops added · +$minutes min',
      one: '1 stop added · +$minutes min',
    );
    return '$_temp0';
  }

  @override
  String get addedStopsClear => 'Clear';

  @override
  String get settingsLicensesAndData => 'Licenses & data sources';

  @override
  String get settingsLicensesAndDataSub =>
      'Attributions for open data and libraries';

  @override
  String get attributionsTitle => 'Licenses & data';

  @override
  String get attributionsIntro =>
      'MyTravelPal is built on open data feeds and open-source libraries. This screen credits every source we use, links to the underlying licences, and covers our legal attribution obligations.';

  @override
  String get attributionsSectionMap => 'Map & geodata';

  @override
  String get attributionsSectionFuel => 'Fuel prices';

  @override
  String get attributionsSectionHazards => 'Adverse events';

  @override
  String get attributionsSectionWeather => 'Weather';

  @override
  String get attributionsSectionSoftware => 'Software libraries';

  @override
  String get attributionsShowLicenses => 'Show package licences';

  @override
  String get attributionsFailed =>
      'Couldn\'t load attributions. Please try again.';

  @override
  String get fuelPriceUnavailable => 'Price not available';

  @override
  String get fuelPriceUnavailableHint =>
      'No public price feed for this country yet';

  @override
  String get planSectionOptionalEyebrow => 'Optional';

  @override
  String get planOptAlertsTitle => 'Alert me to critical events on the route';

  @override
  String get planOptAlertsSub =>
      'Fires, floods, severe weather, and serious hazards within 25 km of the route.';

  @override
  String get planOptTollFreeTitle => 'Show toll-free alternative';

  @override
  String get planOptTollFreeSub =>
      'Compare a route that skips tolls — money saved vs. minutes added.';

  @override
  String get planOptHourlyTollTitle => 'Hourly toll analysis';

  @override
  String get planOptHourlyTollSub =>
      'When during the day skipping tolls actually beats keeping them (traffic-aware).';

  @override
  String get planOptRouteVariantsTitle => 'Compare route variants';

  @override
  String get planOptRouteVariantsSub =>
      'Fastest vs. toll-free vs. scenic — see all three side by side on the results.';

  @override
  String get planOptAvoidMotorwaysTitle => 'Avoid motorways';

  @override
  String get planOptAvoidMotorwaysSub =>
      'Slower and longer, but no tolls and quieter.';

  @override
  String get planOptPreferScenicTitle => 'Prefer scenic';

  @override
  String get planOptPreferScenicSub =>
      'Bias to more interesting roads. A little slower.';

  @override
  String get planPremiumBadge => 'Premium';

  @override
  String planProfileTravellers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count travellers',
      one: '1 traveller',
    );
    return '$_temp0';
  }

  @override
  String get planProfileWithKids => 'kids';

  @override
  String get planProfileWithPets => 'pets';

  @override
  String get planProfileOverrideActive => 'OVERRIDE ACTIVE';

  @override
  String get planProfileOverride => 'Override for this trip';

  @override
  String get planProfileOverriding => 'Overriding for this trip';

  @override
  String get profilePromptSetup => 'Set up your trip profile';

  @override
  String get hotelPrefTitle => 'Find hotels near stops';

  @override
  String get hotelPrefSubOn =>
      'Shows accommodation options near each overnight stop';

  @override
  String get hotelPrefSubOff => 'Off';

  @override
  String get restaurantPrefTitle => 'Add restaurants along the route';

  @override
  String restaurantPrefSubEnabled(int minutes, String band) {
    return 'Up to $minutes min detour · $band';
  }

  @override
  String get restaurantPrefSubOff =>
      'Off. Turn on to see restaurants near your route.';

  @override
  String prefMaxDetour(int minutes) {
    return 'Max detour: $minutes min';
  }

  @override
  String get prefBandBudget => 'Budget';

  @override
  String get prefBandMid => 'Mid';

  @override
  String get prefBandLuxury => 'Luxury';

  @override
  String get prefBandAny => 'Any';

  @override
  String get mealSlotBreakfast => 'Suggested for breakfast';

  @override
  String get mealSlotLunch => 'Suggested for lunch';

  @override
  String get mealSlotDinner => 'Suggested for dinner';

  @override
  String get mealSlotOther => 'Other restaurants';

  @override
  String poiDistanceKm(String km, String minutes) {
    return '$km km · +$minutes min detour';
  }

  @override
  String fuelSavingsChipCheap(String amount) {
    return '-$amount€/L vs country avg';
  }

  @override
  String fuelSavingsChipDear(String amount) {
    return '+$amount€/L vs country avg';
  }

  @override
  String get fuelArbitrageTitle => 'Refuel smart on this route';

  @override
  String fuelArbitrageBody(String cheap, String cheapPrice, String dear,
      String dearPrice, String savings) {
    return 'Fuel in $cheap is around $cheapPrice€/L. In $dear it\'s ~$dearPrice€/L. Filling the tank in $cheap before crossing saves ~$savings€.';
  }

  @override
  String dayTabLabel(int index) {
    return 'Day $index';
  }

  @override
  String dayHeaderRange(int index, String fromKm, String toKm) {
    return 'Day $index · km $fromKm → $toKm';
  }

  @override
  String dayHeaderCity(int index, String from, String to) {
    return 'Day $index · $from → $to';
  }

  @override
  String dayArrivalMarker(String time) {
    return 'Arribes al destí cap a les $time';
  }

  @override
  String daySleepMarker(String time) {
    return 'Finish driving around $time';
  }

  @override
  String dayStartsAt(String time) {
    return 'Surt a les $time';
  }

  @override
  String dayDriveWindow(String start, String end) {
    return '$start → $end';
  }

  @override
  String get restStopWhyTitle => 'Why this stop?';

  @override
  String get restStopWhyKidFriendly => 'Service area marked as kid-friendly';

  @override
  String get restStopWhyPetFriendly => 'Dog / pet area nearby';

  @override
  String get restStopWhyRvFriendly =>
      'Motorhome-compatible (sanitary / dump station)';

  @override
  String restStopWhySafety(String hours) {
    return 'Recommended for road safety: you\'ve been driving ${hours}h. EU regulation 561/2006 suggests at least a 45 min break after 4h30 at the wheel.';
  }

  @override
  String get restStopWhyClose => 'Got it';

  @override
  String dayMealStopAt(String time, String name) {
    return '🍽 $time · $name';
  }

  @override
  String dayRestStopAt(String time, String label) {
    return '☕ $time · $label';
  }

  @override
  String get restStopFilterAll => 'Tots';

  @override
  String get restStopFilterKidFriendly => 'Familiar';

  @override
  String get restStopFilterPetFriendly => 'Amb mascota';

  @override
  String get restStopFilterRvFriendly => 'Autocaravana';

  @override
  String dayHeaderDwell(int index, String place) {
    return 'Day $index · $place';
  }

  @override
  String daySleepStay(String place) {
    return 'Staying in $place';
  }

  @override
  String get nextStopHeroLabel => 'Next suggested stop';

  @override
  String nextStopHeroBody(String slot, String name, String time) {
    return '$slot in $name · around $time';
  }

  @override
  String get daySleepHotelsLabel => 'Hotels near your overnight stop';

  @override
  String hotelDistFromStop(String km) {
    return '$km km from stop';
  }

  @override
  String hotelDistFromDestination(String km) {
    return '$km km from destination';
  }

  @override
  String get daySleepHotelsLabelDestination => 'Hotels near your destination';

  @override
  String get daySleepHotelsEmpty =>
      'Enable hotels in the plan preferences to see overnight options here.';

  @override
  String get daySleepHotelsNotFound =>
      'No hotels found near this route with your current preferences.';

  @override
  String get noHotelsAdjustPrefs => 'Adjust preferences';

  @override
  String get noRestaurantsAdjustPrefs =>
      'No restaurants found with your current preferences.';

  @override
  String get companionAssistantTitle => 'Companion assistant';

  @override
  String get settingsAiPersonalisation => 'AI Personalisation';

  @override
  String get companionAskHint => 'Ask something…';

  @override
  String get companionSend => 'Send';

  @override
  String get companionGroupJoin => 'Join as passenger';

  @override
  String get companionJoin => 'Join';

  @override
  String get resultFuelSavingsTitle => 'Cheap fuel on your route';

  @override
  String get daySleepHotelsSearching => 'Looking for hotels near your stop...';

  @override
  String get enrichmentLoadingTitle => 'Loading extras';

  @override
  String get enrichmentChipHotels => 'Hotels';

  @override
  String get enrichmentChipRestaurants => 'Restaurants';

  @override
  String get enrichmentChipFuel => 'Fuel stations';

  @override
  String get enrichmentChipWeather => 'Weather';

  @override
  String get enrichmentChipAdverse => 'Alerts';

  @override
  String get enrichPulseHeader => 'Right now…';

  @override
  String get enrichPulseHotels => 'Finding hotels with the best price/stars';

  @override
  String get enrichPulseRestaurants =>
      'Filtering restaurants to your preferences';

  @override
  String get enrichPulseFuel =>
      'Locating the cheapest gas stations along the corridor';

  @override
  String get enrichPulseTolls => 'Spotting tolls you can skip without a detour';

  @override
  String get enrichPulseWindows =>
      'Comparing departure hours by expected traffic';

  @override
  String get enrichPulseWeather =>
      'Hour-by-hour forecast across 5 route segments';

  @override
  String get enrichPulseAdverse =>
      'Cross-checking active fires and quakes against your route';

  @override
  String get enrichPulseKids => 'Rest stops with playgrounds nearby';

  @override
  String get enrichPulsePets => 'Locating dog areas and pet-friendly stops';

  @override
  String get enrichPulseCamper =>
      'Camper areas with dump and sanitary facilities';

  @override
  String enrichPulseVehicleEv(String vehicle, String tank) {
    return 'Planning charging stops for your $vehicle ($tank kWh)';
  }

  @override
  String enrichPulseVehicle(String vehicle, String tank) {
    return 'Tuning refuel plan for your $vehicle ($tank L)';
  }

  @override
  String get restStopsWidenedHint =>
      'No stops match the filter; showing the best on this leg.';

  @override
  String get windowsSheetTitle => 'Departure windows';

  @override
  String get windowsSheetHint => 'Tap a card to replan with that departure.';

  @override
  String get windowsSheetOpen => 'See hour-by-hour detail';

  @override
  String get windowsBadgeCurrent => 'Your time';

  @override
  String get windowsBadgeRecommended => 'Recommended';

  @override
  String get windowsMetaDuration => 'Duration';

  @override
  String get windowsMetaArrival => 'Arrival';

  @override
  String get windowsMetaTraffic => 'Traffic';

  @override
  String get trafficLight => 'Light';

  @override
  String get trafficMedium => 'Moderate';

  @override
  String get trafficDense => 'Heavy';

  @override
  String get todEarlyMorning => 'Early morning';

  @override
  String get todMorning => 'Morning';

  @override
  String get todNoon => 'Midday';

  @override
  String get todAfternoon => 'Afternoon';

  @override
  String get todNight => 'Night';

  @override
  String get restaurantPrefCuisinesLabel => 'Cuisine';

  @override
  String get cuisineItalian => 'Italian';

  @override
  String get cuisineSpanish => 'Spanish';

  @override
  String get cuisineTapas => 'Tapas';

  @override
  String get cuisineFrench => 'French';

  @override
  String get cuisineMediterranean => 'Mediterranean';

  @override
  String get cuisineAsian => 'Asian';

  @override
  String get cuisineIndian => 'Indian';

  @override
  String get cuisineBurger => 'Burgers';

  @override
  String get cuisineSeafood => 'Seafood';

  @override
  String get cuisineVegetarian => 'Vegetarian';

  @override
  String get cuisineBbq => 'BBQ / grill';

  @override
  String get cuisineRegional => 'Regional';

  @override
  String timeWindowSpanLabel(int hours) {
    return 'Show ±${hours}h';
  }

  @override
  String get timeWindowSpanHelper =>
      'Drag to widen the window and see if leaving earlier or later saves more time.';

  @override
  String get timeWindowTapHint =>
      'Tap a bar to replan with that departure time.';

  @override
  String get planLoadingRecalculating => 'Recalculating with your settings...';

  @override
  String get planLoadingTitle => 'Building your road trip';

  @override
  String get planLoadingStepRouting => 'Computing the fastest route…';

  @override
  String get planLoadingStepTraffic =>
      'Sampling traffic to pick the best departure hour…';

  @override
  String get planLoadingStepFuel =>
      'Fetching live fuel prices along the corridor…';

  @override
  String get planLoadingStepHotels =>
      'Looking for hotels around any overnight stops…';

  @override
  String get planLoadingStepRestaurants =>
      'Sorting restaurants by meal slot and cuisine…';

  @override
  String get planLoadingStepAlerts =>
      'Scanning for fires, floods, severe weather, and hazards…';

  @override
  String get planLoadingStepTolls =>
      'Comparing toll routes with toll-free alternatives…';

  @override
  String get planLoadingStepAlmost =>
      'Almost there — assembling everything for you…';

  @override
  String get planLoadingHelper =>
      'This can take up to a few minutes. Feel free to keep the phone in your pocket.';

  @override
  String timeWindowApplyLabel(String time) {
    return 'Apply · depart at $time';
  }

  @override
  String get planErrorAuth =>
      'Session expired. Sign in again and try once more.';

  @override
  String get planErrorPremium =>
      'This route needs Premium. Enable it to include hourly toll analysis.';

  @override
  String get planErrorRateLimit =>
      'Too many requests in a short time. Wait a few seconds and retry.';

  @override
  String planErrorGeneric(int code) {
    return 'Something went wrong while planning (code $code). Retry or change your inputs.';
  }

  @override
  String get planErrorNetwork =>
      'We couldn\'t reach the server. Check your connection and retry.';

  @override
  String get planErrorRetry => 'Retry';

  @override
  String get emptyAlertsTitle => 'No serious hazards detected';

  @override
  String get emptyAlertsBody =>
      'No fires, floods or serious hazards reported on your corridor. Safe travels.';

  @override
  String get emptyHotelsTitle => 'No hotels close to the route';

  @override
  String get emptyHotelsBody =>
      'Try widening the max detour or changing the price band to see more options.';

  @override
  String get emptyRestaurantsTitle => 'No restaurants match';

  @override
  String get emptyRestaurantsBody =>
      'Widen the max detour or clear cuisine filters to see more options.';

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
  String get onboardEyebrowFuel => 'TOLLS & FUEL';

  @override
  String get onboardTitleFuel => 'Skip this toll?\nFill up before France?';

  @override
  String get onboardBodyFuel =>
      'We show which tolls are worth skipping by hour, and which fuel station on your route has the best price right now.';

  @override
  String get onboardEyebrowDriving => 'COPILOTO IA · PREMIUM';

  @override
  String get onboardTitleDriving => '\"Should I stop\nfor fuel here?\"';

  @override
  String get onboardBodyDriving =>
      'Conoce tu ruta, tu depósito y los precios siguientes. Responde en segundos. Funciona con Android Auto. (Premium)';

  @override
  String get onboardEyebrowProfile => 'PERSONALISED';

  @override
  String get onboardTitleProfile => 'Fill your profile';

  @override
  String get onboardBodyProfile =>
      'Without a profile we only optimise time. With one we compute real fuel, hotels and meal times tuned to you.';

  @override
  String get onboardTollSkip => 'Saltar-lo';

  @override
  String get onboardTollSavingsAmt => 'estalvia €8';

  @override
  String get onboardTollPay => 'Pagar-lo';

  @override
  String get onboardTollPeakTime => 'Pic 08:00-10:00';

  @override
  String get onboardFuelStationsTitle => 'Gasolineres a la teva ruta';

  @override
  String get onboardProfileGroup => '2 adults + 1 nen';

  @override
  String get onboardProfilePet => 'Gos';

  @override
  String get onboardProfileParking => 'Parking';

  @override
  String get onboardProfileStars => '3+ estrelles';

  @override
  String get onboardProfileBudget => 'Màx. €€';

  @override
  String get onboardCompanionNextStop => 'Propera parada';

  @override
  String get onboardCompanionTank => 'Dipòsit';

  @override
  String get multiDaySleepLabel => 'You\'ll sleep at';

  @override
  String get multiDaySleepNoHotel => 'Overnight stop — no hotel available';

  @override
  String get resumeTripTitle => 'Resume your trip?';

  @override
  String resumeTripBody(String origin, String destination) {
    return 'We detected a $origin → $destination trip in progress. Continue where you left off?';
  }

  @override
  String get resumeTripResume => 'Resume';

  @override
  String get resumeTripDismiss => 'Dismiss';

  @override
  String get hotelPrefStarsLabel => 'Stars';

  @override
  String get hotelPrefDestRadiusLabel => 'Radius from destination';

  @override
  String get biometricPromptReason =>
      'Verify your identity to open MyTravelPal';

  @override
  String get biometricPromptSettings => 'Confirm to enable biometric unlock';

  @override
  String get planDepartureLabel => 'Preferred departure';

  @override
  String get hotelPrefStarsAny => 'Any';

  @override
  String get hotelPrefParkingTitle => 'With parking';

  @override
  String get hotelPrefParkingSub =>
      'Only hotels tagged with parking. Ones missing the tag pass through.';

  @override
  String get hotelFilterParking => 'Parking';

  @override
  String get hotelFilterWifi => 'Free WiFi';

  @override
  String get hotelFilterAccessible => 'Accessible';

  @override
  String get hotelFilterOtherTypes => 'Apartments, houses & more';

  @override
  String get restaurantFilterVegetarian => 'Vegetarian';

  @override
  String get restaurantFilterVegan => 'Vegan';

  @override
  String get restaurantFilterGlutenFree => 'Gluten-free';

  @override
  String get restaurantFilterHalal => 'Halal';

  @override
  String get restaurantFilterKosher => 'Kosher';

  @override
  String get restaurantDietaryLabel => 'Dietary';

  @override
  String get tollSkipSelectAll => 'Select all';

  @override
  String get mapShowLabel => 'Show map';

  @override
  String get mapHideLabel => 'Hide map';

  @override
  String get tripCostTitle => 'TOTAL TRIP COST';

  @override
  String get tripCostFuel => 'Fuel';

  @override
  String get tripCostTolls => 'Tolls';

  @override
  String get tripCostMeals => 'Meals';

  @override
  String get tripCostHotel => 'Hotel';

  @override
  String get tripCostTotal => 'Total estimated';

  @override
  String tripCostPerPerson(String amount) {
    return '$amount / person';
  }

  @override
  String tripCostPerDay(String amount) {
    return '$amount / day';
  }

  @override
  String get poiSpotlightRating => 'rating';

  @override
  String get poiSpotlightStars => 'stars';

  @override
  String poiSpotlightReviews(String count) {
    return '$count reviews';
  }

  @override
  String get poiSpotlightPricePerNight => 'per night';

  @override
  String get poiSpotlightPricePerMeal => 'per meal';

  @override
  String get poiSpotlightPricePerL => 'per litre';

  @override
  String get poiFeaturesHeading => 'Amenities';

  @override
  String get poiMoreInfoLabel => 'More info';

  @override
  String get poiMoreInfoHide => 'Hide';

  @override
  String get poiNoExtraInfo => 'No extra info from OSM for this place.';

  @override
  String poiOpenError(String url) {
    return 'Could not open $url';
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
  String get poiCtaCall => 'Call';

  @override
  String get poiCtaWebsite => 'Website';

  @override
  String get poiContactAddress => 'Address';

  @override
  String get poiContactPhone => 'Phone';

  @override
  String get poiContactWebsite => 'Website';

  @override
  String get poiContactHours => 'Opening hours';

  @override
  String get poiContactCheckin => 'Check-in';

  @override
  String get poiContactCheckout => 'Check-out';

  @override
  String get poiAttr_wifi => 'Free Wi-Fi';

  @override
  String get poiAttr_parking => 'Parking';

  @override
  String get poiAttr_pool => 'Swimming pool';

  @override
  String get poiAttr_airConditioning => 'Air conditioning';

  @override
  String get poiAttr_breakfast => 'Breakfast';

  @override
  String get poiAttr_petFriendly => 'Pets allowed';

  @override
  String get poiAttr_childFriendly => 'Child friendly';

  @override
  String get poiAttr_wheelchairAccess => 'Wheelchair accessible';

  @override
  String get poiAttr_toilets => 'Toilets';

  @override
  String get poiAttr_restaurant => 'Restaurant';

  @override
  String get poiAttr_bar => 'Bar';

  @override
  String get poiAttr_shop => 'Shop';

  @override
  String get poiAttr_outdoorSeating => 'Outdoor seating';

  @override
  String get poiAttr_takeaway => 'Takeaway';

  @override
  String get poiAttr_delivery => 'Delivery';

  @override
  String get poiAttr_creditCards => 'Cards accepted';

  @override
  String get poiAttr_carWash => 'Car wash';

  @override
  String get poiAttr_smoking => 'Smoking area';

  @override
  String get poiAttr_nonSmoking => 'Non-smoking';

  @override
  String get poiAttr_elevator => 'Elevator';

  @override
  String get poiAttr_checkIn => 'Check-in';

  @override
  String get poiAttr_checkOut => 'Check-out';

  @override
  String get poiAttr_dietVegetarian => 'Vegetarian';

  @override
  String get poiAttr_dietVegan => 'Vegan';

  @override
  String get poiAttr_dietHalal => 'Halal';

  @override
  String get poiAttr_dietKosher => 'Kosher';

  @override
  String get poiAttr_dietGlutenFree => 'Gluten-free';

  @override
  String get poiAttr_dog => 'Animals de companyia benvinguts';

  @override
  String get poiAttr_brand => 'Marca';

  @override
  String get poiAttr_city => 'Ciutat';

  @override
  String get poiAttr_street => 'Carrer';

  @override
  String get poiAttr_address => 'Adreça';

  @override
  String get poiAttr_openingHours => 'Horari d\'obertura';

  @override
  String get poiAttr_name => 'Nom';

  @override
  String get poiAttr_phone => 'Telèfon';

  @override
  String get poiAttr_stars => 'Estrelles';

  @override
  String get poiAttr_website => 'Lloc web';

  @override
  String get poiPickerChoose => 'Trieu';

  @override
  String get poiPickerSelected => 'Seleccionat';

  @override
  String get poiPickerHotels => 'Veure alternatives';

  @override
  String get poiPickerRestaurants => 'Veure restaurants propers';

  @override
  String get addToRouteLabel => 'Add to route';

  @override
  String get biometricSetupTitle => 'Enable biometric login?';

  @override
  String get biometricSetupBody =>
      'Use your fingerprint or face to unlock MyTravelPal next time.';

  @override
  String get biometricSetupEnable => 'Enable';

  @override
  String get biometricSetupSkip => 'Not now';

  @override
  String get weatherAlongRouteTitle => 'WEATHER ALONG YOUR ROUTE';

  @override
  String get weatherNoData => 'No weather data available for this route';

  @override
  String get weatherAllClear => 'No alerts';

  @override
  String get fuelNotificationTitle => 'Fill up before the border!';

  @override
  String fuelNotificationBody(
      String cheap, String price, String pricey, String savings) {
    return 'Fuel in $cheap (~$price€/L) before crossing into $pricey — save ~$savings€ per tank';
  }

  @override
  String get tutorialSkip => 'Skip';

  @override
  String get tutorialOriginTitle => 'Where are you starting?';

  @override
  String get tutorialOriginBody =>
      'Tap here to search for a city or use the location button to start from your current position.';

  @override
  String get tutorialDestinationTitle => 'Where are you going?';

  @override
  String get tutorialDestinationBody =>
      'Search for your destination. We\'ll plan the full route with stops, hotels, and tolls.';

  @override
  String get tutorialPrefsTitle => 'Customize your trip';

  @override
  String get tutorialPrefsBody =>
      'Toggle hotels, restaurants, and alerts. Set dietary preferences, star ratings, and more.';

  @override
  String get tutorialTimeWindowTitle => 'Pick the best departure time';

  @override
  String get tutorialTimeWindowBody =>
      'Tap any row to replan your trip with that departure time. The chart shows traffic impact at each hour.';

  @override
  String get tutorialTollTitle => 'Manage toll costs';

  @override
  String get tutorialTollBody =>
      'Toggle individual toll stretches to skip. The total savings update in real time. The color strip shows the best hours to skip.';

  @override
  String styleDailyCapRecommendedHint(int hours) {
    return 'For this pace we suggest $hours h/day.';
  }

  @override
  String get aaCoachTitle => 'How to open it on Android Auto';

  @override
  String get aaCoachStep1 =>
      'Connect the phone to the car by USB (or wireless if your head unit supports it).';

  @override
  String get aaCoachStep2 =>
      'In the car\'s launcher, switch to the \'Point of Interest\' or \'Apps\' category. It does NOT appear next to Google Maps.';

  @override
  String get aaCoachStep3 =>
      'Tap MyTravelPal. The companion shows next stop, cheaper fuel and ETA.';

  @override
  String get aaCoachHint =>
      'First launch takes a few seconds. Park with clear sky to get a GPS fix before starting.';

  @override
  String get aaCoachDontShowAgain => 'Don\'t show again';

  @override
  String get aaCoachDone => 'Got it';

  @override
  String get batteryWhitelistTitle => 'Stop Android from closing us';

  @override
  String get batteryWhitelistBody =>
      'Xiaomi/MIUI, Samsung and other vendors kill backgrounded apps after a few minutes. If you\'re navigating with Google Maps and MyTravelPal dies, you lose the live alerts.';

  @override
  String get batteryWhitelistSteps =>
      'Settings → Apps → MyTravelPal → Battery → No restrictions\n(or \'Don\'t optimize\' depending on your model)';

  @override
  String get batteryWhitelistDontShowAgain => 'Don\'t show again';

  @override
  String get batteryWhitelistLater => 'Not now';

  @override
  String get batteryWhitelistOpen => 'Open help';

  @override
  String get planRoundTripTitle => 'Round trip';

  @override
  String get planRoundTripSubtitle =>
      'We plan the return leg at the same time with the same preferences.';

  @override
  String get roundTripLegOutbound => 'OUTBOUND';

  @override
  String get roundTripLegReturn => 'RETURN';

  @override
  String roundTripSwapTo(String leg) {
    return 'View $leg';
  }

  @override
  String get resultStartTrip => 'Start trip';

  @override
  String get resultStartCompanion =>
      'Iniciar Asistente de conducción (Premium)';

  @override
  String get companionPreflightTitle => 'Ajustos abans de conduir';

  @override
  String get companionPreflightMealWindows => 'Horaris dels àpats';

  @override
  String get companionPreflightDetourTolerance => 'Desviament màxim';

  @override
  String get companionPreflightMealBudget => 'Pressupost per àpat';

  @override
  String get companionPreflightHotelBudget => 'Pressupost per nit';

  @override
  String get companionPreflightSaveToProfile => 'Desar al meu perfil';

  @override
  String get companionPreflightStart => 'Comença a conduir';

  @override
  String get companionPreflightBreakfast => 'Esmorzar';

  @override
  String get companionPreflightLunch => 'Dinar';

  @override
  String get companionPreflightDinner => 'Sopar';

  @override
  String get navPickerTitle => 'Continue in…';

  @override
  String get tripDashboardTitle => 'On the road';

  @override
  String get tripDashboardCenterOnMe => 'Centre on my location';

  @override
  String get tripDashboardOpenNav => 'Open navigation';

  @override
  String tripDashboardNextStopLabel(String slot) {
    return 'NEXT $slot';
  }

  @override
  String tripDashboardInMinutes(int n) {
    return 'in $n min';
  }

  @override
  String get tripDashboardPermissionDenied =>
      'Location denied. Grant the permission to see your position on the route.';

  @override
  String get tripDashboardServiceDisabled =>
      'GPS is off. Enable it to follow your progress on the route.';

  @override
  String tripDashboardProgressLine(String done, String total) {
    return '$done / $total km';
  }

  @override
  String tripDashboardEta(String time) {
    return 'ETA $time';
  }

  @override
  String get tripDashboardActiveNotifTitle => 'Trip in progress';

  @override
  String get tripDashboardActiveNotifBody =>
      'MyTravelPal is following your route in the background.';

  @override
  String tripDashboardForegroundBodyBare(String done, String total) {
    return '$done / $total km covered';
  }

  @override
  String tripDashboardForegroundBodyWithStop(
      String done, String total, String name) {
    return '$done / $total km · next stop: $name';
  }

  @override
  String get tripDashboardSleepStopLabel => 'hotel';

  @override
  String get alertApproachingStopTitle => 'Stop coming up';

  @override
  String alertApproachingStopBody(String slot, String name, int mins) {
    return '$slot at $name in about $mins min. Get ready for the exit.';
  }

  @override
  String get alertNewAdverseAheadTitle => 'New alert on your route';

  @override
  String alertNewAdverseAheadBody(String type, String km) {
    return '$type reported $km km ahead.';
  }

  @override
  String get alertDriftDetectedTitle => 'You\'ve left the route';

  @override
  String alertDriftDetectedBody(String off) {
    return 'You\'re $off m off the planned track. Recalculate?';
  }

  @override
  String get alertBehindScheduleTitle => 'Running behind';

  @override
  String alertBehindScheduleBody(int mins) {
    return 'You\'ll arrive $mins min later than planned.';
  }

  @override
  String tripDashboardCheaperFuel(String brand, String km, String cts) {
    return '$brand in $km km · save $cts ct/L';
  }

  @override
  String get resultOptimalDeparture => 'La teva hora de sortida és òptima';

  @override
  String shortLastDayWarning(String km) {
    return 'Últim tram curt ($km km) — podries arribar avui si avances més l\'endemà.';
  }

  @override
  String get prepareDepartureNow => 'Sortir ara';

  @override
  String get replanNewDepartureTitle =>
      'Recalculant amb la nova hora de sortida…';

  @override
  String get planStopReorderHint => 'Manté premuda la nansa per reordenar';

  @override
  String get planSwapOriginDestination => 'Invertir';

  @override
  String get planStopMoveUp => 'Mou amunt';

  @override
  String get planStopMoveDown => 'Mou avall';

  @override
  String get recentTripsTitle => 'Viatges recents';

  @override
  String recentTripsSubtitle(int count) {
    return '$count desats — toca per reutilitzar';
  }

  @override
  String recentTripsSeeAll(int n) {
    return 'Veure els $n viatges restants a Els meus viatges';
  }

  @override
  String get onRouteTitle => 'A la ruta';

  @override
  String get onRouteEmpty => 'Toca per triar opcions';

  @override
  String get exportShareTitle => 'Compartir ruta';

  @override
  String get exportOpenInMaps => 'Obrir a Google Maps';

  @override
  String get exportOpenInMapsSub => 'With added stops and detours';

  @override
  String get exportCopyLink => 'Copiar enllaç';

  @override
  String get exportLinkCopied => 'Enllaç copiat al porta-retalls';

  @override
  String get exportShareOs => 'Compartir…';

  @override
  String get exportShareSubject => 'La meva ruta a MyTravelPal';

  @override
  String get importFromMaps => 'Importar de Maps';

  @override
  String get importFromMapsTitle => 'Importar ruta de Google Maps';

  @override
  String get importFromMapsHint => 'Enganxa aquí l\'enllaç de Google Maps';

  @override
  String get importFromMapsPaste => 'Enganxar';

  @override
  String get importFromMapsImport => 'Importar';

  @override
  String get importFromMapsError => 'URL no reconeguda';

  @override
  String get importFromMapsErrorMalformed =>
      'URL no vàlida — revisa l\'enllaç i torna-ho a provar';

  @override
  String get importFromMapsErrorShortlink =>
      'No s\'ha pogut expandir l\'enllaç curt — obre\'l a Maps i copia la URL completa';

  @override
  String get importFromMapsErrorGeocode =>
      'No s\'han pogut localitzar els llocs — prova amb una ruta més curta o escriu-los a mà';

  @override
  String get importFromMapsLoading => 'Analitzant l\'enllaç…';

  @override
  String adverseEventsBannerCount(int count) {
    return '$count alerta/es a la teva ruta';
  }

  @override
  String pricePerMeal(String price) {
    return '$price €/àpat';
  }

  @override
  String kmFromOrigin(String km) {
    return '$km km des de l\'origen';
  }

  @override
  String get profileVehicleModel => 'Model';

  @override
  String get profileVehicleModelHint => 'Tria el teu model';

  @override
  String get profileVehicleModelClear => 'Treu el model';

  @override
  String get profileTankLevel => 'Dipòsit actual';

  @override
  String get vehiclePickerSearchHint => 'Cerca marca o model';

  @override
  String get vehiclePickerEmpty => 'Cap model coincideix';

  @override
  String get vehiclePickerLoadError =>
      'No s\'ha pogut carregar la llista. Torna-ho a provar.';

  @override
  String get vehiclePickerCustomOption => 'Vehicle personalitzat';

  @override
  String get vehiclePickerCustomOptionSubtitle =>
      'Introdueix el dipòsit i el consum manualment';

  @override
  String get vehicleCustomTitle => 'Vehicle personalitzat';

  @override
  String get vehicleCustomName => 'Nom del vehicle (opcional)';

  @override
  String get vehicleCustomNameHint => 'p. ex. El meu SUV';

  @override
  String get vehicleCustomTank => 'Dipòsit (L)';

  @override
  String get vehicleCustomTankEv => 'Bateria (kWh)';

  @override
  String get vehicleCustomConsumption => 'Consum (L/100 km)';

  @override
  String get vehicleCustomConsumptionEv => 'Consum (kWh/100 km)';

  @override
  String get vehicleCustomSave => 'Usar personalitzat';

  @override
  String refuelWindowComfortable(String km) {
    return 'Reposta abans del km $km (còmode)';
  }

  @override
  String refuelWindowCritical(String km) {
    return 'Reposta abans del km $km (crític)';
  }

  @override
  String get refuelSuggestionTitle => 'Reposta aquí per estalviar';

  @override
  String refuelSuggestionBody(String station, String km, String price) {
    return '$station · km $km · €$price/L';
  }

  @override
  String refuelSuggestionSavings(String eur) {
    return 'T\'estalvies $eur €';
  }

  @override
  String savingsFuelRow(String eur) {
    return 'Combustible: $eur €';
  }

  @override
  String get garageTitle => 'El meu garatge';

  @override
  String get garageEmpty => 'Encara no hi ha vehicles — afegeix el primer';

  @override
  String get garageAdd => 'Afegir vehicle';

  @override
  String get garageEdit => 'Editar vehicle';

  @override
  String get garageDelete => 'Eliminar';

  @override
  String get garageCancel => 'Cancel·lar';

  @override
  String get garageSave => 'Desar';

  @override
  String get garageDefaultName => 'El meu cotxe';

  @override
  String get garageNameHint => 'Posa-li un nom (p. ex. El meu Golf)';

  @override
  String get garageDefaultTankLabel => 'Nivell de dipòsit per defecte';

  @override
  String get garageDefaultChargeLevelLabel => 'Nivell de càrrega inicial';

  @override
  String get garageAddError => 'No s\'ha pogut desar. Torna-ho a intentar.';

  @override
  String get garageDeleteTitle => 'Eliminar el vehicle?';

  @override
  String garageDeleteBody(String name) {
    return '\"$name\" s\'esborrarà del teu garatge.';
  }

  @override
  String garageSettingsRow(int count) {
    return 'El meu garatge ($count)';
  }

  @override
  String planScreenGarageChip(String name, int pct) {
    return 'Cotxe: $name · $pct %';
  }

  @override
  String get planScreenGarageChooseVehicle =>
      'Trieu un vehicle per a aquest viatge';

  @override
  String get hotelArbitrageTitle => 'Hotels cheaper next door';

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
      other: '$nightsString nights',
      one: 'one night',
    );
    return 'This night lands in $dear. Hotels there run ~$dearPrice€/night vs ~$cheapPrice€/night in $cheap ($pct% less). Push $_temp0 south and save ~$savings€.';
  }

  @override
  String get hotelArbitrageMiniHint =>
      'Same savings if you shift this night south too';

  @override
  String get whatsNewSheetTitle => 'What\'s new';

  @override
  String get whatsNewSheetDismiss => 'Got it';

  @override
  String get profileChipChangeVehicle => 'Change vehicle';

  @override
  String get profileChipEditProfile => 'Edit trip profile';

  @override
  String get whatsNewSheetSuggest => 'Suggest something';

  @override
  String get feedbackSheetTitle => 'Suggestions';

  @override
  String get feedbackSheetSubtitle =>
      'Tell us what would make MyTravelPal better for you. We read every message.';

  @override
  String get feedbackBodyHint => 'What would you change or add?';

  @override
  String get feedbackWantReply => 'I\'d like a reply';

  @override
  String get feedbackEmailHint => 'Your email (optional)';

  @override
  String get feedbackSendButton => 'Send';

  @override
  String get feedbackThanks => 'Thanks! We\'ve got it.';

  @override
  String get feedbackErrorEmpty => 'Say a bit more (min. 3 characters)';

  @override
  String get feedbackErrorEmail => 'That doesn\'t look like a valid email';

  @override
  String get feedbackErrorSend => 'Couldn\'t send. Try again in a moment.';

  @override
  String get settingsSendFeedback => 'Send a suggestion';

  @override
  String get settingsSendFeedbackSubtitle => 'Tell us what to build next';

  @override
  String get enrichPulseRestStops => 'Looking for rest areas along the route';

  @override
  String get exitAppTitle => 'Leave MyTravelPal?';

  @override
  String get exitAppBody => 'Are you sure you want to close the app?';

  @override
  String get exitAppBodyCompanionActive =>
      'Companion mode is running. If you leave now, the drive session keeps running in the background. Stop it from the Companion tab first if you want to close it cleanly.';

  @override
  String get exitAppStay => 'Stay';

  @override
  String get exitAppLeave => 'Leave';

  @override
  String get enrichPulseChargers =>
      'Locating charging stations along the route';

  @override
  String get advEventLabelSource => 'Source';

  @override
  String get advEventLabelReported => 'Reported';

  @override
  String get advEventLabelExpires => 'Valid until';

  @override
  String get advEventLabelDuration => 'Estimated duration';

  @override
  String get advEventSourceWeather => 'Weather forecast (Open-Meteo)';

  @override
  String get advEventSourceOfficial => 'Official feed';

  @override
  String get advEventSourceEffis => 'EFFIS wildfire monitor';

  @override
  String get advEventSourceUsgs => 'USGS earthquake feed';

  @override
  String get advEventSourceUser => 'Community-reported';

  @override
  String get advEventSourceMock => 'Simulated (dev)';

  @override
  String advEventDurationHours(String h) {
    return '$h h';
  }

  @override
  String advEventDurationDays(String d, String h) {
    return '$d d $h h';
  }

  @override
  String get advEventDurationOngoing => 'Ongoing';

  @override
  String get exportShareMtp => 'Share with MyTravelPal users';

  @override
  String get exportShareMtpSubtitle =>
      'Opens directly in the app — they choose their own preferences';

  @override
  String exportShareMtpSubject(String origin, String destination) {
    return '$origin → $destination | MyTravelPal';
  }

  @override
  String get resultFuelStationsOnRoute => 'Benzineres a la ruta';

  @override
  String get resultFuelSavingsAccordionTitle => 'Estalvi en combustible';

  @override
  String get resultTimeSavingsOptimal => 'La teva hora de sortida és òptima';

  @override
  String get hotelMapFullscreenTitle => 'Hotels a la zona';

  @override
  String get restaurantMapFullscreenTitle => 'Restaurants a la zona';

  @override
  String get tollSummaryTitle => 'Peatges del trajecte';

  @override
  String get tollSummaryMapButton => 'Veure al mapa';

  @override
  String activitiesCtaTitle(Object city) {
    return 'Què fer a $city';
  }

  @override
  String get activitiesCtaSubtitle => 'Activitats i experiències locals';

  @override
  String get planIncludeActivities => 'Activitats a la destinació';

  @override
  String get planIncludeActivitiesHint =>
      'Suggeriments GetYourGuide a cada ciutat';

  @override
  String get aiPrefScenicRoutes => 'Prefereixo rutes panoràmiques';

  @override
  String get aiPrefScenicRoutesSub =>
      'Recomanar desviaments per miradors i ports de muntanya';

  @override
  String get aiPrefEcoConscious => 'Conducció eco';

  @override
  String get aiPrefEcoConsciousSub =>
      'Preferir VE, evitar autopistes quan sigui possible';

  @override
  String get aiPrefLocalFood => 'Menjar local primer';

  @override
  String get aiPrefLocalFoodSub =>
      'Prioritzar restaurants locals davant cadenes';

  @override
  String get aiPrefDepartureHour => 'Hora habitual de sortida';

  @override
  String get aiPrefDietary => 'RESTRICCIONS ALIMENTÀRIES';

  @override
  String get aiPrefInterests => 'INTERESSOS';

  @override
  String get aiDietVegetarian => 'Vegetarià';

  @override
  String get aiDietVegan => 'Vegà';

  @override
  String get aiDietGlutenFree => 'Sense gluten';

  @override
  String get aiDietHalal => 'Halal';

  @override
  String get aiInterestCulture => 'Cultura';

  @override
  String get aiInterestNature => 'Natura';

  @override
  String get aiInterestGastronomy => 'Gastronomia';

  @override
  String get aiInterestShopping => 'Compres';

  @override
  String get aiInterestAdventure => 'Aventura';

  @override
  String get wizardSkip => 'Omitir';

  @override
  String get wizardStart => 'Empezar';

  @override
  String get wizardBack => 'Atrás';

  @override
  String get wizardNext => 'Siguiente';

  @override
  String get wizardTakesSeconds => 'Solo 30 segundos';

  @override
  String get wizardWelcomeTitle => 'Bienvenido a MyTravelPal';

  @override
  String get wizardWelcomeBody =>
      'Cuéntanos un poco sobre tus viajes y personalizaremos todo desde el primer momento.';

  @override
  String get wizardWhoTitle => '¿Con quién viajas?';

  @override
  String get wizardWhoSubtitle =>
      'Selecciona todo lo que aplique. Puedes cambiarlo después.';

  @override
  String get wizardWhoKids => 'Viajo con niños';

  @override
  String get wizardWhoPets => 'Viajo con mascotas';

  @override
  String get wizardWhoCamper => 'Viajo en autocaravana';

  @override
  String get wizardVehicleTitle => 'Tu vehículo';

  @override
  String get wizardVehicleSubtitle =>
      'Usaremos esto para calcular el combustible y sugerir rutas.';

  @override
  String get wizardVehicleType => 'Tipo de vehículo';

  @override
  String get wizardFuelType => 'Combustible';

  @override
  String get wizardRhythmTitle => 'Tu ritmo de viaje';

  @override
  String get wizardRhythmSubtitle =>
      'Son valores orientativos — puedes cambiarlos viaje a viaje.';

  @override
  String wizardWakeHour(String h) {
    return 'Salgo a las $h';
  }

  @override
  String wizardBreakEvery(String n) {
    return 'Paro cada ${n}h';
  }

  @override
  String wizardBedtime(String h) {
    return 'Llego al hotel a las $h';
  }

  @override
  String get wizardHotelBudget => 'Presupuesto hotel / noche';

  @override
  String get wizardMealBudget => 'Presupuesto comida / menú';

  @override
  String get wizardDoneTitle => '¡Todo listo!';

  @override
  String get wizardDoneSubtitle =>
      'Tu primera ruta ya estará personalizada para ti.';

  @override
  String get wizardTeaserTitle =>
      'Cuando quieras, en Ajustes también puedes configurar:';

  @override
  String get wizardTeaserVehicleModel =>
      'Modelo exacto de vehículo (consumo real)';

  @override
  String get wizardTeaserRoute => 'Ruta preferida: autopista o panorámica';

  @override
  String get wizardTeaserEmergency => 'Contactos de emergencia';

  @override
  String get wizardTeaserAlertSound => 'Sonido de alertas del Companion';

  @override
  String get wizardTeaserStars => 'Categoría mínima de hotel';

  @override
  String get wizardPlanFirstTrip => 'Planificar mi primer viaje';

  @override
  String get priceBandBudget => 'Económico';

  @override
  String get priceBandMid => 'Estándar';

  @override
  String get priceBandLux => 'Superior';

  @override
  String get wizardModelTitle => 'Tu modelo de vehículo';

  @override
  String get wizardModelSubtitle =>
      'Con datos reales calculamos cuándo y dónde repostar para ahorrarte dinero.';

  @override
  String get wizardModelSearch => 'Buscar marca o modelo...';

  @override
  String get wizardModelGeneric => 'Usar valores genéricos';

  @override
  String get wizardModelGenericSub =>
      'Estimación estándar por tipo de vehículo';

  @override
  String get wizardTollFreeDetour => 'Desviament lliure';

  @override
  String get wizardTollMotorway => 'Autopista';

  @override
  String get wizardTollFaster => 'Més ràpid';

  @override
  String get wizardTollTitle => '¿Evitamos peajes?';

  @override
  String get wizardTollSubtitle =>
      'Analizamos miles de rutas para saber cuándo el desvío vale la pena.';

  @override
  String get wizardTollAvoid => 'Evitar cuando sea posible';

  @override
  String get wizardTollAvoidSub => 'Que me propongan alternativas por defecto';

  @override
  String get wizardTollPay => 'Preferir autopista siempre';

  @override
  String get wizardTollPaySub =>
      'Prefiero ir siempre por autopista salvo que ahorros sean muy claros';

  @override
  String get wizardTollNote =>
      'Puedes cambiar esto para cada viaje desde la pantalla de planificación';

  @override
  String get wizardDrivingNow => 'Conducir ahora con el asistente';

  @override
  String get companionModeLabel => 'Asistente de conducción';

  @override
  String get companionModeDesc =>
      'Co-pilot IA · Recomana alternatives de peatge, restaurants segons els teus gustos i benzineres barates en temps real · Premium';

  @override
  String get aiLearningTitle => 'El asistente te conoce al';

  @override
  String get aiScoreExcellent =>
      'Excelente · Las recomendaciones son muy precisas';

  @override
  String get aiScoreGood => 'Bien · Aún puedes mejorar la personalización';

  @override
  String get aiScoreBasic =>
      'Básico · Completa tu perfil para mejores resultados';

  @override
  String get aiFactorVehicleModel => 'Modelo de vehículo';

  @override
  String get aiFactorVehicleModelHint =>
      'Configura tu modelo para cálculos de combustible exactos';

  @override
  String aiFactorTrips(int count) {
    return '$count viajes realizados';
  }

  @override
  String get aiFactorTripsHint =>
      'Cuantos más viajes, mejor entiende tus rutas habituales';

  @override
  String get aiFactorHotelPrefs => 'Preferencias de hotel';

  @override
  String get aiFactorHotelPrefsHint =>
      'Añade estrellas, parking o wifi para filtrar mejor';

  @override
  String get aiFactorRestPrefs => 'Preferencias de restaurante';

  @override
  String get aiFactorRestPrefsHint =>
      'Añade tipos de cocina para sugerencias más acertadas';

  @override
  String get aiFactorNick => 'Nick y país configurados';

  @override
  String get aiFactorNickHint => 'Completa tu nombre y país en Ajustes';

  @override
  String get aiFactorEmergency => 'Contactos de emergencia';

  @override
  String get aiFactorEmergencyHint =>
      'Añade un contacto para el sistema de seguridad';

  @override
  String get aiFactorProfile => 'Perfil de viaje básico';

  @override
  String get aiFactorProfileHint =>
      'Configura tus horarios de conducción en Ajustes';

  @override
  String get tripQualityTitle => 'Calidad del viaje';

  @override
  String get tripQualityExcellent => 'Excelente';

  @override
  String get tripQualityGood => 'Bueno';

  @override
  String get tripQualityFair => 'Aceptable';

  @override
  String get tripQualityPoor => 'Limitado';

  @override
  String get tripQualityFactorRoute => 'Ruta';

  @override
  String get tripQualityFactorFuel => 'Gasolineras';

  @override
  String get tripQualityFactorHotels => 'Hoteles';

  @override
  String get tripQualityFactorWeather => 'Clima';

  @override
  String get tripQualityFactorAlerts => 'Alertas';

  @override
  String get tripQualityFactorTolls => 'Peajes';

  @override
  String get tripQualityFactorStops => 'Paradas';

  @override
  String get wizardModelConsumption => 'Consumo';

  @override
  String get wizardModelTank => 'Depósito';

  @override
  String get wizardRhythmNote =>
      'Ajusta cualquier día directamente en el resultado del viaje, pulsando el icono ⚙ de cada etapa.';

  @override
  String get wizardTollHowTitle => 'CÓMO FUNCIONA';

  @override
  String get wizardTollHowBody =>
      'En cada viaje analizamos peaje por peaje: si el desvío te ahorra dinero real y el tiempo extra es mínimo, te lo proponemos en la pantalla de resultado. Tú decides aceptarlo o no, y puedes ajustar exactamente cuánto tiempo extra estás dispuesto a asumir.';

  @override
  String get wizardTollPreference => '¿Cuál es tu punto de partida?';

  @override
  String get resultStartCompanionNow => '¡Salir ahora! · Modo Acompañante';

  @override
  String get resultCompanionFarFromOrigin =>
      'Acércate al punto de salida para activar el modo conducción';

  @override
  String get resultReplanWithChanges => 'Recalcular con los cambios aplicados';

  @override
  String get replanTipRoute => 'Optimizando las etapas del día...';

  @override
  String get replanTipFuel => 'Buscando las mejores gasolineras en ruta...';

  @override
  String get replanTipStops => 'Ajustando paradas y tiempos de llegada...';

  @override
  String tripDayBarsCap(int n) {
    return 'Límit: ${n}h';
  }

  @override
  String tripDayBarsUnselected(int n) {
    return '$n parada(es) sense afegir';
  }

  @override
  String get tripDayBarsHint => 'Toca + per incloure-les en la durada total';

  @override
  String get tripDayBarsCapLabel => 'Límit';

  @override
  String get tripDayBarsTitle => 'Distribució per etapes';

  @override
  String get wizardStepProfile => 'Perfil';

  @override
  String get wizardStepVehicle => 'Vehicle';

  @override
  String get wizardStepRhythm => 'Ritmo';

  @override
  String get wizardStepBudget => 'Budget';

  @override
  String wizardModelsAvailable(int count) {
    return '$count models disponibles';
  }
}
