class TeamMember {
  final String name;
  final String initials;
  final String module;
  final String focus;

  const TeamMember({
    required this.name,
    required this.initials,
    required this.module,
    required this.focus,
  });
}

class AppInfo {
  const AppInfo._();

  static const String name = 'RailMate';
  static const String version = 'v2.0.0';
  static const String course = 'BMIT2073 Mobile Application Development';
  static const String session = 'Academic Session 202605';

  static const String tagline =
      'Smart rail navigation and ticketing for Malaysia. One app for LRT, MRT, '
      'Monorail, KTM Komuter and KTMB ETS.';

  static const List<String> problems = [
    'Transfer details are unclear, especially whether a change happens inside '
        'the gates or needs you to exit and walk.',
    'Platform numbers and train direction are hard to work out at large '
        'interchange stations.',
    'There is no easy way to see how crowded a line will be before you travel.',
    'Route planning and ticketing live in separate apps.',
  ];

  static const String sdgStatement =
      'RailMate supports SDG 9: Industry, Innovation and Infrastructure. It '
      'turns Malaysian Government open data into practical travel advice, makes '
      'the existing rail network easier to use, and encourages a shift away '
      'from private vehicles.';

  static const List<TeamMember> team = [
    TeamMember(
      name: 'Goo Siang Ying',
      initials: 'GSY',
      module: 'Module 1',
      focus: 'User authentication, concession profiles and route preferences',
    ),
    TeamMember(
      name: 'Ng Hui Yong',
      initials: 'NHY',
      module: 'Module 2',
      focus: 'Route search, multi criteria planning and the fare matrix',
    ),
    TeamMember(
      name: 'Ng Yoke Khee',
      initials: 'NYK',
      module: 'Module 3',
      focus: 'Transfer guidance, platform and carriage advice, crowd analytics',
    ),
    TeamMember(
      name: 'Ooi Chun Yuan',
      initials: 'OCY',
      module: 'Module 4',
      focus: 'Ticketing, simulated payment, dynamic QR pass and trip history',
    ),
  ];

  static const List<String> dataSources = [
    'GTFS static feed for Rapid Rail KL from api.data.gov.my',
    'GTFS static feed for KTMB from api.data.gov.my',
    'Daily public transport ridership from the data.gov.my data catalogue',
  ];

  static const String paymentDisclaimer =
      'Payment in RailMate is a simulation built for this coursework. No real '
      'money is transferred and no card details are collected or stored.';

  static const String crowdDisclaimer =
      'Crowd levels are predictions calculated from published daily ridership, '
      'the time of day and the day of the week. They are not a live feed, '
      'because no public real time crowd data exists for Malaysian rail.';
}
