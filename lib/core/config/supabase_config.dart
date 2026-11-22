class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = 'https://tpgehmbekzanyokdnfha.supabase.co';

  static const String publishableKey =
      'sb_publishable_U-KxHeA-V0TyEaujrCV5JQ_UNkPp0NI';

  static bool get enabled => url.isNotEmpty && publishableKey.isNotEmpty;

  static const String tableProfiles = 'profiles';
  static const String tableFavourites = 'favourite_routes';
  static const String tableTrips = 'trips';
  static const String tableTickets = 'tickets';
}
