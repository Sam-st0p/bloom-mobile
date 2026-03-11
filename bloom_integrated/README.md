# 🌸 BLOOM — GADRC CvSU Mobile & Web App

Flutter mobile and web application for the Gender and Development Resource Center at Cavite State University.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile Framework | Flutter (Dart) |
| Backend / Auth / DB | Supabase |
| State Management | setState + Streams |
| Fonts | Google Fonts (Nunito) |

## Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/bloom-mobile.git
cd bloom-mobile
```

### 2. Create Your .env File

```bash
cp .env.example .env
```

Then open `.env` and fill in your Supabase keys:
```
SUPABASE_URL=https://vfpgzuehfebhawlidhsz.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
```

> ⚠️ Get your anon key from: Supabase Dashboard → Project Settings → API → anon/public

### 3. Install Dependencies

```bash
flutter pub get
```

### 4. Run the App

```bash
# Android / iOS
flutter run

# Web
flutter run -d chrome

# Specific device
flutter run -d <device_id>
```

## Project Structure

```
lib/
├── main.dart                   # Entry point + Supabase init + AuthGate
├── config/
│   └── supabase_config.dart    # Global supabase client
├── models/
│   └── models.dart             # Data models with fromMap() factories
├── services/
│   ├── auth_service.dart       # signIn, signUp, signOut
│   └── database_service.dart   # All Supabase DB queries
├── screens/
│   ├── login_screen.dart
│   ├── signup_screen.dart
│   ├── main_shell.dart         # Bottom nav shell
│   ├── home_screen.dart
│   ├── library_screen.dart
│   ├── events_screen.dart
│   ├── badges_screen.dart
│   ├── forum_screen.dart
│   └── profile_screen.dart
├── theme/
│   └── app_theme.dart          # AppColors + AppTheme
└── widgets/
    └── common_widgets.dart     # Shared UI components
```

## Branch Workflow

```
main        ← production-ready only, never commit directly
dev         ← integration branch, merge features here first
feat/xxx    ← one branch per feature/screen
```

## Daily Workflow

```bash
git pull origin dev
git checkout -b feat/my-feature
# ... make changes ...
git add .
git commit -m "feat: description"
git push origin feat/my-feature
# Open Pull Request: feat/my-feature → dev
```

## Supabase Tables Used

| Table | Purpose |
|-------|---------|
| profiles | Student profile info |
| modules | Learning modules |
| categories | Module categories |
| student_progress | Progress per student per module |
| seminars | Seminar listings |
| seminar_registrations | Student sign-ups |
| certificates | Issued certificates |
| badges | Badge definitions |
| student_badges | Earned badges per student |
| calendar_events | Published events |
| announcements | Published announcements |

> ⚠️ Do NOT query: `audit_logs`, `activity_logs`, `student_assessment_attempts` — these tables do not exist yet.

## Security Notes

- `.env` is in `.gitignore` — never commit it
- Share `.env` with teammates privately
- Supabase RLS policies protect all data at the database level
- Students can only read/write their own rows

---

GADRC CvSU • March 2026
