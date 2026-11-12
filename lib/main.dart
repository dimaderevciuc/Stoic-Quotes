import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/licenses.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerExtraLicenses();
  runApp(const ProviderScope(child: StoicQuotesApp()));
}
