# My Week

A cloud-connected class timetable app built with Flutter and Firebase.

## Features
- **Cloud Authentication:** Secure user login and account creation using Firebase Auth.
- **Live Firestore Database:** Timetable data is saved to the cloud and updates in real-time.
- **Private Data:** Security rules ensure users can only see their own schedules.
- **Clash Detection:** Alerts you in red if two courses overlap.
- **Time Calculations:** Automatically calculates daily and weekly totals.
- **Full CRUD:** Add, edit, and delete courses.
- **Filtering:** View courses by day (Mon - Fri).

## Screenshots
### Login Screen
![Login](screenshots/login.png)

### Timetable
![Timetable](screenshots/timetable.png)

### Cloud Database
![Firebase](screenshots/firebase.png)

## Setup
1. Clone the repo.
2. Run `flutter pub get`.
3. Run `flutter run -d chrome`.