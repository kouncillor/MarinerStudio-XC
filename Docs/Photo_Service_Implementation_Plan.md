# Photo Service Implementation Plan

## Overview
A comprehensive photo service for NavUnits with local caching, manual Supabase sync, and a 10-photo limit per NavUnit.

## Core Components

### 1. Data Models

```swift
struct NavUnitPhoto: Identifiable, Codable {
    let id: UUID
    let navUnitId: String
    let localFileName: String
    let supabaseUrl: String?
    let timestamp: Date
    let isUploaded: Bool
    let isSyncedFromCloud: Bool
    var userId: String?
    
    // Computed properties
    var localURL: URL { /* Documents directory path */ }
    var thumbnailURL: URL { /* Thumbnail cache path */ }
}

struct PhotoSyncStatus {
    let totalPhotos: Int
    let uploadedPhotos: Int
    let pendingUploads: Int
    let isAtLimit: Bool
}
```

### 2. Service Architecture

```swift
protocol PhotoService {
    // Local operations
    func getPhotos(for navUnitId: String) -> [NavUnitPhoto]
    func takePhoto(for navUnitId: String) async throws -> NavUnitPhoto
    func deletePhoto(_ photo: NavUnitPhoto) async throws
    
    // Manual sync operations
    func uploadPhotos(for navUnitId: String) async throws -> PhotoSyncStatus
    func downloadPhotos(for navUnitId: String) async throws -> [NavUnitPhoto]
    func getSyncStatus(for navUnitId: String) -> PhotoSyncStatus
}

class PhotoServiceImpl: PhotoService {
    private let databaseService: PhotoDatabaseService
    private let supabaseService: PhotoSupabaseService
    private let cacheService: PhotoCacheService
}
```

### 3. Database Layer

```swift
class PhotoDatabaseService {
    // SQLite table: nav_unit_photos (created manually)
    func insertPhoto(_ photo: NavUnitPhoto) throws
    func getPhotos(for navUnitId: String) -> [NavUnitPhoto]
    func updatePhoto(_ photo: NavUnitPhoto) throws
    func deletePhoto(id: UUID) throws
    func getPhotoCount(for navUnitId: String) -> Int
}
```

### 4. Supabase Integration

```swift
class PhotoSupabaseService {
    // Supabase Storage bucket: "nav-unit-photos"
    // Supabase table: "nav_unit_photos" (created manually)
    
    func uploadPhoto(_ photo: NavUnitPhoto, imageData: Data) async throws -> String
    func downloadPhoto(supabaseUrl: String) async throws -> Data
    func getRemotePhotos(for navUnitId: String, userId: String) async throws -> [RemotePhoto]
    func deleteRemotePhoto(supabaseUrl: String) async throws
    func enforcePhotoLimit(for navUnitId: String, userId: String) async throws
}
```

### 5. Cache Management

```swift
class PhotoCacheService {
    private let documentsDirectory: URL
    private let thumbnailDirectory: URL
    
    func savePhoto(_ imageData: Data, fileName: String) throws -> URL
    func loadPhoto(fileName: String) throws -> Data
    func generateThumbnail(from imageData: Data) throws -> Data
    func deleteLocalPhoto(fileName: String) throws
    func clearCache(for navUnitId: String) throws
}
```

## Database Schema

### Local SQLite Table
```sql
CREATE TABLE nav_unit_photos (
    id TEXT PRIMARY KEY,
    nav_unit_id TEXT NOT NULL,
    local_file_name TEXT NOT NULL,
    supabase_url TEXT,
    timestamp INTEGER NOT NULL,
    is_uploaded INTEGER NOT NULL DEFAULT 0,
    is_synced_from_cloud INTEGER NOT NULL DEFAULT 0,
    user_id TEXT,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);

CREATE INDEX idx_nav_unit_photos_nav_unit_id ON nav_unit_photos(nav_unit_id);
CREATE INDEX idx_nav_unit_photos_user_id ON nav_unit_photos(user_id);
CREATE INDEX idx_nav_unit_photos_timestamp ON nav_unit_photos(timestamp);
```

### Supabase Table
```sql
CREATE TABLE nav_unit_photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nav_unit_id TEXT NOT NULL,
    file_name TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    storage_path TEXT NOT NULL,
    file_size INTEGER,
    mime_type TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_nav_unit_photos_nav_unit_user ON nav_unit_photos(nav_unit_id, user_id);
CREATE INDEX idx_nav_unit_photos_user_id ON nav_unit_photos(user_id);
CREATE INDEX idx_nav_unit_photos_created_at ON nav_unit_photos(created_at);

-- Row Level Security (RLS)
ALTER TABLE nav_unit_photos ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only access their own photos
CREATE POLICY "Users can manage their own nav unit photos" ON nav_unit_photos
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Function to enforce 10 photo limit per nav unit
CREATE OR REPLACE FUNCTION enforce_photo_limit()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT COUNT(*) FROM nav_unit_photos 
        WHERE nav_unit_id = NEW.nav_unit_id AND user_id = NEW.user_id) >= 10 THEN
        RAISE EXCEPTION 'Photo limit of 10 per navigation unit exceeded';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to enforce limit on insert
CREATE TRIGGER trigger_enforce_photo_limit
    BEFORE INSERT ON nav_unit_photos
    FOR EACH ROW
    EXECUTE FUNCTION enforce_photo_limit();
```

