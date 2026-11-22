# RailMate

Smart rail navigation and ticketing for Malaysia. One app for LRT, MRT, Monorail, KTM Komuter and KTMB ETS.

RailMate plans a journey across the whole Malaysian rail network, tells you exactly where to change trains and whether that change happens inside the gates, predicts how crowded the trains will be from Malaysian Government open data, and issues a signed electronic ticket.

BMIT2073 Mobile Application Development — Assignment, Academic Session 202605
Sustainable Development Goal 9: Industry, Innovation and Infrastructure

---

## Module ownership

Each member owns one folder under `lib/features/` and presents it in the final code walkthrough.

| Module | Owner | Folder | Responsibility |
| --- | --- | --- | --- |
| **M1** User Authentication and Preferences | Goo Siang Ying | `lib/features/auth/` | Registration, sign in, email OTP, concession passenger types, route preference engine |
| **M2** Smart Rail Route Navigation Engine | Ng Hui Yong | `lib/features/routing/` | Station search, multi criteria route planning, fare and station matrix |
| **M3** Turn-by-Turn Guidance and Crowd Analytics | Ng Yoke Khee | `lib/features/guidance/` | Platform and direction guidance, carriage advice, crowd prediction, GPS arrival alerts |
| **M4** Ticketing, Payment and Trip History | Ooi Chun Yuan | `lib/features/ticketing/` | Booking, simulated payment gateway, dynamic QR pass, My Trips and receipts |

`lib/core/` and `lib/data/` are the shared foundation agreed by the whole team.

---

## Architecture

```
lib/
├── app/                        Application shell, auth gate, bottom navigation
├── core/
│   ├── config/                 Supabase project configuration
│   ├── constants/              App metadata, team, disclaimers
│   ├── providers/              RailDataProvider, SafeNotifier base class
│   ├── theme/                  Colours and Material 3 theme
│   ├── utils/                  Validators, time helpers, geo helpers
│   └── widgets/                Shared UI building blocks
├── data/
│   ├── datasources/
│   │   ├── local/              SQLite schema, bundled asset loader
│   │   └── remote/             data.gov.my client, Supabase service
│   ├── models/                 Station, line, interchange, journey, fare, ticket, profile
│   ├── repositories/           Network, ridership, profile, favourite, history, ticket, sync queue
│   └── services/               Crowd estimator, exit recommender, platform directory
└── features/
    ├── auth/                   Module 1
    ├── routing/                Module 2
    ├── guidance/               Module 3
    └── ticketing/              Module 4
```

State management is **Provider**. Each feature owns a `ChangeNotifier` that extends `SafeNotifier`, which suppresses notifications after disposal.

---

## Data management

### Sources

Everything comes from the Malaysian Government Open Data portal.

| Source | What it gives us |
| --- | --- |
| `gtfs-static/prasarana?category=rapid-rail-kl` | 186 Rapid Rail stops with official coordinates, line colours, running times and service frequencies |
| `gtfs-static/ktmb` | 156 KTMB stops covering Komuter, ETS and the intercity services across Peninsular Malaysia |
| `data-catalogue/?id=ridership_headline` | Daily national rail ridership, used for the crowd model |

`tool/build_network.dart` converts the two GTFS feeds into `assets/data/rail_network.json`. Re-run it with:

```bash
dart run tool/build_network.dart
```

The generated network holds **17 lines, 326 stations and 70 interchanges**, of which 39 are inside the paid area and 31 need you to exit and walk. Interchanges are derived from station name and coordinate proximity, with a small curated list for connections the coordinates alone would miss.

### Three tier loading

`RidershipRepository` never lets the app fail because of the network:

1. **Live** — call data.gov.my and write every record into the local SQLite cache.
2. **Cache** — if the call fails, or the cached copy is under six hours old, read from SQLite.
3. **Bundled** — if there is no cache at all, fall back to `assets/data/ridership_snapshot.json`.

The Plan screen always shows which tier is in use.

### Local database

SQLite via `sqflite`, with `sqflite_common_ffi` so the same code runs on desktop for testing.

