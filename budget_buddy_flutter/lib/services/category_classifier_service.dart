// CategoryClassifierService
//
// Classifies a student expense into 'needs', 'wants', or 'savings'
// using April 2026 Philippine cost-of-living thresholds.
//
// Research basis:
//  - NEDA food poverty line: ₱64/day floor (2024)
//  - Carinderia meal range: ₱100–₱170 (updated April 2026, +₱10 hike)
//  - Fast food single meal: ₱160–₱270 (2026)
//  - PSA food inflation: 1.8% Feb 2026 (Rappler, 2026)
//  - LTFRB fare hike effective March 19, 2026 (all PUV modes)
//  - Jeepney: ₱14 traditional / ₱17 modern regular (March 19, 2026)
//  - Bus: ₱15 city ordinary / ₱18 city aircon / ₱12 provincial ordinary
//  - Student discount: 20% off all PUV fares (LTFRB MC 2017-024, everyday)
//  - Motorcycle ride-hailing (Move It, Angkas, Joyride): dynamic pricing
//    by distance — classified as WANT by service type, not amount
//  - Car ride-hailing (Grab, InDrive): ₱150+ → want
//  - Rail: DOTr 50% student discount valid until 2028
//  - Merienda / snack: ₱20–₱60 (2026)
//  - School supplies single item: ₱10–₱170 (2026)
//  - Mobile load (small prepaid): ₱50–₱149 → need
//
// Classification logic:
//   Needs   = basic sustenance, transport, school supplies within threshold
//   Wants   = upgrade/comfort spending beyond the threshold
//   Savings = explicitly tagged by the user
//
// Confidence levels:
//   high   = clearly within or beyond threshold, low chance of error
//   medium = borderline or context-dependent, user should verify
//   low    = expense type could not be determined from name alone

class ClassificationResult {
  final String category;
  final String reason;
  final String confidence;

  const ClassificationResult({
    required this.category,
    required this.reason,
    required this.confidence,
  });
}

class CategoryClassifierService {
  // ─── FOOD THRESHOLDS (April 2026, Metro Manila) ───────────────────────────

  /// Carinderia / canteen meal ceiling — NEED
  static const double _mealNeedsMax = 170.0;

  /// Fast food upper bound — above this is premium/restaurant dining (WANT)
  static const double _mealWantsThreshold = 270.0;

  /// Buffet / premium restaurant floor — always WANT
  static const double _buffetMin = 450.0;

  /// Merienda / snack ceiling — NEED
  static const double _snackNeedsMax = 60.0;

  /// Premium snack floor (milk tea, Starbucks) — WANT
  static const double _snackWantsThreshold = 120.0;

  // ─── TRANSPORT THRESHOLDS (LTFRB & DOTr, effective March 19, 2026) ────────
  //
  // ── JEEPNEY ─────────────────────────────────────────────────────────────
  //   Traditional jeepney regular : ₱14 min (first 4 km), +₱2.00/km
  //   Traditional jeepney student : ₱11.20 (~₱11) — 20% disc. MC 2017-024
  //   Modern jeepney regular      : ₱17 min (first 1 km), +₱2.30/km
  //   Modern jeepney student      : ₱13.60 (~₱14) — 20% discount
  //   Long route 10 km (trad.)    : ~₱26 (e.g. Cubao–Divisoria)
  //   Note: ₱14 is NCR minimum. Provincial/regional routes may be lower
  //         per individual LTFRB regional office fare matrices.
  //
  // ── BUS — CITY / METRO MANILA ───────────────────────────────────────────
  //   Ordinary city bus regular   : ₱15 min (first 5 km), +₱2.49/km
  //   Ordinary city bus student   : ₱12.00 (~20% disc.)
  //   Aircon city bus regular     : ₱18 min (first 5 km), +₱2.98/km
  //   Aircon city bus student     : ₱14.40 (~₱14) — 20% discount
  //   City bus 10 km (ordinary)   : ~₱27.45
  //   City bus 10 km (aircon)     : ~₱47.80
  //
  // ── BUS — PROVINCIAL (effective March 14–15, 2026) ──────────────────────
  //   Ordinary provincial regular : ₱12 min (first 5 km), +₱2.20/km
  //   Ordinary provincial student : ₱9.60 (~₱10) — 20% discount
  //   Aircon/Deluxe/Super Deluxe  : varies, +₱2.45–₱2.70/km
  //   Luxury bus                  : +₱3.35/km
  //   Example: Batangas 105km     : ~₱230 ordinary / ~₱257 aircon
  //   Example: Manila–Baguio      : ~₱542 ordinary (long-haul)
  //   Provincial bus student max  : up to ₱230 for long trips (NEED)
  //
  // ── RAIL — DOTr 50% student discount valid until 2028 ───────────────────
  //   MRT-3 student : ₱6–₱14   |  MRT-3 regular : ₱12–₱28
  //   LRT-1 student : ₱10–₱28  |  LRT-1 regular : ₱20–₱56
  //   LRT-2 student : ₱8–₱18   |  LRT-2 regular : ₱16–₱36
  //
  // Sources:
  //   LTFRB press briefing March 17, 2026 (PNA, Manila Bulletin, Rappler)
  //   LTFRB SunStar provincial bus March 15, 2026
  //   DOTr advisory June 20, 2025 (50% rail student discount)
  //   LTFRB MC 2017-024 (20% PUV student discount, everyday incl. weekends)

