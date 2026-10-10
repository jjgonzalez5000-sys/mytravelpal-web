/// Whether the toll-free options (toll-free alternative + hourly toll
/// analysis) are really on for a plan: the driver asked for them AND their
/// plan includes them. The server answers 402 to a free user who asks for
/// them, so the request must never carry them for a free plan, whatever the
/// stored default says.
bool effectiveTollFree({required bool wanted, required bool paid}) =>
    wanted && paid;

/// Whether the AI stop suggestions are really on for a plan: the driver
/// asked for them AND their plan is Premium (the server answers 402 to
/// anyone else, and each search spends the daily AI quota).
bool effectiveAiSuggest({required bool wanted, required bool premium}) =>
    wanted && premium;
