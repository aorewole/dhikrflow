import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_scope.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await AppDependencies.initialize();
  runApp(DhikrCounterApp(dependencies: dependencies));
}