  // ── Jeepney ───────────────────────────────────────────────────────────────
  static const double _jeepStudent        = 11.0;   // trad. jeep student min
  static const double _jeepRegular        = 14.0;   // trad. jeep regular min
  static const double _modernJeepRegular  = 17.0;   // modern jeep regular min
  static const double _jeepLongRouteMax   = 34.0;   // trad. jeep 10 km max

  // ── City bus ──────────────────────────────────────────────────────────────
  static const double _cityBusOrdinaryStudent = 12.0;
  static const double _cityBusOrdinaryRegular = 15.0;
  static const double _cityBusAirconStudent   = 14.0;
  static const double _cityBusAirconRegular   = 18.0;
  static const double _cityBusOrdinaryMax     = 60.0;  // ~10 km ordinary trip
  static const double _cityBusAirconMax       = 90.0;  // ~10 km aircon trip

  // ── Provincial bus ────────────────────────────────────────────────────────
  static const double _provBusOrdinaryStudent = 10.0;
  static const double _provBusOrdinaryRegular = 12.0;
  // Long provincial trip (e.g. Batangas ~₱230) still classified as NEED.
  // Beyond ₱300 → medium confidence (very long haul or luxury bus)
  static const double _provBusNeedMax         = 300.0;

  // ── Rail ──────────────────────────────────────────────────────────────────
  static const double _mrtStudentMin  = 6.0;
  static const double _mrtStudentMax  = 14.0;
  static const double _lrt1StudentMin = 10.0;
  static const double _lrt1StudentMax = 28.0;
  static const double _lrt2StudentMin = 8.0;
  static const double _lrt2StudentMax = 18.0;
  static const double _lrt2RegularMax = 36.0;

  // Overall city transit NEED ceiling = LRT-1 regular end-to-end
  static const double _transitNeedsMax = 56.0;

  // ── Ride-hailing ──────────────────────────────────────────────────────────
  // Car ride-hailing (Grab, InDrive) — WANT above this amount
  static const double _carRidehailMin = 150.0;
  // Motorcycle ride-hailing (Move It, Angkas, Joyride) — classified by
  // service TYPE not amount because pricing is distance-dynamic

  // ─── OTHER THRESHOLDS ─────────────────────────────────────────────────────
  static const double _schoolSupplyNeedsMax = 170.0;
  static const double _loadNeedsMax         = 149.0;

  // ─── KEYWORDS ─────────────────────────────────────────────────────────────

  // Always WANT — premium dining regardless of amount
  static const List<String> _foodAlwaysWantsKeywords = [
    'samgyup', 'samgyeopsal',
    'buffet',
    'ihop',
    'sushi',
    'starbucks', 'cbtl',
    'milk tea', 'milktea', 'boba',
  ];

