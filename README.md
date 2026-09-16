# SpillCity

SpillCity is a modern, native social networking mobile application.

## Tech Stack

- **Frontend:** [Flutter](https://flutter.dev/) (Native iOS & Android)
- **Language:** [Dart](https://dart.dev/)
- **Backend:** [PostgreSQL via Supabase](https://supabase.com/)
- **ORM (Backend):** [Drizzle ORM](https://orm.drizzle.team/) (Found in `backend/`)
- **Authentication:** Supabase Auth
- **Real-time Messaging:** Supabase Realtime / Edge Functions (Found in `backend/supabase/`)

## Architecture

The project has been restructured to act as a pure native mobile application repository:
- The **Root Directory** contains all the Flutter UI, Logic, and native iOS/Android configurations.
- The **`backend/` Directory** contains all the server-side logic, including Supabase Edge Functions, database schemas (via Drizzle), and backend package dependencies.

## Features

- **Dynamic Feed:** A premium, news-app-style feed.
- **Social Features:** Profiles, Follows, Likes, Saves, and nested Comments.
- **Real-time Calling & Messaging:** Native VoIP capabilities and direct messaging.
- **Local Persistence:** Caching via SQLite for offline capabilities.

## Getting Started

To run the mobile app:
```bash
flutter pub get
flutter run
```

To manage the backend (Edge functions, migrations):
```bash
cd backend
npm install
supabase start
```
