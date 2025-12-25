# SpendRail Worker App - Architecture

## Project Overview
Production-ready fintech wallet for workers to make QR code payments and request spending approvals.

**Target Platform:** Android (Primary)  
**State Management:** Riverpod  
**Design System:** Custom Modern UI (Non-Material)  
**Languages:** English, Hindi, Marathi

## Technical Stack
- **Backend:** Firebase Auth, Cloud Firestore
- **QR Scanning:** mobile_scanner
- **API Communication:** dio
- **Charts:** fl_chart
- **Localization:** flutter_localizations + custom manager
- **Local Storage:** shared_preferences

## Feature Modules

### 1. Authentication (`features/auth`)
- Firebase Authentication (Email/Password)
- Login Screen
- Registration Screen
- Forgot Password Screen
- Profile Screen with language preferences

### 2. Payment Flow (`features/payment`)
**Critical Hybrid Flow:**
1. QR Scanner → Scans QR code with auto-focus
2. Payment Form → Amount + Voice/Text Note
3. API Call → POST to `http://100.121.212.21/newTransaction`
   - Payload: `{userId, amount, qrData, note, timestamp}`
   - Response: `{firebaseId}`
4. Firestore Listener → Real-time stream on `transactions/{firebaseId}`
   - Status: "processing" → "completed" (success) / "disapproved" (failure)
   - 5-minute timeout

### 3. Pre-Approval (`features/approval`)
- Request form with numeric keypad
- Currency selector
- Text/Voice note input
- Firestore document creation in `requests` collection
- Status change notifications

### 4. History & Analytics (`features/history`)
- Transaction list with search and filters (date, category)
- Dashboard with spending pie chart (fl_chart)
- Export to CSV functionality

### 5. Core Services (`services`)
- `auth_service.dart` - Firebase Authentication
- `payment_service.dart` - API + Firestore hybrid
- `approval_service.dart` - Pre-approval requests
- `history_service.dart` - Transaction history
- `localization_service.dart` - Language management

### 6. Data Models (`models`)
- `user_model.dart`
- `transaction_model.dart`
- `approval_request_model.dart`

## UI/UX Design
- **Color Palette:** Modern fintech (Teal/Blue primary, high contrast)
- **Typography:** Elegant sans-serif fonts (Google Fonts)
- **Spacing:** Generous whitespace
- **Accessibility:** Semantic labels, large fonts support
- **Language Switcher:** AppBar/Drawer toggle

## Navigation Structure
```
/ (Home/Dashboard)
├── /login
├── /register
├── /forgot-password
├── /profile
├── /scan-qr
├── /payment-form
├── /payment-processing
├── /payment-result
├── /request-approval
├── /history
└── /analytics
```

## Implementation Steps
1. ✅ Setup dependencies and Firebase configuration
2. ✅ Create data models (User, Transaction, ApprovalRequest)
3. ✅ Build authentication service and screens
4. ✅ Implement localization manager
5. ✅ Create QR scanner and payment flow
6. ✅ Build pre-approval system
7. ✅ Develop history and analytics screens
8. ✅ Design modern UI theme
9. ✅ Configure Android permissions
10. ✅ Test and debug

## Security & Best Practices
- Secure Firebase rules (server-side)
- Input validation on all forms
- Error handling with debugPrint logging
- Timeout handling for API calls
- Proper state management with Riverpod