  // Amount-based food — routes into _classifyFood()
  static const List<String> _foodKeywords = [
    'canteen', 'kainan', 'carinderia', 'carenderia', 'eatery',
    'restaurant', 'food', 'meal', 'lunch', 'breakfast', 'dinner',
    'merienda', 'snack', 'jollibee', 'mcdo', 'mcdonald', 'kfc',
    'burger', 'pizza', 'shawarma', 'inasal', 'chowking', 'greenwich',
    'max', 'goldilocks', 'red ribbon', 'jollisnack', 'street food',
    'taho', 'fishball', 'kwek kwek', 'banana cue', 'turon', 'siomai',
    'dimsum', 'jollijeep', 'goto', 'lugaw', 'panciteria', 'mami',
    'tapsilog', 'silog', 'longsilog', 'tocilog', 'arroz caldo',
    'bulalo', 'sinigang', 'adobo', 'lechon',
    'ramen', 'bbq', 'coffee', 'cafe',
  ];

  static const List<String> _snackOnlyKeywords = [
    'snack', 'merienda', 'taho', 'fishball', 'kwek', 'banana cue',
    'turon', 'siomai', 'dimsum', 'coffee', 'milk tea', 'milktea',
    'boba', 'cafe', 'starbucks', 'cbtl', 'drinks', 'juice', 'soda',
    'ice cream', 'dessert', 'pastry', 'bread', 'pandesal',
  ];

  // Bus keywords — detect bus type for sub-classification
  static const List<String> _busKeywords = [
    'bus', 'ordinary bus', 'aircon bus', 'air-con bus', 'ac bus',
    'provincial bus', 'victory liner', 'genesis', 'partas', 'five star',
    'philtranco', 'jac liner', 'raymond', 'dagupan bus', 'bohol tours',
    'ceres', 'rural transit', 'baliwag transit',
  ];

  static const List<String> _airconBusKeywords = [
    'aircon bus', 'air-con bus', 'ac bus', 'airconditioned bus',
    'deluxe', 'super deluxe', 'luxury bus',
  ];

  static const List<String> _provincialBusKeywords = [
    'provincial bus', 'victory liner', 'genesis', 'partas', 'five star',
    'philtranco', 'jac liner', 'raymond', 'dagupan bus', 'bohol tours',
    'ceres', 'rural transit', 'baliwag transit', 'provincial',
  ];

  // Motorcycle ride-hailing — classified by service type, not amount
  static const List<String> _motoRidehailKeywords = [
    'move it', 'moveit', 'angkas', 'joyride', 'habal', 'habal-habal',
  ];

  // Car ride-hailing
  static const List<String> _carRidehailKeywords = [
    'grab', 'indrive', 'in-drive', 'in drive',
  ];

  // All transit keywords — broad detection
  static const List<String> _transitKeywords = [
    'jeep', 'jeepney', 'mrt', 'lrt', 'bus', 'fx', 'uv express',
    'tricycle', 'trike', 'pedicab', 'fare', 'transpo', 'transport',
    'commute', 'beep card', 'stored value', 'mybus',
    'victory liner', 'genesis', 'partas', 'five star', 'philtranco',
    'jac liner', 'raymond', 'dagupan bus', 'bohol tours', 'ceres',
    'rural transit', 'baliwag transit',
    'grab', 'indrive', 'in-drive', 'in drive',
    'move it', 'moveit', 'angkas', 'joyride', 'habal',
  ];

  static const List<String> _schoolKeywords = [
    'school', 'supplies', 'notebook', 'ballpen', 'pen', 'pencil',
    'paper', 'bond paper', 'photocopy', 'xerox', 'printing', 'print',
    'book', 'module', 'folder', 'highlighter', 'ruler', 'scissors',
    'calculator', 'lab', 'uniform', 'id', 'tuition', 'enrolment',
    'enrollment', 'registration', 'library', 'thesis', 'research',
    'project', 'plate', 'materials',
  ];

  static const List<String> _loadKeywords = [
    'load', 'data', 'prepaid', 'globe', 'smart', 'dito', 'sun',
    'gcash', 'wifi', 'internet', 'sim', 'promo', 'e-load', 'eload',
  ];

  static const List<String> _savingsKeywords = [
    'savings', 'save', 'paluwagan', 'deposit', 'investment', 'invest',
    'emergency fund', 'piggy', 'ipon', 'pension', 'insurance',
    'mutual fund', 'stocks', 'pag-ibig', 'sss', 'philhealth',
  ];