### Supabase Storage Bucket Configuration
```sql
-- Create storage bucket (via Supabase Dashboard or API)
-- Bucket name: nav-unit-photos
-- Public: false
-- File size limit: 5MB
-- Allowed MIME types: image/jpeg, image/png, image/heic
```

## UI Components

### 1. Camera Button Integration
- Add camera button to `NavUnitDetailsView` action buttons section
- Position between car and phone buttons
- Icon: `"camerasixseven"` (custom) or `"camera.fill"` (system)

### 2. Photo Gallery View

```swift
struct NavUnitPhotoGalleryView: View {
    let navUnitId: String
    @StateObject private var viewModel: PhotoGalleryViewModel
    @State private var showingCamera = false
    @State private var showingPhotoViewer = false
    @State private var selectedPhoto: NavUnitPhoto?
    
    var body: some View {
        // Grid of thumbnails
        // "Take New Photo" button
        // Manual sync controls
        // Photo count indicator (X/10)
    }
}
```

### 3. Photo Viewer

```swift
struct PhotoViewerView: View {
    let photos: [NavUnitPhoto]
    @Binding var selectedPhoto: NavUnitPhoto?
    
    var body: some View {
        // Full-screen photo display
        // Swipe navigation between photos
        // Delete photo option
        // Share photo option
    }
}
```

### 4. Camera Integration

```swift
struct CameraView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    // UIImagePickerController wrapper
    // Handle photo capture and return
}
```

## Implementation Phases

### Phase 1: Core Infrastructure (Week 1)
1. Create `PHOTOS/` folder in project
2. Create data models (`NavUnitPhoto`, sync status)
3. Implement `PhotoDatabaseService` with SQLite operations
4. Create `PhotoCacheService` for local file management
5. **Manual Step**: Execute SQLite table creation script

### Phase 2: Local Photo Management (Week 1-2)
1. Implement camera integration (`CameraView`)
2. Create `PhotoGalleryView` with thumbnail grid
3. Implement `PhotoViewerView` for full-screen viewing
4. Add photo taking, viewing, and local deletion

### Phase 3: Supabase Integration (Week 2)
1. **Manual Step**: Create Supabase table and storage bucket
2. **Manual Step**: Configure RLS policies and photo limit trigger
3. Implement `PhotoSupabaseService` for upload/download
4. Create manual sync UI controls
5. Implement 10-photo limit enforcement

### Phase 4: UI Integration (Week 2-3)
1. Add camera button to `NavUnitDetailsView`
2. Wire up photo gallery presentation
3. Implement sync status indicators
4. Add photo count display and limit warnings

### Phase 5: Polish & Testing (Week 3)
1. Error handling and user feedback
2. Loading states and progress indicators
3. Photo compression and optimization
4. Comprehensive testing of sync scenarios

## Technical Considerations

### Photo Storage Strategy
- **Local**: Store full-resolution photos in Documents directory
- **Thumbnails**: Generate and cache 150x150px thumbnails
- **Cloud**: Compress photos to reasonable size before upload (max 2MB)

### Sync Behavior
- **Upload**: Manual trigger only, batch upload with progress
- **Download**: Manual trigger only, download all or individual photos
- **Conflict Resolution**: Last-write-wins based on timestamp
- **Limit Enforcement**: Server-side validation, oldest photos deleted first

### Performance Optimization
- Lazy loading of thumbnails in gallery
- Background thumbnail generation
- Photo compression before upload
- Efficient SQLite queries with indexes

## File Structure
```
Mariner Studio/
├── PHOTOS/
│   ├── Services/
│   │   ├── PhotoService.swift
│   │   ├── PhotoServiceImpl.swift
│   │   ├── PhotoDatabaseService.swift
│   │   ├── PhotoSupabaseService.swift
│   │   └── PhotoCacheService.swift
│   ├── Models/
│   │   ├── NavUnitPhoto.swift
│   │   └── PhotoSyncStatus.swift
│   ├── Views/
│   │   ├── NavUnitPhotoGalleryView.swift
│   │   ├── PhotoViewerView.swift
│   │   └── CameraView.swift
│   └── ViewModels/
│       └── PhotoGalleryViewModel.swift
```

## Manual Database Setup Steps

### Local SQLite (Execute in DB Browser for SQLite)
1. Open `SS1.db` in database manager
2. Execute the SQLite table creation script above
3. Verify table and indexes are created

### Supabase Setup (Execute in Supabase Dashboard)
1. Navigate to SQL Editor in Supabase Dashboard
2. Execute the Supabase table creation script above
3. Navigate to Storage and create `nav-unit-photos` bucket
4. Configure bucket settings (private, 5MB limit, image types only)
5. Verify RLS policies and trigger are active

## Key Features Summary
✅ **Manual Sync Only** - No automatic downloads/uploads  
✅ **10 Photo Limit** - Enforced server-side per NavUnit via trigger  
✅ **Local Caching** - Full photos + thumbnails stored locally  
✅ **Gallery Interface** - Grid view with "take new" option  
✅ **Photo Viewer** - Full-screen with swipe navigation  
✅ **Supabase Integration** - Storage + metadata table  
✅ **Offline Support** - Full functionality without internet  
✅ **Manual Database Setup** - All tables created manually by developer  

**Estimated Timeline**: 2-3 weeks for complete implementation
**Storage Cost**: Controlled via manual sync + 10 photo limit

---

*Last Updated: July 15, 2025*
*Created for: Mariner Studio XC Photo Service Feature*