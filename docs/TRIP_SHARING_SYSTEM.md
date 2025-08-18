# Trip Sharing System

Complete trip sharing and collaboration system for RouteWise with permission-based access control.

## 🎯 Features

- **Share Links**: Generate secure, expirable share links for trips
- **Permission Levels**: Viewer, Editor, Admin roles with granular permissions  
- **Collaboration**: Invite users via email with role-based access
- **Activity Tracking**: Complete audit log of all trip changes
- **Security**: Token-based sharing with expiration dates
- **Public Editing**: Optional anonymous editing with approval workflows

## 📊 Database Schema

### Trips Table (Enhanced)
```sql
-- Sharing configuration
is_shareable BOOLEAN DEFAULT false
share_token VARCHAR(64) UNIQUE
share_expires_at TIMESTAMP
share_permissions JSONB DEFAULT '{}'

-- Collaboration settings  
allow_public_edit BOOLEAN DEFAULT false
require_approval_for_edits BOOLEAN DEFAULT true
max_collaborators INTEGER DEFAULT 10
```

### Trip Collaborators
```sql
CREATE TABLE trip_collaborators (
  id UUID PRIMARY KEY,
  trip_id INTEGER REFERENCES trips(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  permission_level VARCHAR NOT NULL DEFAULT 'viewer', -- viewer|editor|admin
  invited_by_id UUID REFERENCES users(id),
  status VARCHAR NOT NULL DEFAULT 'pending', -- pending|accepted|rejected|removed
  invited_at TIMESTAMP NOT NULL,
  accepted_at TIMESTAMP,
  last_activity_at TIMESTAMP
);
```

### Trip Activities (Audit Log)
```sql
CREATE TABLE trip_activities (
  id UUID PRIMARY KEY,
  trip_id INTEGER REFERENCES trips(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id),
  action VARCHAR NOT NULL,
  description TEXT,
  changes_data JSONB DEFAULT '{}',
  ip_address VARCHAR,
  user_agent VARCHAR,
  inserted_at TIMESTAMP NOT NULL
);
```

## 🔐 Permission System

### Permission Levels
- **Viewer**: Can view trip details, POIs, and itinerary
- **Editor**: Can edit trip details, add/remove POIs, modify itinerary
- **Admin**: Full editor permissions + manage collaborators

### Permission Matrix
| Action | Owner | Admin | Editor | Viewer | Public* |
|--------|-------|-------|--------|--------|---------|
| View Trip | ✅ | ✅ | ✅ | ✅ | ✅ |
| Edit Trip | ✅ | ✅ | ✅ | ❌ | ⚠️ |
| Add/Remove POIs | ✅ | ✅ | ✅ | ❌ | ⚠️ |
| Manage Collaborators | ✅ | ✅ | ❌ | ❌ | ❌ |
| Delete Trip | ✅ | ❌ | ❌ | ❌ | ❌ |
| Change Sharing | ✅ | ❌ | ❌ | ❌ | ❌ |

*Public editing only when `allow_public_edit` is enabled

## 🌐 API Endpoints

### Trip Sharing
```http
# Enable sharing for a trip
POST /api/trips/:id/share
{
  "sharing": {
    "expires_hours": 168,  # 7 days
    "allow_public_edit": false,
    "require_approval_for_edits": true,
    "max_collaborators": 10
  }
}

# Disable sharing
DELETE /api/trips/:id/share

# View shared trip (public endpoint)
GET /api/shared/trips/:share_token
```

### Collaboration Management
```http
# Add collaborator
POST /api/trips/:id/collaborators
{
  "collaborator": {
    "email": "user@example.com",
    "permission_level": "editor"
  }
}

# Update collaborator permissions
PUT /api/trips/:id/collaborators/:collaborator_id
{
  "collaborator": {
    "permission_level": "admin"
  }
}

# Remove collaborator
DELETE /api/trips/:id/collaborators/:collaborator_id

# Get trip activity log
GET /api/trips/:id/activity
```

## 🔗 Share Link Format

```
https://routewise.app/shared/trips/{share_token}
```

Where `share_token` is a 64-character URL-safe base64 string generated from 32 random bytes:
```elixir
:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
```

## 🚀 Frontend Integration