  static const List<String> _entertainmentKeywords = [
    'cinema', 'movie', 'netflix', 'spotify', 'gaming', 'game',
    'shopee', 'lazada', 'online shop', 'clothes', 'clothing', 'shoes',
    'fashion', 'accessories', 'salon', 'spa', 'massage', 'gym',
    'subscription', 'discord', 'steam', 'mobile legends', 'roblox',
    'concert', 'event', 'bar', 'club', 'alcohol', 'beer', 'videoke',
    'karaoke', 'amusement', 'mall', 'shopping', 'tiktok shop',
    'watch', 'perfume', 'cosmetics', 'makeup',
  ];

  // ─── PUBLIC API ───────────────────────────────────────────────────────────

  ClassificationResult classify({
    required String storeName,
    required double amount,
  }) {
    final name = storeName.toLowerCase().trim();

    // 1. Savings
    if (_matchesAny(name, _savingsKeywords)) {
      return const ClassificationResult(
        category: 'savings',
        reason: 'Detected as a savings or investment transaction.',
        confidence: 'high',
      );
    }

    // 2. Entertainment / lifestyle — always WANT
    if (_matchesAny(name, _entertainmentKeywords)) {
      return ClassificationResult(
        category: 'wants',
        reason:
            '₱${_fmt(amount)} on "${_friendly(storeName)}" is a lifestyle '
            'or entertainment expense.',
        confidence: 'high',
      );
    }

    // 3. Transport
    if (_matchesAny(name, _transitKeywords)) {
      return _classifyTransport(storeName, name, amount);
    }

    // 4. School supplies
    if (_matchesAny(name, _schoolKeywords)) {
      return _classifySchool(storeName, amount);
    }

    // 5. Mobile load / data
    if (_matchesAny(name, _loadKeywords)) {
      return _classifyLoad(storeName, amount);
    }

    // 6a. Food — always WANT (premium dining, checked first)
    if (_matchesAny(name, _foodAlwaysWantsKeywords)) {
      return ClassificationResult(
        category: 'wants',
        reason:
            '"${_friendly(storeName)}" is a premium dining or specialty '
            'drink experience — classified as want regardless of amount. '
            'Tap to change if this was your only available meal option.',
        confidence: 'high',
      );
    }

    // 6b. Food — amount-based
    if (_matchesAny(name, _foodKeywords)) {
      return _classifyFood(storeName, name, amount);
    }

    // 7. Unknown — fallback by amount
    return _classifyByAmountOnly(storeName, amount);
  }

  // ─── TRANSPORT CLASSIFIER ─────────────────────────────────────────────────

