import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ca.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ca'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('pt')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'MyTravelPal'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Plan the drive, not just the destination'**
  String get appTagline;

  /// No description provided for @onboardEyebrowKiller.
  ///
  /// In en, this message translates to:
  /// **'THE MISSING FEATURE'**
  String get onboardEyebrowKiller;

  /// No description provided for @onboardTitleKiller.
  ///
  /// In en, this message translates to:
  /// **'Leave at the right time'**
  String get onboardTitleKiller;

  /// No description provided for @onboardBodyKiller.
  ///
  /// In en, this message translates to:
  /// **'We look at historic traffic around your desired departure and show you the sweet spot — sometimes leaving 30 minutes earlier saves you 90.'**
  String get onboardBodyKiller;

  /// No description provided for @onboardEyebrowHonest.
  ///
  /// In en, this message translates to:
  /// **'HONEST PLANNING'**
  String get onboardEyebrowHonest;

  /// No description provided for @onboardTitleHonest.
  ///
  /// In en, this message translates to:
  /// **'Every cost, up front'**
  String get onboardTitleHonest;

  /// No description provided for @onboardBodyHonest.
  ///
  /// In en, this message translates to:
  /// **'Toll totals, cheapest fuel and EV charging along the route, suggested stops, and hotels or restaurants at the exact detour you can afford.'**
  String get onboardBodyHonest;

  /// No description provided for @onboardEyebrowAlerts.
  ///
  /// In en, this message translates to:
  /// **'STAY AWARE'**
  String get onboardEyebrowAlerts;

  /// No description provided for @onboardTitleAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts that matter'**
  String get onboardTitleAlerts;

  /// No description provided for @onboardBodyAlerts.
  ///
  /// In en, this message translates to:
  /// **'Fires, floods, severe weather, earthquakes — serious hazards only, and only when they actually touch your route.'**
  String get onboardBodyAlerts;

  /// No description provided for @onboardSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardSkip;

  /// No description provided for @onboardContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardContinue;

  /// No description provided for @onboardGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardGetStarted;

  /// No description provided for @onboardFooter.
  ///
  /// In en, this message translates to:
  /// **'Free to start · Premium unlocks the AI trip briefing'**
  String get onboardFooter;

  /// No description provided for @loginContinueApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get loginContinueApple;

  /// No description provided for @loginContinueGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get loginContinueGoogle;

  /// No description provided for @loginContinueFacebook.
  ///
  /// In en, this message translates to:
  /// **'Continue with Facebook'**
  String get loginContinueFacebook;

  /// No description provided for @loginContinueDemo.
  ///
  /// In en, this message translates to:
  /// **'Continue as demo'**
  String get loginContinueDemo;

  /// No description provided for @loginDivider.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get loginDivider;

  /// No description provided for @loginTerms.
  ///
  /// In en, this message translates to:
  /// **'By continuing you accept our terms and privacy policy.'**
  String get loginTerms;

  /// No description provided for @loginBusy.
  ///
  /// In en, this message translates to:
  /// **'Signing you in…'**
  String get loginBusy;

  /// No description provided for @planTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan a road trip'**
  String get planTitle;

  /// No description provided for @planEyebrow.
  ///
  /// In en, this message translates to:
  /// **'THE PLANNER'**
  String get planEyebrow;

  /// No description provided for @planHero.
  ///
  /// In en, this message translates to:
  /// **'Where are we going\ntoday?'**
  String get planHero;

  /// No description provided for @planHeroPersonal.
  ///
  /// In en, this message translates to:
  /// **'Hi {name}, where to?'**
  String planHeroPersonal(String name);

  /// No description provided for @planIntro.
  ///
  /// In en, this message translates to:
  /// **'Pick two points and a time. We handle the rest.'**
  String get planIntro;

  /// No description provided for @planFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get planFrom;

  /// No description provided for @planTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get planTo;

  /// No description provided for @planDesiredDeparture.
  ///
  /// In en, this message translates to:
  /// **'Desired departure'**
  String get planDesiredDeparture;

  /// No description provided for @planCta.
  ///
  /// In en, this message translates to:
  /// **'Plan trip'**
  String get planCta;

  /// No description provided for @planCtaBusy.
  ///
  /// In en, this message translates to:
  /// **'Planning your trip…'**
  String get planCtaBusy;

  /// No description provided for @planCountriesNote.
  ///
  /// In en, this message translates to:
  /// **'Countries are detected automatically from your route.'**
  String get planCountriesNote;

  /// No description provided for @planSectionOptional.
  ///
  /// In en, this message translates to:
  /// **'Along the route'**
  String get planSectionOptional;

  /// No description provided for @planMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get planMoreOptions;

  /// No description provided for @planLessOptions.
  ///
  /// In en, this message translates to:
  /// **'Fewer options'**
  String get planLessOptions;

  /// No description provided for @planRoundTripChip.
  ///
  /// In en, this message translates to:
  /// **'Round trip'**
  String get planRoundTripChip;

  /// No description provided for @planLeaveNowFabTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave now'**
  String get planLeaveNowFabTitle;

  /// No description provided for @leaveNowConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave now to'**
  String get leaveNowConfirmTitle;

  /// No description provided for @leaveNowConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Head to {name}?'**
  String leaveNowConfirmBody(Object name);

  /// No description provided for @leaveNowConfirmCta.
  ///
  /// In en, this message translates to:
  /// **'Let\'s go'**
  String get leaveNowConfirmCta;

  /// No description provided for @leaveNowConfirmChange.
  ///
  /// In en, this message translates to:
  /// **'Change destination'**
  String get leaveNowConfirmChange;

  /// No description provided for @settingsBiometric.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock'**
  String get settingsBiometric;

  /// No description provided for @settingsBiometricSub.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint or face to open the app'**
  String get settingsBiometricSub;

  /// No description provided for @settingsBiometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available on this device'**
  String get settingsBiometricUnavailable;

  /// No description provided for @settingsReplayTutorial.
  ///
  /// In en, this message translates to:
  /// **'Replay tutorial'**
  String get settingsReplayTutorial;

  /// No description provided for @settingsReplayTutorialSub.
  ///
  /// In en, this message translates to:
  /// **'Show the guided coach-marks again'**
  String get settingsReplayTutorialSub;

  /// No description provided for @settingsReplayTutorialToast.
  ///
  /// In en, this message translates to:
  /// **'Tutorial reset. Reopen Plan to see it.'**
  String get settingsReplayTutorialToast;

  /// No description provided for @settingsColorPreset.
  ///
  /// In en, this message translates to:
  /// **'Colour preset'**
  String get settingsColorPreset;

  /// No description provided for @settingsPresetForest.
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get settingsPresetForest;

  /// No description provided for @settingsPresetSunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get settingsPresetSunset;

  /// No description provided for @settingsPresetOcean.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get settingsPresetOcean;

  /// No description provided for @settingsDynamicColor.
  ///
  /// In en, this message translates to:
  /// **'Material You (dynamic)'**
  String get settingsDynamicColor;

  /// No description provided for @settingsDynamicColorSub.
  ///
  /// In en, this message translates to:
  /// **'Match colours to your wallpaper (Android 12+)'**
  String get settingsDynamicColorSub;

  /// No description provided for @settingsOled.
  ///
  /// In en, this message translates to:
  /// **'Pure black (OLED)'**
  String get settingsOled;

  /// No description provided for @settingsOledSub.
  ///
  /// In en, this message translates to:
  /// **'Deeper blacks in dark mode, saves battery on OLED screens'**
  String get settingsOledSub;

  /// No description provided for @parkingSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Find parking'**
  String get parkingSearchTitle;

  /// No description provided for @parkingSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Where are you going?'**
  String get parkingSearchLabel;

  /// No description provided for @parkingSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a destination and see parking nearby.'**
  String get parkingSearchHint;

  /// No description provided for @parkingRadiusLabel.
  ///
  /// In en, this message translates to:
  /// **'Radius'**
  String get parkingRadiusLabel;

  /// No description provided for @parkingNoResults.
  ///
  /// In en, this message translates to:
  /// **'No parking found within radius.'**
  String get parkingNoResults;

  /// No description provided for @parkingPriceUnknown.
  ///
  /// In en, this message translates to:
  /// **'Price ?'**
  String get parkingPriceUnknown;

  /// No description provided for @parkingCovered.
  ///
  /// In en, this message translates to:
  /// **'Covered'**
  String get parkingCovered;

  /// No description provided for @parkingFilterKids.
  ///
  /// In en, this message translates to:
  /// **'Kids'**
  String get parkingFilterKids;

  /// No description provided for @parkingFilterDogs.
  ///
  /// In en, this message translates to:
  /// **'Dogs'**
  String get parkingFilterDogs;

  /// No description provided for @parkingFilterToilets.
  ///
  /// In en, this message translates to:
  /// **'Toilets'**
  String get parkingFilterToilets;

  /// No description provided for @parkingFilterFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get parkingFilterFood;

  /// No description provided for @parkingFilterShowers.
  ///
  /// In en, this message translates to:
  /// **'Showers'**
  String get parkingFilterShowers;

  /// No description provided for @parkingFilterEv.
  ///
  /// In en, this message translates to:
  /// **'EV charger'**
  String get parkingFilterEv;

  /// No description provided for @parkingFilterFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get parkingFilterFuel;

  /// No description provided for @parkingFilterWheelchair.
  ///
  /// In en, this message translates to:
  /// **'Wheelchair'**
  String get parkingFilterWheelchair;

  /// No description provided for @parkingFilterRv.
  ///
  /// In en, this message translates to:
  /// **'RV / camper'**
  String get parkingFilterRv;

  /// No description provided for @parkingFilterTruck.
  ///
  /// In en, this message translates to:
  /// **'Truck'**
  String get parkingFilterTruck;

  /// No description provided for @planFindParkingCta.
  ///
  /// In en, this message translates to:
  /// **'Find parking'**
  String get planFindParkingCta;

  /// No description provided for @poiFindParking.
  ///
  /// In en, this message translates to:
  /// **'Parking'**
  String get poiFindParking;

  /// No description provided for @parkingPrefTitle.
  ///
  /// In en, this message translates to:
  /// **'Parking'**
  String get parkingPrefTitle;

  /// No description provided for @parkingPrefSub.
  ///
  /// In en, this message translates to:
  /// **'Show parkings near the destination.'**
  String get parkingPrefSub;

  /// No description provided for @parkingResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Parking near destination'**
  String get parkingResultTitle;

  /// No description provided for @inspireTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip Inspiration'**
  String get inspireTitle;

  /// No description provided for @inspireHero.
  ///
  /// In en, this message translates to:
  /// **'Describe your dream road trip'**
  String get inspireHero;

  /// No description provided for @inspireSub.
  ///
  /// In en, this message translates to:
  /// **'AI drafts a multi-day itinerary you can turn into a real plan in one tap.'**
  String get inspireSub;

  /// No description provided for @inspireHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Romantic 4-day drive through Italian lakes'**
  String get inspireHint;

  /// No description provided for @inspireGenerate.
  ///
  /// In en, this message translates to:
  /// **'Inspire me'**
  String get inspireGenerate;

  /// No description provided for @inspireGenerating.
  ///
  /// In en, this message translates to:
  /// **'Thinking up your trip…'**
  String get inspireGenerating;

  /// No description provided for @inspireError.
  ///
  /// In en, this message translates to:
  /// **'The muse is offline. Try a different prompt or try again.'**
  String get inspireError;

  /// No description provided for @inspireResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Your proposed itinerary'**
  String get inspireResultTitle;

  /// No description provided for @inspireDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Day {n}'**
  String inspireDayLabel(Object n);

  /// No description provided for @inspireBudgetLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated budget'**
  String get inspireBudgetLabel;

  /// No description provided for @inspireConvertToPlan.
  ///
  /// In en, this message translates to:
  /// **'Turn into a real plan'**
  String get inspireConvertToPlan;

  /// No description provided for @inspireSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get inspireSave;

  /// No description provided for @inspireSavedToast.
  ///
  /// In en, this message translates to:
  /// **'Idea saved. Find it in your saved inspirations.'**
  String get inspireSavedToast;

  /// No description provided for @inspireRecentTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent inspirations'**
  String get inspireRecentTitle;

  /// No description provided for @inspireHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'My AI plans'**
  String get inspireHistoryTitle;

  /// No description provided for @inspireHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No AI plans yet. Generate one from the Plan tab.'**
  String get inspireHistoryEmpty;

  /// No description provided for @inspireHistoryDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get inspireHistoryDelete;

  /// No description provided for @settingsMyAiPlans.
  ///
  /// In en, this message translates to:
  /// **'My AI plans'**
  String get settingsMyAiPlans;

  /// No description provided for @settingsMyAiPlansSub.
  ///
  /// In en, this message translates to:
  /// **'History of Trip Inspiration results'**
  String get settingsMyAiPlansSub;

  /// No description provided for @inspireChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Refine the itinerary'**
  String get inspireChatTitle;

  /// No description provided for @inspireChatHint.
  ///
  /// In en, this message translates to:
  /// **'Change something: \"remove Cremona\", \"leave Friday evening\"…'**
  String get inspireChatHint;

  /// No description provided for @inspireExamplesTitle.
  ///
  /// In en, this message translates to:
  /// **'Or start from an idea'**
  String get inspireExamplesTitle;

  /// No description provided for @inspireExample1.
  ///
  /// In en, this message translates to:
  /// **'Weekend of castles in the Loire Valley'**
  String get inspireExample1;

  /// No description provided for @inspireExample2.
  ///
  /// In en, this message translates to:
  /// **'Coastal drive Barcelona to Marseille'**
  String get inspireExample2;

  /// No description provided for @inspireExample3.
  ///
  /// In en, this message translates to:
  /// **'5-day Alpine loop from Milan'**
  String get inspireExample3;

  /// No description provided for @inspireExample4.
  ///
  /// In en, this message translates to:
  /// **'Northern Spain with kids, no highways'**
  String get inspireExample4;

  /// No description provided for @planOverrideForTrip.
  ///
  /// In en, this message translates to:
  /// **'Override for this trip'**
  String get planOverrideForTrip;

  /// No description provided for @planOverrideActive.
  ///
  /// In en, this message translates to:
  /// **'Overriding for this trip'**
  String get planOverrideActive;

  /// No description provided for @planOverrideClear.
  ///
  /// In en, this message translates to:
  /// **'Clear override'**
  String get planOverrideClear;

  /// No description provided for @planTooltipDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get planTooltipDashboard;

  /// No description provided for @planTooltipReport.
  ///
  /// In en, this message translates to:
  /// **'Report an event'**
  String get planTooltipReport;

  /// No description provided for @planTooltipSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved trips'**
  String get planTooltipSaved;

  /// No description provided for @tabPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get tabPlan;

  /// No description provided for @tabCompanion.
  ///
  /// In en, this message translates to:
  /// **'Companion'**
  String get tabCompanion;

  /// No description provided for @tabMyTrips.
  ///
  /// In en, this message translates to:
  /// **'My trips'**
  String get tabMyTrips;

  /// No description provided for @companionHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Your driving companion'**
  String get companionHeroTitle;

  /// No description provided for @companionHeroBody.
  ///
  /// In en, this message translates to:
  /// **'Set your conditions, then start. The app tracks your drive and recommends when to stop, where to eat, and where to refuel.'**
  String get companionHeroBody;

  /// No description provided for @companionConfigSection.
  ///
  /// In en, this message translates to:
  /// **'CONFIGURATION'**
  String get companionConfigSection;

  /// No description provided for @companionBreakInterval.
  ///
  /// In en, this message translates to:
  /// **'Rest suggestions'**
  String get companionBreakInterval;

  /// No description provided for @companionSuggestBreak.
  ///
  /// In en, this message translates to:
  /// **'Suggest a rest based on drive time'**
  String get companionSuggestBreak;

  /// No description provided for @companionBreakHint.
  ///
  /// In en, this message translates to:
  /// **'Recommend a stop every {hours} h of driving'**
  String companionBreakHint(String hours);

  /// No description provided for @companionFatigueStopExperimental.
  ///
  /// In en, this message translates to:
  /// **'Suggest pulling over on fatigue (experimental)'**
  String get companionFatigueStopExperimental;

  /// No description provided for @companionFatigueStopHint.
  ///
  /// In en, this message translates to:
  /// **'Timer-only signal today — over-eager for short micro-pauses.'**
  String get companionFatigueStopHint;

  /// No description provided for @companionAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alert types'**
  String get companionAlerts;

  /// No description provided for @companionAlertCriticalAdverse.
  ///
  /// In en, this message translates to:
  /// **'Critical incidents (fires, floods, quakes)'**
  String get companionAlertCriticalAdverse;

  /// No description provided for @companionAlertCriticalAdverseHint.
  ///
  /// In en, this message translates to:
  /// **'Recommended. Something serious happening near you — not just weather.'**
  String get companionAlertCriticalAdverseHint;

  /// No description provided for @companionAlertWeather.
  ///
  /// In en, this message translates to:
  /// **'Weather ahead'**
  String get companionAlertWeather;

  /// No description provided for @companionAlertFuel.
  ///
  /// In en, this message translates to:
  /// **'Cheapest fuel along the route'**
  String get companionAlertFuel;

  /// No description provided for @companionAlertBorder.
  ///
  /// In en, this message translates to:
  /// **'Border crossing info'**
  String get companionAlertBorder;

  /// No description provided for @companionAlertToll.
  ///
  /// In en, this message translates to:
  /// **'Toll skip suggestions'**
  String get companionAlertToll;

  /// No description provided for @companionAlertHotel.
  ///
  /// In en, this message translates to:
  /// **'Hotel when past bedtime + 5h of drive'**
  String get companionAlertHotel;

  /// No description provided for @companionStart.
  ///
  /// In en, this message translates to:
  /// **'Start companion'**
  String get companionStart;

  /// No description provided for @companionComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Companion mode launching soon!'**
  String get companionComingSoon;

  /// No description provided for @companionDriveTitle.
  ///
  /// In en, this message translates to:
  /// **'Companion drive'**
  String get companionDriveTitle;

  /// No description provided for @companionForegroundBody.
  ///
  /// In en, this message translates to:
  /// **'MyTravelPal is tracking your drive'**
  String get companionForegroundBody;

  /// No description provided for @companionLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required for the companion.'**
  String get companionLocationDenied;

  /// No description provided for @companionDriving.
  ///
  /// In en, this message translates to:
  /// **'driving'**
  String get companionDriving;

  /// No description provided for @companionAllGood.
  ///
  /// In en, this message translates to:
  /// **'No alerts — enjoy the drive.'**
  String get companionAllGood;

  /// No description provided for @companionEndTitle.
  ///
  /// In en, this message translates to:
  /// **'End companion?'**
  String get companionEndTitle;

  /// No description provided for @companionEndBody.
  ///
  /// In en, this message translates to:
  /// **'Tracking will stop and any active alerts will be lost.'**
  String get companionEndBody;

  /// No description provided for @companionEndKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep driving'**
  String get companionEndKeep;

  /// No description provided for @companionEndConfirm.
  ///
  /// In en, this message translates to:
  /// **'End session'**
  String get companionEndConfirm;

  /// No description provided for @emergencyContactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency contacts'**
  String get emergencyContactsTitle;

  /// No description provided for @emergencyContactsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notified by SMS on crash detection'**
  String get emergencyContactsSubtitle;

  /// No description provided for @emergencyContactsBody.
  ///
  /// In en, this message translates to:
  /// **'Up to 3 people receive an SMS with your location if the companion detects a crash.'**
  String get emergencyContactsBody;

  /// No description provided for @emergencyContactsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No contacts added yet.'**
  String get emergencyContactsEmpty;

  /// No description provided for @emergencyContactsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get emergencyContactsAdd;

  /// No description provided for @emergencyContactsPickFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Pick from contacts'**
  String get emergencyContactsPickFromDevice;

  /// No description provided for @emergencyContactsPickSearch.
  ///
  /// In en, this message translates to:
  /// **'Search contacts'**
  String get emergencyContactsPickSearch;

  /// No description provided for @emergencyContactsPermDenied.
  ///
  /// In en, this message translates to:
  /// **'Contacts permission denied. You can still add manually.'**
  String get emergencyContactsPermDenied;

  /// No description provided for @emergencyContactsNoDevice.
  ///
  /// In en, this message translates to:
  /// **'No contacts with a phone number on this device.'**
  String get emergencyContactsNoDevice;

  /// No description provided for @emergencyContactAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add emergency contact'**
  String get emergencyContactAddTitle;

  /// No description provided for @emergencyContactName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get emergencyContactName;

  /// No description provided for @emergencyContactNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get emergencyContactNameRequired;

  /// No description provided for @emergencyContactPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone (E.164)'**
  String get emergencyContactPhone;

  /// No description provided for @emergencyContactPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a phone number'**
  String get emergencyContactPhoneRequired;

  /// No description provided for @emergencyContactPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use international format: +34612345678'**
  String get emergencyContactPhoneInvalid;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @sosTitle.
  ///
  /// In en, this message translates to:
  /// **'Possible crash detected'**
  String get sosTitle;

  /// No description provided for @sosBody.
  ///
  /// In en, this message translates to:
  /// **'Impact peak {g}g · speed drop {speed} km/h.'**
  String sosBody(String g, String speed);

  /// No description provided for @sosCountdown.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String sosCountdown(int seconds);

  /// No description provided for @sosImOk.
  ///
  /// In en, this message translates to:
  /// **'I\'m OK — cancel'**
  String get sosImOk;

  /// No description provided for @sosCall112.
  ///
  /// In en, this message translates to:
  /// **'Call 112'**
  String get sosCall112;

  /// No description provided for @sosCancelled.
  ///
  /// In en, this message translates to:
  /// **'Alert cancelled.'**
  String get sosCancelled;

  /// No description provided for @sosClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get sosClose;

  /// No description provided for @sosNoContacts.
  ///
  /// In en, this message translates to:
  /// **'No emergency contacts configured. Add one in Settings.'**
  String get sosNoContacts;

  /// No description provided for @sosSmsDispatched.
  ///
  /// In en, this message translates to:
  /// **'SMS prepared for {count} contact(s).'**
  String sosSmsDispatched(int count);

  /// No description provided for @sosSmsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open SMS. Call manually below.'**
  String get sosSmsFailed;

  /// No description provided for @sosSmsPrefix.
  ///
  /// In en, this message translates to:
  /// **'MyTravelPal — possible crash detected. My location:'**
  String get sosSmsPrefix;

  /// No description provided for @weatherForecastTitle.
  ///
  /// In en, this message translates to:
  /// **'7-day forecast'**
  String get weatherForecastTitle;

  /// No description provided for @weatherToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get weatherToday;

  /// No description provided for @leaveNowTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave now with companion'**
  String get leaveNowTitle;

  /// No description provided for @leaveNowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a destination and go — we track and guide you.'**
  String get leaveNowSubtitle;

  /// No description provided for @leaveNowSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Where are you heading?'**
  String get leaveNowSheetTitle;

  /// No description provided for @leaveNowPremiumTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium feature'**
  String get leaveNowPremiumTitle;

  /// No description provided for @leaveNowPremiumBody.
  ///
  /// In en, this message translates to:
  /// **'\'Leave now\' bundles the full plan with the driving companion. Available with MyTravelPal Premium.'**
  String get leaveNowPremiumBody;

  /// No description provided for @leaveNowPremiumDismiss.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get leaveNowPremiumDismiss;

  /// No description provided for @leaveNowPremiumCta.
  ///
  /// In en, this message translates to:
  /// **'Try 7 days free'**
  String get leaveNowPremiumCta;

  /// No description provided for @shareCardOption.
  ///
  /// In en, this message translates to:
  /// **'Share as image'**
  String get shareCardOption;

  /// No description provided for @shareCardOptionSub.
  ///
  /// In en, this message translates to:
  /// **'Perfect for Instagram Stories, WhatsApp, X'**
  String get shareCardOptionSub;

  /// No description provided for @shareLinkOption.
  ///
  /// In en, this message translates to:
  /// **'Share as link'**
  String get shareLinkOption;

  /// No description provided for @shareLinkOptionSub.
  ///
  /// In en, this message translates to:
  /// **'Text summary + deep link to reopen the plan'**
  String get shareLinkOptionSub;

  /// No description provided for @shareLiveHeadline.
  ///
  /// In en, this message translates to:
  /// **'Driving through {city}'**
  String shareLiveHeadline(String city);

  /// No description provided for @shareLiveCaption.
  ///
  /// In en, this message translates to:
  /// **'Driving through {city} with MyTravelPal 🚗'**
  String shareLiveCaption(String city);

  /// No description provided for @planAddStop.
  ///
  /// In en, this message translates to:
  /// **'Add stop'**
  String get planAddStop;

  /// No description provided for @planStopDwellPassThrough.
  ///
  /// In en, this message translates to:
  /// **'Just passing through'**
  String get planStopDwellPassThrough;

  /// No description provided for @planStopDwellOneNight.
  ///
  /// In en, this message translates to:
  /// **'1 night'**
  String get planStopDwellOneNight;

  /// No description provided for @planStopDwellNights.
  ///
  /// In en, this message translates to:
  /// **'{n} nights'**
  String planStopDwellNights(int n);

  /// No description provided for @planStopDwellHours.
  ///
  /// In en, this message translates to:
  /// **'{n} hours'**
  String planStopDwellHours(int n);

  /// No description provided for @planStopDwellTitle.
  ///
  /// In en, this message translates to:
  /// **'How long at {name}?'**
  String planStopDwellTitle(Object name);

  /// No description provided for @planAddStopTitle.
  ///
  /// In en, this message translates to:
  /// **'New stop'**
  String get planAddStopTitle;

  /// No description provided for @planStopLabel.
  ///
  /// In en, this message translates to:
  /// **'Stop {n}'**
  String planStopLabel(int n);

  /// No description provided for @planStopRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove stop'**
  String get planStopRemove;

  /// No description provided for @settingsCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get settingsCurrency;

  /// No description provided for @planErrorPickEndpoints.
  ///
  /// In en, this message translates to:
  /// **'Pick an origin and a destination.'**
  String get planErrorPickEndpoints;

  /// No description provided for @resultBestTimeToLeave.
  ///
  /// In en, this message translates to:
  /// **'BEST TIME TO LEAVE'**
  String get resultBestTimeToLeave;

  /// No description provided for @resultTripSavings.
  ///
  /// In en, this message translates to:
  /// **'YOUR SAVINGS ON THIS TRIP'**
  String get resultTripSavings;

  /// No description provided for @resultTimeSavedLabel.
  ///
  /// In en, this message translates to:
  /// **'time saved'**
  String get resultTimeSavedLabel;

  /// No description provided for @resultExtraTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'extra time'**
  String get resultExtraTimeLabel;

  /// No description provided for @resultMoneySavedLabel.
  ///
  /// In en, this message translates to:
  /// **'money saved'**
  String get resultMoneySavedLabel;

  /// No description provided for @resultDepartureWindowTitle.
  ///
  /// In en, this message translates to:
  /// **'Departure window'**
  String get resultDepartureWindowTitle;

  /// No description provided for @resultDepartureWindowDesc.
  ///
  /// In en, this message translates to:
  /// **'Total minutes at each candidate departure time.'**
  String get resultDepartureWindowDesc;

  /// No description provided for @resultCompareVariantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Compare your options'**
  String get resultCompareVariantsTitle;

  /// No description provided for @resultCompareVariantsEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Route variants'**
  String get resultCompareVariantsEyebrow;

  /// No description provided for @resultAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts along your route'**
  String get resultAlertsTitle;

  /// No description provided for @resultRestStopsTitle.
  ///
  /// In en, this message translates to:
  /// **'Rest stops'**
  String get resultRestStopsTitle;

  /// No description provided for @resultHotelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Hotels'**
  String get resultHotelsTitle;

  /// No description provided for @resultRestaurantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get resultRestaurantsTitle;

  /// No description provided for @resultFuelTitle.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get resultFuelTitle;

  /// No description provided for @resultTollAlternativeEyebrow.
  ///
  /// In en, this message translates to:
  /// **'TOLL-FREE ALTERNATIVE'**
  String get resultTollAlternativeEyebrow;

  /// No description provided for @resultTollAlternativeWorthIt.
  ///
  /// In en, this message translates to:
  /// **'Worth it'**
  String get resultTollAlternativeWorthIt;

  /// No description provided for @resultTollAlternativeMarginal.
  ///
  /// In en, this message translates to:
  /// **'Marginal'**
  String get resultTollAlternativeMarginal;

  /// No description provided for @resultShareTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share this trip'**
  String get resultShareTooltip;

  /// No description provided for @resultExplainTooltip.
  ///
  /// In en, this message translates to:
  /// **'Explain my trip (Premium)'**
  String get resultExplainTooltip;

  /// No description provided for @resultSaveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save trip'**
  String get resultSaveTooltip;

  /// No description provided for @resultSavedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get resultSavedTooltip;

  /// No description provided for @resultTripSaved.
  ///
  /// In en, this message translates to:
  /// **'Trip saved'**
  String get resultTripSaved;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @dashboardGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String dashboardGreeting(String name);

  /// No description provided for @dashboardTravelSoFar.
  ///
  /// In en, this message translates to:
  /// **'Your travel so far'**
  String get dashboardTravelSoFar;

  /// No description provided for @dashboardTrips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get dashboardTrips;

  /// No description provided for @dashboardDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get dashboardDistance;

  /// No description provided for @dashboardHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get dashboardHours;

  /// No description provided for @dashboardTimeSaved.
  ///
  /// In en, this message translates to:
  /// **'TIME SAVED'**
  String get dashboardTimeSaved;

  /// No description provided for @dashboardMoneySaved.
  ///
  /// In en, this message translates to:
  /// **'MONEY SAVED'**
  String get dashboardMoneySaved;

  /// No description provided for @dashboardFuelBudget.
  ///
  /// In en, this message translates to:
  /// **'ESTIMATED FUEL BUDGET'**
  String get dashboardFuelBudget;

  /// No description provided for @dashboardTopSavers.
  ///
  /// In en, this message translates to:
  /// **'Top savers'**
  String get dashboardTopSavers;

  /// No description provided for @dashboardCountries.
  ///
  /// In en, this message translates to:
  /// **'Countries'**
  String get dashboardCountries;

  /// No description provided for @dashboardSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get dashboardSignOut;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip profile'**
  String get profileTitle;

  /// No description provided for @profileOverrideTitle.
  ///
  /// In en, this message translates to:
  /// **'Override for this trip'**
  String get profileOverrideTitle;

  /// No description provided for @profileSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSave;

  /// No description provided for @profileUse.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get profileUse;

  /// No description provided for @profileWhoTravelling.
  ///
  /// In en, this message translates to:
  /// **'Who is travelling'**
  String get profileWhoTravelling;

  /// No description provided for @profileTravellers.
  ///
  /// In en, this message translates to:
  /// **'Travellers'**
  String get profileTravellers;

  /// No description provided for @profileHasKids.
  ///
  /// In en, this message translates to:
  /// **'Travelling with kids'**
  String get profileHasKids;

  /// No description provided for @profileHasPets.
  ///
  /// In en, this message translates to:
  /// **'Travelling with pets'**
  String get profileHasPets;

  /// No description provided for @profileVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get profileVehicle;

  /// No description provided for @profileMealTimes.
  ///
  /// In en, this message translates to:
  /// **'Meal schedule'**
  String get profileMealTimes;

  /// No description provided for @profileReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get profileReminders;

  /// No description provided for @profilePremiumSection.
  ///
  /// In en, this message translates to:
  /// **'Premium (demo)'**
  String get profilePremiumSection;

  /// No description provided for @profileClearProfile.
  ///
  /// In en, this message translates to:
  /// **'Clear profile'**
  String get profileClearProfile;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonShowNMore.
  ///
  /// In en, this message translates to:
  /// **'Show {n} more'**
  String commonShowNMore(int n);

  /// No description provided for @commonShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get commonShowLess;

  /// No description provided for @planLoadingElapsed.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s elapsed'**
  String planLoadingElapsed(int seconds);

  /// No description provided for @planLoadingLongCrossingCountries.
  ///
  /// In en, this message translates to:
  /// **'Cross-checking tolls across the countries you\'re crossing…'**
  String get planLoadingLongCrossingCountries;

  /// No description provided for @planLoadingLongScanningFuel.
  ///
  /// In en, this message translates to:
  /// **'Scanning European fuel-price feeds along the route…'**
  String get planLoadingLongScanningFuel;

  /// No description provided for @planLoadingLongBigTrip.
  ///
  /// In en, this message translates to:
  /// **'Long trips take a bit more — pulling extra hotel and rest data.'**
  String get planLoadingLongBigTrip;

  /// No description provided for @planLoadingLongAlmostDone.
  ///
  /// In en, this message translates to:
  /// **'Almost there — final touches on the itinerary.'**
  String get planLoadingLongAlmostDone;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @searchPlaceholderLegacy.
  ///
  /// In en, this message translates to:
  /// **'Search a city…'**
  String get searchPlaceholderLegacy;

  /// No description provided for @searchNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches.'**
  String get searchNoMatches;

  /// No description provided for @searchStartTyping.
  ///
  /// In en, this message translates to:
  /// **'Type at least 2 characters.'**
  String get searchStartTyping;

  /// No description provided for @searchRecent.
  ///
  /// In en, this message translates to:
  /// **'RECENT'**
  String get searchRecent;

  /// No description provided for @searchUseMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get searchUseMyLocation;

  /// No description provided for @locationServiceOff.
  ///
  /// In en, this message translates to:
  /// **'Location services are off on this device.'**
  String get locationServiceOff;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied.'**
  String get locationPermissionDenied;

  /// No description provided for @locationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t determine your location.'**
  String get locationUnavailable;

  /// No description provided for @favoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoritesTitle;

  /// No description provided for @favoritesEmptyHotels.
  ///
  /// In en, this message translates to:
  /// **'No favorite hotels yet. Tap the star on any hotel to save it.'**
  String get favoritesEmptyHotels;

  /// No description provided for @favoritesEmptyRestaurants.
  ///
  /// In en, this message translates to:
  /// **'No favorite restaurants yet. Tap the star on any restaurant to save it.'**
  String get favoritesEmptyRestaurants;

  /// No description provided for @favoritesTabHotels.
  ///
  /// In en, this message translates to:
  /// **'Hotels'**
  String get favoritesTabHotels;

  /// No description provided for @favoritesTabRestaurants.
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get favoritesTabRestaurants;

  /// No description provided for @favoritesTooltipAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get favoritesTooltipAdd;

  /// No description provided for @favoritesTooltipRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get favoritesTooltipRemove;

  /// No description provided for @planTooltipFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get planTooltipFavorites;

  /// No description provided for @resultBackToPlan.
  ///
  /// In en, this message translates to:
  /// **'Back to plan'**
  String get resultBackToPlan;

  /// No description provided for @alertsAlongYourRoute.
  ///
  /// In en, this message translates to:
  /// **'Alerts along your route'**
  String get alertsAlongYourRoute;

  /// No description provided for @alertsAlongYourRouteDesc.
  ///
  /// In en, this message translates to:
  /// **'Fires, floods, severe weather, snow, earthquakes, landslides — sorted by severity.'**
  String get alertsAlongYourRouteDesc;

  /// No description provided for @restStopsHint.
  ///
  /// In en, this message translates to:
  /// **'Recommended every 2 h of driving. Short breaks keep you sharp on long trips.'**
  String get restStopsHint;

  /// No description provided for @fuelAlongTheRoute.
  ///
  /// In en, this message translates to:
  /// **'Fuel along the route'**
  String get fuelAlongTheRoute;

  /// No description provided for @hotelsNearYourRoute.
  ///
  /// In en, this message translates to:
  /// **'Hotels near your route'**
  String get hotelsNearYourRoute;

  /// No description provided for @restaurantsNearYourRoute.
  ///
  /// In en, this message translates to:
  /// **'Restaurants near your route'**
  String get restaurantsNearYourRoute;

  /// No description provided for @narrativeTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip briefing'**
  String get narrativeTitle;

  /// No description provided for @narrativeGenerating.
  ///
  /// In en, this message translates to:
  /// **'Writing your briefing…'**
  String get narrativeGenerating;

  /// No description provided for @narrativeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t generate the briefing. Try again in a bit.'**
  String get narrativeFailed;

  /// No description provided for @narrativeFooter.
  ///
  /// In en, this message translates to:
  /// **'Generated by Claude — content may miss real-time changes.'**
  String get narrativeFooter;

  /// No description provided for @narrativePremiumBadge.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get narrativePremiumBadge;

  /// No description provided for @shareTripSubject.
  ///
  /// In en, this message translates to:
  /// **'My road trip via MyTravelPal'**
  String get shareTripSubject;

  /// No description provided for @shareFormatTitle.
  ///
  /// In en, this message translates to:
  /// **'Share as…'**
  String get shareFormatTitle;

  /// No description provided for @shareFormatStory.
  ///
  /// In en, this message translates to:
  /// **'Story · 9:16'**
  String get shareFormatStory;

  /// No description provided for @shareFormatStorySub.
  ///
  /// In en, this message translates to:
  /// **'Instagram / TikTok / WhatsApp Stories'**
  String get shareFormatStorySub;

  /// No description provided for @shareFormatFeed.
  ///
  /// In en, this message translates to:
  /// **'Square · 1:1'**
  String get shareFormatFeed;

  /// No description provided for @shareFormatFeedSub.
  ///
  /// In en, this message translates to:
  /// **'Instagram feed, Facebook, LinkedIn'**
  String get shareFormatFeedSub;

  /// No description provided for @shareTitle.
  ///
  /// In en, this message translates to:
  /// **'MyTravelPal — road trip plan'**
  String get shareTitle;

  /// No description provided for @shareRouteLine.
  ///
  /// In en, this message translates to:
  /// **'{km} km · {hours} h free flow · tolls {tolls} €'**
  String shareRouteLine(String km, String hours, String tolls);

  /// No description provided for @shareBestTime.
  ///
  /// In en, this message translates to:
  /// **'Best time to leave: {when} ({minutes} min total)'**
  String shareBestTime(String when, String minutes);

  /// No description provided for @shareTollFreeAlt.
  ///
  /// In en, this message translates to:
  /// **'Toll-free alt: save €{savings} for +{minutes} min'**
  String shareTollFreeAlt(String savings, String minutes);

  /// No description provided for @shareRefuelHint.
  ///
  /// In en, this message translates to:
  /// **'Refuel in {cheap} (~{price}€/L) before {pricey} — save ~{savings}€/tank'**
  String shareRefuelHint(
      String cheap, String price, String pricey, String savings);

  /// No description provided for @shareHotelsHeader.
  ///
  /// In en, this message translates to:
  /// **'Top hotels considered:'**
  String get shareHotelsHeader;

  /// No description provided for @shareRestaurantsHeader.
  ///
  /// In en, this message translates to:
  /// **'Top restaurants considered:'**
  String get shareRestaurantsHeader;

  /// No description provided for @shareHotelLine.
  ///
  /// In en, this message translates to:
  /// **'{name} — {price} €/night · {km} km off route'**
  String shareHotelLine(String name, String price, String km);

  /// No description provided for @shareRestaurantLine.
  ///
  /// In en, this message translates to:
  /// **'{name} — {price} €/meal · {km} km off route'**
  String shareRestaurantLine(String name, String price, String km);

  /// No description provided for @shareOpenInApp.
  ///
  /// In en, this message translates to:
  /// **'Open in MyTravelPal:'**
  String get shareOpenInApp;

  /// No description provided for @eventReport.
  ///
  /// In en, this message translates to:
  /// **'Report an event'**
  String get eventReport;

  /// No description provided for @eventDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get eventDescription;

  /// No description provided for @eventType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get eventType;

  /// No description provided for @eventSeverity.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get eventSeverity;

  /// No description provided for @eventLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get eventLocation;

  /// No description provided for @eventSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get eventSubmit;

  /// No description provided for @eventSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Reported.'**
  String get eventSubmitted;

  /// No description provided for @resultStatDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get resultStatDistance;

  /// No description provided for @resultStatFreeFlow.
  ///
  /// In en, this message translates to:
  /// **'Free flow'**
  String get resultStatFreeFlow;

  /// No description provided for @resultStatTolls.
  ///
  /// In en, this message translates to:
  /// **'Tolls'**
  String get resultStatTolls;

  /// No description provided for @resultEyebrowNearRoute.
  ///
  /// In en, this message translates to:
  /// **'Near your route'**
  String get resultEyebrowNearRoute;

  /// No description provided for @resultEyebrowAlongRoute.
  ///
  /// In en, this message translates to:
  /// **'Along the route'**
  String get resultEyebrowAlongRoute;

  /// No description provided for @resultAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get resultAlerts;

  /// No description provided for @resultRestStops.
  ///
  /// In en, this message translates to:
  /// **'Recommended stops'**
  String get resultRestStops;

  /// No description provided for @resultHotels.
  ///
  /// In en, this message translates to:
  /// **'Hotels'**
  String get resultHotels;

  /// No description provided for @resultRestaurants.
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get resultRestaurants;

  /// No description provided for @resultFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get resultFuel;

  /// No description provided for @resultOptimized.
  ///
  /// In en, this message translates to:
  /// **'Optimized for your trip'**
  String get resultOptimized;

  /// No description provided for @resultOptimizedFuelBudget.
  ///
  /// In en, this message translates to:
  /// **'Estimated fuel budget'**
  String get resultOptimizedFuelBudget;

  /// No description provided for @resultCompareTitle.
  ///
  /// In en, this message translates to:
  /// **'Compare your options'**
  String get resultCompareTitle;

  /// No description provided for @resultCompareStraightApprox.
  ///
  /// In en, this message translates to:
  /// **'Straight-line approx.'**
  String get resultCompareStraightApprox;

  /// No description provided for @resultSleepAt.
  ///
  /// In en, this message translates to:
  /// **'Sleep · {when}'**
  String resultSleepAt(String when);

  /// No description provided for @resultHourlyTollEyebrow.
  ///
  /// In en, this message translates to:
  /// **'HOURLY TOLL VERDICT'**
  String get resultHourlyTollEyebrow;

  /// No description provided for @resultSkipLabel.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get resultSkipLabel;

  /// No description provided for @resultKeepLabel.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get resultKeepLabel;

  /// No description provided for @resultSaveExactly.
  ///
  /// In en, this message translates to:
  /// **'Save '**
  String get resultSaveExactly;

  /// No description provided for @notificationsLeaveSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Time to leave soon'**
  String get notificationsLeaveSoonTitle;

  /// No description provided for @localeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get localeSystem;

  /// No description provided for @localeMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get localeMenuTooltip;

  /// No description provided for @dashboardCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get dashboardCountry;

  /// No description provided for @dashboardNoTripsYet.
  ///
  /// In en, this message translates to:
  /// **'No saved trips yet. Plan and save one to see stats.'**
  String get dashboardNoTripsYet;

  /// No description provided for @dashboardStatCards.
  ///
  /// In en, this message translates to:
  /// **'OVERVIEW'**
  String get dashboardStatCards;

  /// No description provided for @profileVehicleType.
  ///
  /// In en, this message translates to:
  /// **'Vehicle type'**
  String get profileVehicleType;

  /// No description provided for @profileFuelType.
  ///
  /// In en, this message translates to:
  /// **'Fuel type'**
  String get profileFuelType;

  /// No description provided for @profileConsumption.
  ///
  /// In en, this message translates to:
  /// **'Consumption'**
  String get profileConsumption;

  /// No description provided for @profileEvRange.
  ///
  /// In en, this message translates to:
  /// **'EV range'**
  String get profileEvRange;

  /// No description provided for @profileFuelTank.
  ///
  /// In en, this message translates to:
  /// **'Fuel tank'**
  String get profileFuelTank;

  /// No description provided for @profileBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get profileBreakfast;

  /// No description provided for @profileLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get profileLunch;

  /// No description provided for @profileDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get profileDinner;

  /// No description provided for @profileStopMinutes.
  ///
  /// In en, this message translates to:
  /// **'Typical stop minutes'**
  String get profileStopMinutes;

  /// No description provided for @profileReminderMinutes.
  ///
  /// In en, this message translates to:
  /// **'Reminder before departure'**
  String get profileReminderMinutes;

  /// No description provided for @profilePremiumHint.
  ///
  /// In en, this message translates to:
  /// **'Toggle to preview Premium features locally.'**
  String get profilePremiumHint;

  /// No description provided for @profileNoProfile.
  ///
  /// In en, this message translates to:
  /// **'No profile saved yet.'**
  String get profileNoProfile;

  /// No description provided for @eventPlaceholderDescription.
  ///
  /// In en, this message translates to:
  /// **'Short description of what you saw'**
  String get eventPlaceholderDescription;

  /// No description provided for @eventCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get eventCurrentLocation;

  /// No description provided for @eventPickOnMap.
  ///
  /// In en, this message translates to:
  /// **'Pick on map'**
  String get eventPickOnMap;

  /// No description provided for @eventLocationCoords.
  ///
  /// In en, this message translates to:
  /// **'Selected: {lat}, {lon}'**
  String eventLocationCoords(String lat, String lon);

  /// No description provided for @narrativeRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get narrativeRegenerate;

  /// No description provided for @narrativeUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Unlock the AI briefing with Premium.'**
  String get narrativeUpgrade;

  /// No description provided for @compareVariantsRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get compareVariantsRecommended;

  /// No description provided for @compareVariantsFastest.
  ///
  /// In en, this message translates to:
  /// **'Fastest'**
  String get compareVariantsFastest;

  /// No description provided for @compareVariantsCheapest.
  ///
  /// In en, this message translates to:
  /// **'Cheapest'**
  String get compareVariantsCheapest;

  /// No description provided for @compareVariantsScenic.
  ///
  /// In en, this message translates to:
  /// **'Scenic'**
  String get compareVariantsScenic;

  /// No description provided for @compareVariantsAvoidTolls.
  ///
  /// In en, this message translates to:
  /// **'No tolls'**
  String get compareVariantsAvoidTolls;

  /// No description provided for @compareVariantsAvoidMotorways.
  ///
  /// In en, this message translates to:
  /// **'No motorways'**
  String get compareVariantsAvoidMotorways;

  /// No description provided for @hourlyBestHours.
  ///
  /// In en, this message translates to:
  /// **'Best hours to skip tolls'**
  String get hourlyBestHours;

  /// No description provided for @hourlyWorstHours.
  ///
  /// In en, this message translates to:
  /// **'Worst hours to skip tolls'**
  String get hourlyWorstHours;

  /// No description provided for @partialTollSkipsTitle.
  ///
  /// In en, this message translates to:
  /// **'Booth-by-booth skips'**
  String get partialTollSkipsTitle;

  /// No description provided for @partialTollSkipsEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get partialTollSkipsEyebrow;

  /// No description provided for @sleepEyebrow.
  ///
  /// In en, this message translates to:
  /// **'OVERNIGHT'**
  String get sleepEyebrow;

  /// No description provided for @sleepNoHotelSuggestion.
  ///
  /// In en, this message translates to:
  /// **'No hotel picked yet — see the Hotels section.'**
  String get sleepNoHotelSuggestion;

  /// No description provided for @lunchEyebrow.
  ///
  /// In en, this message translates to:
  /// **'LUNCH STOP'**
  String get lunchEyebrow;

  /// No description provided for @dinnerEyebrow.
  ///
  /// In en, this message translates to:
  /// **'DINNER STOP'**
  String get dinnerEyebrow;

  /// No description provided for @breakfastEyebrow.
  ///
  /// In en, this message translates to:
  /// **'BREAKFAST STOP'**
  String get breakfastEyebrow;

  /// No description provided for @resultCompareEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Route variants'**
  String get resultCompareEyebrow;

  /// No description provided for @resultCompareDescription.
  ///
  /// In en, this message translates to:
  /// **'Same start and end — different priorities. Numbers are free-flow.'**
  String get resultCompareDescription;

  /// No description provided for @resultVariantDashed.
  ///
  /// In en, this message translates to:
  /// **'Dashed on the map above'**
  String get resultVariantDashed;

  /// No description provided for @resultOptimizedEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Profile-aware'**
  String get resultOptimizedEyebrow;

  /// No description provided for @dayTollsHeader.
  ///
  /// In en, this message translates to:
  /// **'Tolls today · {amount} € ({count})'**
  String dayTollsHeader(Object amount, int count);

  /// No description provided for @dayTollsSavedSummary.
  ///
  /// In en, this message translates to:
  /// **'You\'ll save {amount} € by skipping {count}.'**
  String dayTollsSavedSummary(Object amount, int count);

  /// No description provided for @tollHourGoodToSkip.
  ///
  /// In en, this message translates to:
  /// **'Good hour to skip ({hh}:00)'**
  String tollHourGoodToSkip(Object hh);

  /// No description provided for @tollHourAvoidSkip.
  ///
  /// In en, this message translates to:
  /// **'Avoid skipping — peak at {hh}:00'**
  String tollHourAvoidSkip(Object hh);

  /// No description provided for @partialTollsPerDayHint.
  ///
  /// In en, this message translates to:
  /// **'You can also toggle these per day in the itinerary below ↓'**
  String get partialTollsPerDayHint;

  /// No description provided for @resultCityHint.
  ///
  /// In en, this message translates to:
  /// **'Near {city}'**
  String resultCityHint(Object city);

  /// No description provided for @resultOptimizedDescription.
  ///
  /// In en, this message translates to:
  /// **'Meal, sleep and fuel picks that match your profile.'**
  String get resultOptimizedDescription;

  /// No description provided for @resultSavingsShiftAndSkip.
  ///
  /// In en, this message translates to:
  /// **'By shifting your departure and skipping tolls.'**
  String get resultSavingsShiftAndSkip;

  /// No description provided for @resultSavingsShift.
  ///
  /// In en, this message translates to:
  /// **'By shifting your departure to the recommended window.'**
  String get resultSavingsShift;

  /// No description provided for @resultSavingsSkip.
  ///
  /// In en, this message translates to:
  /// **'By taking the toll-free alternative.'**
  String get resultSavingsSkip;

  /// No description provided for @resultSavingsNone.
  ///
  /// In en, this message translates to:
  /// **'No savings identified for this route yet.'**
  String get resultSavingsNone;

  /// No description provided for @resultBypassSavingsPrefix.
  ///
  /// In en, this message translates to:
  /// **'You could save up to'**
  String get resultBypassSavingsPrefix;

  /// No description provided for @resultBypassSavingsSuffix.
  ///
  /// In en, this message translates to:
  /// **'with +{minutes} min extra'**
  String resultBypassSavingsSuffix(String minutes);

  /// No description provided for @resultArrival.
  ///
  /// In en, this message translates to:
  /// **'ARRIVAL'**
  String get resultArrival;

  /// No description provided for @resultShift.
  ///
  /// In en, this message translates to:
  /// **'SHIFT'**
  String get resultShift;

  /// No description provided for @resultTraffic.
  ///
  /// In en, this message translates to:
  /// **'TRAFFIC'**
  String get resultTraffic;

  /// No description provided for @resultTotal.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get resultTotal;

  /// No description provided for @resultRestStopNoRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Rest stop at {km} km — no matching restaurant found.'**
  String resultRestStopNoRestaurant(String km);

  /// No description provided for @resultNoHotelHere.
  ///
  /// In en, this message translates to:
  /// **'You should stop around here (~{km} km). No matching hotel found.'**
  String resultNoHotelHere(String km);

  /// No description provided for @resultMealFallback.
  ///
  /// In en, this message translates to:
  /// **'Meal'**
  String get resultMealFallback;

  /// No description provided for @resultHourlyExplainer.
  ///
  /// In en, this message translates to:
  /// **'Common in France & Italy: exit before an expensive toll, take a parallel road for a stretch, re-enter later — often 15-40 min but saves €5-15.'**
  String get resultHourlyExplainer;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get profileSaved;

  /// No description provided for @profileWhoEyebrow.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get profileWhoEyebrow;

  /// No description provided for @profileKidsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Prefers kid-friendly restaurants and hotels.'**
  String get profileKidsSubtitle;

  /// No description provided for @profilePetsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Prefers pet-friendly places, prioritises parking.'**
  String get profilePetsSubtitle;

  /// No description provided for @profileVehicleEyebrow.
  ///
  /// In en, this message translates to:
  /// **'For cost + parking hints'**
  String get profileVehicleEyebrow;

  /// No description provided for @profileMealsEyebrow.
  ///
  /// In en, this message translates to:
  /// **'To match restaurant stops'**
  String get profileMealsEyebrow;

  /// No description provided for @profileRemindersEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Local notifications'**
  String get profileRemindersEyebrow;

  /// No description provided for @profileNotifyBefore.
  ///
  /// In en, this message translates to:
  /// **'Notify me before departure'**
  String get profileNotifyBefore;

  /// No description provided for @profileNotifyOff.
  ///
  /// In en, this message translates to:
  /// **'Off — no reminder will be scheduled.'**
  String get profileNotifyOff;

  /// No description provided for @profileNotifyMinutesBefore.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes before'**
  String profileNotifyMinutesBefore(int minutes);

  /// No description provided for @profilePremiumEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Local toggle · no real payment'**
  String get profilePremiumEyebrow;

  /// No description provided for @profilePremiumBody.
  ///
  /// In en, this message translates to:
  /// **'Real StoreKit / Play Billing gating comes later. For now this toggle enables Premium locally so you can preview those features.'**
  String get profilePremiumBody;

  /// No description provided for @profileSimulatePremium.
  ///
  /// In en, this message translates to:
  /// **'Simulate Premium'**
  String get profileSimulatePremium;

  /// No description provided for @profileSimulatePremiumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlocks the AI trip briefing and hourly toll analysis.'**
  String get profileSimulatePremiumSubtitle;

  /// No description provided for @profileOverrideHeroDesc.
  ///
  /// In en, this message translates to:
  /// **'Change your profile just for this trip — different vehicle, travellers or meal times without touching your saved profile.'**
  String get profileOverrideHeroDesc;

  /// No description provided for @profileGlobalHeroDesc.
  ///
  /// In en, this message translates to:
  /// **'Set this once. Every plan uses it to rank hotels and restaurants, estimate fuel, and time meal stops.'**
  String get profileGlobalHeroDesc;

  /// No description provided for @eventPickPlace.
  ///
  /// In en, this message translates to:
  /// **'Pick a place and describe what you saw.'**
  String get eventPickPlace;

  /// No description provided for @eventThankYou.
  ///
  /// In en, this message translates to:
  /// **'Report submitted — thank you!'**
  String get eventThankYou;

  /// No description provided for @eventCouldNotSubmit.
  ///
  /// In en, this message translates to:
  /// **'Could not submit: {reason}'**
  String eventCouldNotSubmit(String reason);

  /// No description provided for @eventIntro.
  ///
  /// In en, this message translates to:
  /// **'Help other drivers know what you saw. Reports expire after 24 hours by default.'**
  String get eventIntro;

  /// No description provided for @eventWhatHappened.
  ///
  /// In en, this message translates to:
  /// **'What happened'**
  String get eventWhatHappened;

  /// No description provided for @eventWhatHappenedEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get eventWhatHappenedEyebrow;

  /// No description provided for @eventSeverityInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get eventSeverityInfo;

  /// No description provided for @eventSeverityWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get eventSeverityWarning;

  /// No description provided for @eventSeverityCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get eventSeverityCritical;

  /// No description provided for @eventWhere.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get eventWhere;

  /// No description provided for @eventWhereEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Nearest city'**
  String get eventWhereEyebrow;

  /// No description provided for @eventDescribeTitle.
  ///
  /// In en, this message translates to:
  /// **'Describe it'**
  String get eventDescribeTitle;

  /// No description provided for @eventDescribeEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Short & useful'**
  String get eventDescribeEyebrow;

  /// No description provided for @eventDescribeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Trees down on A6 southbound, 2 lanes closed'**
  String get eventDescribeHint;

  /// No description provided for @eventSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get eventSubmitting;

  /// No description provided for @eventSubmitReport.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get eventSubmitReport;

  /// No description provided for @narrativeBusy.
  ///
  /// In en, this message translates to:
  /// **'Composing your trip briefing…'**
  String get narrativeBusy;

  /// No description provided for @narrativeErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch the briefing'**
  String get narrativeErrorTitle;

  /// No description provided for @narrativeGeneratedAt.
  ///
  /// In en, this message translates to:
  /// **'Generated {when}'**
  String narrativeGeneratedAt(String when);

  /// No description provided for @narrativeReadAloud.
  ///
  /// In en, this message translates to:
  /// **'Read aloud'**
  String get narrativeReadAloud;

  /// No description provided for @narrativeStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get narrativeStop;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved trips'**
  String get historyTitle;

  /// No description provided for @historyEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No saved trips yet'**
  String get historyEmptyTitle;

  /// No description provided for @historyEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Plan a trip and tap the bookmark to keep it here for later.'**
  String get historyEmptyBody;

  /// No description provided for @historyPlanCta.
  ///
  /// In en, this message translates to:
  /// **'Plan a trip'**
  String get historyPlanCta;

  /// No description provided for @historyDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted {trip}'**
  String historyDeleted(String trip);

  /// No description provided for @historyReplanFailed.
  ///
  /// In en, this message translates to:
  /// **'Re-plan failed: {status}'**
  String historyReplanFailed(int status);

  /// No description provided for @historyDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get historyDeleteTooltip;

  /// No description provided for @historyReopenCta.
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get historyReopenCta;

  /// No description provided for @historyRepeatCta.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get historyRepeatCta;

  /// No description provided for @resultFuelCollapsedHint.
  ///
  /// In en, this message translates to:
  /// **'Show the {count} cheapest stations along the route'**
  String resultFuelCollapsedHint(int count);

  /// No description provided for @resultBestTimeVsFreeFlow.
  ///
  /// In en, this message translates to:
  /// **'{delta} min vs free flow'**
  String resultBestTimeVsFreeFlow(String delta);

  /// No description provided for @resultBestTimeEarlier.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min earlier than your target'**
  String resultBestTimeEarlier(int minutes);

  /// No description provided for @resultBestTimeLater.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min later than your target'**
  String resultBestTimeLater(int minutes);

  /// No description provided for @resultHeroSavedBadge.
  ///
  /// In en, this message translates to:
  /// **'{magnitude} saved'**
  String resultHeroSavedBadge(String magnitude);

  /// No description provided for @consistencyNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Trip plan needs review'**
  String get consistencyNeedsReview;

  /// No description provided for @consistencyNeedsReviewErrors.
  ///
  /// In en, this message translates to:
  /// **'Trip plan needs review · {errors} errors'**
  String consistencyNeedsReviewErrors(int errors);

  /// No description provided for @consistencyNeedsReviewMixed.
  ///
  /// In en, this message translates to:
  /// **'Trip plan needs review · {errors} error(s), {warnings} warning(s)'**
  String consistencyNeedsReviewMixed(int errors, int warnings);

  /// No description provided for @consistencyHeadsUp.
  ///
  /// In en, this message translates to:
  /// **'Heads-up on your trip plan'**
  String get consistencyHeadsUp;

  /// No description provided for @consistencyHeadsUpWarnings.
  ///
  /// In en, this message translates to:
  /// **'Heads-up on your trip plan · {warnings} warnings'**
  String consistencyHeadsUpWarnings(int warnings);

  /// No description provided for @consistencyMoreCount.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String consistencyMoreCount(int count);

  /// No description provided for @planProfileClearOverride.
  ///
  /// In en, this message translates to:
  /// **'Clear override'**
  String get planProfileClearOverride;

  /// No description provided for @weatherSunny.
  ///
  /// In en, this message translates to:
  /// **'Sunny'**
  String get weatherSunny;

  /// No description provided for @weatherPartlyCloudy.
  ///
  /// In en, this message translates to:
  /// **'Partly cloudy'**
  String get weatherPartlyCloudy;

  /// No description provided for @weatherCloudy.
  ///
  /// In en, this message translates to:
  /// **'Cloudy'**
  String get weatherCloudy;

  /// No description provided for @weatherFog.
  ///
  /// In en, this message translates to:
  /// **'Fog'**
  String get weatherFog;

  /// No description provided for @weatherDrizzle.
  ///
  /// In en, this message translates to:
  /// **'Drizzle'**
  String get weatherDrizzle;

  /// No description provided for @weatherRain.
  ///
  /// In en, this message translates to:
  /// **'Rain'**
  String get weatherRain;

  /// No description provided for @weatherHeavyRain.
  ///
  /// In en, this message translates to:
  /// **'Heavy rain'**
  String get weatherHeavyRain;

  /// No description provided for @weatherSnow.
  ///
  /// In en, this message translates to:
  /// **'Snow'**
  String get weatherSnow;

  /// No description provided for @weatherHeavySnow.
  ///
  /// In en, this message translates to:
  /// **'Heavy snow'**
  String get weatherHeavySnow;

  /// No description provided for @weatherThunderstorm.
  ///
  /// In en, this message translates to:
  /// **'Thunderstorm'**
  String get weatherThunderstorm;

  /// No description provided for @historyBestAt.
  ///
  /// In en, this message translates to:
  /// **'Best {when}'**
  String historyBestAt(String when);

  /// No description provided for @historyWantedAt.
  ///
  /// In en, this message translates to:
  /// **'Wanted {when}'**
  String historyWantedAt(String when);

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search a city, museum, place…'**
  String get searchPlaceholder;

  /// No description provided for @placesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'SAVED PLACES'**
  String get placesSectionTitle;

  /// No description provided for @placeSaveAsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save as place'**
  String get placeSaveAsTooltip;

  /// No description provided for @placeSaveDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save as…'**
  String get placeSaveDialogTitle;

  /// No description provided for @placeCustomLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get placeCustomLabel;

  /// No description provided for @placeCustomHint.
  ///
  /// In en, this message translates to:
  /// **'Home, Work, Grandma…'**
  String get placeCustomHint;

  /// No description provided for @placePresetHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get placePresetHome;

  /// No description provided for @placePresetWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get placePresetWork;

  /// No description provided for @placePresetSchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get placePresetSchool;

  /// No description provided for @placePresetGym.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get placePresetGym;

  /// No description provided for @placeSavedAs.
  ///
  /// In en, this message translates to:
  /// **'Saved as {label}'**
  String placeSavedAs(String label);

  /// No description provided for @favoritesTabPlaces.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get favoritesTabPlaces;

  /// No description provided for @favoritesEmptyPlaces.
  ///
  /// In en, this message translates to:
  /// **'No saved places yet. Tap the star on any search result to save it.'**
  String get favoritesEmptyPlaces;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsSectionUnits.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get settingsSectionUnits;

  /// No description provided for @settingsUnitSystem.
  ///
  /// In en, this message translates to:
  /// **'Unit system'**
  String get settingsUnitSystem;

  /// No description provided for @settingsUnitsMetric.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get settingsUnitsMetric;

  /// No description provided for @settingsUnitsImperial.
  ///
  /// In en, this message translates to:
  /// **'Imperial'**
  String get settingsUnitsImperial;

  /// No description provided for @settingsSectionTrip.
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get settingsSectionTrip;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// No description provided for @settingsSectionData.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get settingsSectionData;

  /// No description provided for @settingsExportData.
  ///
  /// In en, this message translates to:
  /// **'Download my data'**
  String get settingsExportData;

  /// No description provided for @settingsExportDataSub.
  ///
  /// In en, this message translates to:
  /// **'Get a JSON file with everything MyTravelPal holds about you.'**
  String get settingsExportDataSub;

  /// No description provided for @settingsExportError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t export data — check your connection.'**
  String get settingsExportError;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsDeleteAccountSub.
  ///
  /// In en, this message translates to:
  /// **'Removes your profile, saved trips and preferences permanently.'**
  String get settingsDeleteAccountSub;

  /// No description provided for @settingsDeleteAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get settingsDeleteAccountConfirmTitle;

  /// No description provided for @settingsDeleteAccountConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This deletes your profile and every saved trip from our servers. This action cannot be undone.'**
  String get settingsDeleteAccountConfirmBody;

  /// No description provided for @settingsDeleteAccountCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsDeleteAccountCancel;

  /// No description provided for @settingsDeleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete forever'**
  String get settingsDeleteAccountConfirm;

  /// No description provided for @settingsDeleteAccountPartial.
  ///
  /// In en, this message translates to:
  /// **'Signed out locally, but the server may still hold data. Try again from a stable connection.'**
  String get settingsDeleteAccountPartial;

  /// No description provided for @settingsSupport.
  ///
  /// In en, this message translates to:
  /// **'Support & contact'**
  String get settingsSupport;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get settingsTerms;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @planTooltipSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get planTooltipSettings;

  /// No description provided for @styleSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Travel style'**
  String get styleSectionTitle;

  /// No description provided for @styleSectionEyebrow.
  ///
  /// In en, this message translates to:
  /// **'How you like to drive'**
  String get styleSectionEyebrow;

  /// No description provided for @stylePresetDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get stylePresetDirect;

  /// No description provided for @stylePresetBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get stylePresetBalanced;

  /// No description provided for @stylePresetSlow.
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get stylePresetSlow;

  /// No description provided for @stylePresetDirectHint.
  ///
  /// In en, this message translates to:
  /// **'Push through, minimal stops, never overnight.'**
  String get stylePresetDirectHint;

  /// No description provided for @stylePresetBalancedHint.
  ///
  /// In en, this message translates to:
  /// **'Steady pace, breaks when it makes sense.'**
  String get stylePresetBalancedHint;

  /// No description provided for @stylePresetSlowHint.
  ///
  /// In en, this message translates to:
  /// **'Savour the drive, generous stops, split long trips.'**
  String get stylePresetSlowHint;

  /// No description provided for @styleCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get styleCustom;

  /// No description provided for @styleAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get styleAdvanced;

  /// No description provided for @stylePaceLabel.
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get stylePaceLabel;

  /// No description provided for @stylePacePush.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get stylePacePush;

  /// No description provided for @stylePaceSteady.
  ///
  /// In en, this message translates to:
  /// **'Steady'**
  String get stylePaceSteady;

  /// No description provided for @stylePaceSavour.
  ///
  /// In en, this message translates to:
  /// **'Savour'**
  String get stylePaceSavour;

  /// No description provided for @styleOvernightLabel.
  ///
  /// In en, this message translates to:
  /// **'Overnight stops'**
  String get styleOvernightLabel;

  /// No description provided for @styleOvernightNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get styleOvernightNever;

  /// No description provided for @styleOvernightIfNeeded.
  ///
  /// In en, this message translates to:
  /// **'If needed'**
  String get styleOvernightIfNeeded;

  /// No description provided for @styleOvernightAlwaysIfLong.
  ///
  /// In en, this message translates to:
  /// **'Split long trips'**
  String get styleOvernightAlwaysIfLong;

  /// No description provided for @styleDailyCapLabel.
  ///
  /// In en, this message translates to:
  /// **'Max hours driving per day'**
  String get styleDailyCapLabel;

  /// No description provided for @styleBedtimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Bedtime'**
  String get styleBedtimeLabel;

  /// No description provided for @styleWakeLabel.
  ///
  /// In en, this message translates to:
  /// **'Wake time'**
  String get styleWakeLabel;

  /// No description provided for @styleBreakLabel.
  ///
  /// In en, this message translates to:
  /// **'Break style'**
  String get styleBreakLabel;

  /// No description provided for @styleBreakMinimal.
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get styleBreakMinimal;

  /// No description provided for @styleBreakScenic.
  ///
  /// In en, this message translates to:
  /// **'Scenic'**
  String get styleBreakScenic;

  /// No description provided for @styleBreakFoodie.
  ///
  /// In en, this message translates to:
  /// **'Foodie'**
  String get styleBreakFoodie;

  /// No description provided for @planStyleChip.
  ///
  /// In en, this message translates to:
  /// **'{preset} · {hours}h/day'**
  String planStyleChip(String preset, int hours);

  /// No description provided for @planStyleChipCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom · {hours}h/day'**
  String planStyleChipCustom(int hours);

  /// No description provided for @planStyleOverrideTitle.
  ///
  /// In en, this message translates to:
  /// **'Style for this trip'**
  String get planStyleOverrideTitle;

  /// No description provided for @planStyleOverrideSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Overrides your saved profile only for this plan.'**
  String get planStyleOverrideSubtitle;

  /// No description provided for @planStyleUseSavedProfile.
  ///
  /// In en, this message translates to:
  /// **'Use my saved profile'**
  String get planStyleUseSavedProfile;

  /// No description provided for @arrivalHintTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'d arrive at {hour}:00'**
  String arrivalHintTitle(String hour);

  /// No description provided for @arrivalHintBody.
  ///
  /// In en, this message translates to:
  /// **'Later than your bedtime ({bedtime}:00). Consider stopping overnight — hotels are ready below.'**
  String arrivalHintBody(String bedtime);

  /// No description provided for @arrivalHintCta.
  ///
  /// In en, this message translates to:
  /// **'See hotels'**
  String get arrivalHintCta;

  /// No description provided for @vehicleTypeCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get vehicleTypeCar;

  /// No description provided for @vehicleTypeMotorbike.
  ///
  /// In en, this message translates to:
  /// **'Motorbike'**
  String get vehicleTypeMotorbike;

  /// No description provided for @vehicleTypeVan.
  ///
  /// In en, this message translates to:
  /// **'Van'**
  String get vehicleTypeVan;

  /// No description provided for @vehicleTypeCamper.
  ///
  /// In en, this message translates to:
  /// **'Camper'**
  String get vehicleTypeCamper;

  /// No description provided for @fuelTypePetrol.
  ///
  /// In en, this message translates to:
  /// **'Petrol'**
  String get fuelTypePetrol;

  /// No description provided for @fuelTypeDiesel.
  ///
  /// In en, this message translates to:
  /// **'Diesel'**
  String get fuelTypeDiesel;

  /// No description provided for @fuelTypeHybrid.
  ///
  /// In en, this message translates to:
  /// **'Hybrid'**
  String get fuelTypeHybrid;

  /// No description provided for @fuelTypeElectric.
  ///
  /// In en, this message translates to:
  /// **'Electric'**
  String get fuelTypeElectric;

  /// No description provided for @fuelTypeLpg.
  ///
  /// In en, this message translates to:
  /// **'LPG'**
  String get fuelTypeLpg;

  /// No description provided for @routeVariantFastest.
  ///
  /// In en, this message translates to:
  /// **'Fastest'**
  String get routeVariantFastest;

  /// No description provided for @routeVariantTollFree.
  ///
  /// In en, this message translates to:
  /// **'Toll-free'**
  String get routeVariantTollFree;

  /// No description provided for @routeVariantScenic.
  ///
  /// In en, this message translates to:
  /// **'Scenic'**
  String get routeVariantScenic;

  /// No description provided for @eventTypeFire.
  ///
  /// In en, this message translates to:
  /// **'Fire'**
  String get eventTypeFire;

  /// No description provided for @eventTypeStrike.
  ///
  /// In en, this message translates to:
  /// **'Strike'**
  String get eventTypeStrike;

  /// No description provided for @eventTypeWeather.
  ///
  /// In en, this message translates to:
  /// **'Adverse weather'**
  String get eventTypeWeather;

  /// No description provided for @eventTypeAccident.
  ///
  /// In en, this message translates to:
  /// **'Accident'**
  String get eventTypeAccident;

  /// No description provided for @eventTypeRoadwork.
  ///
  /// In en, this message translates to:
  /// **'Roadwork'**
  String get eventTypeRoadwork;

  /// No description provided for @eventTypeFlood.
  ///
  /// In en, this message translates to:
  /// **'Flood'**
  String get eventTypeFlood;

  /// No description provided for @eventTypeSnow.
  ///
  /// In en, this message translates to:
  /// **'Snow'**
  String get eventTypeSnow;

  /// No description provided for @eventTypeProtest.
  ///
  /// In en, this message translates to:
  /// **'Protest'**
  String get eventTypeProtest;

  /// No description provided for @eventTypeEarthquake.
  ///
  /// In en, this message translates to:
  /// **'Earthquake'**
  String get eventTypeEarthquake;

  /// No description provided for @eventTypeLandslide.
  ///
  /// In en, this message translates to:
  /// **'Landslide'**
  String get eventTypeLandslide;

  /// No description provided for @eventTypeAvalanche.
  ///
  /// In en, this message translates to:
  /// **'Avalanche'**
  String get eventTypeAvalanche;

  /// No description provided for @eventTypeClosure.
  ///
  /// In en, this message translates to:
  /// **'Road closure'**
  String get eventTypeClosure;

  /// No description provided for @eventTypeHeatwave.
  ///
  /// In en, this message translates to:
  /// **'Heatwave'**
  String get eventTypeHeatwave;

  /// No description provided for @eventTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get eventTypeOther;

  /// No description provided for @tollStretchLabel.
  ///
  /// In en, this message translates to:
  /// **'Toll stretch {index} / {total}'**
  String tollStretchLabel(int index, int total);

  /// No description provided for @tollBoothLabel.
  ///
  /// In en, this message translates to:
  /// **'Toll booth {index}'**
  String tollBoothLabel(int index);

  /// No description provided for @addedToRouteLabel.
  ///
  /// In en, this message translates to:
  /// **'ADDED'**
  String get addedToRouteLabel;

  /// No description provided for @replanWithStops.
  ///
  /// In en, this message translates to:
  /// **'Recalculate route with stops'**
  String get replanWithStops;

  /// No description provided for @addToRouteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add to route'**
  String get addToRouteTooltip;

  /// No description provided for @removeFromRouteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove from route'**
  String get removeFromRouteTooltip;

  /// No description provided for @addedStopsChip.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 stop added · +{minutes} min} other{{count} stops added · +{minutes} min}}'**
  String addedStopsChip(int count, String minutes);

  /// No description provided for @addedStopsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get addedStopsClear;

  /// No description provided for @settingsLicensesAndData.
  ///
  /// In en, this message translates to:
  /// **'Licenses & data sources'**
  String get settingsLicensesAndData;

  /// No description provided for @settingsLicensesAndDataSub.
  ///
  /// In en, this message translates to:
  /// **'Attributions for open data and libraries'**
  String get settingsLicensesAndDataSub;

  /// No description provided for @attributionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Licenses & data'**
  String get attributionsTitle;

  /// No description provided for @attributionsIntro.
  ///
  /// In en, this message translates to:
  /// **'MyTravelPal is built on open data feeds and open-source libraries. This screen credits every source we use, links to the underlying licences, and covers our legal attribution obligations.'**
  String get attributionsIntro;

  /// No description provided for @attributionsSectionMap.
  ///
  /// In en, this message translates to:
  /// **'Map & geodata'**
  String get attributionsSectionMap;

  /// No description provided for @attributionsSectionFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel prices'**
  String get attributionsSectionFuel;

  /// No description provided for @attributionsSectionHazards.
  ///
  /// In en, this message translates to:
  /// **'Adverse events'**
  String get attributionsSectionHazards;

  /// No description provided for @attributionsSectionWeather.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get attributionsSectionWeather;

  /// No description provided for @attributionsSectionSoftware.
  ///
  /// In en, this message translates to:
  /// **'Software libraries'**
  String get attributionsSectionSoftware;

  /// No description provided for @attributionsShowLicenses.
  ///
  /// In en, this message translates to:
  /// **'Show package licences'**
  String get attributionsShowLicenses;

  /// No description provided for @attributionsFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load attributions. Please try again.'**
  String get attributionsFailed;

  /// No description provided for @fuelPriceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Price not available'**
  String get fuelPriceUnavailable;

  /// No description provided for @fuelPriceUnavailableHint.
  ///
  /// In en, this message translates to:
  /// **'No public price feed for this country yet'**
  String get fuelPriceUnavailableHint;

  /// No description provided for @planSectionOptionalEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get planSectionOptionalEyebrow;

  /// No description provided for @planOptAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Alert me to critical events on the route'**
  String get planOptAlertsTitle;

  /// No description provided for @planOptAlertsSub.
  ///
  /// In en, this message translates to:
  /// **'Fires, floods, severe weather, and serious hazards within 25 km of the route.'**
  String get planOptAlertsSub;

  /// No description provided for @planOptTollFreeTitle.
  ///
  /// In en, this message translates to:
  /// **'Show toll-free alternative'**
  String get planOptTollFreeTitle;

  /// No description provided for @planOptTollFreeSub.
  ///
  /// In en, this message translates to:
  /// **'Compare a route that skips tolls — money saved vs. minutes added.'**
  String get planOptTollFreeSub;

  /// No description provided for @planOptHourlyTollTitle.
  ///
  /// In en, this message translates to:
  /// **'Hourly toll analysis'**
  String get planOptHourlyTollTitle;

  /// No description provided for @planOptHourlyTollSub.
  ///
  /// In en, this message translates to:
  /// **'When during the day skipping tolls actually beats keeping them (traffic-aware).'**
  String get planOptHourlyTollSub;

  /// No description provided for @planOptRouteVariantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Compare route variants'**
  String get planOptRouteVariantsTitle;

  /// No description provided for @planOptRouteVariantsSub.
  ///
  /// In en, this message translates to:
  /// **'Fastest vs. toll-free vs. scenic — see all three side by side on the results.'**
  String get planOptRouteVariantsSub;

  /// No description provided for @planOptAvoidMotorwaysTitle.
  ///
  /// In en, this message translates to:
  /// **'Avoid motorways'**
  String get planOptAvoidMotorwaysTitle;

  /// No description provided for @planOptAvoidMotorwaysSub.
  ///
  /// In en, this message translates to:
  /// **'Slower and longer, but no tolls and quieter.'**
  String get planOptAvoidMotorwaysSub;

  /// No description provided for @planOptPreferScenicTitle.
  ///
  /// In en, this message translates to:
  /// **'Prefer scenic'**
  String get planOptPreferScenicTitle;

  /// No description provided for @planOptPreferScenicSub.
  ///
  /// In en, this message translates to:
  /// **'Bias to more interesting roads. A little slower.'**
  String get planOptPreferScenicSub;

  /// No description provided for @planPremiumBadge.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get planPremiumBadge;

  /// No description provided for @planProfileTravellers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 traveller} other{{count} travellers}}'**
  String planProfileTravellers(int count);

  /// No description provided for @planProfileWithKids.
  ///
  /// In en, this message translates to:
  /// **'kids'**
  String get planProfileWithKids;

  /// No description provided for @planProfileWithPets.
  ///
  /// In en, this message translates to:
  /// **'pets'**
  String get planProfileWithPets;

  /// No description provided for @planProfileOverrideActive.
  ///
  /// In en, this message translates to:
  /// **'OVERRIDE ACTIVE'**
  String get planProfileOverrideActive;

  /// No description provided for @planProfileOverride.
  ///
  /// In en, this message translates to:
  /// **'Override for this trip'**
  String get planProfileOverride;

  /// No description provided for @planProfileOverriding.
  ///
  /// In en, this message translates to:
  /// **'Overriding for this trip'**
  String get planProfileOverriding;

  /// No description provided for @profilePromptSetup.
  ///
  /// In en, this message translates to:
  /// **'Set up your trip profile'**
  String get profilePromptSetup;

  /// No description provided for @hotelPrefTitle.
  ///
  /// In en, this message translates to:
  /// **'Find hotels near stops'**
  String get hotelPrefTitle;

  /// No description provided for @hotelPrefSubOn.
  ///
  /// In en, this message translates to:
  /// **'Shows accommodation options near each overnight stop'**
  String get hotelPrefSubOn;

  /// No description provided for @hotelPrefSubOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get hotelPrefSubOff;

  /// No description provided for @restaurantPrefTitle.
  ///
  /// In en, this message translates to:
  /// **'Add restaurants along the route'**
  String get restaurantPrefTitle;

  /// No description provided for @restaurantPrefSubEnabled.
  ///
  /// In en, this message translates to:
  /// **'Up to {minutes} min detour · {band}'**
  String restaurantPrefSubEnabled(int minutes, String band);

  /// No description provided for @restaurantPrefSubOff.
  ///
  /// In en, this message translates to:
  /// **'Off. Turn on to see restaurants near your route.'**
  String get restaurantPrefSubOff;

  /// No description provided for @prefMaxDetour.
  ///
  /// In en, this message translates to:
  /// **'Max detour: {minutes} min'**
  String prefMaxDetour(int minutes);

  /// No description provided for @prefBandBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get prefBandBudget;

  /// No description provided for @prefBandMid.
  ///
  /// In en, this message translates to:
  /// **'Mid'**
  String get prefBandMid;

  /// No description provided for @prefBandLuxury.
  ///
  /// In en, this message translates to:
  /// **'Luxury'**
  String get prefBandLuxury;

  /// No description provided for @prefBandAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get prefBandAny;

  /// No description provided for @mealSlotBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Suggested for breakfast'**
  String get mealSlotBreakfast;

  /// No description provided for @mealSlotLunch.
  ///
  /// In en, this message translates to:
  /// **'Suggested for lunch'**
  String get mealSlotLunch;

  /// No description provided for @mealSlotDinner.
  ///
  /// In en, this message translates to:
  /// **'Suggested for dinner'**
  String get mealSlotDinner;

  /// No description provided for @mealSlotOther.
  ///
  /// In en, this message translates to:
  /// **'Other restaurants'**
  String get mealSlotOther;

  /// No description provided for @poiDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km · +{minutes} min detour'**
  String poiDistanceKm(String km, String minutes);

  /// No description provided for @fuelSavingsChipCheap.
  ///
  /// In en, this message translates to:
  /// **'-{amount}€/L vs country avg'**
  String fuelSavingsChipCheap(String amount);

  /// No description provided for @fuelSavingsChipDear.
  ///
  /// In en, this message translates to:
  /// **'+{amount}€/L vs country avg'**
  String fuelSavingsChipDear(String amount);

  /// No description provided for @fuelArbitrageTitle.
  ///
  /// In en, this message translates to:
  /// **'Refuel smart on this route'**
  String get fuelArbitrageTitle;

  /// No description provided for @fuelArbitrageBody.
  ///
  /// In en, this message translates to:
  /// **'Fuel in {cheap} is around {cheapPrice}€/L. In {dear} it\'s ~{dearPrice}€/L. Filling the tank in {cheap} before crossing saves ~{savings}€.'**
  String fuelArbitrageBody(String cheap, String cheapPrice, String dear,
      String dearPrice, String savings);

  /// No description provided for @dayTabLabel.
  ///
  /// In en, this message translates to:
  /// **'Day {index}'**
  String dayTabLabel(int index);

  /// No description provided for @dayHeaderRange.
  ///
  /// In en, this message translates to:
  /// **'Day {index} · km {fromKm} → {toKm}'**
  String dayHeaderRange(int index, String fromKm, String toKm);

  /// No description provided for @dayHeaderCity.
  ///
  /// In en, this message translates to:
  /// **'Day {index} · {from} → {to}'**
  String dayHeaderCity(int index, String from, String to);

  /// No description provided for @dayArrivalMarker.
  ///
  /// In en, this message translates to:
  /// **'Arrive at your destination around {time}'**
  String dayArrivalMarker(String time);

  /// No description provided for @daySleepMarker.
  ///
  /// In en, this message translates to:
  /// **'Finish driving around {time}'**
  String daySleepMarker(String time);

  /// No description provided for @dayHeaderDwell.
  ///
  /// In en, this message translates to:
  /// **'Day {index} · {place}'**
  String dayHeaderDwell(int index, String place);

  /// No description provided for @daySleepStay.
  ///
  /// In en, this message translates to:
  /// **'Staying in {place}'**
  String daySleepStay(String place);

  /// No description provided for @nextStopHeroLabel.
  ///
  /// In en, this message translates to:
  /// **'Next suggested stop'**
  String get nextStopHeroLabel;

  /// No description provided for @nextStopHeroBody.
  ///
  /// In en, this message translates to:
  /// **'{slot} in {name} · around {time}'**
  String nextStopHeroBody(String slot, String name, String time);

  /// No description provided for @daySleepHotelsLabel.
  ///
  /// In en, this message translates to:
  /// **'Hotels near your overnight stop'**
  String get daySleepHotelsLabel;

  /// No description provided for @hotelDistFromStop.
  ///
  /// In en, this message translates to:
  /// **'{km} km from stop'**
  String hotelDistFromStop(String km);

  /// No description provided for @hotelDistFromDestination.
  ///
  /// In en, this message translates to:
  /// **'{km} km from destination'**
  String hotelDistFromDestination(String km);

  /// No description provided for @daySleepHotelsLabelDestination.
  ///
  /// In en, this message translates to:
  /// **'Hotels near your destination'**
  String get daySleepHotelsLabelDestination;

  /// No description provided for @daySleepHotelsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enable hotels in the plan preferences to see overnight options here.'**
  String get daySleepHotelsEmpty;

  /// No description provided for @restaurantPrefCuisinesLabel.
  ///
  /// In en, this message translates to:
  /// **'Cuisine'**
  String get restaurantPrefCuisinesLabel;

  /// No description provided for @cuisineItalian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get cuisineItalian;

  /// No description provided for @cuisineSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get cuisineSpanish;

  /// No description provided for @cuisineTapas.
  ///
  /// In en, this message translates to:
  /// **'Tapas'**
  String get cuisineTapas;

  /// No description provided for @cuisineFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get cuisineFrench;

  /// No description provided for @cuisineMediterranean.
  ///
  /// In en, this message translates to:
  /// **'Mediterranean'**
  String get cuisineMediterranean;

  /// No description provided for @cuisineAsian.
  ///
  /// In en, this message translates to:
  /// **'Asian'**
  String get cuisineAsian;

  /// No description provided for @cuisineIndian.
  ///
  /// In en, this message translates to:
  /// **'Indian'**
  String get cuisineIndian;

  /// No description provided for @cuisineBurger.
  ///
  /// In en, this message translates to:
  /// **'Burgers'**
  String get cuisineBurger;

  /// No description provided for @cuisineSeafood.
  ///
  /// In en, this message translates to:
  /// **'Seafood'**
  String get cuisineSeafood;

  /// No description provided for @cuisineVegetarian.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get cuisineVegetarian;

  /// No description provided for @cuisineBbq.
  ///
  /// In en, this message translates to:
  /// **'BBQ / grill'**
  String get cuisineBbq;

  /// No description provided for @cuisineRegional.
  ///
  /// In en, this message translates to:
  /// **'Regional'**
  String get cuisineRegional;

  /// No description provided for @timeWindowSpanLabel.
  ///
  /// In en, this message translates to:
  /// **'Show ±{hours}h'**
  String timeWindowSpanLabel(int hours);

  /// No description provided for @timeWindowSpanHelper.
  ///
  /// In en, this message translates to:
  /// **'Drag to widen the window and see if leaving earlier or later saves more time.'**
  String get timeWindowSpanHelper;

  /// No description provided for @timeWindowTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a bar to replan with that departure time.'**
  String get timeWindowTapHint;

  /// No description provided for @planLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Building your road trip'**
  String get planLoadingTitle;

  /// No description provided for @planLoadingStepRouting.
  ///
  /// In en, this message translates to:
  /// **'Computing the fastest route…'**
  String get planLoadingStepRouting;

  /// No description provided for @planLoadingStepTraffic.
  ///
  /// In en, this message translates to:
  /// **'Sampling traffic to pick the best departure hour…'**
  String get planLoadingStepTraffic;

  /// No description provided for @planLoadingStepFuel.
  ///
  /// In en, this message translates to:
  /// **'Fetching live fuel prices along the corridor…'**
  String get planLoadingStepFuel;

  /// No description provided for @planLoadingStepHotels.
  ///
  /// In en, this message translates to:
  /// **'Looking for hotels around any overnight stops…'**
  String get planLoadingStepHotels;

  /// No description provided for @planLoadingStepRestaurants.
  ///
  /// In en, this message translates to:
  /// **'Sorting restaurants by meal slot and cuisine…'**
  String get planLoadingStepRestaurants;

  /// No description provided for @planLoadingStepAlerts.
  ///
  /// In en, this message translates to:
  /// **'Scanning for fires, floods, severe weather, and hazards…'**
  String get planLoadingStepAlerts;

  /// No description provided for @planLoadingStepTolls.
  ///
  /// In en, this message translates to:
  /// **'Comparing toll routes with toll-free alternatives…'**
  String get planLoadingStepTolls;

  /// No description provided for @planLoadingStepAlmost.
  ///
  /// In en, this message translates to:
  /// **'Almost there — assembling everything for you…'**
  String get planLoadingStepAlmost;

  /// No description provided for @planLoadingHelper.
  ///
  /// In en, this message translates to:
  /// **'This can take up to a few minutes. Feel free to keep the phone in your pocket.'**
  String get planLoadingHelper;

  /// No description provided for @timeWindowApplyLabel.
  ///
  /// In en, this message translates to:
  /// **'Apply · depart at {time}'**
  String timeWindowApplyLabel(String time);

  /// No description provided for @planErrorAuth.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Sign in again and try once more.'**
  String get planErrorAuth;

  /// No description provided for @planErrorPremium.
  ///
  /// In en, this message translates to:
  /// **'This route needs Premium. Enable it to include hourly toll analysis.'**
  String get planErrorPremium;

  /// No description provided for @planErrorRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Too many requests in a short time. Wait a few seconds and retry.'**
  String get planErrorRateLimit;

  /// No description provided for @planErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while planning (code {code}). Retry or change your inputs.'**
  String planErrorGeneric(int code);

  /// No description provided for @planErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t reach the server. Check your connection and retry.'**
  String get planErrorNetwork;

  /// No description provided for @planErrorRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get planErrorRetry;

  /// No description provided for @emptyAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'No serious hazards detected'**
  String get emptyAlertsTitle;

  /// No description provided for @emptyAlertsBody.
  ///
  /// In en, this message translates to:
  /// **'No fires, floods or serious hazards reported on your corridor. Safe travels.'**
  String get emptyAlertsBody;

  /// No description provided for @emptyHotelsTitle.
  ///
  /// In en, this message translates to:
  /// **'No hotels close to the route'**
  String get emptyHotelsTitle;

  /// No description provided for @emptyHotelsBody.
  ///
  /// In en, this message translates to:
  /// **'Try widening the max detour or changing the price band to see more options.'**
  String get emptyHotelsBody;

  /// No description provided for @emptyRestaurantsTitle.
  ///
  /// In en, this message translates to:
  /// **'No restaurants match'**
  String get emptyRestaurantsTitle;

  /// No description provided for @emptyRestaurantsBody.
  ///
  /// In en, this message translates to:
  /// **'Widen the max detour or clear cuisine filters to see more options.'**
  String get emptyRestaurantsBody;

  /// No description provided for @onboardEyebrowFuel.
  ///
  /// In en, this message translates to:
  /// **'REAL PRICES'**
  String get onboardEyebrowFuel;

  /// No description provided for @onboardTitleFuel.
  ///
  /// In en, this message translates to:
  /// **'Save on every refuel'**
  String get onboardTitleFuel;

  /// No description provided for @onboardBodyFuel.
  ///
  /// In en, this message translates to:
  /// **'Live per-station prices along your route across Europe. Premium brands mixed in with low-cost independents.'**
  String get onboardBodyFuel;

  /// No description provided for @onboardEyebrowDriving.
  ///
  /// In en, this message translates to:
  /// **'ON THE ROAD'**
  String get onboardEyebrowDriving;

  /// No description provided for @onboardTitleDriving.
  ///
  /// In en, this message translates to:
  /// **'Your smart copilot'**
  String get onboardTitleDriving;

  /// No description provided for @onboardBodyDriving.
  ///
  /// In en, this message translates to:
  /// **'Live dashboard with next stop, dynamic ETA and new alerts. Android Auto ready.'**
  String get onboardBodyDriving;

  /// No description provided for @onboardEyebrowProfile.
  ///
  /// In en, this message translates to:
  /// **'PERSONALISED'**
  String get onboardEyebrowProfile;

  /// No description provided for @onboardTitleProfile.
  ///
  /// In en, this message translates to:
  /// **'Fill your profile'**
  String get onboardTitleProfile;

  /// No description provided for @onboardBodyProfile.
  ///
  /// In en, this message translates to:
  /// **'Without a profile we only optimise time. With one we compute real fuel, hotels and meal times tuned to you.'**
  String get onboardBodyProfile;

  /// No description provided for @multiDaySleepLabel.
  ///
  /// In en, this message translates to:
  /// **'You\'ll sleep at'**
  String get multiDaySleepLabel;

  /// No description provided for @multiDaySleepNoHotel.
  ///
  /// In en, this message translates to:
  /// **'Overnight stop — no hotel available'**
  String get multiDaySleepNoHotel;

  /// No description provided for @resumeTripTitle.
  ///
  /// In en, this message translates to:
  /// **'Resume your trip?'**
  String get resumeTripTitle;

  /// No description provided for @resumeTripBody.
  ///
  /// In en, this message translates to:
  /// **'We detected a {origin} → {destination} trip in progress. Continue where you left off?'**
  String resumeTripBody(String origin, String destination);

  /// No description provided for @resumeTripResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeTripResume;

  /// No description provided for @resumeTripDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get resumeTripDismiss;

  /// No description provided for @hotelPrefStarsLabel.
  ///
  /// In en, this message translates to:
  /// **'Stars'**
  String get hotelPrefStarsLabel;

  /// No description provided for @hotelPrefDestRadiusLabel.
  ///
  /// In en, this message translates to:
  /// **'Radius from destination'**
  String get hotelPrefDestRadiusLabel;

  /// No description provided for @biometricPromptReason.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity to open MyTravelPal'**
  String get biometricPromptReason;

  /// No description provided for @biometricPromptSettings.
  ///
  /// In en, this message translates to:
  /// **'Confirm to enable biometric unlock'**
  String get biometricPromptSettings;

  /// No description provided for @planDepartureLabel.
  ///
  /// In en, this message translates to:
  /// **'Preferred departure'**
  String get planDepartureLabel;

  /// No description provided for @hotelPrefStarsAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get hotelPrefStarsAny;

  /// No description provided for @hotelPrefParkingTitle.
  ///
  /// In en, this message translates to:
  /// **'With parking'**
  String get hotelPrefParkingTitle;

  /// No description provided for @hotelPrefParkingSub.
  ///
  /// In en, this message translates to:
  /// **'Only hotels tagged with parking. Ones missing the tag pass through.'**
  String get hotelPrefParkingSub;

  /// No description provided for @hotelFilterParking.
  ///
  /// In en, this message translates to:
  /// **'Parking'**
  String get hotelFilterParking;

  /// No description provided for @hotelFilterWifi.
  ///
  /// In en, this message translates to:
  /// **'Free WiFi'**
  String get hotelFilterWifi;

  /// No description provided for @hotelFilterAccessible.
  ///
  /// In en, this message translates to:
  /// **'Accessible'**
  String get hotelFilterAccessible;

  /// No description provided for @hotelFilterOtherTypes.
  ///
  /// In en, this message translates to:
  /// **'Apartments, houses & more'**
  String get hotelFilterOtherTypes;

  /// No description provided for @restaurantFilterVegetarian.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get restaurantFilterVegetarian;

  /// No description provided for @restaurantFilterVegan.
  ///
  /// In en, this message translates to:
  /// **'Vegan'**
  String get restaurantFilterVegan;

  /// No description provided for @restaurantFilterGlutenFree.
  ///
  /// In en, this message translates to:
  /// **'Gluten-free'**
  String get restaurantFilterGlutenFree;

  /// No description provided for @restaurantFilterHalal.
  ///
  /// In en, this message translates to:
  /// **'Halal'**
  String get restaurantFilterHalal;

  /// No description provided for @restaurantFilterKosher.
  ///
  /// In en, this message translates to:
  /// **'Kosher'**
  String get restaurantFilterKosher;

  /// No description provided for @restaurantDietaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Dietary'**
  String get restaurantDietaryLabel;

  /// No description provided for @tollSkipSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get tollSkipSelectAll;

  /// No description provided for @mapShowLabel.
  ///
  /// In en, this message translates to:
  /// **'Show map'**
  String get mapShowLabel;

  /// No description provided for @mapHideLabel.
  ///
  /// In en, this message translates to:
  /// **'Hide map'**
  String get mapHideLabel;

  /// No description provided for @tripCostTitle.
  ///
  /// In en, this message translates to:
  /// **'TOTAL TRIP COST'**
  String get tripCostTitle;

  /// No description provided for @tripCostFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get tripCostFuel;

  /// No description provided for @tripCostTolls.
  ///
  /// In en, this message translates to:
  /// **'Tolls'**
  String get tripCostTolls;

  /// No description provided for @tripCostMeals.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get tripCostMeals;

  /// No description provided for @tripCostHotel.
  ///
  /// In en, this message translates to:
  /// **'Hotel'**
  String get tripCostHotel;

  /// No description provided for @tripCostTotal.
  ///
  /// In en, this message translates to:
  /// **'Total estimated'**
  String get tripCostTotal;

  /// No description provided for @addToRouteLabel.
  ///
  /// In en, this message translates to:
  /// **'Add to route'**
  String get addToRouteLabel;

  /// No description provided for @biometricSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable biometric login?'**
  String get biometricSetupTitle;

  /// No description provided for @biometricSetupBody.
  ///
  /// In en, this message translates to:
  /// **'Use your fingerprint or face to unlock MyTravelPal next time.'**
  String get biometricSetupBody;

  /// No description provided for @biometricSetupEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get biometricSetupEnable;

  /// No description provided for @biometricSetupSkip.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get biometricSetupSkip;

  /// No description provided for @weatherAlongRouteTitle.
  ///
  /// In en, this message translates to:
  /// **'WEATHER ALONG YOUR ROUTE'**
  String get weatherAlongRouteTitle;

  /// No description provided for @fuelNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Fill up before the border!'**
  String get fuelNotificationTitle;

  /// No description provided for @fuelNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'Fuel in {cheap} (~{price}€/L) before crossing into {pricey} — save ~{savings}€ per tank'**
  String fuelNotificationBody(
      String cheap, String price, String pricey, String savings);

  /// No description provided for @tutorialSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get tutorialSkip;

  /// No description provided for @tutorialOriginTitle.
  ///
  /// In en, this message translates to:
  /// **'Where are you starting?'**
  String get tutorialOriginTitle;

  /// No description provided for @tutorialOriginBody.
  ///
  /// In en, this message translates to:
  /// **'Tap here to search for a city or use the location button to start from your current position.'**
  String get tutorialOriginBody;

  /// No description provided for @tutorialDestinationTitle.
  ///
  /// In en, this message translates to:
  /// **'Where are you going?'**
  String get tutorialDestinationTitle;

  /// No description provided for @tutorialDestinationBody.
  ///
  /// In en, this message translates to:
  /// **'Search for your destination. We\'ll plan the full route with stops, hotels, and tolls.'**
  String get tutorialDestinationBody;

  /// No description provided for @tutorialPrefsTitle.
  ///
  /// In en, this message translates to:
  /// **'Customize your trip'**
  String get tutorialPrefsTitle;

  /// No description provided for @tutorialPrefsBody.
  ///
  /// In en, this message translates to:
  /// **'Toggle hotels, restaurants, and alerts. Set dietary preferences, star ratings, and more.'**
  String get tutorialPrefsBody;

  /// No description provided for @tutorialTimeWindowTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick the best departure time'**
  String get tutorialTimeWindowTitle;

  /// No description provided for @tutorialTimeWindowBody.
  ///
  /// In en, this message translates to:
  /// **'Tap any row to replan your trip with that departure time. The chart shows traffic impact at each hour.'**
  String get tutorialTimeWindowBody;

  /// No description provided for @tutorialTollTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage toll costs'**
  String get tutorialTollTitle;

  /// No description provided for @tutorialTollBody.
  ///
  /// In en, this message translates to:
  /// **'Toggle individual toll stretches to skip. The total savings update in real time. The color strip shows the best hours to skip.'**
  String get tutorialTollBody;

  /// No description provided for @styleDailyCapRecommendedHint.
  ///
  /// In en, this message translates to:
  /// **'For this pace we suggest {hours} h/day.'**
  String styleDailyCapRecommendedHint(int hours);

  /// No description provided for @aaCoachTitle.
  ///
  /// In en, this message translates to:
  /// **'How to open it on Android Auto'**
  String get aaCoachTitle;

  /// No description provided for @aaCoachStep1.
  ///
  /// In en, this message translates to:
  /// **'Connect the phone to the car by USB (or wireless if your head unit supports it).'**
  String get aaCoachStep1;

  /// No description provided for @aaCoachStep2.
  ///
  /// In en, this message translates to:
  /// **'In the car\'s launcher, switch to the \'Point of Interest\' or \'Apps\' category. It does NOT appear next to Google Maps.'**
  String get aaCoachStep2;

  /// No description provided for @aaCoachStep3.
  ///
  /// In en, this message translates to:
  /// **'Tap MyTravelPal. The companion shows next stop, cheaper fuel and ETA.'**
  String get aaCoachStep3;

  /// No description provided for @aaCoachHint.
  ///
  /// In en, this message translates to:
  /// **'First launch takes a few seconds. Park with clear sky to get a GPS fix before starting.'**
  String get aaCoachHint;

  /// No description provided for @aaCoachDontShowAgain.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show again'**
  String get aaCoachDontShowAgain;

  /// No description provided for @aaCoachDone.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get aaCoachDone;

  /// No description provided for @batteryWhitelistTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop Android from closing us'**
  String get batteryWhitelistTitle;

  /// No description provided for @batteryWhitelistBody.
  ///
  /// In en, this message translates to:
  /// **'Xiaomi/MIUI, Samsung and other vendors kill backgrounded apps after a few minutes. If you\'re navigating with Google Maps and MyTravelPal dies, you lose the live alerts.'**
  String get batteryWhitelistBody;

  /// No description provided for @batteryWhitelistSteps.
  ///
  /// In en, this message translates to:
  /// **'Settings → Apps → MyTravelPal → Battery → No restrictions\n(or \'Don\'t optimize\' depending on your model)'**
  String get batteryWhitelistSteps;

  /// No description provided for @batteryWhitelistDontShowAgain.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show again'**
  String get batteryWhitelistDontShowAgain;

  /// No description provided for @batteryWhitelistLater.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get batteryWhitelistLater;

  /// No description provided for @batteryWhitelistOpen.
  ///
  /// In en, this message translates to:
  /// **'Open help'**
  String get batteryWhitelistOpen;

  /// No description provided for @planRoundTripTitle.
  ///
  /// In en, this message translates to:
  /// **'Round trip'**
  String get planRoundTripTitle;

  /// No description provided for @planRoundTripSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We plan the return leg at the same time with the same preferences.'**
  String get planRoundTripSubtitle;

  /// No description provided for @roundTripLegOutbound.
  ///
  /// In en, this message translates to:
  /// **'OUTBOUND'**
  String get roundTripLegOutbound;

  /// No description provided for @roundTripLegReturn.
  ///
  /// In en, this message translates to:
  /// **'RETURN'**
  String get roundTripLegReturn;

  /// No description provided for @roundTripSwapTo.
  ///
  /// In en, this message translates to:
  /// **'View {leg}'**
  String roundTripSwapTo(String leg);

  /// No description provided for @resultStartTrip.
  ///
  /// In en, this message translates to:
  /// **'Start trip'**
  String get resultStartTrip;

  /// No description provided for @navPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue in…'**
  String get navPickerTitle;

  /// No description provided for @tripDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'On the road'**
  String get tripDashboardTitle;

  /// No description provided for @tripDashboardCenterOnMe.
  ///
  /// In en, this message translates to:
  /// **'Centre on my location'**
  String get tripDashboardCenterOnMe;

  /// No description provided for @tripDashboardOpenNav.
  ///
  /// In en, this message translates to:
  /// **'Open navigation'**
  String get tripDashboardOpenNav;

  /// No description provided for @tripDashboardNextStopLabel.
  ///
  /// In en, this message translates to:
  /// **'NEXT {slot}'**
  String tripDashboardNextStopLabel(String slot);

  /// No description provided for @tripDashboardInMinutes.
  ///
  /// In en, this message translates to:
  /// **'in {n} min'**
  String tripDashboardInMinutes(int n);

  /// No description provided for @tripDashboardPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location denied. Grant the permission to see your position on the route.'**
  String get tripDashboardPermissionDenied;

  /// No description provided for @tripDashboardServiceDisabled.
  ///
  /// In en, this message translates to:
  /// **'GPS is off. Enable it to follow your progress on the route.'**
  String get tripDashboardServiceDisabled;

  /// No description provided for @tripDashboardProgressLine.
  ///
  /// In en, this message translates to:
  /// **'{done} / {total} km'**
  String tripDashboardProgressLine(String done, String total);

  /// No description provided for @tripDashboardEta.
  ///
  /// In en, this message translates to:
  /// **'ETA {time}'**
  String tripDashboardEta(String time);

  /// No description provided for @tripDashboardActiveNotifTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip in progress'**
  String get tripDashboardActiveNotifTitle;

  /// No description provided for @tripDashboardActiveNotifBody.
  ///
  /// In en, this message translates to:
  /// **'MyTravelPal is following your route in the background.'**
  String get tripDashboardActiveNotifBody;

  /// No description provided for @tripDashboardForegroundBodyBare.
  ///
  /// In en, this message translates to:
  /// **'{done} / {total} km covered'**
  String tripDashboardForegroundBodyBare(String done, String total);

  /// No description provided for @tripDashboardForegroundBodyWithStop.
  ///
  /// In en, this message translates to:
  /// **'{done} / {total} km · next stop: {name}'**
  String tripDashboardForegroundBodyWithStop(
      String done, String total, String name);

  /// No description provided for @tripDashboardSleepStopLabel.
  ///
  /// In en, this message translates to:
  /// **'hotel'**
  String get tripDashboardSleepStopLabel;

  /// No description provided for @alertApproachingStopTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop coming up'**
  String get alertApproachingStopTitle;

  /// No description provided for @alertApproachingStopBody.
  ///
  /// In en, this message translates to:
  /// **'{slot} at {name} in about {mins} min. Get ready for the exit.'**
  String alertApproachingStopBody(String slot, String name, int mins);

  /// No description provided for @alertNewAdverseAheadTitle.
  ///
  /// In en, this message translates to:
  /// **'New alert on your route'**
  String get alertNewAdverseAheadTitle;

  /// No description provided for @alertNewAdverseAheadBody.
  ///
  /// In en, this message translates to:
  /// **'{type} reported {km} km ahead.'**
  String alertNewAdverseAheadBody(String type, String km);

  /// No description provided for @alertDriftDetectedTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'ve left the route'**
  String get alertDriftDetectedTitle;

  /// No description provided for @alertDriftDetectedBody.
  ///
  /// In en, this message translates to:
  /// **'You\'re {off} m off the planned track. Recalculate?'**
  String alertDriftDetectedBody(String off);

  /// No description provided for @alertBehindScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Running behind'**
  String get alertBehindScheduleTitle;

  /// No description provided for @alertBehindScheduleBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll arrive {mins} min later than planned.'**
  String alertBehindScheduleBody(int mins);

  /// No description provided for @tripDashboardCheaperFuel.
  ///
  /// In en, this message translates to:
  /// **'{brand} in {km} km · save {cts} ct/L'**
  String tripDashboardCheaperFuel(String brand, String km, String cts);

  /// No description provided for @resultOptimalDeparture.
  ///
  /// In en, this message translates to:
  /// **'Your departure time is optimal'**
  String get resultOptimalDeparture;

  /// No description provided for @shortLastDayWarning.
  ///
  /// In en, this message translates to:
  /// **'Short last leg ({km} km) — you could arrive today if you push further the day before.'**
  String shortLastDayWarning(String km);

  /// No description provided for @prepareDepartureNow.
  ///
  /// In en, this message translates to:
  /// **'Leave now'**
  String get prepareDepartureNow;

  /// No description provided for @replanNewDepartureTitle.
  ///
  /// In en, this message translates to:
  /// **'Recalculating with new departure time…'**
  String get replanNewDepartureTitle;

  /// No description provided for @planStopReorderHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press the handle to reorder'**
  String get planStopReorderHint;

  /// No description provided for @planSwapOriginDestination.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get planSwapOriginDestination;

  /// No description provided for @planStopMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get planStopMoveUp;

  /// No description provided for @planStopMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get planStopMoveDown;

  /// No description provided for @recentTripsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent trips'**
  String get recentTripsTitle;

  /// No description provided for @recentTripsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} saved — tap to reuse'**
  String recentTripsSubtitle(int count);

  /// No description provided for @onRouteTitle.
  ///
  /// In en, this message translates to:
  /// **'Along the route'**
  String get onRouteTitle;

  /// No description provided for @onRouteEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tap to pick options'**
  String get onRouteEmpty;

  /// No description provided for @exportShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share route'**
  String get exportShareTitle;

  /// No description provided for @exportOpenInMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Google Maps'**
  String get exportOpenInMaps;

  /// No description provided for @exportCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get exportCopyLink;

  /// No description provided for @exportLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard'**
  String get exportLinkCopied;

  /// No description provided for @exportShareOs.
  ///
  /// In en, this message translates to:
  /// **'Share…'**
  String get exportShareOs;

  /// No description provided for @exportShareSubject.
  ///
  /// In en, this message translates to:
  /// **'My route on MyTravelPal'**
  String get exportShareSubject;

  /// No description provided for @importFromMaps.
  ///
  /// In en, this message translates to:
  /// **'Import from Maps'**
  String get importFromMaps;

  /// No description provided for @importFromMapsTitle.
  ///
  /// In en, this message translates to:
  /// **'Import a Google Maps route'**
  String get importFromMapsTitle;

  /// No description provided for @importFromMapsHint.
  ///
  /// In en, this message translates to:
  /// **'Paste a Google Maps link here'**
  String get importFromMapsHint;

  /// No description provided for @importFromMapsPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get importFromMapsPaste;

  /// No description provided for @importFromMapsImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importFromMapsImport;

  /// No description provided for @importFromMapsError.
  ///
  /// In en, this message translates to:
  /// **'URL not recognised'**
  String get importFromMapsError;

  /// No description provided for @importFromMapsLoading.
  ///
  /// In en, this message translates to:
  /// **'Parsing link…'**
  String get importFromMapsLoading;

  /// No description provided for @adverseEventsBannerCount.
  ///
  /// In en, this message translates to:
  /// **'{count} alert(s) on your route'**
  String adverseEventsBannerCount(int count);

  /// No description provided for @pricePerMeal.
  ///
  /// In en, this message translates to:
  /// **'{price} €/meal'**
  String pricePerMeal(String price);

  /// No description provided for @kmFromOrigin.
  ///
  /// In en, this message translates to:
  /// **'{km} km from origin'**
  String kmFromOrigin(String km);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'ca',
        'de',
        'en',
        'es',
        'fr',
        'it',
        'pt'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ca':
      return AppLocalizationsCa();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
