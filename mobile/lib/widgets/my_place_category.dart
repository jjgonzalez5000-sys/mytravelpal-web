import 'package:flutter/material.dart';

import '../design/stop_category_style.dart';
import '../domain/my_place.dart';
import '../l10n/app_localizations.dart';

IconData myPlaceCategoryIcon(MyPlaceCategory c) =>
    stopCategoryStyle(c).icon;

String myPlaceCategoryLabel(AppLocalizations l, MyPlaceCategory c) =>
    switch (c) {
      MyPlaceCategory.food => l.myPlacesCatFood,
      MyPlaceCategory.viewpoint => l.myPlacesCatViewpoint,
      MyPlaceCategory.culture => l.myPlacesCatCulture,
      MyPlaceCategory.history => l.myPlacesCatHistory,
      MyPlaceCategory.nature => l.myPlacesCatNature,
      MyPlaceCategory.beach => l.myPlacesCatBeach,
      MyPlaceCategory.kids => l.myPlacesCatKids,
      MyPlaceCategory.shopping => l.myPlacesCatShopping,
      MyPlaceCategory.other => l.myPlacesCatOther,
    };