  ClassificationResult _classifyTransport(
    String storeName,
    String nameLower,
    double amount,
  ) {
    // ── Motorcycle ride-hailing: Move It, Angkas, Joyride ──────────────────
    // Dynamic distance-based pricing — no fixed threshold.
    // Classified as WANT by service type since choosing ride-hailing
    // over available jeep/LRT/bus is a comfort/speed upgrade.
    if (_matchesAny(nameLower, _motoRidehailKeywords)) {
      return ClassificationResult(
        category: 'wants',
        reason:
            '"${_friendly(storeName)}" is a motorcycle ride-hailing app with '
            'dynamic distance-based pricing — the fare alone cannot determine '
            'the category. Classified as want because choosing ride-hailing '
            'over the jeepney (₱11 student / ₱13 regular) or bus is a '
            'comfort and speed upgrade. Tap to change to Needs if no public '
            'transport was available (e.g., late for class, heavy rain, '
            'no jeep on route, carrying heavy load).',
        confidence: 'medium',
      );
    }

    // ── Car ride-hailing: Grab, InDrive ────────────────────────────────────
    if (_matchesAny(nameLower, _carRidehailKeywords)) {
      if (amount < _carRidehailMin) {
        return ClassificationResult(
          category: 'needs',
          reason:
              '₱${_fmt(amount)} on "${_friendly(storeName)}" is below the '
              'typical car ride-hailing range. Could be a short promo trip — '
              'verify if this was necessary.',
          confidence: 'low',
        );
      }
      return ClassificationResult(
        category: 'wants',
        reason:
            '₱${_fmt(amount)} for a car ride-hailing service is a comfort '
            'and convenience upgrade over public transport (jeep: ₱14, '
            'city bus: ₱15, LRT: up to ₱56). Tap to change if no other '
            'option was available.',
        confidence: 'high',
      );
    }

    // ── Provincial bus ──────────────────────────────────────────────────────
    if (_matchesAny(nameLower, _provincialBusKeywords)) {
      if (amount <= _provBusOrdinaryStudent) {
        return ClassificationResult(
          category: 'needs',
          reason:
              '₱${_fmt(amount)} matches the provincial ordinary bus student '
              'fare minimum (₱${_fmt(_provBusOrdinaryStudent)} after 20% disc.). '
              'Basic commuting need.',
          confidence: 'high',
        );
      }
      if (amount <= _provBusOrdinaryRegular) {
        return ClassificationResult(
          category: 'needs',
          reason:
              '₱${_fmt(amount)} matches the provincial ordinary bus regular '
              'fare minimum (₱${_fmt(_provBusOrdinaryRegular)} for first 5 km). '
              'Basic commuting need.',
          confidence: 'high',
        );
      }
      if (amount <= _provBusNeedMax) {
        return ClassificationResult(
          category: 'needs',
          reason:
              '₱${_fmt(amount)} is within the provincial bus range — a longer '
              'inter-city or inter-province trip (e.g. Batangas ~₱230, '
              'aircon ~₱257). Basic commuting need.',
          confidence: 'high',
        );
      }
      // Above ₱300 — very long haul or luxury bus, still likely a need
      return ClassificationResult(
        category: 'needs',
        reason:
            '₱${_fmt(amount)} is a very long provincial bus trip or luxury '
            'bus class (e.g. Manila–Baguio ~₱542). Still classified as need '
            '— tap to change if this was not a necessary trip.',
        confidence: 'medium',
      );
    }

    // ── City / aircon bus ───────────────────────────────────────────────────
    if (_matchesAny(nameLower, _busKeywords)) {
      final isAircon = _matchesAny(nameLower, _airconBusKeywords);

      if (isAircon) {
        if (amount <= _cityBusAirconStudent) {
          return ClassificationResult(
            category: 'needs',
            reason:
                '₱${_fmt(amount)} matches the city aircon bus student fare '
                'minimum (₱${_fmt(_cityBusAirconStudent)} after 20% disc.). '
                'Basic commuting need.',
            confidence: 'high',
          );
        }
        if (amount <= _cityBusAirconMax) {
          return ClassificationResult(
            category: 'needs',
            reason:
                '₱${_fmt(amount)} is within the city aircon bus fare range '
                '(₱${_fmt(_cityBusAirconRegular)} min, up to ~₱${_fmt(_cityBusAirconMax)} '
                'for longer routes). Basic commuting need.',
            confidence: 'high',
          );
        }
        return ClassificationResult(
          category: 'needs',
          reason:
              '₱${_fmt(amount)} is a longer city aircon bus trip. Still '
              'classified as need — tap to change if this was discretionary.',
          confidence: 'medium',
        );
      }

      // Ordinary city bus
      if (amount <= _cityBusOrdinaryStudent) {
        return ClassificationResult(
          category: 'needs',
          reason:
              '₱${_fmt(amount)} matches the city ordinary bus student fare '
              'minimum (₱${_fmt(_cityBusOrdinaryStudent)} after 20% disc.). '
              'Basic commuting need.',
          confidence: 'high',
        );
      }
      if (amount <= _cityBusOrdinaryMax) {
        return ClassificationResult(
          category: 'needs',
          reason:
              '₱${_fmt(amount)} is within the city ordinary bus fare range '
              '(₱${_fmt(_cityBusOrdinaryRegular)} min, ~₱27 for 10 km trip). '
              'Basic commuting need.',
          confidence: 'high',
        );
      }
      return ClassificationResult(
        category: 'needs',
        reason:
            '₱${_fmt(amount)} is a longer city bus trip. Still classified '
            'as need — tap to change if this was discretionary.',
        confidence: 'medium',
      );
    }

    // ── Rail: MRT-3, LRT-1, LRT-2 ──────────────────────────────────────────
    if (amount <= _jeepRegular) {
      // ₱14 and below — traditional jeepney (student ₱11 / regular ₱14)
      // or MRT-3 student fare minimum
      return ClassificationResult(
        category: 'needs',
        reason:
            '₱${_fmt(amount)} is within the jeepney fare range '
            '(student: ₱${_fmt(_jeepStudent)}, regular: ₱${_fmt(_jeepRegular)}) '
            'or MRT-3 student fare. Basic commuting need.',
        confidence: 'high',
      );
    }

    if (amount <= _modernJeepRegular) {
      // ₱15–₱17 — modern jeepney regular min or long traditional jeep trip
      return ClassificationResult(
        category: 'needs',
        reason:
            '₱${_fmt(amount)} is within the modern jeepney regular fare '
            'range (min: ₱${_fmt(_modernJeepRegular)}) or a longer traditional '
            'jeepney trip. Basic commuting need.',
        confidence: 'high',
      );
    }

    if (amount <= _jeepLongRouteMax) {
      // ₱18–₱34 — long jeepney route (e.g. 10 km = ~₱26) or MRT-3 regular
      return ClassificationResult(
        category: 'needs',
        reason:
            '₱${_fmt(amount)} is within the long jeepney route range '
            '(up to ₱${_fmt(_jeepLongRouteMax)} for ~10 km) or MRT-3 regular fare. '
            'Basic commuting need.',
        confidence: 'high',
      );
    }

    if (amount <= _mrtStudentMax) {
      return ClassificationResult(
        category: 'needs',
        reason:
            '₱${_fmt(amount)} is within the MRT-3 student fare range '
            '(₱${_fmt(_mrtStudentMin)}–₱${_fmt(_mrtStudentMax)}) or a longer jeepney trip. '
            'Basic commuting need.',
        confidence: 'high',
      );
    }

    if (amount <= _lrt2StudentMax) {
      return ClassificationResult(
        category: 'needs',
        reason:
            '₱${_fmt(amount)} is within the LRT-2 student fare range '
            '(₱${_fmt(_lrt2StudentMin)}–₱${_fmt(_lrt2StudentMax)}) or MRT-3 regular fare. '
            'Basic commuting need.',
        confidence: 'high',
      );
    }

    if (amount <= _lrt1StudentMax) {
      return ClassificationResult(
        category: 'needs',
        reason:
            '₱${_fmt(amount)} is within the LRT-1 student fare range '
            '(₱${_fmt(_lrt1StudentMin)}–₱${_fmt(_lrt1StudentMax)}) or LRT-2/MRT-3 regular. '
            'Basic commuting need.',
        confidence: 'high',
      );
    }

    if (amount <= _lrt2RegularMax) {
      return ClassificationResult(
        category: 'needs',
        reason:
            '₱${_fmt(amount)} is within the LRT-2 regular fare range '
            '(up to ₱${_fmt(_lrt2RegularMax)}) or a long LRT-1 student trip. '
            'Basic commuting need.',
        confidence: 'high',
      );
    }

    if (amount <= _transitNeedsMax) {
      return ClassificationResult(
        category: 'needs',
        reason:
            '₱${_fmt(amount)} is within the LRT-1 regular fare range '
            '(₱20–₱${_fmt(_transitNeedsMax)} end-to-end). Basic commuting need.',
        confidence: 'high',
      );
    }

    // Above ₱56 — above all known rail/jeep fares, not detected as bus
    if (amount < _carRidehailMin) {
      return ClassificationResult(
        category: 'needs',
        reason:
            '₱${_fmt(amount)} exceeds standard single-trip rail fares '
            '(LRT-1 regular max: ₱${_fmt(_transitNeedsMax)}). Could be a '
            'multi-leg commute, UV Express, or FX. Classified as need — '
            'tap to change if this was a comfort choice.',
        confidence: 'medium',
      );
    }

    // ₱150+ unrecognized transit — likely ride-hailing
    return ClassificationResult(
      category: 'wants',
      reason:
          '₱${_fmt(amount)} for transport is well above all known rail, '
          'jeepney, and city bus fares. Likely a ride-hailing or premium '
          'option — tap to change if this was a necessary multi-leg commute.',
      confidence: 'medium',
    );
  }

