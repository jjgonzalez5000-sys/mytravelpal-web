import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';

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
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it')
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
  /// **'Fires, strikes, adverse weather, roadworks — you decide when we surface them, and only when they actually touch your route.'**
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
  /// **'Meal times'**
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
  /// **'Fires, strikes, adverse weather, roadworks, accidents, floods, snow, protests — sorted by severity.'**
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
  /// **'Rest stops'**
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
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
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
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
