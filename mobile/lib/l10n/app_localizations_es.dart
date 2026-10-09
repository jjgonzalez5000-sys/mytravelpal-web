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
  String get onboardEyebrowKiller => 'EL COSTE REAL';

  @override
  String get onboardTitleKiller =>
      'Tu GPS te lleva.\nNosotros te decimos cuánto.';

  @override
  String get onboardBodyKiller =>
      'Peajes, gasolina, hoteles y comidas calculados antes de salir. Sin sorpresas.';

  @override
  String get onboardEyebrowHonest => 'TU PERFIL, TU VIAJE';

  @override
  String get onboardTitleHonest =>
      '2 adultos, 1 niño, perro.\nParking. 3 estrellas máx €€.';

  @override
  String get onboardBodyHonest =>
      'Hoteles y restaurantes filtrados por tus preferencias reales. No una lista genérica — la tuya.';

  @override
  String get onboardEyebrowAlerts => 'ALERTAS EN TIEMPO REAL';

  @override
  String get onboardTitleAlerts => 'Incendio a 14 km\nde tu ruta.';

  @override
  String get onboardBodyAlerts =>
      'Incendios, tormentas, terremotos, cierres de carretera. Solo los eventos que afectan a tu ruta concreta, antes de llegar.';

  @override
  String get onboardCostFuel => 'Gasolina';

  @override
  String get onboardCostTolls => 'Peajes';

  @override
  String get onboardCostMeals => 'Comidas';

  @override
  String get onboardCostHotel => 'Hotel';

  @override
  String get onboardCostTotal => 'TOTAL';

  @override
  String get onboardSavingsTitle => 'Ahorros detectados';

  @override
  String get onboardSavingsToll => 'Peaje alternativo';

  @override
  String get onboardSavingsFuel => 'Gasolinera óptima';

  @override
  String get onboardSavingsHotel => 'Mejor hotel';

  @override
  String get onboardSavingsTotal => 'TOTAL AHORRADO';

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
  String get planMoreOptions => 'Más opciones';

  @override
  String get planLessOptions => 'Menos opciones';

  @override
  String get planRoundTripChip => 'Ida y vuelta';

  @override
  String get planLeaveNowFabTitle => 'Salir ya';

  @override
  String get leaveNowConfirmTitle => 'Salir ya hacia';

  @override
  String leaveNowConfirmBody(Object name) {
    return '¿Vamos a $name?';
  }

  @override
  String get leaveNowConfirmCta => 'Vamos';

  @override
  String get leaveNowConfirmChange => 'Cambiar destino';

  @override
  String get settingsBiometric => 'Desbloqueo biométrico';

  @override
  String get settingsBiometricSub => 'Usa huella o cara para abrir la app';

  @override
  String get settingsBiometricUnavailable =>
      'No disponible en este dispositivo';

  @override
  String get settingsReplayTutorial => 'Repetir tutorial';

  @override
  String get settingsReplayTutorialSub =>
      'Vuelve a mostrar los coach-marks guiados';

  @override
  String get settingsReplayTutorialToast =>
      'Tutorial reiniciado. Vuelve a Planificar para verlo.';

  @override
  String get settingsColorPreset => 'Paleta de color';

  @override
  String get settingsPresetForest => 'Bosque';

  @override
  String get settingsPresetSunset => 'Atardecer';

  @override
  String get settingsPresetOcean => 'Océano';

  @override
  String get settingsDynamicColor => 'Material You (dinámico)';

  @override
  String get settingsDynamicColorSub =>
      'Adapta los colores a tu fondo de pantalla (Android 12+)';

  @override
  String get settingsOled => 'Negro puro (OLED)';

  @override
  String get settingsOledSub =>
      'Negros más profundos en modo oscuro, ahorra batería en pantallas OLED';

  @override
  String get parkingSearchTitle => 'Buscar parking';

  @override
  String get parkingSearchLabel => '¿Dónde vas?';

  @override
  String get parkingSearchHint =>
      'Elige un destino y verás los parkings cercanos.';

  @override
  String get parkingRadiusLabel => 'Radio';

  @override
  String get parkingNoResults => 'No hay parkings en este radio.';

  @override
  String get parkingPriceUnknown => 'Precio ?';

  @override
  String get parkingCovered => 'Cubierto';

  @override
  String get parkingFilterKids => 'Niños';

  @override
  String get parkingFilterDogs => 'Perros';

  @override
  String get parkingFilterToilets => 'Aseos';

  @override
  String get parkingFilterFood => 'Comida';

  @override
  String get parkingFilterShowers => 'Duchas';

  @override
  String get parkingFilterEv => 'Cargador EV';

  @override
  String get parkingFilterFuel => 'Gasolinera';

  @override
  String get parkingFilterWheelchair => 'Accesible';

  @override
  String get parkingFilterRv => 'Autocaravana';

  @override
  String get parkingFilterTruck => 'Camión';

  @override
  String get planFindParkingCta => 'Buscar parking';

  @override
  String get poiFindParking => 'Parking';

  @override
  String get parkingPrefTitle => 'Parking';

  @override
  String get parkingPrefSub => 'Muestra parkings cerca del destino.';

  @override
  String get parkingResultTitle => 'Parkings cerca del destino';

  @override
  String get inspireTitle => 'Inspiración de viaje';

  @override
  String get inspireHero => 'Describe tu viaje soñado';

  @override
  String get inspireSub =>
      'La IA propone un itinerario multi-día que puedes convertir en un plan real con un toque.';

  @override
  String get inspireHint =>
      'ej. Escapada romántica de 4 días por los lagos italianos';

  @override
  String get inspireGenerate => 'Inspírame';

  @override
  String get inspireGenerating => 'Preparando tu ruta…';

  @override
  String get inspireError =>
      'La musa está fuera de servicio. Prueba otro texto o inténtalo de nuevo.';

  @override
  String get inspireResultTitle => 'Itinerario propuesto';

  @override
  String inspireDayLabel(Object n) {
    return 'Día $n';
  }

  @override
  String get inspireBudgetLabel => 'Presupuesto estimado';

  @override
  String get inspireConvertToPlan => 'Convertir en plan real';

  @override
  String get inspireSave => 'Guardar';

  @override
  String get inspireSavedToast =>
      'Idea guardada. La encontrarás en tus inspiraciones guardadas.';

  @override
  String get inspireRecentTitle => 'Recientes';

  @override
  String get inspireHistoryTitle => 'Mis planes IA';

  @override
  String get inspireHistoryEmpty =>
      'Aún no hay planes IA. Genera uno desde la pestaña Planificar.';

  @override
  String get inspireHistoryDelete => 'Borrar';

  @override
  String get settingsMyAiPlans => 'Mis planes IA';

  @override
  String get settingsMyAiPlansSub => 'Historial de Trip Inspiration';

  @override
  String get inspireChatTitle => 'Ajusta el itinerario';

  @override
  String get inspireChatHint =>
      'Pide un cambio: \"quita Cremona\", \"salgo viernes por la tarde\"…';

  @override
  String get inspireExamplesTitle => 'O parte de una idea';

  @override
  String get inspireExample1 =>
      'Fin de semana de castillos por el valle del Loira';

  @override
  String get inspireExample2 => 'Ruta costera de Barcelona a Marsella';

  @override
  String get inspireExample3 => '5 días por los Alpes desde Milán';

  @override
  String get inspireExample4 => 'Norte de España con niños, sin autopistas';

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
  String get tabPlan => 'Planificar';

  @override
  String get tabCompanion => 'Acompañar';

  @override
  String get tabMyTrips => 'Mis viajes';

  @override
  String get companionHeroTitle => 'Tu compañero de viaje';

  @override
  String get companionHeroBody =>
      'Configura tus condiciones y arranca. La app te acompaña mientras conduces y te recomienda paradas, comida y repostaje.';

  @override
  String get companionConfigSection => 'CONFIGURACIÓN';

  @override
  String get companionBreakInterval => 'Sugerencias de descanso';

  @override
  String get companionSuggestBreak =>
      'Sugerir descanso según tiempo de conducción';

  @override
  String companionBreakHint(String hours) {
    return 'Recomendar parada cada $hours h de conducción';
  }

  @override
  String get companionFatigueStopExperimental =>
      'Sugerir parar por cansancio (experimental)';

  @override
  String get companionFatigueStopHint =>
      'Hoy sólo por temporizador — se dispara con micro-pausas cortas.';

  @override
  String get companionAlerts => 'Tipos de aviso';

  @override
  String get companionAlertCriticalAdverse =>
      'Incidentes críticos (incendios, riadas, tormentas)';

  @override
  String get companionAlertCriticalAdverseHint =>
      'Recomendado. Algo grave pasando cerca — no es meteo simple.';

  @override
  String get companionAlertWeather => 'Meteo por delante';

  @override
  String get companionAlertFuel => 'Gasolineras más baratas en ruta';

  @override
  String get companionAlertBorder => 'Aviso al cruzar fronteras';

  @override
  String get companionAlertToll => 'Sugerencias para saltar peajes';

  @override
  String get companionAlertHotel =>
      'Hotel al pasar tu hora + 5 h de conducción';

  @override
  String get companionStart => 'Iniciar acompañamiento';

  @override
  String get companionComingSoon => 'Modo acompañamiento disponible pronto!';

  @override
  String get companionDriveTitle => 'Acompañante activo';

  @override
  String get companionForegroundBody =>
      'MyTravelPal está siguiendo tu conducción';

  @override
  String get companionLocationDenied =>
      'Se necesita permiso de ubicación para el acompañante.';

  @override
  String get companionDriving => 'conduciendo';

  @override
  String get companionAllGood => 'Sin avisos — disfruta el viaje.';

  @override
  String get companionWeatherRowEmpty => 'Sin alertas próximas';

  @override
  String get companionEndTitle => '¿Terminar acompañante?';

  @override
  String get companionEndBody =>
      'El seguimiento se detendrá y los avisos activos se perderán.';

  @override
  String get companionEndKeep => 'Seguir conduciendo';

  @override
  String get companionEndConfirm => 'Terminar sesión';

  @override
  String get emergencyContactsTitle => 'Contactos de emergencia';

  @override
  String get emergencyContactsSubtitle =>
      'Reciben SMS si se detecta un impacto';

  @override
  String get emergencyContactsBody =>
      'Hasta 3 personas reciben un SMS con tu ubicación si el acompañante detecta un impacto.';

  @override
  String get emergencyContactsEmpty => 'Aún no hay contactos.';

  @override
  String get emergencyContactsAdd => 'Añadir contacto';

  @override
  String get emergencyContactsPickFromDevice => 'Elegir de contactos';

  @override
  String get emergencyContactsPickSearch => 'Buscar contactos';

  @override
  String get emergencyContactsPermDenied =>
      'Permiso denegado. Puedes añadir manualmente.';

  @override
  String get emergencyContactsNoDevice =>
      'No hay contactos con teléfono en el dispositivo.';

  @override
  String get emergencyContactAddTitle => 'Añadir contacto de emergencia';

  @override
  String get emergencyContactName => 'Nombre';

  @override
  String get emergencyContactNameRequired => 'Escribe un nombre';

  @override
  String get emergencyContactPhone => 'Teléfono (E.164)';

  @override
  String get emergencyContactPhoneRequired => 'Escribe un teléfono';

  @override
  String get emergencyContactPhoneInvalid =>
      'Formato internacional: +34612345678';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get sosTitle => 'Posible impacto detectado';

  @override
  String sosBody(String g, String speed) {
    return 'Pico de impacto ${g}g · caída de velocidad $speed km/h.';
  }

  @override
  String sosCountdown(int seconds) {
    return '${seconds}s';
  }

  @override
  String get sosImOk => 'Estoy bien — cancelar';

  @override
  String get sosCall112 => 'Llamar 112';

  @override
  String get sosCancelled => 'Alerta cancelada.';

  @override
  String get sosClose => 'Cerrar';

  @override
  String get sosNoContacts =>
      'No hay contactos configurados. Añade uno en Ajustes.';

  @override
  String sosSmsDispatched(int count) {
    return 'SMS preparado para $count contacto(s).';
  }

  @override
  String get sosSmsFailed => 'No se pudo abrir SMS. Llama manualmente abajo.';

  @override
  String get sosSmsPrefix =>
      'MyTravelPal — posible impacto detectado. Mi ubicación:';

  @override
  String get weatherForecastTitle => 'Previsión 7 días';

  @override
  String get weatherToday => 'Hoy';

  @override
  String get leaveNowTitle => 'Salir ya con acompañante';

  @override
  String get leaveNowSubtitle =>
      'Elige destino y arranca — te seguimos y te guiamos.';

  @override
  String get leaveNowSheetTitle => '¿A dónde vas?';

  @override
  String get leaveNowPremiumTitle => 'Función Premium';

  @override
  String get leaveNowPremiumBody =>
      '\'Salir ya\' combina el plan completo con el acompañante durante la conducción. Disponible con MyTravelPal Premium.';

  @override
  String get leaveNowPremiumDismiss => 'Más tarde';

  @override
  String get leaveNowPremiumCta => 'Probar 7 días gratis';

  @override
  String get shareCardOption => 'Compartir como imagen';

  @override
  String get shareCardOptionSub =>
      'Perfecto para Instagram Stories, WhatsApp, X';

  @override
  String get shareLinkOption => 'Compartir como enlace';

  @override
  String get shareLinkOptionSub =>
      'Resumen en texto + link para reabrir el plan';

  @override
  String get shareToSocial => 'Compartir en redes';

  @override
  String get sharePlanTitle => 'Compartir enlace del viaje';

  @override
  String get sharePlanSubtitle => 'Código QR + enlace para reabrir este plan';

  @override
  String get sharePlanCopy => 'Copiar enlace';

  @override
  String get sharePlanCopied => 'Enlace copiado';

  @override
  String shareLiveHeadline(String city) {
    return 'Conduciendo por $city';
  }

  @override
  String shareLiveCaption(String city) {
    return 'Conduciendo por $city con MyTravelPal 🚗';
  }

  @override
  String get planAddStop => 'Añadir parada';

  @override
  String get planStopDwellPassThrough => 'Solo paso';

  @override
  String get planStopDwellOneNight => '1 noche';

  @override
  String planStopDwellNights(int n) {
    return '$n noches';
  }

  @override
  String planStopDwellHours(int n) {
    return '$n horas';
  }

  @override
  String planStopDwellTitle(Object name) {
    return '¿Cuánto tiempo en $name?';
  }

  @override
  String get planAddStopTitle => 'Nueva parada';

  @override
  String planStopLabel(int n) {
    return 'Parada $n';
  }

  @override
  String get planStopRemove => 'Quitar parada';

  @override
  String get settingsCurrency => 'Moneda';

  @override
  String get planErrorPickEndpoints => 'Elige un origen y un destino.';

  @override
  String get resultBestTimeToLeave => 'MEJOR HORA PARA SALIR';

  @override
  String get resultTripSavings => 'TUS AHORROS EN ESTE VIAJE';

  @override
  String get resultSavingsDetected => 'Ahorros detectados';

  @override
  String get resultTollSaving => 'Peaje alternativo';

  @override
  String get resultFuelSaving => 'Combustible';

  @override
  String get resultTimeSaving => 'Salida óptima';

  @override
  String get resultTotalSaving => 'AHORRO TOTAL';

  @override
  String resultSavingPct(String pct) {
    return '$pct% menos';
  }

  @override
  String get resultSavingsSuggestionsTitle => 'Sugerencias para ahorrar tiempo';

  @override
  String get resultSavingsClaimedHint =>
      'Ahorro reflejado tras aplicar la ventana óptima.';

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
  String get resultSaveChangesTooltip => 'Guardar cambios';

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
  String get dashboardSaved => 'ahorrado';

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
  String commonShowNMore(int n) {
    return 'Ver $n más';
  }

  @override
  String get commonShowLess => 'Ver menos';

  @override
  String planLoadingElapsed(int seconds) {
    return '${seconds}s transcurridos';
  }

  @override
  String get planLoadingLongCrossingCountries =>
      'Cruzando peajes en todos los países que vas a atravesar…';

  @override
  String get planLoadingLongScanningFuel =>
      'Escaneando precios de combustible europeos a lo largo de tu ruta…';

  @override
  String get planLoadingLongBigTrip =>
      'Los viajes largos tardan un poco más — cargando datos extra de hoteles y descansos.';

  @override
  String get planLoadingLongAlmostDone =>
      'Ya casi está — últimos retoques al itinerario.';

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
      'Incendios, inundaciones, temporal grave, nieve, terremotos, corrimientos — ordenados por severidad.';

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
  String get shareFormatTitle => 'Compartir como…';

  @override
  String get shareFormatStory => 'Story · 9:16';

  @override
  String get shareFormatStorySub => 'Instagram / TikTok / WhatsApp Stories';

  @override
  String get shareFormatFeed => 'Cuadrado · 1:1';

  @override
  String get shareFormatFeedSub => 'Feed de Instagram, Facebook, LinkedIn';

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
  String get resultStatPlanned => 'Planificado';

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
  String get mealSlotBreak => 'Descanso';

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
  String get partialTollSkipsTitle => 'Peaje a peaje · Optimización Premium';

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
  String dayTollsHeader(Object amount, int count) {
    return 'Peajes de este día · $amount € ($count)';
  }

  @override
  String dayTollsSavedSummary(Object amount, int count) {
    return 'Ahorras $amount € saltando $count.';
  }

  @override
  String tollHourGoodToSkip(Object hh) {
    return 'Buena hora para saltar ($hh:00)';
  }

  @override
  String tollHourAvoidSkip(Object hh) {
    return 'No lo saltes — hora pico $hh:00';
  }

  @override
  String get partialTollsPerDayHint =>
      'También puedes marcarlos por tramo en el resumen del viaje ↓';

  @override
  String resultCityHint(Object city) {
    return 'Cerca de $city';
  }

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
  String get resultBypassSavingsPrefix => 'Podrías ahorrar hasta';

  @override
  String resultBypassSavingsSuffix(String minutes) {
    return 'con +$minutes min extra';
  }

  @override
  String get resultArrival => 'LLEGADA';

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
  String get historyReplanNetworkError =>
      'La conexión se cortó durante el recálculo. Comprueba tu señal e inténtalo de nuevo.';

  @override
  String get retryLabel => 'Reintentar';

  @override
  String get historyDeleteTooltip => 'Borrar';

  @override
  String get historyReopenCta => 'Ver plan';

  @override
  String get historyRepeatCta => 'Repetir';

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
    return 'Mostrar las $count gasolineras más baratas de la ruta';
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
  String consistencyFuelNoStations(String km) {
    return 'El viaje son $km km, pero de momento no vemos gasolineras a lo largo de la ruta. Los precios y las paradas sugeridas no están disponibles para este tramo.';
  }

  @override
  String get consistencyFuelNoStationsHint =>
      'Puede que los datos aún estén cargando. Prueba a refrescar en unos minutos, o añade tu propia parada tocando el mapa.';

  @override
  String get consistencyFuelRangeExceeded =>
      'Tu vehículo no cubre la ruta con un solo depósito o carga. Vas a necesitar repostar o cargar durante el viaje.';

  @override
  String consistencyMealBeforeDeparture(String slot, String km) {
    return 'Se ha programado $slot en el km $km antes de la salida del viaje. Ajusta el horario de la parada o la hora de salida.';
  }

  @override
  String consistencyMealAfterArrival(String slot, String km) {
    return 'Se ha programado $slot en el km $km después de la llegada. Ajusta el horario de la parada o el ritmo del viaje.';
  }

  @override
  String consistencyMealImpossibleSpeed(String slot, String km, String kmh) {
    return 'Para llegar a $slot en el km $km desde la salida haría falta ~$kmh km/h — no es posible. Revisa la parada.';
  }

  @override
  String consistencyMealSuspiciousSpeed(String slot, String km, String kmh) {
    return 'Para llegar a $slot en el km $km desde la salida se necesitan ~$kmh km/h. Comprueba si el ritmo es realista.';
  }

  @override
  String consistencyMealTooCloseToArrival(String slot, String km, String mins) {
    return '$slot en el km $km está muy cerca de la llegada ($mins min antes). Igual conviene comer ya en el destino.';
  }

  @override
  String consistencySleepBeforeDeparture(String km) {
    return 'El descanso nocturno se ha programado antes de la salida (km $km). Revisa la hora.';
  }

  @override
  String consistencySleepAfterArrival(String km) {
    return 'El descanso nocturno se ha programado después de la llegada (km $km). Es posible que sobre.';
  }

  @override
  String consistencySleepImpossibleSpeed(String km, String kmh) {
    return 'Llegar al descanso en el km $km requiere ~$kmh km/h — imposible. Revisa el tramo.';
  }

  @override
  String consistencySleepSuspiciousSpeed(String km, String kmh) {
    return 'El descanso en el km $km implica ~$kmh km/h de media. Comprueba si el ritmo es realista.';
  }

  @override
  String get mealSlotBreakfastCap => 'Desayuno';

  @override
  String get mealSlotLunchCap => 'Comida';

  @override
  String get mealSlotDinnerCap => 'Cena';

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
  String get settingsSectionVehicle => 'Vehículo y ruta';

  @override
  String get settingsSectionAppearance => 'Apariencia';

  @override
  String get settingsSectionAI => 'Personalización IA';

  @override
  String get notifSoundTitle => 'Sonido de alertas';

  @override
  String get notifSoundDefault => 'Sonido predeterminado';

  @override
  String get notifSoundDefaultSub =>
      'Usa el sonido de notificación del sistema';

  @override
  String get notifSoundSilent => 'Silencio';

  @override
  String get notifSoundSilentSub => 'Sin sonido al llegar alertas';

  @override
  String get settingsSectionSafety => 'Contactos y seguridad';

  @override
  String get settingsSectionAccount => 'Cuenta';

  @override
  String get settingsDensityLabel => 'Densidad';

  @override
  String get settingsDensityComfortable => 'Cómoda';

  @override
  String get settingsDensityCompact => 'Compacta';

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
  String get settingsRadarAlerts => 'Alertas de radar';

  @override
  String get settingsRadarAlertsSubtitle =>
      'Vibración y banner cuando hay un radar a menos de 400 m (Essential+).';

  @override
  String get settingsSectionAbout => 'Acerca de';

  @override
  String get settingsSectionData => 'Tus datos';

  @override
  String get settingsExportData => 'Descargar mis datos';

  @override
  String get settingsExportDataSub =>
      'Obtén un JSON con todo lo que MyTravelPal guarda sobre ti.';

  @override
  String get settingsExportError =>
      'No se pudieron exportar los datos — revisa tu conexión.';

  @override
  String get settingsDeleteAccount => 'Borrar mi cuenta';

  @override
  String get settingsDeleteAccountSub =>
      'Elimina tu perfil, viajes guardados y preferencias de forma permanente.';

  @override
  String get settingsDeleteAccountConfirmTitle => '¿Borrar cuenta?';

  @override
  String get settingsDeleteAccountConfirmBody =>
      'Esto borra tu perfil y todos los viajes guardados de nuestros servidores. No se puede deshacer.';

  @override
  String get settingsDeleteAccountCancel => 'Cancelar';

  @override
  String get settingsDeleteAccountConfirm => 'Borrar para siempre';

  @override
  String get settingsDeleteAccountPartial =>
      'Sesión cerrada, pero el servidor puede aún tener datos. Reintenta con conexión estable.';

  @override
  String get settingsDeleteAccountDone => 'Cuenta borrada. Sesión cerrada.';

  @override
  String get settingsDeleteAccountInProgress => 'Borrando cuenta…';

  @override
  String get settingsSupport => 'Soporte y contacto';

  @override
  String get settingsPrivacyPolicy => 'Política de privacidad';

  @override
  String get settingsTerms => 'Términos del servicio';

  @override
  String get settingsVersion => 'Versión';

  @override
  String get planTooltipSettings => 'Ajustes';

  @override
  String get styleSectionTitle => 'Ritmo de conducción';

  @override
  String get styleSectionEyebrow => 'Cómo organizas tus jornadas';

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
  String get styleDrivingStartLabel => 'Hora preferida para empezar a conducir';

  @override
  String get drivingWindowNightStart => 'Conducción nocturna al inicio';

  @override
  String get drivingWindowNightEnd => 'Conducción nocturna al final';

  @override
  String get dayEditKmNoLimit => 'Máx. km: sin límite';

  @override
  String dayEditKmCap(int km) {
    return 'Máx. km: $km km';
  }

  @override
  String dayEditSheetTitle(int day) {
    return 'Ajustar día $day';
  }

  @override
  String get dayEditStartHour => 'Hora de empezar a conducir';

  @override
  String dayEditMaxDriving(int hours) {
    return 'Máximo horas al volante: $hours h (incluye descansos)';
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
  String get dayReduceKmTitle => 'Tiempo de conducción reducido';

  @override
  String dayReduceKmBody(String reducedKm) {
    return 'Con este horario llegarás hasta aprox. $reducedKm km. ¿Quieres ajustar el límite de kilómetros?';
  }

  @override
  String get dayReduceKmKeep => 'Mantener km actuales';

  @override
  String dayReduceKmAdjust(String reducedKm) {
    return 'Ajustar a $reducedKm km';
  }

  @override
  String dayEditEndHour(String time) {
    return 'Terminarás de conducir a las $time';
  }

  @override
  String get dayEditPickTime => 'Elegir hora';

  @override
  String get dayEditEndTimePicker =>
      '¿A qué hora quieres terminar de conducir?';

  @override
  String get dayEditSave => 'Aplicar';

  @override
  String get dayEditCancel => 'Cancelar';

  @override
  String get dayEditReset => 'Restablecer';

  @override
  String get resultReplanning => 'Recalculando...';

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
  String get fuelTypeE85 => 'E85 / Etanol';

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
  String get eventTypeHeavyRain => 'Lluvia fuerte';

  @override
  String get eventTypeHail => 'Granizo';

  @override
  String get eventTypeThunderstorm => 'Tormenta eléctrica';

  @override
  String get eventTypeHighWind => 'Viento fuerte';

  @override
  String get eventTypeDenseFog => 'Niebla densa';

  @override
  String get eventTypeFreezingRain => 'Lluvia helada';

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
  String get addedToRouteLabel => 'AÑADIDO';

  @override
  String get replanWithStops => 'Recalcular ruta con paradas';

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
      'Incendios, inundaciones, temporal grave y peligros serios a menos de 25 km de la ruta.';

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
  String dayHeaderCity(int index, String from, String to) {
    return 'Día $index · $from → $to';
  }

  @override
  String dayArrivalMarker(String time) {
    return 'Llegas a tu destino hacia las $time';
  }

  @override
  String daySleepMarker(String time) {
    return 'Terminas de conducir hacia las $time';
  }

  @override
  String dayStartsAt(String time) {
    return 'Sale a las $time';
  }

  @override
  String dayDriveWindow(String start, String end) {
    return '$start → $end';
  }

  @override
  String get restStopWhyTitle => '¿Por qué esta parada?';

  @override
  String get restStopWhyKidFriendly =>
      'Área de servicio marcada como apta para niños';

  @override
  String get restStopWhyPetFriendly => 'Zona para perros / mascotas cerca';

  @override
  String get restStopWhyRvFriendly =>
      'Compatible con autocaravana (sanitario / vaciado)';

  @override
  String restStopWhySafety(String hours) {
    return 'Recomendado por seguridad vial: llevas ${hours}h conduciendo. La normativa EU 561/2006 sugiere una pausa de al menos 45 min tras 4h30 al volante.';
  }

  @override
  String get restStopWhyClose => 'Entendido';

  @override
  String dayMealStopAt(String time, String name) {
    return '🍽 $time · $name';
  }

  @override
  String dayRestStopAt(String time, String label) {
    return '☕ $time · $label';
  }

  @override
  String get restStopFilterAll => 'Todos';

  @override
  String get restStopFilterKidFriendly => 'Familiar';

  @override
  String get restStopFilterPetFriendly => 'Con mascota';

  @override
  String get restStopFilterRvFriendly => 'Autocaravana';

  @override
  String dayHeaderDwell(int index, String place) {
    return 'Día $index · $place';
  }

  @override
  String daySleepStay(String place) {
    return 'Estancia en $place';
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
  String get daySleepHotelsNotFound =>
      'No encontramos hoteles cerca de esta ruta con tus preferencias actuales.';

  @override
  String get noHotelsAdjustPrefs => 'Ajustar preferencias';

  @override
  String get noRestaurantsAdjustPrefs =>
      'No encontramos restaurantes con tus preferencias actuales.';

  @override
  String get companionAssistantTitle => 'Asistente companion';

  @override
  String get settingsAiPersonalisation => 'Personalización IA';

  @override
  String get companionAskHint => 'Pregúntame algo…';

  @override
  String get companionSend => 'Enviar';

  @override
  String get companionGroupJoin => 'Unirme como pasajero';

  @override
  String get companionJoin => 'Unirme';

  @override
  String get resultFuelSavingsTitle => 'Combustible barato en tu ruta';

  @override
  String get daySleepHotelsSearching =>
      'Buscando hoteles cerca de tu parada...';

  @override
  String get enrichmentLoadingTitle => 'Cargando datos extra';

  @override
  String get enrichmentChipHotels => 'Hoteles';

  @override
  String get enrichmentChipRestaurants => 'Restaurantes';

  @override
  String get enrichmentChipFuel => 'Gasolineras';

  @override
  String get enrichmentChipWeather => 'Meteo';

  @override
  String get enrichmentChipAdverse => 'Alertas';

  @override
  String get enrichPulseHeader => 'Ahora mismo…';

  @override
  String get enrichPulseHotels => 'Buscando hoteles con mejor precio/estrellas';

  @override
  String get enrichPulseRestaurants =>
      'Filtrando restaurantes según tus preferencias';

  @override
  String get enrichPulseFuel =>
      'Localizando las gasolineras más baratas del corredor';

  @override
  String get enrichPulseTolls => 'Detectando peajes evitables sin desviarte';

  @override
  String get enrichPulseWindows => 'Comparando horarios por tráfico esperado';

  @override
  String get enrichPulseWeather =>
      'Previsión hora a hora en 5 tramos de la ruta';

  @override
  String get enrichPulseAdverse =>
      'Cruzando incendios y otros peligros graves con tu ruta';

  @override
  String get enrichPulseKids => 'Paradas con zona infantil o parque cerca';

  @override
  String get enrichPulsePets => 'Localizando pipicanes y áreas pet-friendly';

  @override
  String get enrichPulseCamper =>
      'Buscando áreas para camper con vaciado y sanitarios';

  @override
  String enrichPulseVehicleEv(String vehicle, String tank) {
    return 'Planificando carga de tu $vehicle ($tank kWh)';
  }

  @override
  String enrichPulseVehicle(String vehicle, String tank) {
    return 'Ajustando repostaje a tu $vehicle ($tank L)';
  }

  @override
  String get restStopsWidenedHint =>
      'Sin paradas con el filtro; mostramos las mejores del tramo.';

  @override
  String get windowsSheetTitle => 'Ventanas de salida';

  @override
  String get windowsSheetHint =>
      'Toca una tarjeta para replanificar con esa salida.';

  @override
  String get windowsSheetOpen => 'Ver detalle por hora';

  @override
  String get windowsBadgeCurrent => 'Tu hora';

  @override
  String get windowsBadgeRecommended => 'Recomendada';

  @override
  String get windowsMetaDuration => 'Duración';

  @override
  String get windowsMetaArrival => 'Llegada';

  @override
  String get windowsMetaTraffic => 'Tráfico';

  @override
  String get trafficLight => 'Ligero';

  @override
  String get trafficMedium => 'Moderado';

  @override
  String get trafficDense => 'Denso';

  @override
  String get todEarlyMorning => 'Madrugada';

  @override
  String get todMorning => 'Mañana';

  @override
  String get todNoon => 'Mediodía';

  @override
  String get todAfternoon => 'Tarde';

  @override
  String get todNight => 'Noche';

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
  String get timeWindowTapHint =>
      'Toca una barra para recalcular con esa hora de salida.';

  @override
  String get planLoadingRecalculating => 'Recalculando con tus ajustes...';

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
      'Escaneando incendios, inundaciones, temporal grave y peligros…';

  @override
  String get planLoadingStepTolls =>
      'Comparando rutas con peaje y alternativas sin peaje…';

  @override
  String get planLoadingStepAlmost => 'Casi listo — juntando todo para ti…';

  @override
  String get planLoadingHelper =>
      'Puede tardar hasta varios minutos. Puedes guardar el móvil un momento.';

  @override
  String timeWindowApplyLabel(String time) {
    return 'Aplicar · salida a las $time';
  }

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
  String get emptyAlertsTitle => 'Sin peligros graves detectados';

  @override
  String get emptyAlertsBody =>
      'No detectamos incendios, inundaciones ni peligros graves en tu corredor. Buen viaje.';

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
  String get emptyRestaurantsNotFoundTitle =>
      'Sin restaurantes cerca de la ruta';

  @override
  String get emptyRestaurantsNotFoundBody =>
      'El buscador no encontró opciones. Prueba a ampliar la desviación máxima en Preferencias.';

  @override
  String get emptyFuelNotFoundTitle => 'Sin datos de gasolina en esta zona';

  @override
  String get emptyFuelNotFoundBody =>
      'Los proveedores no cubren esta ruta. Los precios reales aparecerán en zonas con datos oficiales.';

  @override
  String get onboardEyebrowFuel => 'PEAJES Y COMBUSTIBLE';

  @override
  String get onboardTitleFuel =>
      '¿Salto este peaje?\n¿Reposto antes de Francia?';

  @override
  String get onboardBodyFuel =>
      'Te decimos qué peajes vale la pena saltar según la hora, y qué gasolinera de tu ruta tiene el mejor precio ahora mismo.';

  @override
  String get onboardEyebrowDriving => 'COPILOTO IA · PREMIUM';

  @override
  String get onboardTitleDriving => '\"¿Paro a repostar\naquí o espero?\"';

  @override
  String get onboardBodyDriving =>
      'Conoce tu ruta, tu depósito y los precios siguientes. Responde en segundos. Funciona con Android Auto. (Premium)';

  @override
  String get onboardEyebrowProfile => 'PERSONALIZADO';

  @override
  String get onboardTitleProfile => 'Rellena tu perfil';

  @override
  String get onboardBodyProfile =>
      'Sin perfil optimizamos solo tiempo. Con perfil calculamos fuel real, hoteles y comidas ajustadas a ti.';

  @override
  String get onboardTollSkip => 'Saltarlo';

  @override
  String get onboardTollSavingsAmt => 'ahorra €8';

  @override
  String get onboardTollPay => 'Pagarlo';

  @override
  String get onboardTollPeakTime => 'Pico 08:00-10:00';

  @override
  String get onboardFuelStationsTitle => 'Gasolineras en tu ruta';

  @override
  String get onboardProfileGroup => '2 adultos + 1 niño';

  @override
  String get onboardProfilePet => 'Perro';

  @override
  String get onboardProfileParking => 'Parking';

  @override
  String get onboardProfileStars => '3+ estrellas';

  @override
  String get onboardProfileBudget => 'Máx. €€';

  @override
  String get onboardCompanionNextStop => 'Próxima parada';

  @override
  String get onboardCompanionTank => 'Depósito';

  @override
  String get onboardAlertFire =>
      'Incendio forestal · km 214 · 14 km de tu ruta';

  @override
  String get onboardAlertSevere => 'SEVERO';

  @override
  String get onboardAlertStorm => 'Tormenta fuerte · Girona · próx. 2h';

  @override
  String get onboardAlertWarning => 'AVISO';

  @override
  String get onboardCompanionQuestion => '¿Paro a repostar aquí o espero?';

  @override
  String get onboardCompanionFuelStation => 'Eroski · km 387 — 1.52 €/L';

  @override
  String get onboardCompanionFuelAdvice =>
      'La siguiente estación en 58 km cuesta 1.79 €/L.\nCon tu depósito actual llegas de sobra.';

  @override
  String get onboardFuelStation1 => 'Eroski · km 387';

  @override
  String get onboardFuelStation2 => 'BP Autovía · km 412';

  @override
  String get onboardFuelStation3 => 'Shell A-1 · km 445';

  @override
  String get onboardHotelName => 'Hotel Castilla ★★★';

  @override
  String get onboardHotelMeta => '€85/noche · 0.8 km';

  @override
  String get onboardHotelAttrs => 'Parking ✓  Perros ✓';

  @override
  String get onboardRestaurantName => 'La Posada del Oso';

  @override
  String get onboardRestaurantMeta => '€14/menú · 2 min';

  @override
  String get onboardRestaurantAttrs => 'Terraza ✓  Perros ✓';

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
  String get hotelPrefDestRadiusLabel => 'Radio desde el destino';

  @override
  String get biometricPromptReason =>
      'Verifica tu identidad para abrir MyTravelPal';

  @override
  String get biometricPromptSettings =>
      'Confirma para activar el desbloqueo biométrico';

  @override
  String get planDepartureLabel => 'Salida preferida';

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
  String get hotelFilterOtherTypes => 'Apartamentos, casas y más';

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
  String get tripCostNoExpense => 'Sin gasto';

  @override
  String get replanLostTitle =>
      'Algunas selecciones ya no encajan en la nueva ruta';

  @override
  String get replanLostBody =>
      'Al cambiar los kilómetros, estas selecciones ya no corresponden a la ruta. Si continúas se desmarcarán y te ofreceremos otras opciones. Si cancelas, tu plan actual se queda como está.';

  @override
  String replanLostHotel(String name, int day) {
    return 'Hotel: $name · día $day';
  }

  @override
  String replanLostRestaurant(String name) {
    return 'Restaurante: $name';
  }

  @override
  String replanLostFuel(String name) {
    return 'Gasolinera: $name';
  }

  @override
  String replanLostMeal(String name) {
    return 'Parada de comida: $name';
  }

  @override
  String replanLostSleep(String name) {
    return 'Parada para dormir: $name';
  }

  @override
  String get styleKmCapNone => 'Máx. km/día: sin límite';

  @override
  String styleKmCapValue(int km) {
    return 'Máx. km/día: $km km';
  }

  @override
  String get styleKmCapRemove => 'Quitar límite de km';

  @override
  String get purchaseBetaNote =>
      'Beta cerrada: al tocar un plan se simula la suscripción. No se cobra nada.';

  @override
  String purchaseBetaApplied(String plan) {
    return 'Beta: plan $plan aplicado (simulado)';
  }

  @override
  String get settingsBetaAccess => 'ACCESO BETA';

  @override
  String get settingsTierFreeName => 'Gratuito';

  @override
  String get myPlacesTitle => 'Mis sitios';

  @override
  String myPlacesSettingsRow(int count) {
    return 'Mis sitios ($count)';
  }

  @override
  String get myPlacesSettingsSub => 'Sitios donde te gusta parar';

  @override
  String get myPlacesEmpty =>
      'Guarda los sitios donde te gusta parar. Cuando una ruta pase cerca de uno, te lo sugeriremos.';

  @override
  String get myPlacesAdd => 'Añadir un sitio';

  @override
  String get myPlacesSearchHint => 'Busca un sitio o pega un enlace de mapa';

  @override
  String get myPlacesSearch => 'Buscar';

  @override
  String get myPlacesNoResults =>
      'No hemos encontrado nada. Prueba con otro nombre o pega un enlace que incluya coordenadas.';

  @override
  String get myPlacesNameLabel => 'Nombre';

  @override
  String get myPlacesNoteLabel => 'Nota (opcional)';

  @override
  String get myPlacesCategoryLabel => 'Categoría';

  @override
  String get myPlacesSave => 'Guardar sitio';

  @override
  String myPlacesRemoved(String name) {
    return '$name eliminado';
  }

  @override
  String get myPlacesUndo => 'Deshacer';

  @override
  String myPlacesLimit(int max) {
    return 'Puedes guardar hasta $max sitios.';
  }

  @override
  String get myPlacesFromLink => 'Sitio del enlace';

  @override
  String get myPlacesCatFood => 'Comida';

  @override
  String get myPlacesCatViewpoint => 'Mirador';

  @override
  String get myPlacesCatCulture => 'Cultura';

  @override
  String get myPlacesCatNature => 'Naturaleza';

  @override
  String get myPlacesCatKids => 'Con niños';

  @override
  String get myPlacesCatOther => 'Otro';

  @override
  String get myPlacesOnRouteTitle => 'Tus sitios en esta ruta';

  @override
  String myPlacesOffRoute(String km, int min) {
    return 'A $km km de la ruta · ~$min min';
  }

  @override
  String get myPlacesAddToRoute => 'Añadir';

  @override
  String get myPlacesRemoveFromRoute => 'Quitar';

  @override
  String get companionJoinTitle => 'Unirme como pasajero';

  @override
  String get companionJoinHint => 'Código de 6 caracteres';

  @override
  String get companionJoinButton => 'Unirme';

  @override
  String get companionJoinCodeInvalid => 'El código debe tener 6 caracteres';

  @override
  String get passengerViewTitle => 'Companion — Pasajero';

  @override
  String passengerViewCode(String code) {
    return 'Código: $code';
  }

  @override
  String get passengerViewSpeed => 'Velocidad del conductor';

  @override
  String get passengerViewNextStop => 'Próxima parada';

  @override
  String get passengerViewDestination => 'Destino';

  @override
  String get passengerViewRefresh => 'Actualizando cada 5 s';

  @override
  String passengerViewRadarBanner(String meters) {
    return 'Radar a $meters m';
  }

  @override
  String get passengerViewSlowDown => 'Reduce la velocidad';

  @override
  String passengerViewRadarAhead(String distance) {
    return 'Radar en $distance';
  }

  @override
  String get replanLostConfirm => 'Continuar y desmarcar';

  @override
  String get replanLostCancel => 'Mantener el plan actual';

  @override
  String tripCostPerPerson(String amount) {
    return '$amount / persona';
  }

  @override
  String tripCostPerDay(String amount) {
    return '$amount / día';
  }

  @override
  String get poiSpotlightRating => 'valoración';

  @override
  String get poiSpotlightStars => 'estrellas';

  @override
  String poiSpotlightReviews(String count) {
    return '$count reseñas';
  }

  @override
  String get poiSpotlightPricePerNight => 'por noche';

  @override
  String get poiSpotlightPricePerMeal => 'por comida';

  @override
  String get poiSpotlightPricePerL => 'por litro';

  @override
  String get poiFeaturesHeading => 'Servicios';

  @override
  String get poiMoreInfoLabel => 'Más info';

  @override
  String get poiMoreInfoHide => 'Ocultar';

  @override
  String get poiNoExtraInfo => 'Sin información adicional de OSM.';

  @override
  String poiOpenError(String url) {
    return 'No se pudo abrir $url';
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
  String get poiCtaCall => 'Llamar';

  @override
  String get poiCtaWebsite => 'Web';

  @override
  String get poiContactAddress => 'Dirección';

  @override
  String get poiContactPhone => 'Teléfono';

  @override
  String get poiContactWebsite => 'Web';

  @override
  String get poiContactHours => 'Horario';

  @override
  String get poiContactCheckin => 'Entrada';

  @override
  String get poiContactCheckout => 'Salida';

  @override
  String get poiAttr_wifi => 'WiFi';

  @override
  String get poiAttr_parking => 'Parking';

  @override
  String get poiAttr_pool => 'Piscina';

  @override
  String get poiAttr_airConditioning => 'Aire acondicionado';

  @override
  String get poiAttr_breakfast => 'Desayuno incluido';

  @override
  String get poiAttr_petFriendly => 'Mascotas admitidas';

  @override
  String get poiAttr_childFriendly => 'Apto niños';

  @override
  String get poiAttr_wheelchairAccess => 'Accesible silla de ruedas';

  @override
  String get poiAttr_toilets => 'Aseos';

  @override
  String get poiAttr_restaurant => 'Restaurante';

  @override
  String get poiAttr_bar => 'Bar';

  @override
  String get poiAttr_shop => 'Tienda';

  @override
  String get poiAttr_outdoorSeating => 'Terraza';

  @override
  String get poiAttr_takeaway => 'Para llevar';

  @override
  String get poiAttr_delivery => 'Reparto a domicilio';

  @override
  String get poiAttr_creditCards => 'Tarjetas aceptadas';

  @override
  String get poiAttr_carWash => 'Lavado de coches';

  @override
  String get poiAttr_smoking => 'Zona de fumadores';

  @override
  String get poiAttr_nonSmoking => 'Sin humos';

  @override
  String get poiAttr_elevator => 'Ascensor';

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
  String get poiAttr_dietGlutenFree => 'Sin gluten';

  @override
  String get poiAttr_dog => 'Mascotas bienvenidas';

  @override
  String get poiAttr_brand => 'Marca';

  @override
  String get poiAttr_city => 'Ciudad';

  @override
  String get poiAttr_street => 'Calle';

  @override
  String get poiAttr_address => 'Dirección';

  @override
  String get poiAttr_openingHours => 'Horario';

  @override
  String get poiAttr_name => 'Nombre';

  @override
  String get poiAttr_phone => 'Teléfono';

  @override
  String get poiAttr_stars => 'Estrellas';

  @override
  String get poiAttr_website => 'Sitio web';

  @override
  String get poiPickerChoose => 'Elegir';

  @override
  String get poiPickerSelected => 'Seleccionado';

  @override
  String get poiPickerHotels => 'Ver alternativas';

  @override
  String get poiPickerRestaurants => 'Ver restaurantes cercanos';

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
  String get weatherNoData => 'Sin datos de clima disponibles para esta ruta';

  @override
  String get weatherAllClear => 'Sin alertas';

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
  String get resultStartCompanion =>
      'Iniciar Asistente de conducción (Premium)';

  @override
  String get companionPreflightTitle => 'Ajustes antes de conducir';

  @override
  String get companionPreflightMealWindows => 'Horarios de comida';

  @override
  String get companionPreflightDetourTolerance => 'Desvío máximo';

  @override
  String get companionPreflightMealBudget => 'Presupuesto por comida';

  @override
  String get companionPreflightHotelBudget => 'Presupuesto por noche';

  @override
  String get companionPreflightSaveToProfile => 'Guardar en mi perfil';

  @override
  String get companionPreflightStart => 'Empezar a conducir';

  @override
  String get companionPreflightBreakfast => 'Desayuno';

  @override
  String get companionPreflightLunch => 'Almuerzo';

  @override
  String get companionPreflightDinner => 'Cena';

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

  @override
  String get resultOptimalDeparture => 'Tu hora de salida es óptima';

  @override
  String shortLastDayWarning(String km) {
    return 'Último tramo corto ($km km) — podrías llegar hoy si avanzas más el día anterior.';
  }

  @override
  String get prepareDepartureNow => 'Salir ahora';

  @override
  String get replanNewDepartureTitle => 'Calculando con nueva hora de salida…';

  @override
  String get planStopReorderHint => 'Mantén pulsado el asa para reordenar';

  @override
  String get planSwapOriginDestination => 'Invertir';

  @override
  String get planStopMoveUp => 'Mover arriba';

  @override
  String get planStopMoveDown => 'Mover abajo';

  @override
  String get recentTripsTitle => 'Viajes recientes';

  @override
  String recentTripsSubtitle(int count) {
    return '$count guardados — toca para reutilizar';
  }

  @override
  String recentTripsSeeAll(int n) {
    return 'Ver los $n viajes restantes en Mis viajes';
  }

  @override
  String get onRouteTitle => 'En la ruta';

  @override
  String get onRouteEmpty => 'Toca para elegir opciones';

  @override
  String get exportShareTitle => 'Compartir ruta';

  @override
  String get exportOpenInMaps => 'Abrir en Google Maps';

  @override
  String get exportOpenInMapsSub => 'Con paradas y desvíos añadidos';

  @override
  String get exportCopyLink => 'Copiar enlace';

  @override
  String get exportLinkCopied => 'Enlace copiado al portapapeles';

  @override
  String get exportShareOs => 'Compartir…';

  @override
  String get exportShareSubject => 'Mi ruta en MyTravelPal';

  @override
  String get importFromMaps => 'Importar de Maps';

  @override
  String get importFromMapsTitle => 'Importar ruta de Google Maps';

  @override
  String get importFromMapsHint => 'Pega aquí el enlace de Google Maps';

  @override
  String get importFromMapsPaste => 'Pegar';

  @override
  String get importFromMapsImport => 'Importar';

  @override
  String get importFromMapsError => 'URL no reconocida';

  @override
  String get importFromMapsErrorMalformed =>
      'URL no válida — revisa el enlace e inténtalo de nuevo';

  @override
  String get importFromMapsErrorShortlink =>
      'No se pudo expandir el enlace corto — ábrelo en Maps y copia la URL completa';

  @override
  String get importFromMapsErrorGeocode =>
      'No se pudieron localizar los lugares en el mapa — prueba con una ruta más corta o escríbelos a mano';

  @override
  String get importFromMapsLoading => 'Analizando enlace…';

  @override
  String adverseEventsBannerCount(int count) {
    return '$count alerta(s) en tu ruta';
  }

  @override
  String pricePerMeal(String price) {
    return '$price €/comida';
  }

  @override
  String kmFromOrigin(String km) {
    return '$km km desde el origen';
  }

  @override
  String get profileVehicleModel => 'Modelo';

  @override
  String get profileVehicleModelHint => 'Elige tu modelo';

  @override
  String get profileVehicleModelClear => 'Quitar modelo';

  @override
  String get profileTankLevel => 'Depósito actual';

  @override
  String get vehiclePickerSearchHint => 'Buscar marca o modelo';

  @override
  String get vehiclePickerEmpty => 'Ningún modelo coincide con la búsqueda';

  @override
  String get vehiclePickerLoadError =>
      'No se pudo cargar el listado. Inténtalo más tarde.';

  @override
  String get vehiclePickerCustomOption => 'Vehículo personalizado';

  @override
  String get vehiclePickerCustomOptionSubtitle =>
      'Introduce el depósito y consumo manualmente';

  @override
  String get vehicleCustomTitle => 'Vehículo personalizado';

  @override
  String get vehicleCustomName => 'Nombre del vehículo (opcional)';

  @override
  String get vehicleCustomNameHint => 'ej. Mi SUV';

  @override
  String get vehicleCustomTank => 'Depósito (L)';

  @override
  String get vehicleCustomTankEv => 'Batería (kWh)';

  @override
  String get vehicleCustomConsumption => 'Consumo (L/100 km)';

  @override
  String get vehicleCustomConsumptionEv => 'Consumo (kWh/100 km)';

  @override
  String get vehicleCustomSave => 'Usar personalizado';

  @override
  String refuelWindowComfortable(String km) {
    return 'Reposta antes del km $km (cómodo)';
  }

  @override
  String refuelWindowCritical(String km) {
    return 'Reposta antes del km $km (crítico)';
  }

  @override
  String get refuelSuggestionTitle => 'Reposta aquí para ahorrar';

  @override
  String refuelSuggestionBody(String station, String km, String price) {
    return '$station · km $km · €$price/L';
  }

  @override
  String refuelSuggestionSavings(String eur) {
    return 'Te ahorras $eur €';
  }

  @override
  String savingsFuelRow(String eur) {
    return 'Combustible: $eur €';
  }

  @override
  String get garageTitle => 'Mi garaje';

  @override
  String get garageEmpty => 'Aún no hay coches — añade el primero';

  @override
  String get garageAdd => 'Añadir coche';

  @override
  String get garageEdit => 'Editar coche';

  @override
  String get garageDelete => 'Eliminar';

  @override
  String get garageCancel => 'Cancelar';

  @override
  String get garageSave => 'Guardar';

  @override
  String get garageDefaultName => 'Mi coche';

  @override
  String get garageNameHint => 'Ponle nombre (ej. Mi Golf)';

  @override
  String get garageDefaultTankLabel => 'Nivel de depósito por defecto';

  @override
  String get garageDefaultChargeLevelLabel => 'Nivel de carga inicial';

  @override
  String get garageAddError => 'No se pudo guardar. Inténtalo otra vez.';

  @override
  String get garageDeleteTitle => '¿Eliminar coche?';

  @override
  String garageDeleteBody(String name) {
    return '\"$name\" se borrará de tu garaje.';
  }

  @override
  String garageSettingsRow(int count) {
    return 'Mi garaje ($count)';
  }

  @override
  String planScreenGarageChip(String name, int pct) {
    return 'Coche: $name · $pct %';
  }

  @override
  String get planScreenGarageChooseVehicle => 'Elige un coche para este viaje';

  @override
  String get hotelArbitrageTitle => 'Hoteles más baratos al lado';

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
      other: '$nightsString noches',
      one: 'una noche',
    );
    return 'Esta noche cae en $dear, ~$dearPrice€/noche. En $cheap son ~$cheapPrice€ ($pct% menos). Mueve $_temp0 y ahorras ~$savings€.';
  }

  @override
  String get hotelArbitrageMiniHint =>
      'Mismo ahorro si mueves esta noche también al sur';

  @override
  String get whatsNewSheetTitle => 'Novedades';

  @override
  String get whatsNewSheetDismiss => 'Entendido';

  @override
  String get profileChipChangeVehicle => 'Cambiar vehículo';

  @override
  String get profileChipEditProfile => 'Editar perfil del viaje';

  @override
  String get whatsNewSheetSuggest => 'Sugerir algo';

  @override
  String get feedbackSheetTitle => 'Sugerencias';

  @override
  String get feedbackSheetSubtitle =>
      'Cuéntanos qué haría MyTravelPal mejor para ti. Leemos cada mensaje.';

  @override
  String get feedbackBodyHint => '¿Qué cambiarías o añadirías?';

  @override
  String get feedbackWantReply => 'Quiero respuesta';

  @override
  String get feedbackEmailHint => 'Tu email (opcional)';

  @override
  String get feedbackSendButton => 'Enviar';

  @override
  String get feedbackThanks => '¡Gracias! Lo tenemos.';

  @override
  String get feedbackErrorEmpty => 'Cuéntanos un poco más (mín. 3 caracteres)';

  @override
  String get feedbackErrorEmail => 'Ese email no parece válido';

  @override
  String get feedbackErrorSend =>
      'No pudimos enviarlo. Reintenta en un momento.';

  @override
  String get settingsSendFeedback => 'Enviar una sugerencia';

  @override
  String get settingsSendFeedbackSubtitle => 'Cuéntanos qué construir';

  @override
  String get enrichPulseRestStops =>
      'Buscando áreas de descanso a lo largo de la ruta';

  @override
  String get exitAppTitle => '¿Salir de MyTravelPal?';

  @override
  String get exitAppBody => '¿Seguro que quieres cerrar la app?';

  @override
  String get exitAppBodyCompanionActive =>
      'El modo Companion está activo. Si sales ahora, la sesión de conducción sigue en segundo plano. Detenla desde la pestaña Companion si quieres cerrarla limpiamente.';

  @override
  String get exitAppStay => 'Quedarme';

  @override
  String get exitAppLeave => 'Salir';

  @override
  String get enrichPulseChargers =>
      'Localizando electrolineras a lo largo de la ruta';

  @override
  String get advEventLabelSource => 'Fuente';

  @override
  String get advEventLabelReported => 'Detectado';

  @override
  String get advEventLabelExpires => 'Válido hasta';

  @override
  String get advEventLabelDuration => 'Duración estimada';

  @override
  String get advEventSourceWeather => 'Previsión meteorológica (Open-Meteo)';

  @override
  String get advEventSourceOfficial => 'Feed oficial';

  @override
  String get advEventSourceEffis => 'Monitor de incendios EFFIS';

  @override
  String get advEventSourceUsgs => 'Feed sísmico USGS';

  @override
  String get advEventSourceUser => 'Aviso comunidad';

  @override
  String get advEventSourceMock => 'Simulado (dev)';

  @override
  String advEventDurationHours(String h) {
    return '$h h';
  }

  @override
  String advEventDurationDays(String d, String h) {
    return '$d d $h h';
  }

  @override
  String get advEventDurationOngoing => 'En curso';

  @override
  String get exportShareMtp => 'Compartir con usuarios de MyTravelPal';

  @override
  String get exportShareMtpSubtitle =>
      'Abre directamente en la app — ellos eligen sus preferencias';

  @override
  String exportShareMtpSubject(String origin, String destination) {
    return '$origin → $destination | MyTravelPal';
  }

  @override
  String get resultFuelStationsOnRoute => 'Gasolineras en ruta';

  @override
  String get resultFuelSavingsAccordionTitle => 'Ahorro en combustible';

  @override
  String get resultTimeSavingsOptimal => 'Tu hora de salida es óptima';

  @override
  String get hotelMapFullscreenTitle => 'Hoteles en la zona';

  @override
  String get restaurantMapFullscreenTitle => 'Restaurantes en la zona';

  @override
  String get tollSummaryTitle => 'Peajes del trayecto';

  @override
  String get tollSummaryMapButton => 'Ver en mapa';

  @override
  String activitiesCtaTitle(Object city) {
    return 'Qué hacer en $city';
  }

  @override
  String get activitiesCtaSubtitle => 'Actividades y experiencias locales';

  @override
  String get planIncludeActivities => 'Actividades en el destino';

  @override
  String get planIncludeActivitiesHint =>
      'Sugerencias de GetYourGuide en cada ciudad';

  @override
  String get aiPrefScenicRoutes => 'Prefiero rutas panorámicas';

  @override
  String get aiPrefScenicRoutesSub =>
      'Recomendar desvíos por miradores y puertos';

  @override
  String get aiPrefEcoConscious => 'Conducción eco';

  @override
  String get aiPrefEcoConsciousSub =>
      'Preferir EVs, evitar autopistas cuando sea posible';

  @override
  String get aiPrefLocalFood => 'Comida local primero';

  @override
  String get aiPrefLocalFoodSub =>
      'Priorizar restaurantes locales sobre cadenas';

  @override
  String get aiPrefDepartureHour => 'Hora habitual de salida';

  @override
  String get aiPrefDietary => 'RESTRICCIONES DIETÉTICAS';

  @override
  String get aiPrefInterests => 'INTERESES';

  @override
  String get aiDietVegetarian => 'Vegetariano';

  @override
  String get aiDietVegan => 'Vegano';

  @override
  String get aiDietGlutenFree => 'Sin gluten';

  @override
  String get aiDietHalal => 'Halal';

  @override
  String get aiInterestCulture => 'Cultura';

  @override
  String get aiInterestNature => 'Naturaleza';

  @override
  String get aiInterestGastronomy => 'Gastronomía';

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
    return 'Paro cada $n';
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
  String get wizardTollFreeDetour => 'Desvío libre';

  @override
  String get wizardTollMotorway => 'Autopista';

  @override
  String get wizardTollFaster => 'Más rápido';

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
      'Copiloto IA · Recomienda peajes alternativos, restaurantes según tus gustos y gasolineras baratas en tiempo real · Premium';

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
      'Mide si la ruta tiene geometría válida y si se han planificado las paradas de descanso obligatorias (normativa EU: pausa cada 4,5h).';

  @override
  String get tripQualityExplainFuel =>
      'Indica si hay precios de gasolina disponibles en tu ruta y si has añadido la gasolinera óptima. Penaliza si hay estaciones disponibles pero no has seleccionado ninguna.';

  @override
  String get tripQualityExplainHotels =>
      'Evalúa si hay hoteles disponibles para las noches del viaje y si has seleccionado dónde dormir. Un hotel sin seleccionar es una noche sin reservar.';

  @override
  String get tripQualityExplainWeather =>
      'Analiza las condiciones meteorológicas a lo largo de la ruta. Verde = condiciones favorables. Amarillo = lluvia o niebla. Rojo = tormenta o nieve.';

  @override
  String get tripQualityExplainAlerts =>
      'Cuenta los eventos adversos activos en o cerca de tu ruta: incendios, tormentas, terremotos, cierres de carretera. Cero alertas = puntuación máxima.';

  @override
  String get tripQualityExplainTolls =>
      'Evalúa si hay datos de peajes disponibles para tu ruta y si puedes optimizar qué peajes pagar o saltarte. Sin datos de peajes = penalización parcial.';

  @override
  String get tripQualityFactorTollTime => 'Tiempo extra';

  @override
  String get tripQualityExplainTollTime =>
      'Compara el dinero que ahorras al saltarte peajes con el tiempo extra que añaden. Baja cuando pierdes mucho tiempo por poco dinero: menos de 25 € ahorrados por cada hora extra.';

  @override
  String get tripQualityExplainStops =>
      'Mide si has planificado las paradas de comida y descanso. Para el ritmo \'saveur\' o con niños/mascotas, las paradas son importantes para el confort del viaje.';

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
    return 'Límite: ${n}h';
  }

  @override
  String tripDayBarsUnselected(int n) {
    return '$n parada(s) sin añadir';
  }

  @override
  String get tripDayBarsHint => 'Toca + para incluirlas en la duración total';

  @override
  String get tripDayBarsCapLabel => 'Cap';

  @override
  String get tripDayBarsTitle => 'Distribución por etapas';

  @override
  String get wizardStepProfile => 'Perfil';

  @override
  String get wizardStepVehicle => 'Vehículo';

  @override
  String get wizardStepRhythm => 'Ritmo';

  @override
  String get wizardStepBudget => 'Presupuesto';

  @override
  String wizardModelsAvailable(int count) {
    return '$count modelos disponibles';
  }

  @override
  String wizardModelsMore(int count) {
    return '+$count — busca por nombre';
  }

  @override
  String get wizardTollSavingsDemo => 'Ahorro €8';

  @override
  String companionNotifFuelBody(int km) {
    return 'A $km km · Toca \"Desviar\" para añadirla a tu ruta en Maps';
  }

  @override
  String get companionDemoNotifFuel => 'A 3 km · Desvía en Maps para repostar';

  @override
  String get companionDemoNotifRoute =>
      'A 18 km en tu ruta · Considera la N-II · Desviar en Maps';

  @override
  String get companionDemoNotifMeal =>
      'Menú €12 · A 4 km · ¿Paramos a comer? Desviar en Maps';

  @override
  String get companionDemoNotifEta => 'ETA en 10 min · 12 km · Sin incidencias';

  @override
  String get companionOffRouteTitle => '¿Estás fuera de la ruta?';

  @override
  String get companionOffRouteBody =>
      'Tu posición está lejos de la ruta planificada. En modo libre el asistente sigue contigo sin calcular km de ruta.';

  @override
  String get companionOffRouteBack => 'Volver a la ruta';

  @override
  String get companionFreeModeBtn => 'Modo libre';

  @override
  String companionGroupSessionError(String error) {
    return 'No se pudo crear la sesión grupal: $error';
  }

  @override
  String get companionMealStopTitle => 'Cambiar parada de comida';

  @override
  String get companionMealStopDelayBody =>
      '¿Quieres retrasar la parada de comida? La moveremos al siguiente área de servicio.';

  @override
  String get settingsLogoutStep3 => '3/4 · Cerrando sesión…';

  @override
  String get settingsLogoutStep4 => '4/4 · Volviendo al inicio…';

  @override
  String get settingsNickTaken => 'Ya está en uso';

  @override
  String get settingsNickHelper =>
      'Tu nombre en el ranking de rutas. Elige un nick y tu país — solo visible en el Hall of Fame.';

  @override
  String get settingsNickEmpty => 'Sin nick aún';

  @override
  String get settingsCountrySearch => 'Buscar país...';

  @override
  String get settingsPremiumDevNote => 'Se activará por compra en producción';

  @override
  String get settingsTierFeaturesPremium =>
      '✓ Companion IA · Peajes optimizados · Android Auto · Grupos · Monitor de viaje';

  @override
  String get settingsTierFeaturesEssential =>
      '✓ Gasolineras óptimas · Peajes básicos · Alertas adversas · Radares';

  @override
  String get settingsTierFeaturesFree =>
      'Solo planificación básica · Sin optimización de combustible ni peajes';

  @override
  String resultStationAdded(String name) {
    return '$name añadida · estimación de depósito actualizada en los días siguientes';
  }

  @override
  String get resultRestStopFallback => 'Parada de descanso';

  @override
  String get resultTooltipProfile => 'Perfil y vehículo';

  @override
  String get resultRecalculating => 'Recalculando con tus nuevos ajustes…';

  @override
  String resultPlanReady(int km, int h, int m) {
    return 'Plan listo · $km km · ${h}h ${m}m';
  }

  @override
  String get resultGenericConsumptionHint =>
      'Cálculo con consumo genérico. Configura tu vehículo para mayor precisión.';

  @override
  String resultFuelSavingsPct(int pct) {
    return '$pct% del coste';
  }

  @override
  String get resultChartAdded => '  añadido';

  @override
  String get resultSettingsChangedBody =>
      'Tus ajustes han cambiado. ¿Recalcular con los nuevos valores?';

  @override
  String resultSummaryStops(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paradas',
      one: '$count parada',
    );
    return '$_temp0';
  }

  @override
  String resultFuelStationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gasolineras',
      one: '$count gasolinera',
    );
    return '$_temp0';
  }

  @override
  String resultSummaryTolls(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count peajes saltados',
      one: '$count peaje saltado',
    );
    return '$_temp0';
  }

  @override
  String resultSummaryHotels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hoteles',
      one: '$count hotel',
    );
    return '$_temp0';
  }

  @override
  String get resultGyGError => 'No se pudo abrir GetYourGuide';

  @override
  String resultGyGActivities(String city) {
    return 'Ver actividades en $city';
  }
}
