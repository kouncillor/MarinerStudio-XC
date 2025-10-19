# Feedback System Documentation

## Overview
Mariner Studio includes a comprehensive 4-option feedback system that maintains feature parity between iOS and Android platforms. The system allows users to submit feedback, report issues, request features, and contact support directly from within the app.

**SF Symbol Icon**: `pencil.and.list.clipboard`

---

## Feedback Options

### 1. Email Us
- Opens the device's mail composer (MessageUI)
- Pre-fills email template with device information
- Recipient: `admin@ospreyapplications.com`
- Includes app version, iOS version, and device model
- Handles error state when no email is configured

### 2. Visit Forums
- Opens Safari to the Mariner Studio community forums
- Forum URL: `https://marinerstudio.freeforums.net/`
- Allows users to engage with the community
- Error handling for network issues

### 3. Send Feedback (In-App)
- SwiftUI modal form for general feedback
- Fields:
  - Message (required, with character limits)
  - Contact info (optional email/name)
  - Anonymous checkbox (hides contact info when enabled)
- Submits directly to Supabase `feedback` table
- Includes source view tracking
- Loading states and success/error messages

### 4. Request Feature (In-App)
- SwiftUI modal form for feature requests
- Fields:
  - Feature description (required)
  - Feature importance explanation
  - Contact info (optional)
- Submits to Supabase `feedback` table with type "feature_request"
- Same validation and error handling as general feedback

---

## Architecture

### Core Components

#### DeviceInfoHelper
**Location**: `MarinerStudio-XC/Mariner Studio/Utils/DeviceInfoHelper.swift`

Provides device information for feedback submissions:
- App version and build number
- iOS version
- Device model
- Email template formatting

#### FeedbackModels
**Location**: `MarinerStudio-XC/Mariner Studio/Models/FeedbackModels.swift`

Data structures for feedback:
- `FeedbackSubmission` struct
- `FeedbackType` enum (general, feature_request)
- `FeedbackResponse` struct
- Codable conformance for Supabase integration

#### SupabaseManager
**Location**: `MarinerStudio-XC/Mariner Studio/Supabase/SupabaseManager.swift`

Backend integration:
- `submitFeedback()` method for async submission
- Handles both general feedback and feature requests
- Error handling with Swift Result types
- Stores data in shared Supabase `feedback` table (iOS + Android)

#### FeedbackView
**Location**: `MarinerStudio-XC/Mariner Studio/Views/FeedbackView.swift`

Main UI component:
- 4-option card layout
- Email and forum integrations
- Modal sheets for in-app feedback forms
- Source view context display
- Form validation and submission logic

---

## Source View Tracking

The feedback system tracks which view the user navigated from using a `sourceView` parameter. This helps identify which features users are providing feedback about.

### Integrated Views (34 total)

#### Menu Views (6)
1. TideMenuView → "Tides Menu"
2. CurrentMenuView → "Currents Menu"
3. BuoyMenuView → "Buoys Menu"
4. WeatherMenuView → "Weather Menu"
5. RouteMenuView → "Routes Menu"
6. NavUnitMenuView → "Nav Units Menu"

#### Favorites Views (6)
7. TideFavoritesView → "Tide Favorites"
8. CurrentFavoritesView → "Current Favorites"
9. BuoyFavoritesView → "Buoy Favorites"
10. WeatherFavoritesView → "Weather Favorites"
11. RouteFavoritesView → "Route Favorites"
12. NavUnitFavoritesView → "Nav Unit Favorites"

#### Station/List Views (5)
13. TidalHeightStationsView → "Tidal Height Stations"
14. TidalCurrentStationsView → "Tidal Current Stations"
15. BuoyStationsView → "Buoy Stations"
16. NavUnitsView → "Nav Units List"
17. AllRoutesView → "All Routes"

#### Prediction/Detail Views (5)
18. TidalHeightPredictionView → "Tidal Height Prediction"
19. TidalCurrentPredictionView → "Tidal Current Prediction"
20. BuoyStationWebView → "Buoy Station Details"
21. NavUnitDetailsView → "Nav Unit Details"
22. SimpleRouteDetailsView → "Route Details"

#### Weather Views (4)
23. CurrentLocalWeatherView → "Current Weather"
24. CurrentLocalWeatherViewForMap → "Map Weather"
25. HourlyForecastView → "Hourly Forecast"
26. WeatherMapView → "Weather Map"

#### Route Management Views (4)
27. EmbeddedRoutesBrowseView → "Browse Public Routes"
28. ImportPersonalRoutesView → "Import Routes"
29. CreateRouteView → "Create Route"
30. VoyagePlanRoutesView → "Voyage Plan"

#### Additional Views (3)
31. EmbeddedRoutesBrowseViewSimple → "Browse Routes (Simple)"
32. RadarWebView → "Radar"
33. NavUnitPhotoGalleryView → "Nav Unit Photos"

#### Map View (1)
34. NauticalMapView → "Map"

---

## UI Pattern

Feedback access is consistently implemented across all views:
- **Location**: Navigation bar trailing area (top-right)
- **Icon**: SF Symbol `pencil.and.list.clipboard`
- **Behavior**: Navigates to FeedbackView with appropriate sourceView parameter
- **Style**: Consistent with iOS/SwiftUI conventions

---

## Database Schema

### Supabase `feedback` Table

**Columns**:
- `id` (auto-generated)
- `feedback_type` (string: "general" or "feature_request")
- `message` (text, required)
- `is_anonymous` (boolean)
- `source_view` (string, tracks origin)
- `app_version` (string)
- `ios_version` (string)
- `device_model` (string)
- `contact_info` (string, nullable)
- `feature_importance` (text, nullable - only for feature requests)
- `created_at` (timestamp)

**Note**: This table is shared between iOS and Android platforms for centralized feedback management.

---

## Error Handling

The feedback system includes robust error handling:
- **Network failures**: User-friendly error messages with retry suggestions
- **Email not configured**: Alerts user to configure email on device
- **Form validation**: Character limits and required field checks
- **Offline state**: Graceful degradation with informative messages
- **Supabase errors**: Logged for debugging, user sees generic error message

---

## Future Enhancements

### Admin Panel (Planned)
- `getAllFeedback()` method stub exists in SupabaseManager
- Will allow admin dashboard to view/manage feedback
- Can filter by type, source, date, etc.

---

## Contact Information

- **Support Email**: admin@ospreyapplications.com
- **Community Forum**: https://marinerstudio.freeforums.net/
- **Platform**: iOS (feature parity with Android)

---

## Testing Checklist

When modifying the feedback system, verify:
- ✅ All 4 feedback options function correctly
- ✅ Data submits successfully to Supabase
- ✅ Source view tracking works from all integrated views
- ✅ Email composer opens with pre-filled template
- ✅ Forum link opens in Safari
- ✅ Form validation prevents invalid submissions
- ✅ Anonymous mode hides contact information
- ✅ Error states display user-friendly messages
- ✅ Loading states show during submission
- ✅ Success messages confirm submission