  // ─── FOOD CLASSIFIER ──────────────────────────────────────────────────────

  ClassificationResult _classifyFood(
    String storeName,
    String nameLower,
    double amount,
  ) {
    if (amount >= _buffetMin) {
      return ClassificationResult(
        category: 'wants',
        reason:
            '₱${_fmt(amount)} exceeds the ₱${_fmt(_buffetMin)} buffet '
            'threshold — premium dining experience, not basic sustenance.',
        confidence: 'high',
      );
    }

    // Snack / merienda sub-type
    if (_matchesAny(nameLower, _snackOnlyKeywords)) {
      if (amount <= _snackNeedsMax) {
        return ClassificationResult(
          category: 'needs',
          reason:
              '₱${_fmt(amount)} is within the 2026 merienda/snack range '
              '(₱20–₱${_fmt(_snackNeedsMax)}).',
          confidence: 'high',
        );
      }
      if (amount <= _snackWantsThreshold) {
        return ClassificationResult(
          category: 'wants',
          reason:
              '₱${_fmt(amount)} for a snack or drink exceeds the basic '
              'merienda range — premium treat (e.g., milk tea, Starbucks). '
              'Tap to change if this was your main meal.',
          confidence: 'medium',
        );
      }
      return ClassificationResult(
        category: 'wants',
        reason:
            '₱${_fmt(amount)} for a snack is well above the student '
            'merienda budget of ₱${_fmt(_snackNeedsMax)}.',
        confidence: 'high',
      );
    }

    // Regular meal
    if (amount <= _mealNeedsMax) {
      return ClassificationResult(
        category: 'needs',
        reason:
            '₱${_fmt(amount)} is within the 2026 carinderia/canteen meal '
            'range (₱100–₱${_fmt(_mealNeedsMax)}). Basic sustenance need.',
        confidence: 'high',
      );
    }

    if (amount <= _mealWantsThreshold) {
      return ClassificationResult(
        category: 'wants',
        reason:
            '₱${_fmt(amount)} is above the basic carinderia range — could '
            'be a fast food combo or restaurant meal. Tap to change if '
            'this was your only affordable option.',
        confidence: 'medium',
      );
    }

    return ClassificationResult(
      category: 'wants',
      reason:
          '₱${_fmt(amount)} for food significantly exceeds the basic '
          'student meal budget of ₱${_fmt(_mealNeedsMax)} per meal.',
      confidence: 'high',
    );
  }

