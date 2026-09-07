import 'package:flutter/material.dart';
import 'routes.dart';
import 'theme.dart';

class MyTuneApp extends StatelessWidget {
  const MyTuneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MyTune',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
    );
  }
}