### Share Button Component
```typescript
interface ShareTripProps {
  tripId: string;
  onShare: (shareData: ShareData) => void;
}

interface ShareData {
  share_url: string;
  share_token: string;
  expires_at: string;
  permissions: SharePermissions;
}

// Enable sharing
const shareTrip = async (tripId: string, settings: ShareSettings) => {
  const response = await fetch(`/api/trips/${tripId}/share`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ sharing: settings })
  });
  return response.json();
};
```

### Permission Check Utilities
```typescript
const canEditTrip = (trip: Trip, currentUser: User) => {
  if (trip.user_id === currentUser.id) return true;
  if (trip.allow_public_edit && isSharingValid(trip)) return true;
  
  const collaborator = trip.collaborators?.find(c => 
    c.user.id === currentUser.id && c.status === 'accepted'
  );
  return collaborator?.permission_level in ['editor', 'admin'];
};
```

## 🎨 UI/UX Flow

### 1. Share Button in Trip Planning
```jsx
<ShareButton 
  tripId={trip.id}
  currentSharing={trip.sharing_info}
  onShare={handleShare}
  onUnshare={handleUnshare}
/>
```

### 2. Share Modal
- **Basic Sharing**: Generate link with default 30-day expiration
- **Advanced Options**: 
  - Custom expiration (hours/days/weeks)
  - Allow public editing toggle
  - Require approval for edits toggle
  - Max collaborators limit

### 3. Collaboration Panel
- **Invite by Email**: Add collaborators with permission level selection
- **Manage Permissions**: Edit existing collaborator permissions
- **Activity Feed**: Show recent trip changes and who made them

### 4. Shared Trip View
- **Trip Owner Info**: Display trip creator's name/avatar
- **Permission Indicator**: Show current user's permission level
- **Edit Controls**: Show/hide edit buttons based on permissions
- **Collaboration Status**: Display active collaborators

## 🔒 Security Considerations

### Token Security
- **Cryptographically Secure**: 32 random bytes (256-bit entropy)
- **URL-Safe**: Base64 encoding without padding
- **Unique**: Database-level unique constraint
- **Expirable**: Configurable expiration timestamps

### Access Control
- **Permission Verification**: Every API call checks user permissions
- **Activity Logging**: All changes tracked with user, IP, and timestamp
- **Rate Limiting**: Standard API rate limiting applies
- **Input Validation**: Comprehensive parameter validation

### Privacy Protection
- **User Data**: Only necessary user info (name, email) shared with collaborators
- **Trip Content**: Full trip data only accessible to authorized users
- **Activity Logs**: Personal activity data only visible to trip owner

## 📈 Usage Examples

### Basic Trip Sharing
1. User creates a trip for "Pacific Coast Highway Road Trip"
2. Clicks "Share" button in trip planning interface
3. System generates secure share link valid for 30 days
4. User copies link and sends to friends via text/email
5. Friends can view trip details and suggest edits (if enabled)

### Collaborative Planning
1. Trip owner invites collaborators via email
2. Invited users receive notification with accept/reject options
3. Accepted collaborators can edit trip based on permission level
4. All changes tracked in activity log
5. Trip owner can manage permissions and remove collaborators

### Public Trip Sharing
1. Enable "Allow public edits" for community input
2. Share link allows anonymous users to suggest changes
3. If "Require approval" enabled, changes go to pending state
4. Trip owner reviews and approves/rejects suggestions
5. Activity log tracks all anonymous contributions

## 🛠️ Development Notes

### Migration Applied
```bash
mix ecto.migrate
# Migration 20250818011227_add_sharing_to_trips.exs completed successfully
```

### Files Created/Modified
- **Models**: `TripCollaborator`, `TripActivity` schemas
- **Controller**: `TripSharingController` with full API
- **Context**: Enhanced `Trips` context with sharing functions
- **Migration**: Database schema changes applied
- **Routes**: API endpoints added to router

### Next Steps for Frontend Integration
1. **Share Button Component**: Add to trip planning page
2. **Share Modal**: Create sharing options interface
3. **Collaboration Panel**: Build collaborator management UI
4. **Permission Guards**: Add permission checks to edit controls
5. **Activity Feed**: Display trip change history
6. **Shared Trip Page**: Public view for shared trips

The system is now fully functional on the backend with comprehensive API support for all sharing and collaboration features.