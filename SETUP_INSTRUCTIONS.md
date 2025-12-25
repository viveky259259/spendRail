# SpendRail Worker App - Setup Instructions

## Firebase Configuration

This app requires Firebase to be configured before it can run. Please follow these steps:

### 1. Set up Firebase Project
1. Open the **Firebase panel** in Dreamflow (left sidebar)
2. Click "Connect to Firebase" or "Setup Firebase"
3. Follow the guided setup to connect your Firebase project
4. Ensure you enable:
   - **Firebase Authentication** (Email/Password)
   - **Cloud Firestore**

### 2. Firebase Configuration Files
The Dreamflow Firebase panel will automatically:
- Generate proper `firebase_options.dart` with your project credentials
- Configure Android and iOS with necessary Firebase files
- Set up authentication and Firestore

### 3. Firestore Security Rules
Set up these basic security rules in your Firebase Console → Firestore → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection - users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Transactions collection - users can read/write their own transactions
    match /transactions/{transactionId} {
      allow read: if request.auth != null && 
        resource.data.userId == request.auth.uid;
      allow write: if request.auth != null;
    }
    
    // Approval requests - users can read/write their own requests
    match /requests/{requestId} {
      allow read, write: if request.auth != null && 
        resource.data.userId == request.auth.uid;
    }
  }
}
```

### 4. Backend API Setup
The payment flow uses a backend API at `http://100.121.212.21/newTransaction`.

**Ensure your backend:**
- Accepts POST requests with: `{userId, amount, qrData, note, timestamp}`
- Returns: `{firebaseId}` - the Firestore document ID
- Creates a document in Firestore `transactions/{firebaseId}` collection
- Updates the transaction status: `processing` → `completed` or `disapproved`

## Testing Without Firebase

If you want to test the UI without Firebase:
1. Comment out Firebase initialization in `lib/main.dart`
2. Mock the auth and payment services
3. Use local state management instead

## App Features

1. **Authentication**: Email/Password login and registration
2. **QR Scanning**: Scan QR codes for payments with auto-focus
3. **Payment Flow**: 
   - Scan QR → Enter amount & note → API call → Real-time Firestore listener → Result
4. **Pre-Approval**: Request spending approval with amount and notes
5. **History**: View and filter transaction history
6. **Analytics**: Spending breakdown by category with pie charts
7. **Multilingual**: English, Hindi, Marathi support

## Permissions

The app requires these Android permissions (already configured):
- `CAMERA` - For QR code scanning
- `INTERNET` - For API and Firebase communication
- `RECORD_AUDIO` - For voice notes
- `WRITE_EXTERNAL_STORAGE` / `READ_EXTERNAL_STORAGE` - For storing voice recordings

## Running the App

1. Complete Firebase setup via Dreamflow
2. Ensure your backend API is running
3. Run the app on an Android device or emulator
4. Register a new account or login
5. Start scanning QR codes to make payments!
