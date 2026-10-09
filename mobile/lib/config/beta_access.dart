/// Closed-beta switch. While true:
///  * a fresh install starts on the Premium tier,
///  * Settings shows the "beta access" tier selector,
///  * tapping a price in the subscription sheet simulates having that
///    subscription (no Play Billing, no charge).
///
/// It is a compile-time define so a production build cannot be flipped from
/// inside the app. A release meant for the public store MUST be built with
///   --dart-define=BETA_ACCESS=false
/// which starts users on Free, hides the selector and sends every price tap
/// through the real Play Billing purchase.
const bool kBetaAccess =
    bool.fromEnvironment('BETA_ACCESS', defaultValue: true);

/// Tier a fresh install starts on.
String defaultTierFor({required bool betaAccess}) =>
    betaAccess ? 'premium' : 'free';

/// Whether [tier] unlocks the server-side premium gates (the flag sent in
/// the `X-MyTravelPal-Premium` header). Essential counts, as it always has.
bool premiumFlagForTier(String tier) => tier != 'free';