  // ─── OTHER CLASSIFIERS ────────────────────────────────────────────────────

  ClassificationResult _classifySchool(String storeName, double amount) {
    if (amount <= _schoolSupplyNeedsMax) {
      return ClassificationResult(
        category: 'needs',
        reason:
            '₱${_fmt(amount)} for school supplies is within the 2026 '
            'student academic expense range '
            '(up to ₱${_fmt(_schoolSupplyNeedsMax)}).',
        confidence: 'high',
      );
    }
    return ClassificationResult(
      category: 'needs',
      reason:
          '₱${_fmt(amount)} is a larger academic expense (e.g., textbook, '
          'lab fee, uniform). Classified as need — verify if discretionary.',
      confidence: 'medium',
    );
  }

  ClassificationResult _classifyLoad(String storeName, double amount) {
    if (amount <= _loadNeedsMax) {
      return ClassificationResult(
        category: 'needs',
        reason:
            '₱${_fmt(amount)} for mobile load or data is within the basic '
            'student connectivity need (up to ₱${_fmt(_loadNeedsMax)}).',
        confidence: 'high',
      );
    }
    return ClassificationResult(
      category: 'wants',
      reason:
          '₱${_fmt(amount)} for load or data is above the basic prepaid '
          'range — likely a large promo, streaming subscription, or WiFi '
          'bill. Tap to change if this was a basic connectivity expense.',
      confidence: 'medium',
    );
  }

