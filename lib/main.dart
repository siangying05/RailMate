import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/railmate_app.dart';
import 'core/providers/rail_data_provider.dart';
import 'data/datasources/remote/supabase_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/guidance/providers/guidance_provider.dart';
import 'features/routing/providers/favourite_provider.dart';
import 'features/routing/providers/journey_provider.dart';
import 'features/ticketing/providers/ticket_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.instance.initialise();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RailDataProvider()..initialise()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..bootstrap()),
        ChangeNotifierProvider(create: (_) => JourneyProvider()),
        ChangeNotifierProvider(create: (_) => FavouriteProvider()),
        ChangeNotifierProvider(create: (_) => GuidanceProvider()),
        ChangeNotifierProvider(create: (_) => TicketProvider()),
      ],
      child: const RailMateApp(),
    ),
  );
}
