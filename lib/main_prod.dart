import 'package:flutter/material.dart';

import 'app.dart';
import 'config/env.dart';

void main() {
  runApp(const MyApp(env: Env.prod));
}
