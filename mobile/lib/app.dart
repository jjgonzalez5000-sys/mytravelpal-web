import 'package:flutter/material.dart';

import 'screens/plan_screen.dart';
import 'theme.dart';

class MyTravelPalApp extends StatelessWidget {
  const MyTravelPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyTravelPal',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const PlanScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
