import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_size/window_size.dart';

import '../controller/statecontroller.dart';
import '../view/appStartup.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setWindowMinSize(const Size(1000, 800));
  setWindowMaxSize(Size.infinite);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StateController()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AppStartup(),
    );
  }
}
