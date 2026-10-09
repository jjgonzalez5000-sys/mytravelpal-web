import 'package:flutter/material.dart';

import '../domain/my_place.dart';
import '../l10n/app_localizations.dart';

IconData myPlaceCategoryIcon(MyPlaceCategory c) => switch (c) {
      MyPlaceCategory.food => Icons.restaurant_outlined,
      MyPlaceCategory.viewpoint => Icons.landscape_outlined,
      MyPlaceCategory.culture => Icons.museum_outlined,
      MyPlaceCategory.nature => Icons.park_outlined,
      MyPlaceCategory.kids => Icons.child_care_outlined,
      MyPlaceCategory.other => Icons.place_outlined,
    };

String myPlaceCategoryLabel(AppLocalizations l, MyPlaceCategory c) =>
    switch (c) {
      MyPlaceCategory.food => l.myPlacesCatFood,
      MyPlaceCategory.viewpoint => l.myPlacesCatViewpoint,
      MyPlaceCategory.culture => l.myPlacesCatCulture,
      MyPlaceCategory.nature => l.myPlacesCatNature,
      MyPlaceCategory.kids => l.myPlacesCatKids,
      MyPlaceCategory.other => l.myPlacesCatOther,
    };
