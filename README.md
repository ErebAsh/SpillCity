<div align="center">
<h3 align="center">
  <img src="assets/logo.png" alt="SpillCity Logo" width="150" />
  <br>
  SpillCity
</h3>
<p align="center">
  <strong>A premium, high-performance social networking platform built for iOS and Android.</strong>
</p>

  [![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev/)
  [![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev/)
  [![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?logo=supabase)](https://supabase.com/)
  [![Agora](https://img.shields.io/badge/Agora-WebRTC-099DFD)](https://agora.io)
  [![Cloudinary](https://img.shields.io/badge/Cloudinary-Media-3448C5?logo=cloudinary)](https://cloudinary.com/)
  
</div>

---

## 📱 About The Project

SpillCity is a complete, native social networking application written in Flutter. It is designed to provide a fast, fluid, and premium user experience comparable to leading modern social platforms. 

The architecture is entirely serverless, relying on **Supabase** for database management and authentication, **Supabase Edge Functions** for secure backend logic, and **Agora** for high-fidelity audio and video calling.

## ✨ Features

- **Rich Social Feed**: Dynamic, news-app-style scrolling feed with images, videos, and gradients.
- **Real-Time Messaging**: Instant direct messaging powered by WebSockets (Pusher/Supabase Realtime).
- **High-Quality Calling**: Native VoIP 1-on-1 and group video/voice calls via the Agora SDK.
- **Ephemeral Stories**: Instagram-style stories with read receipts and view tracking.
- **Secure Architecture**: 100% serverless with sensitive secrets isolated in Deno-based Supabase Edge Functions.
- **Cloud Media**: Direct, secure, signed uploads to Cloudinary for images and videos.
- **Push Notifications**: Integrated FCM (Firebase Cloud Messaging) for instant updates.
- **Offline Capabilities**: Local caching and persistence for a seamless offline experience.

## 🛠️ Tech Stack

### Frontend (Client)
- **Framework:** Flutter (Native iOS & Android)
- **Language:** Dart
- **State Management:** Riverpod / Provider (Implementation specific)
- **Routing:** GoRouter

### Backend (Serverless)
- **Database:** PostgreSQL (Hosted via Supabase)
- **Authentication:** Supabase Auth (JWT)
- **Cloud Functions:** Supabase Edge Functions (Deno / TypeScript)
- **WebRTC / Calling:** Agora SDK
- **Real-Time Signaling:** Pusher
- **Media Storage:** Cloudinary

## 🚀 Getting Started

Follow these instructions to get a copy of the project up and running on your local machine for development and testing.

### Prerequisites

You will need the following installed:
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.19 or higher recommended)
* [Supabase CLI](https://supabase.com/docs/guides/cli/getting-started) (For deploying Edge Functions)
* Android Studio / Xcode (For running emulators)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/ErebAsh/SpillCity.git
   cd SpillCity
   ```

2. **Install Flutter Dependencies**
   ```bash
   flutter pub get
   ```

3. **Set Up Environment Variables**
   Duplicate the example config file and fill in your public API keys:
   ```bash
   cp lib/core/constants/app_config.example.dart lib/core/constants/app_config.dart
   ```
   *(Note: `app_config.dart` is gitignored to protect your keys).*

4. **Run the App**
   ```bash
   flutter run
   ```

## 🔐 Backend Configuration

The backend logic is securely handled by **Supabase Edge Functions**.

To deploy the functions to your Supabase project:
```bash
# Link your local repo to your Supabase project
supabase link --project-ref <your-project-id>

# Deploy all edge functions
supabase functions deploy
```

To set up your database schema and Row Level Security (RLS), copy and paste the contents of `supabase/schema.sql` into the Supabase SQL Editor.

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

## 📬 Contact

**ErebAsh**

*   **GitHub:** [@ErebAsh](https://github.com/ErebAsh)
*   **LinkedIn:** [Himanshu Raj](https://www.linkedin.com/in/himanshurajjnu/)
*   **Email:** [hr7207096@gmail.com](mailto:hr7207096@gmail.com)

Project Link: [https://github.com/ErebAsh/SpillCity](https://github.com/ErebAsh/SpillCity)