| Table | Purpose |
| --- | --- |
| `profiles` | Local mirror of the user profile |
| `favourites` | Saved routes, unique per user and station pair |
| `search_history` | Recent searches, trimmed to 20 rows per user |
| `tickets` | Issued tickets with their signing secret |
| `ridership_cache` | Cached open data records |
| `sync_queue` | Changes waiting to be pushed to Supabase |

### Remote

Supabase provides authentication and cloud storage. Every write goes to SQLite first, then to Supabase. If the remote is unreachable the change is queued in `sync_queue` and pushed on the next successful connection, so the app is fully usable offline.

Run `supabase_schema.sql` once in the Supabase SQL editor. It creates the tables, indexes and row level security policies so a signed in user can only read and write their own rows.

---

## How the recommendations are computed

### Route planning (M2)

The network is a directed graph where a node is a `(station, line)` pair. Edges are **board**, **ride**, **transfer** inside the paid area, **walk** between connecting stations, and **alight**.

Dijkstra's algorithm runs three times with different weightings — fastest, fewest transfers, least crowded — plus diversification runs that ban the dominant line to surface genuinely different alternatives. Walking connections carry a heavier penalty than gated ones, because passengers prefer not to leave the paid area. Intercity legs carry a fare penalty so an expensive express service is not proposed as a shortcut.

Selecting **Paid area transfers only** removes every walking edge from the search.

### Fares (M2)

Fares are distance based, using the real kilometres from the GTFS feeds. Consecutive legs on the same operator are charged as one continuous segment rather than separately, which is how Malaysian integrated fares actually work. The card type multiplier (Touch 'n Go, cash token, concession card) and the passenger type multiplier are then applied.

### Crowd prediction (M3)

```
crowd score = base load × time-of-day factor × day-of-week factor × peak multiplier
```

- **base load** = average daily ridership for the line, multiplied by that line's share of its ridership column, divided by the line's daily capacity
- **time-of-day factor** = interpolated demand curve with morning and evening peaks
- **day-of-week factor** = computed from the actual ridership records for that weekday, not hard coded

Scores map to Low, Moderate and High. Carriage level loads are derived from the same score with a centre bias, because middle carriages fill first.

### Guidance (M3)

Platform numbers come from a curated layout file for 22 major interchanges and are derived by rule elsewhere. The app tells you which it is using: a verified layout or general guidance. Transfers are labelled as **inside the gates** or **exit and walk**, with the walking time and whether the route is step free.

### Ticketing (M4)

The QR pass is signed with HMAC-SHA256 over the reference, origin, destination, passenger count and a 30 second rotation window. The signature covers every field, so altering the passenger count or the destination invalidates the code. A screenshot stops working after one window.

Payment is a simulated gateway with a staged progress flow. No real money moves and no card details are collected.

---

## Running the project

```bash
flutter pub get
```

```bash
flutter run
```

```bash
flutter test
```

56 tests cover the network data, the routing engine, the fare engine, the crowd model, input validation, the QR signing and the SQLite repositories.

---

## Dependencies

| Package | Why |
| --- | --- |
| `provider` | State management |
| `http` | data.gov.my API calls |
| `supabase_flutter` | Authentication and remote sync |
| `sqflite` / `sqflite_common_ffi` | Local database |
| `collection` | Priority queue for Dijkstra's algorithm |
| `geolocator` | Nearest station and arrival alerts |
| `flutter_local_notifications` | Arrival alert notifications |
| `qr_flutter` | Dynamic QR pass rendering |
| `crypto` | HMAC signing for the QR pass |

---

## Honest limitations

- **Crowd levels are predictions, not live data.** Malaysia does not publish real time rail crowding. RailMate says so in the app.
- **Arrival alerts use your own GPS position,** not train positions. The GTFS realtime vehicle feed exists for buses only, not for rail.
- **Payment is simulated.** This is a coursework prototype.
- **Platform numbers are verified for 22 major interchanges** and derived by rule elsewhere. The app labels which is which.
- Travel times come from the operators' published GTFS timetables, so they are planning estimates rather than live running times.
