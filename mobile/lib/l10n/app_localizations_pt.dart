// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appName => 'MyTravelPal';

  @override
  String get appTagline => 'Planeia a viagem, não só o destino';

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
  String get onboardCostFuel => 'Combustível';

  @override
  String get onboardCostTolls => 'Portagens';

  @override
  String get onboardCostMeals => 'Refeições';

  @override
  String get onboardCostHotel => 'Hotel';

  @override
  String get onboardCostTotal => 'TOTAL';

  @override
  String get onboardSavingsTitle => 'Poupanças detectadas';

  @override
  String get onboardSavingsToll => 'Portagem alternativa';

  @override
  String get onboardSavingsFuel => 'Posto óptimo';

  @override
  String get onboardSavingsHotel => 'Melhor hotel';

  @override
  String get onboardSavingsTotal => 'TOTAL POUPADO';

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
  String get planEyebrow => 'O PLANIFICADOR';

  @override
  String get planHero => 'Para onde vamos\nhoje?';

  @override
  String planHeroPersonal(String name) {
    return 'Para onde vamos,\n$name?';
  }

  @override
  String get planIntro =>
      'Escolhe dois pontos e uma hora. Do resto tratamos nós.';

  @override
  String get planFrom => 'De';

  @override
  String get planTo => 'Até';

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
  String get planTooltipDashboard => 'Painel';

  @override
  String get planTooltipReport => 'Reportar evento';

  @override
  String get planTooltipSaved => 'Viagens guardadas';

  @override
  String get tabPlan => 'Planear';

  @override
  String get tabCompanion => 'Acompanhante';

  @override
  String get tabMyTrips => 'As minhas viagens';

  @override
  String get companionHeroTitle => 'O teu acompanhante de viagem';

  @override
  String get companionHeroBody =>
      'Define as tuas condições e arranca. A app segue a tua condução e recomenda quando parar, onde comer e onde abastecer.';

  @override
  String get companionConfigSection => 'CONFIGURAÇÃO';

  @override
  String get companionBreakInterval => 'Sugerir pausa a cada';

  @override
  String get companionSuggestBreak => 'Suggest a rest based on drive time';

  @override
  String companionBreakHint(String hours) {
    return 'Recomendar paragem a cada $hours h de condução';
  }

  @override
  String get companionFatigueStopExperimental =>
      'Suggest pulling over on fatigue (experimental)';

  @override
  String get companionFatigueStopHint =>
      'Timer-only signal today — over-eager for short micro-pauses.';

  @override
  String get companionAlerts => 'Tipos de alerta';

  @override
  String get companionAlertCriticalAdverse =>
      'Critical incidents (fires, floods, quakes)';

  @override
  String get companionAlertCriticalAdverseHint =>
      'Recommended. Something serious happening near you — not just weather.';

  @override
  String get companionAlertWeather => 'Meteorologia à frente';

  @override
  String get companionAlertFuel => 'Oportunidades de combustível';

  @override
  String get companionAlertBorder => 'Aviso ao cruzar fronteiras';

  @override
  String get companionAlertToll => 'Sugestões para evitar portagens';

  @override
  String get companionAlertHotel => 'Hotéis quando estiveres cansado';

  @override
  String get companionStart => 'Iniciar acompanhante';

  @override
  String get companionComingSoon => 'Modo acompanhante em breve';

  @override
  String get companionDriveTitle => 'Acompanhante ativo';

  @override
  String get companionForegroundBody =>
      'MyTravelPal está a seguir a tua condução';

  @override
  String get companionLocationDenied =>
      'É necessária permissão de localização para o acompanhante.';

  @override
  String get companionDriving => 'em condução';

  @override
  String get companionAllGood => 'Sem alertas — boa viagem.';

  @override
  String get companionWeatherRowEmpty => 'Sem alertas próximos';

  @override
  String get companionEndTitle => 'Terminar acompanhante?';

  @override
  String get companionEndBody =>
      'O rastreio será interrompido e os alertas ativos serão perdidos.';

  @override
  String get companionEndKeep => 'Continuar';

  @override
  String get companionEndConfirm => 'Terminar sessão';

  @override
  String get emergencyContactsTitle => 'Contactos de emergência';

  @override
  String get emergencyContactsSubtitle => 'Recebem SMS se for detetado impacto';

  @override
  String get emergencyContactsBody =>
      'Até 3 pessoas recebem um SMS com a tua localização se o acompanhante detetar um impacto.';

  @override
  String get emergencyContactsEmpty => 'Ainda não há contactos.';

  @override
  String get emergencyContactsAdd => 'Adicionar contacto';

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
  String get emergencyContactAddTitle => 'Adicionar contacto de emergência';

  @override
  String get emergencyContactName => 'Nome';

  @override
  String get emergencyContactNameRequired => 'Introduz um nome';

  @override
  String get emergencyContactPhone => 'Telefone (E.164)';

  @override
  String get emergencyContactPhoneRequired => 'Introduz um telefone';

  @override
  String get emergencyContactPhoneInvalid =>
      'Formato internacional: +351912345678';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get sosTitle => 'Possível impacto detetado';

  @override
  String sosBody(String g, String speed) {
    return 'Pico de impacto ${g}g · queda de velocidade $speed km/h.';
  }

  @override
  String sosCountdown(int seconds) {
    return '${seconds}s';
  }

  @override
  String get sosImOk => 'Estou bem — cancelar';

  @override
  String get sosCall112 => 'Ligar 112';

  @override
  String get sosCancelled => 'Alerta cancelado.';

  @override
  String get sosClose => 'Fechar';

  @override
  String get sosNoContacts =>
      'Sem contactos configurados. Adiciona um em Definições.';

  @override
  String sosSmsDispatched(int count) {
    return 'SMS preparado para $count contacto(s).';
  }

  @override
  String get sosSmsFailed =>
      'Não foi possível abrir o SMS. Liga manualmente abaixo.';

  @override
  String get sosSmsPrefix =>
      'MyTravelPal — possível impacto detetado. A minha localização:';

  @override
  String get weatherForecastTitle => 'Previsão 7 dias';

  @override
  String get weatherToday => 'Hoje';

  @override
  String get leaveNowTitle => 'Partir já com acompanhante';

  @override
  String get leaveNowSubtitle =>
      'Escolhe destino e arranca — seguimos e guiamos.';

  @override
  String get leaveNowSheetTitle => 'Para onde vais?';

  @override
  String get leaveNowPremiumTitle => 'Funcionalidade Premium';

  @override
  String get leaveNowPremiumBody =>
      '\'Partir já\' combina o plano completo com o acompanhante de condução. Disponível com MyTravelPal Premium.';

  @override
  String get leaveNowPremiumDismiss => 'Mais tarde';

  @override
  String get leaveNowPremiumCta => 'Experimentar 7 dias grátis';

  @override
  String get shareCardOption => 'Partilhar como imagem';

  @override
  String get shareCardOptionSub =>
      'Perfeito para Instagram Stories, WhatsApp, X';

  @override
  String get shareLinkOption => 'Partilhar como link';

  @override
  String get shareLinkOptionSub =>
      'Resumo em texto + link para reabrir o plano';

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
    return 'A conduzir por $city';
  }

  @override
  String shareLiveCaption(String city) {
    return 'A conduzir por $city com MyTravelPal 🚗';
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
    return '$n horas';
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
  String get dashboardSaved => 'poupado';

  @override
  String get dashboardCountries => 'Countries';

  @override
  String get dashboardSignOut => 'Terminar sessão';

  @override
  String get profileTitle => 'Perfil de viagem';

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
  String get planTooltipFavorites => 'Favoritos';

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
  String get resultStatPlanned => 'Planned';

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
      'Connection dropped during re-plan. Check your signal and try again.';

  @override
  String get retryLabel => 'Retry';

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
      other: '$count guardados',
      one: '1 guardado',
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
  String get weatherSunny => 'Sol';

  @override
  String get weatherPartlyCloudy => 'Parcialmente nublado';

  @override
  String get weatherCloudy => 'Nublado';

  @override
  String get weatherFog => 'Nevoeiro';

  @override
  String get weatherDrizzle => 'Chuvisco';

  @override
  String get weatherRain => 'Chuva';

  @override
  String get weatherHeavyRain => 'Chuva forte';

  @override
  String get weatherSnow => 'Neve';

  @override
  String get weatherHeavySnow => 'Neve forte';

  @override
  String get weatherThunderstorm => 'Trovoada';

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
  String get settingsTitle => 'Definições';

  @override
  String get settingsSectionVehicle => 'Veículo e rota';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionAI => 'Personalização IA';

  @override
  String get notifSoundTitle => 'Som de alertas';

  @override
  String get notifSoundDefault => 'Som padrão';

  @override
  String get notifSoundDefaultSub => 'Usa o som de notificação do sistema';

  @override
  String get notifSoundSilent => 'Silêncio';

  @override
  String get notifSoundSilentSub => 'Sem som para alertas';

  @override
  String get settingsSectionSafety => 'Contactos e segurança';

  @override
  String get settingsSectionAccount => 'Conta';

  @override
  String get settingsDensityLabel => 'Densidade';

  @override
  String get settingsDensityComfortable => 'Confortável';

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
  String get planTooltipSettings => 'Definições';

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
  String get drivingWindowNightStart => 'Condução nocturna no início';

  @override
  String get drivingWindowNightEnd => 'Condução nocturna no final';

  @override
  String get dayEditKmNoLimit => 'Máx. km: sem limite';

  @override
  String dayEditKmCap(int km) {
    return 'Máx. km: $km km';
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
  String get dayReduceKmTitle => 'Driving time reduced';

  @override
  String dayReduceKmBody(String reducedKm) {
    return 'With this schedule you will reach approx. $reducedKm km. Do you want to adjust the km limit?';
  }

  @override
  String get dayReduceKmKeep => 'Keep current km';

  @override
  String dayReduceKmAdjust(String reducedKm) {
    return 'Adjust to $reducedKm km';
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
  String get fuelTypeE85 => 'E85 / Ethanol';

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
  String get eventTypeEarthquake => 'Terramoto';

  @override
  String get eventTypeLandslide => 'Deslizamento';

  @override
  String get eventTypeAvalanche => 'Avalanche';

  @override
  String get eventTypeClosure => 'Estrada cortada';

  @override
  String get eventTypeHeatwave => 'Onda de calor';

  @override
  String get eventTypeHeavyRain => 'Chuva forte';

  @override
  String get eventTypeHail => 'Granizo';

  @override
  String get eventTypeThunderstorm => 'Trovoada';

  @override
  String get eventTypeHighWind => 'Vento forte';

  @override
  String get eventTypeDenseFog => 'Nevoeiro denso';

  @override
  String get eventTypeFreezingRain => 'Chuva gelada';

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
    return 'Chega ao destino por volta das $time';
  }

  @override
  String daySleepMarker(String time) {
    return 'Finish driving around $time';
  }

  @override
  String dayStartsAt(String time) {
    return 'Sai às $time';
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
  String get restStopFilterAll => 'Todas';

  @override
  String get restStopFilterKidFriendly => 'Familiar';

  @override
  String get restStopFilterPetFriendly => 'Pet-friendly';

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
  String get onboardTollSkip => 'Evitá-lo';

  @override
  String get onboardTollSavingsAmt => 'poupa €8';

  @override
  String get onboardTollPay => 'Pagá-lo';

  @override
  String get onboardTollPeakTime => 'Pico 08:00-10:00';

  @override
  String get onboardFuelStationsTitle => 'Postos de abastecimento na sua rota';

  @override
  String get onboardProfileGroup => '2 adultos + 1 criança';

  @override
  String get onboardProfilePet => 'Cão';

  @override
  String get onboardProfileParking => 'Parking';

  @override
  String get onboardProfileStars => '3+ estrelas';

  @override
  String get onboardProfileBudget => 'Máx. €€';

  @override
  String get onboardCompanionNextStop => 'Próxima paragem';

  @override
  String get onboardCompanionTank => 'Depósito';

  @override
  String get onboardAlertFire =>
      'Incêndio florestal · km 214 · 14 km da sua rota';

  @override
  String get onboardAlertSevere => 'GRAVE';

  @override
  String get onboardAlertStorm => 'Tempestade forte · Girona · em 2h';

  @override
  String get onboardAlertWarning => 'AVISO';

  @override
  String get onboardCompanionQuestion => 'Abastecimento aqui ou espero?';

  @override
  String get onboardCompanionFuelStation => 'Galp · km 387 — 1.52 €/L';

  @override
  String get onboardCompanionFuelAdvice =>
      'A próxima estação a 58 km custa 1,79 €/L.\nO seu depósito atual chega mais que suficiente.';

  @override
  String get onboardFuelStation1 => 'Galp · km 387';

  @override
  String get onboardFuelStation2 => 'BP Auto-estrada · km 412';

  @override
  String get onboardFuelStation3 => 'Shell A1 · km 445';

  @override
  String get onboardHotelName => 'Hotel Lisboa ★★★';

  @override
  String get onboardHotelMeta => '€85/noite · 0.8 km';

  @override
  String get onboardHotelAttrs => 'Parking ✓  Cães ✓';

  @override
  String get onboardRestaurantName => 'O Velho Moinho';

  @override
  String get onboardRestaurantMeta => '€14/menu · 2 min';

  @override
  String get onboardRestaurantAttrs => 'Esplanada ✓  Cães ✓';

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
  String get tripCostNoExpense => 'No expense';

  @override
  String get replanLostTitle => 'Some picks no longer fit the new route';

  @override
  String get replanLostBody =>
      'Because the distance changes, these picks no longer match the route. If you continue they will be deselected and we will offer other options. If you cancel, your current plan stays as it is.';

  @override
  String replanLostHotel(String name, int day) {
    return 'Hotel: $name · day $day';
  }

  @override
  String replanLostRestaurant(String name) {
    return 'Restaurant: $name';
  }

  @override
  String replanLostFuel(String name) {
    return 'Fuel station: $name';
  }

  @override
  String replanLostMeal(String name) {
    return 'Meal stop: $name';
  }

  @override
  String replanLostSleep(String name) {
    return 'Overnight stop: $name';
  }

  @override
  String get styleKmCapNone => 'Max km/day: no limit';

  @override
  String styleKmCapValue(int km) {
    return 'Max km/day: $km km';
  }

  @override
  String get styleKmCapRemove => 'Remove km limit';

  @override
  String get purchaseBetaNote =>
      'Closed beta: tapping a plan simulates the subscription. Nothing is charged.';

  @override
  String purchaseBetaApplied(String plan) {
    return 'Beta: $plan plan applied (simulated)';
  }

  @override
  String get settingsBetaAccess => 'BETA ACCESS';

  @override
  String get settingsTierFreeName => 'Free';

  @override
  String get myPlacesTitle => 'My places';

  @override
  String myPlacesSettingsRow(int count) {
    return 'My places ($count)';
  }

  @override
  String get myPlacesSettingsSub => 'Places you like to stop at';

  @override
  String get myPlacesEmpty =>
      'Save the places you like to stop at. When a route passes near one, we will suggest it.';

  @override
  String get myPlacesAdd => 'Add a place';

  @override
  String get myPlacesSearchHint => 'Search a place or paste a map link';

  @override
  String get myPlacesSearch => 'Search';

  @override
  String get myPlacesNoResults =>
      'Nothing found. Try another name, or paste a link that contains coordinates.';

  @override
  String get myPlacesNameLabel => 'Name';

  @override
  String get myPlacesNoteLabel => 'Note (optional)';

  @override
  String get myPlacesCategoryLabel => 'Category';

  @override
  String get myPlacesSave => 'Save place';

  @override
  String myPlacesRemoved(String name) {
    return '$name removed';
  }

  @override
  String get myPlacesUndo => 'Undo';

  @override
  String myPlacesLimit(int max) {
    return 'You can save up to $max places.';
  }

  @override
  String get myPlacesFromLink => 'Place from link';

  @override
  String get myPlacesCatFood => 'Food';

  @override
  String get myPlacesCatViewpoint => 'Viewpoint';

  @override
  String get myPlacesCatCulture => 'Culture';

  @override
  String get myPlacesCatNature => 'Nature';

  @override
  String get myPlacesCatKids => 'With kids';

  @override
  String get myPlacesCatOther => 'Other';

  @override
  String get myPlacesOnRouteTitle => 'Your places on this route';

  @override
  String myPlacesOffRoute(String km, int min) {
    return '$km km off route · ~$min min';
  }

  @override
  String get myPlacesAddToRoute => 'Add';

  @override
  String get myPlacesRemoveFromRoute => 'Remove';

  @override
  String get companionJoinTitle => 'Join as passenger';

  @override
  String get companionJoinHint => '6-character code';

  @override
  String get companionJoinButton => 'Join';

  @override
  String get companionJoinCodeInvalid => 'The code must have 6 characters';

  @override
  String get passengerViewTitle => 'Companion — Passenger';

  @override
  String passengerViewCode(String code) {
    return 'Code: $code';
  }

  @override
  String get passengerViewSpeed => 'Driver speed';

  @override
  String get passengerViewNextStop => 'Next stop';

  @override
  String get passengerViewDestination => 'Destination';

  @override
  String get passengerViewRefresh => 'Updating every 5 s';

  @override
  String passengerViewRadarBanner(String meters) {
    return 'Speed camera in $meters m';
  }

  @override
  String get passengerViewSlowDown => 'Slow down';

  @override
  String passengerViewRadarAhead(String distance) {
    return 'Speed camera in $distance';
  }

  @override
  String get paywallSubtitle => 'Choose the plan that fits your trips';

  @override
  String get paywallFreePrice => 'Always free';

  @override
  String get paywallFreeSubtitle => 'Basic trip planning';

  @override
  String get paywallFreeF1 => 'Route + toll estimate';

  @override
  String get paywallFreeF2 => 'Fuel prices along route';

  @override
  String get paywallFreeF3 => 'Hotel + restaurant suggestions';

  @override
  String get paywallFreeF4 => '3 saved trips';

  @override
  String get paywallCurrentPlan => 'Current plan';

  @override
  String get paywallEssentialSubtitle => 'Best for occasional travelers';

  @override
  String get paywallEssentialF1 => 'Everything in Free';

  @override
  String get paywallEssentialF2 => 'Unlimited saved trips';

  @override
  String get paywallEssentialF3 => 'Weather along route';

  @override
  String get paywallEssentialF4 => 'Adverse events (fires, floods)';

  @override
  String get paywallEssentialF5 => 'Trip cost breakdown';

  @override
  String get paywallEssentialF6 => '14-day free trial';

  @override
  String get paywallStartTrial => 'Start 14-day trial';

  @override
  String get paywallOpening => 'Opening...';

  @override
  String get paywallMonthly => 'Monthly';

  @override
  String get paywallYearly => 'Yearly';

  @override
  String get paywallSave33 => 'Save 33%';

  @override
  String get paywallPremiumSubtitle => 'For road-trip enthusiasts';

  @override
  String get paywallPremiumF1 => 'Everything in Essential';

  @override
  String get paywallPremiumF2 => 'AI Trip Companion (in-drive)';

  @override
  String get paywallPremiumF3 => 'AI trip inspiration';

  @override
  String get paywallPremiumF4 => 'Real-time hotel price alerts';

  @override
  String get paywallPremiumF5 => 'Priority customer support';

  @override
  String get paywallPremiumF6 => 'Early access to new features';

  @override
  String get paywallGetPremium => 'Get Premium';

  @override
  String get paywallRestore => 'Restore purchases';

  @override
  String get planOptTollFreeLocked => 'Toll-free options require Premium';

  @override
  String get planOptSeePlans => 'See plans';

  @override
  String paywallPerYear(String amount) {
    return '$amount/yr';
  }

  @override
  String paywallPerMonth(String amount) {
    return '$amount/mo';
  }

  @override
  String get paywallLegal =>
      'Payment will be charged to your Google Play account at confirmation of purchase. Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Play Store Settings > Subscriptions.';

  @override
  String get replanLostConfirm => 'Continue and deselect';

  @override
  String get replanLostCancel => 'Keep current plan';

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
  String get poiAttr_dog => 'Animais de estimação bem-vindos';

  @override
  String get poiAttr_brand => 'Marca';

  @override
  String get poiAttr_city => 'Cidade';

  @override
  String get poiAttr_street => 'Rua';

  @override
  String get poiAttr_address => 'Endereço';

  @override
  String get poiAttr_openingHours => 'Horário de funcionamento';

  @override
  String get poiAttr_name => 'Nome';

  @override
  String get poiAttr_phone => 'Telefone';

  @override
  String get poiAttr_stars => 'Estrelas';

  @override
  String get poiAttr_website => 'Site';

  @override
  String get poiPickerChoose => 'Escolher';

  @override
  String get poiPickerSelected => 'Selecionado';

  @override
  String get poiPickerHotels => 'Ver alternativas';

  @override
  String get poiPickerRestaurants => 'Ver restaurantes próximos';

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
  String get companionPreflightTitle => 'Ajustes antes de conduzir';

  @override
  String get companionPreflightMealWindows => 'Horários das refeições';

  @override
  String get companionPreflightDetourTolerance => 'Desvio máximo';

  @override
  String get companionPreflightMealBudget => 'Orçamento por refeição';

  @override
  String get companionPreflightHotelBudget => 'Orçamento por noite';

  @override
  String get companionPreflightSaveToProfile => 'Guardar no meu perfil';

  @override
  String get companionPreflightStart => 'Começar a conduzir';

  @override
  String get companionPreflightBreakfast => 'Pequeno-almoço';

  @override
  String get companionPreflightLunch => 'Almoço';

  @override
  String get companionPreflightDinner => 'Jantar';

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
  String get resultOptimalDeparture => 'A sua hora de partida é óptima';

  @override
  String shortLastDayWarning(String km) {
    return 'Último troço curto ($km km) — pode chegar hoje se avançar mais no dia anterior.';
  }

  @override
  String get prepareDepartureNow => 'Sair agora';

  @override
  String get replanNewDepartureTitle =>
      'A recalcular com o novo horário de partida…';

  @override
  String get planStopReorderHint => 'Mantém a alça para reordenar';

  @override
  String get planSwapOriginDestination => 'Inverter';

  @override
  String get planStopMoveUp => 'Mover para cima';

  @override
  String get planStopMoveDown => 'Mover para baixo';

  @override
  String get recentTripsTitle => 'Viagens recentes';

  @override
  String recentTripsSubtitle(int count) {
    return '$count guardadas — toca para reutilizar';
  }

  @override
  String recentTripsSeeAll(int n) {
    return 'Ver as $n outras viagens em As minhas viagens';
  }

  @override
  String get onRouteTitle => 'Na rota';

  @override
  String get onRouteEmpty => 'Toca para escolher opções';

  @override
  String get exportShareTitle => 'Partilhar rota';

  @override
  String get exportOpenInMaps => 'Abrir no Google Maps';

  @override
  String get exportOpenInMapsSub => 'With added stops and detours';

  @override
  String get exportCopyLink => 'Copiar ligação';

  @override
  String get exportLinkCopied => 'Ligação copiada para a área de transferência';

  @override
  String get exportShareOs => 'Partilhar…';

  @override
  String get exportShareSubject => 'A minha rota no MyTravelPal';

  @override
  String get importFromMaps => 'Importar de Maps';

  @override
  String get importFromMapsTitle => 'Importar rota do Google Maps';

  @override
  String get importFromMapsHint => 'Cola aqui a ligação do Google Maps';

  @override
  String get importFromMapsPaste => 'Colar';

  @override
  String get importFromMapsImport => 'Importar';

  @override
  String get importFromMapsError => 'URL não reconhecido';

  @override
  String get importFromMapsErrorMalformed =>
      'URL inválido — verifica a ligação e tenta novamente';

  @override
  String get importFromMapsErrorShortlink =>
      'Não foi possível expandir a ligação curta — abre-a no Maps e copia o URL completo';

  @override
  String get importFromMapsErrorGeocode =>
      'Não foi possível localizar os lugares — tenta uma rota mais curta ou escreve-os à mão';

  @override
  String get importFromMapsLoading => 'A analisar a ligação…';

  @override
  String adverseEventsBannerCount(int count) {
    return '$count alerta(s) na sua rota';
  }

  @override
  String pricePerMeal(String price) {
    return '$price €/refeição';
  }

  @override
  String kmFromOrigin(String km) {
    return '$km km desde a origem';
  }

  @override
  String get profileVehicleModel => 'Modelo';

  @override
  String get profileVehicleModelHint => 'Escolha o seu modelo';

  @override
  String get profileVehicleModelClear => 'Remover modelo';

  @override
  String get profileTankLevel => 'Depósito atual';

  @override
  String get vehiclePickerSearchHint => 'Procurar marca ou modelo';

  @override
  String get vehiclePickerEmpty => 'Nenhum modelo corresponde';

  @override
  String get vehiclePickerLoadError =>
      'Não foi possível carregar a lista. Tente novamente.';

  @override
  String get vehiclePickerCustomOption => 'Veículo personalizado';

  @override
  String get vehiclePickerCustomOptionSubtitle =>
      'Insira manualmente o depósito e o consumo';

  @override
  String get vehicleCustomTitle => 'Veículo personalizado';

  @override
  String get vehicleCustomName => 'Nome do veículo (opcional)';

  @override
  String get vehicleCustomNameHint => 'ex. Meu SUV';

  @override
  String get vehicleCustomTank => 'Depósito (L)';

  @override
  String get vehicleCustomTankEv => 'Bateria (kWh)';

  @override
  String get vehicleCustomConsumption => 'Consumo (L/100 km)';

  @override
  String get vehicleCustomConsumptionEv => 'Consumo (kWh/100 km)';

  @override
  String get vehicleCustomSave => 'Usar personalizado';

  @override
  String refuelWindowComfortable(String km) {
    return 'Abasteça até ao km $km (confortável)';
  }

  @override
  String refuelWindowCritical(String km) {
    return 'Abasteça até ao km $km (crítico)';
  }

  @override
  String get refuelSuggestionTitle => 'Abasteça aqui para poupar';

  @override
  String refuelSuggestionBody(String station, String km, String price) {
    return '$station · km $km · €$price/L';
  }

  @override
  String refuelSuggestionSavings(String eur) {
    return 'Poupa $eur €';
  }

  @override
  String savingsFuelRow(String eur) {
    return 'Combustível: $eur €';
  }

  @override
  String get garageTitle => 'A minha garagem';

  @override
  String get garageEmpty => 'Ainda sem veículos — adicione o primeiro';

  @override
  String get garageAdd => 'Adicionar veículo';

  @override
  String get garageEdit => 'Editar veículo';

  @override
  String get garageDelete => 'Eliminar';

  @override
  String get garageCancel => 'Cancelar';

  @override
  String get garageSave => 'Guardar';

  @override
  String get garageDefaultName => 'O meu carro';

  @override
  String get garageNameHint => 'Dê-lhe um nome (ex. O meu Golf)';

  @override
  String get garageDefaultTankLabel => 'Nível de depósito por defeito';

  @override
  String get garageDefaultChargeLevelLabel => 'Nível de carga inicial';

  @override
  String get garageAddError => 'Não foi possível guardar. Tente de novo.';

  @override
  String get garageDeleteTitle => 'Eliminar veículo?';

  @override
  String garageDeleteBody(String name) {
    return '\"$name\" será removido da sua garagem.';
  }

  @override
  String garageSettingsRow(int count) {
    return 'A minha garagem ($count)';
  }

  @override
  String planScreenGarageChip(String name, int pct) {
    return 'Carro: $name · $pct %';
  }

  @override
  String get planScreenGarageChooseVehicle =>
      'Escolha um veículo para esta viagem';

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
  String get resultFuelStationsOnRoute => 'Postos de combustível na rota';

  @override
  String get resultFuelSavingsAccordionTitle => 'Poupança de combustível';

  @override
  String get resultTimeSavingsOptimal => 'A sua hora de partida é ótima';

  @override
  String get hotelMapFullscreenTitle => 'Hotéis na área';

  @override
  String get restaurantMapFullscreenTitle => 'Restaurantes na área';

  @override
  String get tollSummaryTitle => 'Pedágios do trajeto';

  @override
  String get tollSummaryMapButton => 'Ver no mapa';

  @override
  String activitiesCtaTitle(Object city) {
    return 'O que fazer em $city';
  }

  @override
  String get activitiesCtaSubtitle => 'Atividades e experiências locais';

  @override
  String get planIncludeActivities => 'Atividades no destino';

  @override
  String get planIncludeActivitiesHint =>
      'Sugestões GetYourGuide em cada cidade';

  @override
  String get aiPrefScenicRoutes => 'Prefiro rotas panorâmicas';

  @override
  String get aiPrefScenicRoutesSub =>
      'Recomendar desvios por miradouros e serras';

  @override
  String get aiPrefEcoConscious => 'Condução eco';

  @override
  String get aiPrefEcoConsciousSub =>
      'Preferir veículos elétricos, evitar autoestradas quando possível';

  @override
  String get aiPrefLocalFood => 'Comida local primeiro';

  @override
  String get aiPrefLocalFoodSub =>
      'Priorizar restaurantes locais em vez de cadeias';

  @override
  String get aiPrefDepartureHour => 'Hora habitual de partida';

  @override
  String get aiPrefDietary => 'RESTRIÇÕES ALIMENTARES';

  @override
  String get aiPrefInterests => 'INTERESSES';

  @override
  String get aiDietVegetarian => 'Vegetariano';

  @override
  String get aiDietVegan => 'Vegano';

  @override
  String get aiDietGlutenFree => 'Sem glúten';

  @override
  String get aiDietHalal => 'Halal';

  @override
  String get aiInterestCulture => 'Cultura';

  @override
  String get aiInterestNature => 'Natureza';

  @override
  String get aiInterestGastronomy => 'Gastronomia';

  @override
  String get aiInterestShopping => 'Compras';

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
  String get wizardTollFreeDetour => 'Free detour';

  @override
  String get wizardTollMotorway => 'Motorway';

  @override
  String get wizardTollFaster => 'Faster';

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
      'Co-piloto IA · Recomenda alternativas a portagens, restaurantes segundo os seus gostos e combustível barato em tempo real · Premium';

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
  String get tripQualityExplainRoute =>
      'Mede se a rota tem geometria válida e se as paragens de descanso obrigatórias foram planeadas (regulamento UE: pausa a cada 4,5h).';

  @override
  String get tripQualityExplainFuel =>
      'Indica se há preços de combustível disponíveis na sua rota e se adicionou o posto ótimo.';

  @override
  String get tripQualityExplainHotels =>
      'Avalia se há hotéis disponíveis para as noites da viagem e se selecionou onde dormir.';

  @override
  String get tripQualityExplainWeather =>
      'Analisa as condições meteorológicas ao longo da rota. Verde = favorável. Amarelo = chuva ou nevoeiro. Vermelho = tempestade ou neve.';

  @override
  String get tripQualityExplainAlerts =>
      'Conta os eventos adversos ativos na ou perto da sua rota: incêndios, tempestades, terramotos, encerramentos de estradas.';

  @override
  String get tripQualityExplainTolls =>
      'Avalia se há dados de portagens disponíveis e se pode otimizar quais portagens pagar ou ignorar.';

  @override
  String get tripQualityFactorTollTime => 'Extra time';

  @override
  String get tripQualityExplainTollTime =>
      'Compares the money you save by skipping tolls with the extra time they add. It drops when you lose a lot of time for little money: under 25 EUR saved per extra hour.';

  @override
  String get tripQualityExplainStops =>
      'Mede se planeou as paragens de refeição e descanso. Para o ritmo \'saveur\' ou com crianças/animais, as paragens são importantes.';

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
    return 'Cap: ${n}h';
  }

  @override
  String tripDayBarsUnselected(int n) {
    return '$n stop(s) not added';
  }

  @override
  String get tripDayBarsHint => 'Tap + to include them in total duration';

  @override
  String get tripDayBarsCapLabel => 'Cap';

  @override
  String get tripDayBarsTitle => 'Distribuição por etapas';

  @override
  String get wizardStepProfile => 'Perfil';

  @override
  String get wizardStepVehicle => 'Veículo';

  @override
  String get wizardStepRhythm => 'Ritmo';

  @override
  String get wizardStepBudget => 'Budget';

  @override
  String wizardModelsAvailable(int count) {
    return '$count modelos disponíveis';
  }

  @override
  String wizardModelsMore(int count) {
    return '+$count — pesquisar por nome';
  }

  @override
  String get wizardTollSavingsDemo => 'Poupa €8';

  @override
  String companionNotifFuelBody(int km) {
    return 'A $km km · Toque em \"Desvio\" para adicionar à sua rota';
  }

  @override
  String get companionDemoNotifFuel => 'A 3 km · Desvie no Maps para abastecer';

  @override
  String get companionDemoNotifRoute =>
      'A 18 km na sua rota · Considere a N-II · Desvio no Maps';

  @override
  String get companionDemoNotifMeal =>
      'Menu €12 · A 4 km · Paramos para comer? Desvio no Maps';

  @override
  String get companionDemoNotifEta => 'ETA em 10 min · 12 km · Sem incidentes';

  @override
  String get companionOffRouteTitle => 'Fora da rota?';

  @override
  String get companionOffRouteBody =>
      'A sua posição está longe da rota planeada. No modo livre o assistente fica consigo sem calcular km.';

  @override
  String get companionOffRouteBack => 'Voltar à rota';

  @override
  String get companionFreeModeBtn => 'Modo livre';

  @override
  String companionGroupSessionError(String error) {
    return 'Não foi possível criar a sessão de grupo: $error';
  }

  @override
  String get companionMealStopTitle => 'Alterar paragem de refeição';

  @override
  String get companionMealStopDelayBody =>
      'Quer atrasar a paragem de refeição? Moveremos para a próxima área de serviço.';

  @override
  String get settingsLogoutStep3 => '3/4 · A fechar sessão…';

  @override
  String get settingsLogoutStep4 => '4/4 · A voltar ao início…';

  @override
  String get settingsNickTaken => 'Já em uso';

  @override
  String get settingsNickHelper =>
      'O seu nome no ranking de rotas. Escolha um nick e o seu país — apenas visível no Hall of Fame.';

  @override
  String get settingsNickEmpty => 'Sem nick ainda';

  @override
  String get settingsCountrySearch => 'Pesquisar país...';

  @override
  String get settingsPremiumDevNote => 'Será ativado por compra em produção';

  @override
  String get settingsTierFeaturesPremium =>
      '✓ Companion IA · Portagens otimizadas · Android Auto · Grupos · Monitor de viagem';

  @override
  String get settingsTierFeaturesEssential =>
      '✓ Postos ótimos · Portagens básicas · Alertas adversos · Radares';

  @override
  String get settingsTierFeaturesFree =>
      'Apenas planeamento básico · Sem otimização de combustível nem portagens';

  @override
  String resultStationAdded(String name) {
    return '$name adicionada · estimativa do depósito atualizada para os dias seguintes';
  }

  @override
  String get resultRestStopFallback => 'Área de descanso';

  @override
  String get resultTooltipProfile => 'Perfil e veículo';

  @override
  String get resultRecalculating => 'Recalculando com as novas configurações…';

  @override
  String resultPlanReady(int km, int h, int m) {
    return 'Plano pronto · $km km · ${h}h ${m}m';
  }

  @override
  String get resultGenericConsumptionHint =>
      'Cálculo com consumo genérico. Configure o seu veículo para maior precisão.';

  @override
  String resultFuelSavingsPct(int pct) {
    return '$pct% do custo';
  }

  @override
  String get resultChartAdded => '  adicionado';

  @override
  String get resultSettingsChangedBody =>
      'As suas configurações mudaram. Recalcular com os novos valores?';

  @override
  String resultSummaryStops(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paragens',
      one: '$count paragem',
    );
    return '$_temp0';
  }

  @override
  String resultFuelStationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fuel stations',
      one: '$count fuel station',
    );
    return '$_temp0';
  }

  @override
  String resultSummaryTolls(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count portagens ignoradas',
      one: '$count portagem ignorada',
    );
    return '$_temp0';
  }

  @override
  String resultSummaryHotels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hotéis',
      one: '$count hotel',
    );
    return '$_temp0';
  }

  @override
  String get resultGyGError => 'Não foi possível abrir GetYourGuide';

  @override
  String resultGyGActivities(String city) {
    return 'Ver atividades em $city';
  }

  @override
  String get suggestEntryTitle => 'AI suggestions';

  @override
  String get suggestEntrySubtitle =>
      'Real stops near your route that fit your free time';

  @override
  String get suggestSheetTitle => 'Stops for your route';

  @override
  String get suggestWholeTrip => 'Whole trip';

  @override
  String suggestDay(int day) {
    return 'Day $day';
  }

  @override
  String get suggestFreeTime => 'Free time for stops';

  @override
  String get suggestInterests => 'What you like';

  @override
  String get suggestFind => 'Find stops';

  @override
  String get suggestSearching => 'Looking for places near your route…';

  @override
  String suggestMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String suggestCost(int detour, int visit) {
    return 'Detour $detour min · visit $visit min';
  }

  @override
  String get suggestFits => 'Fits your free time';

  @override
  String get suggestTooLong => 'Does not fit your free time';

  @override
  String get suggestAdd => 'Add';

  @override
  String get suggestAdded => 'Added';

  @override
  String get suggestNoAiNote =>
      'AI is not available right now. Showing the most notable places, without an explanation.';

  @override
  String get suggestNoPlaces => 'No places of interest near this stretch.';

  @override
  String get suggestError => 'Could not load suggestions. Please try again.';

  @override
  String get suggestQuota =>
      'You have reached the daily suggestion limit. Come back tomorrow.';

  @override
  String suggestAddedSnack(String name) {
    return '$name added to the route';
  }

  @override
  String suggestUsed(int used, int window) {
    return 'Uses $used of $window free min';
  }
}