  ClassificationResult _classifyByAmountOnly(
    String storeName,
    double amount,
  ) {
    if (amount <= 60) {
      return ClassificationResult(
        category: 'needs',
        reason:
            '₱${_fmt(amount)} is a small purchase likely within basic daily '
            'needs. Could not detect expense type — tap to verify.',
        confidence: 'low',
      );
    }
    if (amount <= 200) {
      return ClassificationResult(
        category: 'needs',
        reason:
            '₱${_fmt(amount)} is a moderate expense — could be a basic need. '
            'Could not detect expense type. Tap to change if discretionary.',
        confidence: 'low',
      );
    }
    if (amount <= 450) {
      return ClassificationResult(
        category: 'wants',
        reason:
            '₱${_fmt(amount)} is above typical basic need amounts. Marked '
            'as want — tap to change if this was a necessity.',
        confidence: 'low',
      );
    }
    return ClassificationResult(
      category: 'wants',
      reason:
          '₱${_fmt(amount)} is a significant expense. Classified as want — '
          'tap to change if this was a necessity.',
      confidence: 'low',
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────

  bool _matchesAny(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (text.contains(kw)) return true;
    }
    return false;
  }

  String _fmt(double amount) {
    return amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
  }

  String _friendly(String storeName) {
    return storeName.trim().isEmpty ? 'this item' : storeName.trim();
  }

  // ─── UI HELPERS ───────────────────────────────────────────────────────────

  /// Cycles: needs → wants → savings → needs
  String toggleCategory(String current) {
    switch (current) {
      case 'needs':
        return 'wants';
      case 'wants':
        return 'savings';
      case 'savings':
      default:
        return 'needs';
    }
  }

  /// Returns display metadata for a given category.
  Map<String, dynamic> categoryMeta(String category) {
    switch (category) {
      case 'needs':
        return {
          'label': 'Needs',
          'color': 0xFF4CAF50,
          'icon': 'fastfood',
          'description': 'Basic necessity — food, transport, school',
        };
      case 'wants':
        return {
          'label': 'Wants',
          'color': 0xFFFF9800,
          'icon': 'sports_esports',
          'description': 'Comfort or lifestyle spending',
        };
      case 'savings':
      default:
        return {
          'label': 'Savings',
          'color': 0xFF4A90E2,
          'icon': 'account_balance_wallet',
          'description': 'Money set aside intentionally',
        };
    }
  }

  // ─── QUICK REFERENCE (March–April 2026 LTFRB + DOTr thresholds) ──────────
  //
  // JEEPNEY (effective March 19, 2026):
  //   ₱11   Traditional student (20% off ₱14)  → NEED (high)
  //   ₱14   Traditional regular                 → NEED (high)
  //   ₱14   Modern jeepney student              → NEED (high)
  //   ₱17   Modern jeepney regular              → NEED (high)
  //   ₱26   10 km traditional trip              → NEED (high)
  //
  // CITY BUS (effective March 19, 2026):
  //   ₱12   Ordinary bus student (20% off ₱15)  → NEED (high)
  //   ₱15   Ordinary bus regular                 → NEED (high)
  //   ₱14   Aircon bus student (20% off ₱18)    → NEED (high)
  //   ₱18   Aircon bus regular                   → NEED (high)
  //   ₱27   10 km ordinary city bus trip         → NEED (high)
  //
  // PROVINCIAL BUS (effective March 14–15, 2026):
  //   ₱10   Ordinary provincial student          → NEED (high)
  //   ₱12   Ordinary provincial regular          → NEED (high)
  //   ₱230  Batangas ordinary (105 km)           → NEED (high)
  //   ₱257  Batangas aircon (105 km)             → NEED (high)
  //   ₱542  Manila–Baguio ordinary               → NEED (medium)
  //
  // RAIL — DOTr 50% student discount valid until 2028:
  //   ₱6–14  MRT-3 student                      → NEED (high)
  //   ₱12–28 MRT-3 regular                      → NEED (high)
  //   ₱10–28 LRT-1 student                      → NEED (high)
  //   ₱20–56 LRT-1 regular                      → NEED (high)
  //   ₱8–18  LRT-2 student                      → NEED (high)
  //   ₱16–36 LRT-2 regular                      → NEED (high)
  //
  // RIDE-HAILING:
  //   any    Move It / Angkas / Joyride          → WANT (medium)
  //   ₱150+  Grab / InDrive                      → WANT (high)
  //
  // FOOD:
  //   ₱120  Canteen / carinderia meal            → NEED (high)
  //   ₱170  Fast food value meal                 → NEED (high)
  //   ₱200  Fast food combo                      → WANT (medium)
  //   ₱450+ Samgyup / buffet                     → WANT (high)
  //   any   Starbucks / milk tea / boba          → WANT (high)
  //   ₱35   Banana cue / fishball                → NEED (high)
  //
  // SCHOOL:
  //   ₱15   Ballpen                              → NEED (high)
  //   ₱170  Printed modules                      → NEED (high)
  //   ₱500  Full textbook                        → NEED (medium)
  //
  // LOAD:
  //   ₱50   Prepaid load                         → NEED (high)
  //   ₱149  Data promo                           → NEED (high)
  //   ₱299  Streaming subscription               → WANT (medium)
}
