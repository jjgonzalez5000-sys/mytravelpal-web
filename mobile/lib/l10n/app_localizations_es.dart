// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'MyTravelPal';

  @override
  String get appTagline => 'Planifica el viaje, no solo el destino';

  @override
  String get onboardEyebrowKiller => 'LA FUNCIÓN QUE FALTABA';

  @override
  String get onboardTitleKiller => 'Sal a la hora justa';

  @override
  String get onboardBodyKiller =>
      'Analizamos el tráfico histórico alrededor de tu hora deseada y te enseñamos la ventana óptima — a veces salir 30 minutos antes te ahorra 90.';

  @override
  String get onboardEyebrowHonest => 'PLANIFICACIÓN HONESTA';

  @override
  String get onboardTitleHonest => 'Todos los costes, por adelantado';

  @override
  String get onboardBodyHonest =>
      'Totales de peajes, gasolina y carga eléctrica más baratas en tu ruta, paradas sugeridas y hoteles o restaurantes al detour que te puedas permitir.';

  @override
  String get onboardEyebrowAlerts => 'MANTENTE INFORMADO';

  @override
  String get onboardTitleAlerts => 'Alertas que importan';

  @override
  String get onboardBodyAlerts =>
      'Incendios, huelgas, mal tiempo, obras — tú decides cuándo aparecen, y solo cuando afectan a tu ruta.';

  @override
  String get onboardSkip => 'Saltar';

  @override
  String get onboardContinue => 'Continuar';

  @override
  String get onboardGetStarted => 'Comenzar';

  @override
  String get onboardFooter =>
      'Empezar gratis · Premium desbloquea el resumen IA del viaje';

  @override
  String get loginContinueApple => 'Continuar con Apple';

  @override
  String get loginContinueGoogle => 'Continuar con Google';

  @override
  String get loginContinueFacebook => 'Continuar con Facebook';

  @override
  String get loginContinueDemo => 'Continuar como demo';

  @override
  String get loginDivider => 'o';

  @override
  String get loginTerms =>
      'Al continuar aceptas nuestros términos y política de privacidad.';

  @override
  String get loginBusy => 'Iniciando sesión…';

  @override
  String get planTitle => 'Planifica un viaje';

  @override
  String get planEyebrow => 'EL PLANIFICADOR';

  @override
  String get planHero => '¿A dónde vamos\nhoy?';

  @override
  String planHeroPersonal(String name) {
    return 'Hola $name, ¿a dónde vamos?';
  }

  @override
  String get planIntro =>
      'Elige dos puntos y una hora. Del resto nos ocupamos nosotros.';

  @override
  String get planFrom => 'Desde';

  @override
  String get planTo => 'Hasta';

  @override
  String get planDesiredDeparture => 'Hora deseada de salida';

  @override
  String get planCta => 'Planificar viaje';

  @override
  String get planCtaBusy => 'Planificando tu viaje…';

  @override
  String get planCountriesNote =>
      'Los países se detectan automáticamente desde tu ruta.';

  @override
  String get planSectionOptional => 'En la ruta';

  @override
  String get planOverrideForTrip => 'Sobrescribir para este viaje';

  @override
  String get planOverrideActive => 'Sobrescribiendo para este viaje';

  @override
  String get planOverrideClear => 'Quitar';

  @override
  String get planTooltipDashboard => 'Panel';

  @override
  String get planTooltipReport => 'Reportar un evento';

  @override
  String get planTooltipSaved => 'Viajes guardados';

  @override
  String get planErrorPickEndpoints => 'Elige un origen y un destino.';

  @override
  String get resultBestTimeToLeave => 'MEJOR HORA PARA SALIR';

  @override
  String get resultTripSavings => 'TUS AHORROS EN ESTE VIAJE';

  @override
  String get resultTimeSavedLabel => 'tiempo ahorrado';

  @override
  String get resultExtraTimeLabel => 'tiempo extra';

  @override
  String get resultMoneySavedLabel => 'dinero ahorrado';

  @override
  String get resultDepartureWindowTitle => 'Ventana de salida';

  @override
  String get resultDepartureWindowDesc =>
      'Minutos totales en cada hora candidata de salida.';

  @override
  String get resultCompareVariantsTitle => 'Compara tus opciones';

  @override
  String get resultCompareVariantsEyebrow => 'Variantes de ruta';

  @override
  String get resultAlertsTitle => 'Alertas en tu ruta';

  @override
  String get resultRestStopsTitle => 'Paradas de descanso';

  @override
  String get resultHotelsTitle => 'Hoteles';

  @override
  String get resultRestaurantsTitle => 'Restaurantes';

  @override
  String get resultFuelTitle => 'Combustible';

  @override
  String get resultTollAlternativeEyebrow => 'ALTERNATIVA SIN PEAJES';

  @override
  String get resultTollAlternativeWorthIt => 'Merece la pena';

  @override
  String get resultTollAlternativeMarginal => 'Marginal';

  @override
  String get resultShareTooltip => 'Compartir este viaje';

  @override
  String get resultExplainTooltip => 'Explícame el viaje (Premium)';

  @override
  String get resultSaveTooltip => 'Guardar viaje';

  @override
  String get resultSavedTooltip => 'Guardado';

  @override
  String get resultTripSaved => 'Viaje guardado';

  @override
  String get dashboardTitle => 'Panel';

  @override
  String dashboardGreeting(String name) {
    return 'Hola, $name';
  }

  @override
  String get dashboardTravelSoFar => 'Tus viajes hasta ahora';

  @override
  String get dashboardTrips => 'Viajes';

  @override
  String get dashboardDistance => 'Distancia';

  @override
  String get dashboardHours => 'Horas';

  @override
  String get dashboardTimeSaved => 'TIEMPO AHORRADO';

  @override
  String get dashboardMoneySaved => 'DINERO AHORRADO';

  @override
  String get dashboardFuelBudget => 'PRESUPUESTO DE COMBUSTIBLE';

  @override
  String get dashboardTopSavers => 'Mejores ahorros';

  @override
  String get dashboardCountries => 'Países';

  @override
  String get dashboardSignOut => 'Cerrar sesión';

  @override
  String get profileTitle => 'Perfil del viaje';

  @override
  String get profileOverrideTitle => 'Sobrescribir para este viaje';

  @override
  String get profileSave => 'Guardar';

  @override
  String get profileUse => 'Usar';

  @override
  String get profileWhoTravelling => 'Quién viaja';

  @override
  String get profileTravellers => 'Viajeros';

  @override
  String get profileHasKids => 'Viajando con niños';

  @override
  String get profileHasPets => 'Viajando con mascotas';

  @override
  String get profileVehicle => 'Vehículo';

  @override
  String get profileMealTimes => 'Horario de comidas';

  @override
  String get profileReminders => 'Recordatorios';

  @override
  String get profilePremiumSection => 'Premium (demo)';

  @override
  String get profileClearProfile => 'Borrar perfil';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonClear => 'Borrar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonRemove => 'Quitar';

  @override
  String get searchPlaceholderLegacy => 'Buscar una ciudad…';

  @override
  String get searchNoMatches => 'Sin resultados.';

  @override
  String get searchStartTyping => 'Escribe al menos 2 caracteres.';

  @override
  String get searchRecent => 'RECIENTES';

  @override
  String get searchUseMyLocation => 'Usar mi ubicación';

  @override
  String get locationServiceOff =>
      'La ubicación está desactivada en este dispositivo.';

  @override
  String get locationPermissionDenied => 'Permiso de ubicación denegado.';

  @override
  String get locationUnavailable => 'No pudimos determinar tu ubicación.';

  @override
  String get favoritesTitle => 'Favoritos';

  @override
  String get favoritesEmptyHotels =>
      'Aún no tienes hoteles favoritos. Toca la estrella en cualquier hotel para guardarlo.';

  @override
  String get favoritesEmptyRestaurants =>
      'Aún no tienes restaurantes favoritos. Toca la estrella en cualquier restaurante para guardarlo.';

  @override
  String get favoritesTabHotels => 'Hoteles';

  @override
  String get favoritesTabRestaurants => 'Restaurantes';

  @override
  String get favoritesTooltipAdd => 'Añadir a favoritos';

  @override
  String get favoritesTooltipRemove => 'Quitar de favoritos';

  @override
  String get planTooltipFavorites => 'Favoritos';

  @override
  String get resultBackToPlan => 'Volver al plan';

  @override
  String get alertsAlongYourRoute => 'Alertas en tu ruta';

  @override
  String get alertsAlongYourRouteDesc =>
      'Incendios, huelgas, mal tiempo, obras, accidentes, inundaciones, nieve, protestas — ordenadas por severidad.';

  @override
  String get restStopsHint =>
      'Recomendadas cada 2 h de conducción. Los descansos cortos te mantienen despierto en trayectos largos.';

  @override
  String get fuelAlongTheRoute => 'Combustible en la ruta';

  @override
  String get hotelsNearYourRoute => 'Hoteles cerca de tu ruta';

  @override
  String get restaurantsNearYourRoute => 'Restaurantes cerca de tu ruta';

  @override
  String get narrativeTitle => 'Resumen del viaje';

  @override
  String get narrativeGenerating => 'Escribiendo tu resumen…';

  @override
  String get narrativeFailed =>
      'No pudimos generar el resumen. Vuelve a intentarlo en un momento.';

  @override
  String get narrativeFooter =>
      'Generado por Claude — puede no reflejar cambios en tiempo real.';

  @override
  String get narrativePremiumBadge => 'Premium';

  @override
  String get shareTripSubject => 'Mi viaje con MyTravelPal';

  @override
  String get shareTitle => 'MyTravelPal — plan de viaje';

  @override
  String shareRouteLine(String km, String hours, String tolls) {
    return '$km km · $hours h flujo libre · peajes $tolls €';
  }

  @override
  String shareBestTime(String when, String minutes) {
    return 'Mejor hora para salir: $when ($minutes min totales)';
  }

  @override
  String shareTollFreeAlt(String savings, String minutes) {
    return 'Alternativa sin peajes: ahorra $savings € por +$minutes min';
  }

  @override
  String shareRefuelHint(
      String cheap, String price, String pricey, String savings) {
    return 'Reposta en $cheap (~$price€/L) antes de $pricey — ahorra ~$savings€/depósito';
  }

  @override
  String get shareHotelsHeader => 'Mejores hoteles considerados:';

  @override
  String get shareRestaurantsHeader => 'Mejores restaurantes considerados:';

  @override
  String shareHotelLine(String name, String price, String km) {
    return '$name — $price €/noche · $km km de la ruta';
  }

  @override
  String shareRestaurantLine(String name, String price, String km) {
    return '$name — $price €/comida · $km km de la ruta';
  }

  @override
  String get shareOpenInApp => 'Ábrelo en MyTravelPal:';

  @override
  String get eventReport => 'Reportar un evento';

  @override
  String get eventDescription => 'Descripción';

  @override
  String get eventType => 'Tipo';

  @override
  String get eventSeverity => 'Severidad';

  @override
  String get eventLocation => 'Ubicación';

  @override
  String get eventSubmit => 'Enviar';

  @override
  String get eventSubmitted => 'Reportado.';

  @override
  String get resultStatDistance => 'Distancia';

  @override
  String get resultStatFreeFlow => 'Sin tráfico';

  @override
  String get resultStatTolls => 'Peajes';

  @override
  String get resultEyebrowNearRoute => 'Cerca de tu ruta';

  @override
  String get resultEyebrowAlongRoute => 'En la ruta';

  @override
  String get resultAlerts => 'Alertas';

  @override
  String get resultRestStops => 'Paradas recomendadas';

  @override
  String get resultHotels => 'Hoteles';

  @override
  String get resultRestaurants => 'Restaurantes';

  @override
  String get resultFuel => 'Combustible';

  @override
  String get resultOptimized => 'Optimizado para tu viaje';

  @override
  String get resultOptimizedFuelBudget => 'Presupuesto estimado de combustible';

  @override
  String get resultCompareTitle => 'Compara tus opciones';

  @override
  String get resultCompareStraightApprox => 'Aprox. línea recta.';

  @override
  String resultSleepAt(String when) {
    return 'Dormir · $when';
  }

  @override
  String get resultHourlyTollEyebrow => 'VEREDICTO DE PEAJES POR HORA';

  @override
  String get resultSkipLabel => 'Saltar';

  @override
  String get resultKeepLabel => 'Mantener';

  @override
  String get resultSaveExactly => 'Ahorra ';

  @override
  String get notificationsLeaveSoonTitle => 'Toca salir pronto';

  @override
  String get localeSystem => 'Sistema';

  @override
  String get localeMenuTooltip => 'Idioma';

  @override
  String get dashboardCountry => 'País';

  @override
  String get dashboardNoTripsYet =>
      'Aún no hay viajes guardados. Planifica y guarda uno para ver estadísticas.';

  @override
  String get dashboardStatCards => 'RESUMEN';

  @override
  String get profileVehicleType => 'Tipo de vehículo';

  @override
  String get profileFuelType => 'Tipo de combustible';

  @override
  String get profileConsumption => 'Consumo';

  @override
  String get profileEvRange => 'Autonomía eléctrica';

  @override
  String get profileFuelTank => 'Depósito';

  @override
  String get profileBreakfast => 'Desayuno';

  @override
  String get profileLunch => 'Comida';

  @override
  String get profileDinner => 'Cena';

  @override
  String get profileStopMinutes => 'Duración típica de parada';

  @override
  String get profileReminderMinutes => 'Aviso antes de salir';

  @override
  String get profilePremiumHint =>
      'Activa para previsualizar funciones Premium en local.';

  @override
  String get profileNoProfile => 'Aún no has guardado ningún perfil.';

  @override
  String get eventPlaceholderDescription =>
      'Breve descripción de lo que has visto';

  @override
  String get eventCurrentLocation => 'Ubicación actual';

  @override
  String get eventPickOnMap => 'Elegir en el mapa';

  @override
  String eventLocationCoords(String lat, String lon) {
    return 'Seleccionado: $lat, $lon';
  }

  @override
  String get narrativeRegenerate => 'Regenerar';

  @override
  String get narrativeUpgrade => 'Desbloquea el resumen IA con Premium.';

  @override
  String get compareVariantsRecommended => 'Recomendado';

  @override
  String get compareVariantsFastest => 'Más rápido';

  @override
  String get compareVariantsCheapest => 'Más barato';

  @override
  String get compareVariantsScenic => 'Paisajístico';

  @override
  String get compareVariantsAvoidTolls => 'Sin peajes';

  @override
  String get compareVariantsAvoidMotorways => 'Sin autopistas';

  @override
  String get hourlyBestHours => 'Mejores horas para saltar peajes';

  @override
  String get hourlyWorstHours => 'Peores horas para saltar peajes';

  @override
  String get partialTollSkipsTitle => 'Peaje a peaje';

  @override
  String get partialTollSkipsEyebrow => 'Detalle';

  @override
  String get sleepEyebrow => 'PARA DORMIR';

  @override
  String get sleepNoHotelSuggestion =>
      'Ningún hotel elegido — mira la sección de Hoteles.';

  @override
  String get lunchEyebrow => 'PARADA DE COMIDA';

  @override
  String get dinnerEyebrow => 'PARADA DE CENA';

  @override
  String get breakfastEyebrow => 'PARADA DE DESAYUNO';

  @override
  String get resultCompareEyebrow => 'Variantes de ruta';

  @override
  String get resultCompareDescription =>
      'Mismo origen y destino — prioridades distintas. Los tiempos son sin tráfico.';

  @override
  String get resultVariantDashed => 'Discontinua en el mapa de arriba';

  @override
  String get resultOptimizedEyebrow => 'Según tu perfil';

  @override
  String get resultOptimizedDescription =>
      'Comidas, dormir y combustible que encajan con tu perfil.';

  @override
  String get resultSavingsShiftAndSkip =>
      'Cambiando la hora de salida y saltando peajes.';

  @override
  String get resultSavingsShift =>
      'Cambiando la salida a la ventana recomendada.';

  @override
  String get resultSavingsSkip => 'Cogiendo la alternativa sin peajes.';

  @override
  String get resultSavingsNone =>
      'Sin ahorros identificados para esta ruta todavía.';

  @override
  String get resultShift => 'CAMBIO';

  @override
  String get resultTraffic => 'TRÁFICO';

  @override
  String get resultTotal => 'TOTAL';

  @override
  String resultRestStopNoRestaurant(String km) {
    return 'Parada en el km $km — sin restaurante compatible.';
  }

  @override
  String resultNoHotelHere(String km) {
    return 'Buena parada aquí (~$km km). Sin hotel compatible.';
  }

  @override
  String get resultMealFallback => 'Comida';

  @override
  String get resultHourlyExplainer =>
      'Común en Francia e Italia: salir antes de un peaje caro, coger una carretera paralela un tramo y volver a entrar — suele añadir 15-40 min pero ahorra 5-15 €.';

  @override
  String get profileSaved => 'Perfil guardado';

  @override
  String get profileWhoEyebrow => 'Personas';

  @override
  String get profileKidsSubtitle =>
      'Prioriza restaurantes y hoteles amigables con niños.';

  @override
  String get profilePetsSubtitle =>
      'Prioriza lugares que admiten mascotas y con aparcamiento.';

  @override
  String get profileVehicleEyebrow => 'Para coste y aparcamiento';

  @override
  String get profileMealsEyebrow => 'Para casar con paradas de restaurante';

  @override
  String get profileRemindersEyebrow => 'Notificaciones locales';

  @override
  String get profileNotifyBefore => 'Avisar antes de la salida';

  @override
  String get profileNotifyOff => 'Desactivado — no se programará recordatorio.';

  @override
  String profileNotifyMinutesBefore(int minutes) {
    return '$minutes minutos antes';
  }

  @override
  String get profilePremiumEyebrow => 'Toggle local · sin pago real';

  @override
  String get profilePremiumBody =>
      'El gating real con StoreKit / Play Billing viene después. De momento este toggle activa Premium en local para que puedas previsualizar esas funciones.';

  @override
  String get profileSimulatePremium => 'Simular Premium';

  @override
  String get profileSimulatePremiumSubtitle =>
      'Desbloquea el resumen IA y el análisis de peajes por hora.';

  @override
  String get profileOverrideHeroDesc =>
      'Cambia tu perfil solo para este viaje — otro vehículo, otros viajeros u otras horas de comida sin tocar tu perfil guardado.';

  @override
  String get profileGlobalHeroDesc =>
      'Configúralo una vez. Cada plan lo usa para ordenar hoteles y restaurantes, estimar combustible y ajustar las paradas de comida.';

  @override
  String get eventPickPlace => 'Elige un lugar y describe lo que has visto.';

  @override
  String get eventThankYou => 'Reporte enviado — ¡gracias!';

  @override
  String eventCouldNotSubmit(String reason) {
    return 'No se pudo enviar: $reason';
  }

  @override
  String get eventIntro =>
      'Ayuda a otros conductores a saber lo que has visto. Los reportes expiran a las 24 horas por defecto.';

  @override
  String get eventWhatHappened => 'Qué ha pasado';

  @override
  String get eventWhatHappenedEyebrow => 'Tipo';

  @override
  String get eventSeverityInfo => 'Información';

  @override
  String get eventSeverityWarning => 'Aviso';

  @override
  String get eventSeverityCritical => 'Crítica';

  @override
  String get eventWhere => 'Dónde';

  @override
  String get eventWhereEyebrow => 'Ciudad más cercana';

  @override
  String get eventDescribeTitle => 'Descríbelo';

  @override
  String get eventDescribeEyebrow => 'Corto y útil';

  @override
  String get eventDescribeHint =>
      'p.ej. Árboles caídos en A6 sur, 2 carriles cortados';

  @override
  String get eventSubmitting => 'Enviando…';

  @override
  String get eventSubmitReport => 'Enviar reporte';

  @override
  String get narrativeBusy => 'Componiendo tu resumen de viaje…';

  @override
  String get narrativeErrorTitle => 'No pudimos obtener el resumen';

  @override
  String narrativeGeneratedAt(String when) {
    return 'Generado $when';
  }

  @override
  String get narrativeReadAloud => 'Leer en voz alta';

  @override
  String get narrativeStop => 'Parar';

  @override
  String get historyTitle => 'Viajes guardados';

  @override
  String get historyEmptyTitle => 'Aún no hay viajes guardados';

  @override
  String get historyEmptyBody =>
      'Planifica un viaje y toca el marcador para guardarlo aquí.';

  @override
  String get historyPlanCta => 'Planificar un viaje';

  @override
  String historyDeleted(String trip) {
    return 'Borrado $trip';
  }

  @override
  String historyReplanFailed(int status) {
    return 'Falló el replan: $status';
  }

  @override
  String get historyDeleteTooltip => 'Borrar';

  @override
  String get historyReopenCta => 'Ver plan';

  @override
  String get historyRepeatCta => 'Repetir';

  @override
  String resultFuelCollapsedHint(int count) {
    return 'Mostrar las $count gasolineras de la ruta';
  }

  @override
  String resultBestTimeVsFreeFlow(String delta) {
    return '$delta min vs flujo libre';
  }

  @override
  String resultBestTimeEarlier(int minutes) {
    return '$minutes min antes de tu hora deseada';
  }

  @override
  String resultBestTimeLater(int minutes) {
    return '$minutes min después de tu hora deseada';
  }

  @override
  String resultHeroSavedBadge(String magnitude) {
    return '$magnitude ahorrados';
  }

  @override
  String get consistencyNeedsReview => 'Revisa tu plan de viaje';

  @override
  String consistencyNeedsReviewErrors(int errors) {
    return 'Revisa tu plan de viaje · $errors errores';
  }

  @override
  String consistencyNeedsReviewMixed(int errors, int warnings) {
    return 'Revisa tu plan de viaje · $errors error(es), $warnings aviso(s)';
  }

  @override
  String get consistencyHeadsUp => 'Aviso sobre tu plan de viaje';

  @override
  String consistencyHeadsUpWarnings(int warnings) {
    return 'Aviso sobre tu plan de viaje · $warnings avisos';
  }

  @override
  String consistencyMoreCount(int count) {
    return '+$count más';
  }

  @override
  String get planProfileClearOverride => 'Deshacer ajuste';

  @override
  String get weatherSunny => 'Soleado';

  @override
  String get weatherPartlyCloudy => 'Parcialmente nublado';

  @override
  String get weatherCloudy => 'Nublado';

  @override
  String get weatherFog => 'Niebla';

  @override
  String get weatherDrizzle => 'Llovizna';

  @override
  String get weatherRain => 'Lluvia';

  @override
  String get weatherHeavyRain => 'Lluvia intensa';

  @override
  String get weatherSnow => 'Nieve';

  @override
  String get weatherHeavySnow => 'Nevada intensa';

  @override
  String get weatherThunderstorm => 'Tormenta';

  @override
  String historyBestAt(String when) {
    return 'Óptima $when';
  }

  @override
  String historyWantedAt(String when) {
    return 'Deseada $when';
  }

  @override
  String get searchPlaceholder => 'Buscar una ciudad, museo, lugar…';

  @override
  String get placesSectionTitle => 'LUGARES GUARDADOS';

  @override
  String get placeSaveAsTooltip => 'Guardar como lugar';

  @override
  String get placeSaveDialogTitle => 'Guardar como…';

  @override
  String get placeCustomLabel => 'Etiqueta';

  @override
  String get placeCustomHint => 'Casa, trabajo, abuela…';

  @override
  String get placePresetHome => 'Casa';

  @override
  String get placePresetWork => 'Trabajo';

  @override
  String get placePresetSchool => 'Colegio';

  @override
  String get placePresetGym => 'Gimnasio';

  @override
  String placeSavedAs(String label) {
    return 'Guardado como $label';
  }

  @override
  String get favoritesTabPlaces => 'Lugares';

  @override
  String get favoritesEmptyPlaces =>
      'Aún no hay lugares guardados. Toca la estrella en cualquier resultado de búsqueda para guardarlo.';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsSectionAppearance => 'Apariencia';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsSectionUnits => 'Unidades';

  @override
  String get settingsUnitSystem => 'Sistema de unidades';

  @override
  String get settingsUnitsMetric => 'Métrico';

  @override
  String get settingsUnitsImperial => 'Imperial';

  @override
  String get settingsSectionTrip => 'Viaje';

  @override
  String get settingsSectionAbout => 'Acerca de';

  @override
  String get settingsVersion => 'Versión';

  @override
  String get planTooltipSettings => 'Ajustes';

  @override
  String get styleSectionTitle => 'Estilo de viaje';

  @override
  String get styleSectionEyebrow => 'Cómo te gusta conducir';

  @override
  String get stylePresetDirect => 'Directo';

  @override
  String get stylePresetBalanced => 'Equilibrado';

  @override
  String get stylePresetSlow => 'Tranquilo';

  @override
  String get stylePresetDirectHint =>
      'Del tirón, paradas mínimas, sin dormir por el camino.';

  @override
  String get stylePresetBalancedHint =>
      'Ritmo natural, descansos cuando tenga sentido.';

  @override
  String get stylePresetSlowHint =>
      'Disfruta la conducción, paradas generosas, divide trayectos largos.';

  @override
  String get styleCustom => 'Personalizado';

  @override
  String get styleAdvanced => 'Avanzado';

  @override
  String get stylePaceLabel => 'Ritmo';

  @override
  String get stylePacePush => 'Del tirón';

  @override
  String get stylePaceSteady => 'Normal';

  @override
  String get stylePaceSavour => 'Con calma';

  @override
  String get styleOvernightLabel => 'Paradas para dormir';

  @override
  String get styleOvernightNever => 'Nunca';

  @override
  String get styleOvernightIfNeeded => 'Si hace falta';

  @override
  String get styleOvernightAlwaysIfLong => 'Dividir trayectos largos';

  @override
  String get styleDailyCapLabel => 'Máx. horas al volante por día';

  @override
  String get styleBedtimeLabel => 'Hora de dormir';

  @override
  String get styleWakeLabel => 'Hora de despertarse';

  @override
  String get styleBreakLabel => 'Estilo de parada';

  @override
  String get styleBreakMinimal => 'Mínimo';

  @override
  String get styleBreakScenic => 'Paisajístico';

  @override
  String get styleBreakFoodie => 'Gastronómico';

  @override
  String planStyleChip(String preset, int hours) {
    return '$preset · ${hours}h/día';
  }

  @override
  String planStyleChipCustom(int hours) {
    return 'Personalizado · ${hours}h/día';
  }

  @override
  String get planStyleOverrideTitle => 'Estilo para este viaje';

  @override
  String get planStyleOverrideSubtitle =>
      'Sobrescribe tu perfil guardado solo para este plan.';

  @override
  String get planStyleUseSavedProfile => 'Usar mi perfil guardado';

  @override
  String arrivalHintTitle(String hour) {
    return 'Llegarías a las $hour:00';
  }

  @override
  String arrivalHintBody(String bedtime) {
    return 'Más tarde que tu hora de dormir ($bedtime:00). Considera parar a dormir — los hoteles están abajo.';
  }

  @override
  String get arrivalHintCta => 'Ver hoteles';

  @override
  String get vehicleTypeCar => 'Coche';

  @override
  String get vehicleTypeMotorbike => 'Moto';

  @override
  String get vehicleTypeVan => 'Furgoneta';

  @override
  String get vehicleTypeCamper => 'Autocaravana';

  @override
  String get fuelTypePetrol => 'Gasolina';

  @override
  String get fuelTypeDiesel => 'Diésel';

  @override
  String get fuelTypeHybrid => 'Híbrido';

  @override
  String get fuelTypeElectric => 'Eléctrico';

  @override
  String get fuelTypeLpg => 'GLP';

  @override
  String get routeVariantFastest => 'Más rápida';

  @override
  String get routeVariantTollFree => 'Sin peajes';

  @override
  String get routeVariantScenic => 'Escénica';

  @override
  String get eventTypeFire => 'Incendio';

  @override
  String get eventTypeStrike => 'Huelga';

  @override
  String get eventTypeWeather => 'Meteorología adversa';

  @override
  String get eventTypeAccident => 'Accidente';

  @override
  String get eventTypeRoadwork => 'Obras';

  @override
  String get eventTypeFlood => 'Inundación';

  @override
  String get eventTypeSnow => 'Nieve';

  @override
  String get eventTypeProtest => 'Manifestación';

  @override
  String get eventTypeEarthquake => 'Terremoto';

  @override
  String get eventTypeLandslide => 'Deslizamiento';

  @override
  String get eventTypeAvalanche => 'Avalancha';

  @override
  String get eventTypeClosure => 'Vía cortada';

  @override
  String get eventTypeHeatwave => 'Ola de calor';

  @override
  String get eventTypeOther => 'Otros';

  @override
  String tollStretchLabel(int index, int total) {
    return 'Tramo con peaje $index / $total';
  }

  @override
  String tollBoothLabel(int index) {
    return 'Peaje $index';
  }

  @override
  String get addToRouteTooltip => 'Añadir a la ruta';

  @override
  String get removeFromRouteTooltip => 'Quitar de la ruta';

  @override
  String addedStopsChip(int count, String minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paradas añadidas · +$minutes min',
      one: '1 parada añadida · +$minutes min',
    );
    return '$_temp0';
  }

  @override
  String get addedStopsClear => 'Limpiar';

  @override
  String get settingsLicensesAndData => 'Licencias y fuentes de datos';

  @override
  String get settingsLicensesAndDataSub =>
      'Atribución de datos abiertos y librerías';

  @override
  String get attributionsTitle => 'Licencias y datos';

  @override
  String get attributionsIntro =>
      'MyTravelPal se apoya en fuentes de datos abiertas y librerías open-source. Esta pantalla acredita cada fuente, enlaza con sus licencias y cubre nuestras obligaciones legales de atribución.';

  @override
  String get attributionsSectionMap => 'Mapa y geodatos';

  @override
  String get attributionsSectionFuel => 'Precios de combustible';

  @override
  String get attributionsSectionHazards => 'Eventos adversos';

  @override
  String get attributionsSectionWeather => 'Meteorología';

  @override
  String get attributionsSectionSoftware => 'Librerías de software';

  @override
  String get attributionsShowLicenses => 'Ver licencias de paquetes';

  @override
  String get attributionsFailed =>
      'No se pudieron cargar las atribuciones. Inténtalo de nuevo.';

  @override
  String get fuelPriceUnavailable => 'Precio no disponible';

  @override
  String get fuelPriceUnavailableHint =>
      'No hay feed público de precios en este país todavía';

  @override
  String get planSectionOptionalEyebrow => 'Opcional';

  @override
  String get planOptAlertsTitle => 'Avisarme de eventos críticos en la ruta';

  @override
  String get planOptAlertsSub =>
      'Incendios, huelgas, meteorología, obras y más a menos de 25 km de la ruta.';

  @override
  String get planOptTollFreeTitle => 'Mostrar alternativa sin peajes';

  @override
  String get planOptTollFreeSub =>
      'Compara una ruta que evita peajes — dinero ahorrado vs. minutos añadidos.';

  @override
  String get planOptHourlyTollTitle => 'Análisis de peajes por hora';

  @override
  String get planOptHourlyTollSub =>
      'A qué horas del día evitar peajes realmente compensa (según el tráfico).';

  @override
  String get planOptRouteVariantsTitle => 'Comparar variantes de ruta';

  @override
  String get planOptRouteVariantsSub =>
      'Más rápida vs. sin peajes vs. escénica — las tres en paralelo en los resultados.';

  @override
  String get planOptAvoidMotorwaysTitle => 'Evitar autopistas';

  @override
  String get planOptAvoidMotorwaysSub =>
      'Más lento y más largo, pero sin peajes y más tranquilo.';

  @override
  String get planOptPreferScenicTitle => 'Preferir escénica';

  @override
  String get planOptPreferScenicSub =>
      'Prioriza carreteras más interesantes. Algo más lento.';

  @override
  String get planPremiumBadge => 'Premium';

  @override
  String planProfileTravellers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count viajeros',
      one: '1 viajero',
    );
    return '$_temp0';
  }

  @override
  String get planProfileWithKids => 'niños';

  @override
  String get planProfileWithPets => 'mascotas';

  @override
  String get planProfileOverrideActive => 'SUSTITUCIÓN ACTIVA';

  @override
  String get planProfileOverride => 'Sustituir para este viaje';

  @override
  String get planProfileOverriding => 'Sustituyendo para este viaje';

  @override
  String get profilePromptSetup => 'Configura tu perfil de viaje';

  @override
  String get hotelPrefTitle => 'Buscar hoteles cerca de las paradas';

  @override
  String get hotelPrefSubOn =>
      'Muestra opciones de alojamiento cerca de cada punto de pernocta';

  @override
  String get hotelPrefSubOff => 'Desactivado';

  @override
  String get restaurantPrefTitle => 'Añadir restaurantes en la ruta';

  @override
  String restaurantPrefSubEnabled(int minutes, String band) {
    return 'Hasta $minutes min de desvío · $band';
  }

  @override
  String get restaurantPrefSubOff =>
      'Desactivado. Actívalo para ver restaurantes cerca de la ruta.';

  @override
  String prefMaxDetour(int minutes) {
    return 'Desvío máx: $minutes min';
  }

  @override
  String get prefBandBudget => 'Económico';

  @override
  String get prefBandMid => 'Medio';

  @override
  String get prefBandLuxury => 'Lujo';

  @override
  String get prefBandAny => 'Cualquiera';

  @override
  String get mealSlotBreakfast => 'Sugeridos para desayuno';

  @override
  String get mealSlotLunch => 'Sugeridos para comida';

  @override
  String get mealSlotDinner => 'Sugeridos para cena';

  @override
  String get mealSlotOther => 'Otros restaurantes';

  @override
  String poiDistanceKm(String km, String minutes) {
    return '$km km · +$minutes min de desvío';
  }

  @override
  String fuelSavingsChipCheap(String amount) {
    return '-$amount€/L vs media país';
  }

  @override
  String fuelSavingsChipDear(String amount) {
    return '+$amount€/L vs media país';
  }

  @override
  String get fuelArbitrageTitle => 'Reposta con cabeza en esta ruta';

  @override
  String fuelArbitrageBody(String cheap, String cheapPrice, String dear,
      String dearPrice, String savings) {
    return 'El combustible en $cheap está a ~$cheapPrice€/L. En $dear sube a ~$dearPrice€/L. Llenar el depósito en $cheap antes de cruzar ahorra ~$savings€.';
  }

  @override
  String dayTabLabel(int index) {
    return 'Día $index';
  }

  @override
  String dayHeaderRange(int index, String fromKm, String toKm) {
    return 'Día $index · km $fromKm → $toKm';
  }

  @override
  String daySleepMarker(String time) {
    return 'Terminas de conducir hacia las $time';
  }

  @override
  String get nextStopHeroLabel => 'Próxima parada sugerida';

  @override
  String nextStopHeroBody(String slot, String name, String time) {
    return '$slot en $name · hacia las $time';
  }

  @override
  String get daySleepHotelsLabel => 'Hoteles cerca del punto de pernocta';

  @override
  String hotelDistFromStop(String km) {
    return '$km km de la parada';
  }

  @override
  String hotelDistFromDestination(String km) {
    return '$km km del destino';
  }

  @override
  String get daySleepHotelsLabelDestination => 'Hoteles cerca del destino';

  @override
  String get daySleepHotelsEmpty =>
      'Activa hoteles en las preferencias del plan para ver opciones de pernocta.';

  @override
  String get restaurantPrefCuisinesLabel => 'Tipo de cocina';

  @override
  String get cuisineItalian => 'Italiana';

  @override
  String get cuisineSpanish => 'Española';

  @override
  String get cuisineTapas => 'Tapas';

  @override
  String get cuisineFrench => 'Francesa';

  @override
  String get cuisineMediterranean => 'Mediterránea';

  @override
  String get cuisineAsian => 'Asiática';

  @override
  String get cuisineIndian => 'India';

  @override
  String get cuisineBurger => 'Hamburguesas';

  @override
  String get cuisineSeafood => 'Pescado / mariscos';

  @override
  String get cuisineVegetarian => 'Vegetariana';

  @override
  String get cuisineBbq => 'Parrilla / BBQ';

  @override
  String get cuisineRegional => 'Regional';

  @override
  String timeWindowSpanLabel(int hours) {
    return 'Mostrar ±${hours}h';
  }

  @override
  String get timeWindowSpanHelper =>
      'Arrastra para ampliar la ventana y ver si salir antes o después ahorra más tiempo.';

  @override
  String get planLoadingTitle => 'Preparando tu viaje';

  @override
  String get planLoadingStepRouting => 'Calculando la ruta más rápida…';

  @override
  String get planLoadingStepTraffic =>
      'Muestreando tráfico para elegir la mejor hora de salida…';

  @override
  String get planLoadingStepFuel =>
      'Obteniendo precios reales de combustible del corredor…';

  @override
  String get planLoadingStepHotels =>
      'Buscando hoteles cerca de las paradas para pernoctar…';

  @override
  String get planLoadingStepRestaurants =>
      'Ordenando restaurantes por horario y tipo de cocina…';

  @override
  String get planLoadingStepAlerts =>
      'Escaneando incendios, obras, meteorología, protestas…';

  @override
  String get planLoadingStepTolls =>
      'Comparando rutas con peaje y alternativas sin peaje…';

  @override
  String get planLoadingStepAlmost => 'Casi listo — juntando todo para ti…';

  @override
  String get planLoadingHelper =>
      'Suele tardar entre 5 y 15 segundos. Puedes guardar el móvil un momento.';

  @override
  String get planErrorAuth =>
      'Sesión caducada. Vuelve a entrar y prueba de nuevo.';

  @override
  String get planErrorPremium =>
      'Esta ruta necesita Premium. Actívalo para incluir el análisis de peajes por hora.';

  @override
  String get planErrorRateLimit =>
      'Demasiadas peticiones en poco tiempo. Espera unos segundos y reintenta.';

  @override
  String planErrorGeneric(int code) {
    return 'Algo fue mal al planificar (código $code). Reintenta o cámbianos los datos.';
  }

  @override
  String get planErrorNetwork =>
      'No pudimos conectar con el servidor. Comprueba tu conexión y reintenta.';

  @override
  String get planErrorRetry => 'Reintentar';

  @override
  String get emptyAlertsTitle => 'Ruta sin alertas';

  @override
  String get emptyAlertsBody =>
      'No detectamos incendios, obras ni eventos adversos en tu corredor. Buen viaje.';

  @override
  String get emptyHotelsTitle => 'Sin hoteles cerca de la ruta';

  @override
  String get emptyHotelsBody =>
      'Prueba a ampliar el desvío máximo o cambia la banda de precio para ver más opciones.';

  @override
  String get emptyRestaurantsTitle => 'Sin restaurantes que encajen';

  @override
  String get emptyRestaurantsBody =>
      'Amplía el desvío máximo o quita filtros de cocina para ver más opciones.';

  @override
  String get onboardEyebrowFuel => 'PRECIOS REALES';

  @override
  String get onboardTitleFuel => 'Ahorra en cada repostaje';

  @override
  String get onboardBodyFuel =>
      'Precios oficiales por estación en España, Francia e Italia. Marcas premium mezcladas entre las más baratas.';

  @override
  String get onboardEyebrowDriving => 'EN LA CARRETERA';

  @override
  String get onboardTitleDriving => 'Tu copiloto inteligente';

  @override
  String get onboardBodyDriving =>
      'Dashboard en vivo con próxima parada, ETA dinámico y alertas nuevas. Compatible con Android Auto.';

  @override
  String get onboardEyebrowProfile => 'PERSONALIZADO';

  @override
  String get onboardTitleProfile => 'Rellena tu perfil';

  @override
  String get onboardBodyProfile =>
      'Sin perfil optimizamos solo tiempo. Con perfil calculamos fuel real, hoteles y comidas ajustadas a ti.';

  @override
  String get multiDaySleepLabel => 'Dormirás en';

  @override
  String get multiDaySleepNoHotel => 'Punto de pernocta sin hotel disponible';

  @override
  String get resumeTripTitle => '¿Retomamos tu viaje?';

  @override
  String resumeTripBody(String origin, String destination) {
    return 'Detectamos un viaje $origin → $destination en marcha. ¿Continuamos donde lo dejaste?';
  }

  @override
  String get resumeTripResume => 'Retomar';

  @override
  String get resumeTripDismiss => 'Descartar';

  @override
  String get hotelPrefStarsLabel => 'Estrellas';

  @override
  String get hotelPrefStarsAny => 'Todas';

  @override
  String get hotelPrefParkingTitle => 'Con parking';

  @override
  String get hotelPrefParkingSub =>
      'Solo hoteles con parking indicado. Los que no tienen la etiqueta también pasan.';

  @override
  String get hotelFilterParking => 'Parking';

  @override
  String get hotelFilterWifi => 'WiFi gratis';

  @override
  String get hotelFilterAccessible => 'Accesible';

  @override
  String get hotelFilterOtherTypes => 'Casas rurales y más';

  @override
  String get restaurantFilterVegetarian => 'Vegetariano';

  @override
  String get restaurantFilterVegan => 'Vegano';

  @override
  String get restaurantFilterGlutenFree => 'Sin gluten';

  @override
  String get restaurantFilterHalal => 'Halal';

  @override
  String get restaurantFilterKosher => 'Kosher';

  @override
  String get restaurantDietaryLabel => 'Dieta';

  @override
  String get tollSkipSelectAll => 'Seleccionar todos';

  @override
  String get mapShowLabel => 'Mostrar mapa';

  @override
  String get mapHideLabel => 'Ocultar mapa';

  @override
  String get tripCostTitle => 'COSTE TOTAL DEL VIAJE';

  @override
  String get tripCostFuel => 'Combustible';

  @override
  String get tripCostTolls => 'Peajes';

  @override
  String get tripCostMeals => 'Comidas';

  @override
  String get tripCostHotel => 'Hotel';

  @override
  String get tripCostTotal => 'Total estimado';

  @override
  String get addToRouteLabel => 'Añadir a la ruta';

  @override
  String get biometricSetupTitle => '¿Activar acceso biométrico?';

  @override
  String get biometricSetupBody =>
      'Usa tu huella o cara para desbloquear MyTravelPal.';

  @override
  String get biometricSetupEnable => 'Activar';

  @override
  String get biometricSetupSkip => 'Ahora no';

  @override
  String get weatherAlongRouteTitle => 'CLIMA EN TU RUTA';

  @override
  String get fuelNotificationTitle => '¡Reposta antes de la frontera!';

  @override
  String fuelNotificationBody(
      String cheap, String price, String pricey, String savings) {
    return 'Combustible en $cheap (~$price€/L) antes de cruzar a $pricey — ahorra ~$savings€ por depósito';
  }

  @override
  String get tutorialSkip => 'Saltar';

  @override
  String get tutorialOriginTitle => '¿Desde dónde sales?';

  @override
  String get tutorialOriginBody =>
      'Toca aquí para buscar una ciudad o usa el botón de ubicación para salir desde donde estás.';

  @override
  String get tutorialDestinationTitle => '¿A dónde vas?';

  @override
  String get tutorialDestinationBody =>
      'Busca tu destino. Planificaremos la ruta completa con paradas, hoteles y peajes.';

  @override
  String get tutorialPrefsTitle => 'Personaliza tu viaje';

  @override
  String get tutorialPrefsBody =>
      'Activa hoteles, restaurantes y alertas. Configura preferencias dietéticas, estrellas y más.';

  @override
  String get tutorialTimeWindowTitle => 'Elige la mejor hora de salida';

  @override
  String get tutorialTimeWindowBody =>
      'Toca cualquier franja para replanificar con esa hora. El gráfico muestra el impacto del tráfico en cada hora.';

  @override
  String get tutorialTollTitle => 'Gestiona los peajes';

  @override
  String get tutorialTollBody =>
      'Activa o desactiva tramos de peaje individualmente. El ahorro total se actualiza en tiempo real. La barra de colores muestra las mejores horas para saltar.';

  @override
  String styleDailyCapRecommendedHint(int hours) {
    return 'Para este ritmo recomendamos $hours h/día.';
  }

  @override
  String get aaCoachTitle => 'Cómo verla en Android Auto';

  @override
  String get aaCoachStep1 =>
      'Conecta el móvil al coche por USB (o wireless si tu head unit lo soporta).';

  @override
  String get aaCoachStep2 =>
      'En el launcher del coche, cambia a la categoría \'Point of Interest\' o \'Apps\'. NO aparece junto a Google Maps.';

  @override
  String get aaCoachStep3 =>
      'Toca MyTravelPal. Se abre el companion con próxima parada, gasolina más barata y ETA.';

  @override
  String get aaCoachHint =>
      'La primera vez tarda unos segundos. Aparca con vista al cielo para tener GPS antes de arrancar.';

  @override
  String get aaCoachDontShowAgain => 'No mostrar de nuevo';

  @override
  String get aaCoachDone => 'Entendido';

  @override
  String get batteryWhitelistTitle => 'Evita que Android nos cierre';

  @override
  String get batteryWhitelistBody =>
      'Xiaomi/MIUI y otras marcas cierran apps en segundo plano tras unos minutos. Si estás navegando con Google Maps y MyTravelPal muere, pierdes las alertas en vivo.';

  @override
  String get batteryWhitelistSteps =>
      'Ajustes → Aplicaciones → MyTravelPal → Batería → Sin restricciones\n(o \'No optimizar\' según tu modelo)';

  @override
  String get batteryWhitelistDontShowAgain => 'No mostrar de nuevo';

  @override
  String get batteryWhitelistLater => 'Ahora no';

  @override
  String get batteryWhitelistOpen => 'Abrir ayuda';

  @override
  String get planRoundTripTitle => 'Ida y vuelta';

  @override
  String get planRoundTripSubtitle =>
      'Planificamos el viaje de vuelta a la vez con las mismas preferencias.';

  @override
  String get roundTripLegOutbound => 'IDA';

  @override
  String get roundTripLegReturn => 'VUELTA';

  @override
  String roundTripSwapTo(String leg) {
    return 'Ver $leg';
  }

  @override
  String get resultStartTrip => 'Iniciar viaje';

  @override
  String get navPickerTitle => 'Continuar en…';

  @override
  String get tripDashboardTitle => 'En ruta';

  @override
  String get tripDashboardCenterOnMe => 'Centrar en mi posición';

  @override
  String get tripDashboardOpenNav => 'Abrir navegación';

  @override
  String tripDashboardNextStopLabel(String slot) {
    return 'PRÓXIMA $slot';
  }

  @override
  String tripDashboardInMinutes(int n) {
    return 'en $n min';
  }

  @override
  String get tripDashboardPermissionDenied =>
      'Ubicación denegada. Activa el permiso para ver tu posición en la ruta.';

  @override
  String get tripDashboardServiceDisabled =>
      'GPS desactivado. Enciéndelo para seguir tu progreso en la ruta.';

  @override
  String tripDashboardProgressLine(String done, String total) {
    return '$done / $total km';
  }

  @override
  String tripDashboardEta(String time) {
    return 'ETA $time';
  }

  @override
  String get tripDashboardActiveNotifTitle => 'Viaje activo';

  @override
  String get tripDashboardActiveNotifBody =>
      'MyTravelPal sigue tu ruta en segundo plano.';

  @override
  String tripDashboardForegroundBodyBare(String done, String total) {
    return '$done / $total km recorridos';
  }

  @override
  String tripDashboardForegroundBodyWithStop(
      String done, String total, String name) {
    return '$done / $total km · próxima parada: $name';
  }

  @override
  String get tripDashboardSleepStopLabel => 'hotel';

  @override
  String get alertApproachingStopTitle => 'Parada cerca';

  @override
  String alertApproachingStopBody(String slot, String name, int mins) {
    return '$slot en $name en unos $mins min. Prepara la salida.';
  }

  @override
  String get alertNewAdverseAheadTitle => 'Nueva alerta en la ruta';

  @override
  String alertNewAdverseAheadBody(String type, String km) {
    return '$type detectado a $km km por delante.';
  }

  @override
  String get alertDriftDetectedTitle => 'Te desviaste de la ruta';

  @override
  String alertDriftDetectedBody(String off) {
    return 'Estás a $off m del trazado planificado. ¿Recalcular?';
  }

  @override
  String get alertBehindScheduleTitle => 'Vas con retraso';

  @override
  String alertBehindScheduleBody(int mins) {
    return 'Llegarás $mins min más tarde de lo previsto.';
  }

  @override
  String tripDashboardCheaperFuel(String brand, String km, String cts) {
    return '$brand en $km km · ahorras $cts ct/L';
  }
}
