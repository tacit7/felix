# Frontend Integration Plan - Trip Sharing System

Complete action plan for integrating the trip sharing system into the RouteWise frontend.

## 🎯 Overview

The backend trip sharing system is complete with secure share links, role-based collaboration, and activity tracking. This document outlines the step-by-step frontend integration plan.

## 📋 Implementation Roadmap

### Phase 1: Core Components (Week 1)
- [ ] Share button component
- [ ] Basic share modal with link generation
- [ ] Permission utilities and hooks
- [ ] API service layer integration

### Phase 2: Collaboration Features (Week 2)
- [ ] Collaborator management panel
- [ ] Invitation system UI
- [ ] Permission-based edit controls
- [ ] Activity feed component

### Phase 3: Public Sharing (Week 3)
- [ ] Shared trip public view page
- [ ] Anonymous editing interface
- [ ] Approval workflow UI
- [ ] Share link validation and error handling

### Phase 4: Polish & Testing (Week 4)
- [ ] Loading states and error handling
- [ ] Mobile responsiveness
- [ ] Comprehensive testing
- [ ] Documentation and deployment

## 🛠️ Technical Implementation

### 1. API Service Layer

Create sharing-specific API functions:

```typescript
// services/api/tripSharing.ts
import { api } from './base';

export interface ShareSettings {
  expires_hours?: number;
  allow_public_edit?: boolean;
  require_approval_for_edits?: boolean;
  max_collaborators?: number;
}

export interface ShareData {
  share_url: string;
  share_token: string;
  expires_at: string;
  permissions: Record<string, boolean>;
  settings: {
    allow_public_edit: boolean;
    require_approval_for_edits: boolean;
    max_collaborators: number;
  };
}

export interface Collaborator {
  id: string;
  user: {
    id: string;
    username: string;
    full_name: string;
    email: string;
  };
  permission_level: 'viewer' | 'editor' | 'admin';
  status: 'pending' | 'accepted' | 'rejected' | 'removed';
  invited_at: string;
  accepted_at?: string;
  last_activity_at?: string;
}

export interface TripActivity {
  id: string;
  action: string;
  description: string;
  user?: {
    username: string;
    full_name: string;
  };
  changes_data: Record<string, any>;
  timestamp: string;
}

export const tripSharingApi = {
  // Share management
  async shareTrip(tripId: string, settings: ShareSettings = {}): Promise<ShareData> {
    const response = await api.post(`/trips/${tripId}/share`, { sharing: settings });
    return response.data.data;
  },

  async unshareTrip(tripId: string): Promise<void> {
    await api.delete(`/trips/${tripId}/share`);
  },

  async getSharedTrip(shareToken: string): Promise<SharedTripData> {
    const response = await api.get(`/shared/trips/${shareToken}`);
    return response.data.data;
  },

  // Collaboration management
  async addCollaborator(tripId: string, email: string, permissionLevel: string): Promise<Collaborator> {
    const response = await api.post(`/trips/${tripId}/collaborators`, {
      collaborator: { email, permission_level: permissionLevel }
    });
    return response.data.data.collaborator;
  },

  async updateCollaborator(tripId: string, collaboratorId: string, permissionLevel: string): Promise<Collaborator> {
    const response = await api.put(`/trips/${tripId}/collaborators/${collaboratorId}`, {
      collaborator: { permission_level: permissionLevel }
    });
    return response.data.data.collaborator;
  },

  async removeCollaborator(tripId: string, collaboratorId: string): Promise<void> {
    await api.delete(`/trips/${tripId}/collaborators/${collaboratorId}`);
  },

  // Activity tracking
  async getTripActivity(tripId: string): Promise<TripActivity[]> {
    const response = await api.get(`/trips/${tripId}/activity`);
    return response.data.data.activities;
  }
};

export interface SharedTripData {
  trip: Trip;
  permissions: Record<string, boolean>;
  owner: {
    id: string;
    username: string;
    full_name: string;
  };
  collaborators: Collaborator[];
  sharing_info: {
    is_shareable: boolean;
    expires_at?: string;
    allow_public_edit: boolean;
  };
}
```

### 2. Permission Utilities

Create utilities for permission checking:

```typescript
// utils/permissions.ts
export type PermissionLevel = 'viewer' | 'editor' | 'admin';

export interface Trip {
  id: string;
  user_id: string;
  is_shareable: boolean;
  share_expires_at?: string;
  allow_public_edit: boolean;
  collaborators?: Collaborator[];
}

export interface User {
  id: string;
  username: string;
  full_name: string;
  email: string;
}

export const permissionUtils = {
  isOwner(trip: Trip, user: User): boolean {
    return trip.user_id === user.id;
  },

  isSharingValid(trip: Trip): boolean {
    if (!trip.is_shareable) return false;
    if (!trip.share_expires_at) return true;
    return new Date(trip.share_expires_at) > new Date();
  },

  canView(trip: Trip, user?: User): boolean {
    if (!user) return this.isSharingValid(trip);
    if (this.isOwner(trip, user)) return true;
    if (this.isSharingValid(trip)) return true;
    
    const collaborator = this.getCollaborator(trip, user);
    return collaborator?.status === 'accepted';
  },

  canEdit(trip: Trip, user?: User): boolean {
    if (!user) return trip.allow_public_edit && this.isSharingValid(trip);
    if (this.isOwner(trip, user)) return true;
    if (trip.allow_public_edit && this.isSharingValid(trip)) return true;
    
    const collaborator = this.getCollaborator(trip, user);
    return collaborator?.status === 'accepted' && 
           ['editor', 'admin'].includes(collaborator.permission_level);
  },

  canManageCollaborators(trip: Trip, user: User): boolean {
    if (this.isOwner(trip, user)) return true;
    
    const collaborator = this.getCollaborator(trip, user);
    return collaborator?.status === 'accepted' && 
           collaborator.permission_level === 'admin';
  },

  canDelete(trip: Trip, user: User): boolean {
    return this.isOwner(trip, user);
  },

  canShare(trip: Trip, user: User): boolean {
    return this.isOwner(trip, user);
  },

  getCollaborator(trip: Trip, user: User): Collaborator | undefined {
    return trip.collaborators?.find(c => c.user.id === user.id);
  },

  getUserPermissionLevel(trip: Trip, user?: User): PermissionLevel | 'anonymous' | 'owner' {
    if (!user) return 'anonymous';
    if (this.isOwner(trip, user)) return 'owner';
    
    const collaborator = this.getCollaborator(trip, user);
    return collaborator?.permission_level || 'viewer';
  }
};
```

### 3. React Hooks

Create hooks for sharing functionality:

```typescript
// hooks/useSharing.ts
import { useState, useCallback } from 'react';
import { tripSharingApi, ShareSettings, ShareData } from '../services/api/tripSharing';
import { toast } from 'react-hot-toast';

export const useSharing = (tripId: string) => {
  const [isSharing, setIsSharing] = useState(false);
  const [shareData, setShareData] = useState<ShareData | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const shareTrip = useCallback(async (settings: ShareSettings = {}) => {
    setIsLoading(true);
    try {
      const data = await tripSharingApi.shareTrip(tripId, settings);
      setShareData(data);
      setIsSharing(true);
      toast.success('Trip shared successfully!');
      return data;
    } catch (error) {
      toast.error('Failed to share trip');
      throw error;
    } finally {
      setIsLoading(false);
    }
  }, [tripId]);

  const unshareTrip = useCallback(async () => {
    setIsLoading(true);
    try {
      await tripSharingApi.unshareTrip(tripId);
      setShareData(null);
      setIsSharing(false);
      toast.success('Trip unshared successfully');
    } catch (error) {
      toast.error('Failed to unshare trip');
      throw error;
    } finally {
      setIsLoading(false);
    }
  }, [tripId]);

  const copyShareLink = useCallback(() => {
    if (shareData?.share_url) {
      navigator.clipboard.writeText(shareData.share_url);
      toast.success('Share link copied to clipboard!');
    }
  }, [shareData?.share_url]);

  return {
    isSharing,
    shareData,
    isLoading,
    shareTrip,
    unshareTrip,
    copyShareLink
  };
};

// hooks/useCollaborators.ts
import { useState, useCallback, useEffect } from 'react';
import { tripSharingApi, Collaborator } from '../services/api/tripSharing';
import { toast } from 'react-hot-toast';

export const useCollaborators = (tripId: string) => {
  const [collaborators, setCollaborators] = useState<Collaborator[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  const addCollaborator = useCallback(async (email: string, permissionLevel: string) => {
    setIsLoading(true);
    try {
      const newCollaborator = await tripSharingApi.addCollaborator(tripId, email, permissionLevel);
      setCollaborators(prev => [...prev, newCollaborator]);
      toast.success(`Invitation sent to ${email}`);
      return newCollaborator;
    } catch (error) {
      toast.error('Failed to add collaborator');
      throw error;
    } finally {
      setIsLoading(false);
    }
  }, [tripId]);

  const updateCollaborator = useCallback(async (collaboratorId: string, permissionLevel: string) => {
    setIsLoading(true);
    try {
      const updated = await tripSharingApi.updateCollaborator(tripId, collaboratorId, permissionLevel);
      setCollaborators(prev => 
        prev.map(c => c.id === collaboratorId ? updated : c)
      );
      toast.success('Permissions updated');
      return updated;
    } catch (error) {
      toast.error('Failed to update permissions');
      throw error;
    } finally {
      setIsLoading(false);
    }
  }, [tripId]);

  const removeCollaborator = useCallback(async (collaboratorId: string) => {
    setIsLoading(true);
    try {
      await tripSharingApi.removeCollaborator(tripId, collaboratorId);
      setCollaborators(prev => prev.filter(c => c.id !== collaboratorId));
      toast.success('Collaborator removed');
    } catch (error) {
      toast.error('Failed to remove collaborator');
      throw error;
    } finally {
      setIsLoading(false);
    }
  }, [tripId]);

  return {
    collaborators,
    isLoading,
    addCollaborator,
    updateCollaborator,
    removeCollaborator,
    setCollaborators
  };
};
```

### 4. Share Button Component

Main sharing component for trip planning page:

```typescript
// components/sharing/ShareButton.tsx
import React, { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Share2, Users, Link } from 'lucide-react';
import { ShareModal } from './ShareModal';
import { CollaboratorsModal } from './CollaboratorsModal';
import { useSharing } from '@/hooks/useSharing';
import { permissionUtils } from '@/utils/permissions';

interface ShareButtonProps {
  trip: Trip;
  currentUser: User;
  className?: string;
}

export const ShareButton: React.FC<ShareButtonProps> = ({ 
  trip, 
  currentUser, 
  className 
}) => {
  const [showShareModal, setShowShareModal] = useState(false);
  const [showCollaboratorsModal, setShowCollaboratorsModal] = useState(false);
  const { shareData, isSharing, copyShareLink } = useSharing(trip.id);

  const canShare = permissionUtils.canShare(trip, currentUser);
  const canManageCollaborators = permissionUtils.canManageCollaborators(trip, currentUser);

  if (!canShare) return null;

  const handleQuickShare = () => {
    if (isSharing && shareData) {
      copyShareLink();
    } else {
      setShowShareModal(true);
    }
  };

  return (
    <>
      <div className={`flex items-center gap-2 ${className}`}>
        <Button
          onClick={handleQuickShare}
          variant={isSharing ? "outline" : "default"}
          className="flex items-center gap-2"
        >
          {isSharing ? <Link className="w-4 h-4" /> : <Share2 className="w-4 h-4" />}
          {isSharing ? 'Copy Link' : 'Share Trip'}
        </Button>

        {canManageCollaborators && (
          <Button
            onClick={() => setShowCollaboratorsModal(true)}
            variant="outline"
            size="sm"
            className="flex items-center gap-2"
          >
            <Users className="w-4 h-4" />
            Collaborators
            {trip.collaborators?.length ? (
              <span className="bg-blue-100 text-blue-800 px-1.5 py-0.5 rounded-full text-xs">
                {trip.collaborators.length}
              </span>
            ) : null}
          </Button>
        )}
      </div>

      <ShareModal
        trip={trip}
        isOpen={showShareModal}
        onClose={() => setShowShareModal(false)}
      />

      <CollaboratorsModal
        trip={trip}
        isOpen={showCollaboratorsModal}
        onClose={() => setShowCollaboratorsModal(false)}
      />
    </>
  );
};
```

### 5. Share Modal Component

Modal for configuring sharing settings:

```typescript
// components/sharing/ShareModal.tsx
import React, { useState } from 'react';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Copy, Check, Calendar, Shield, Users } from 'lucide-react';
import { useSharing } from '@/hooks/useSharing';
import { ShareSettings } from '@/services/api/tripSharing';

interface ShareModalProps {
  trip: Trip;
  isOpen: boolean;
  onClose: () => void;
}

export const ShareModal: React.FC<ShareModalProps> = ({ trip, isOpen, onClose }) => {
  const { shareTrip, unshareTrip, shareData, isSharing, isLoading, copyShareLink } = useSharing(trip.id);
  const [copied, setCopied] = useState(false);
  const [settings, setSettings] = useState<ShareSettings>({
    expires_hours: 168, // 7 days
    allow_public_edit: false,
    require_approval_for_edits: true,
    max_collaborators: 10
  });

  const handleShare = async () => {
    await shareTrip(settings);
  };

  const handleUnshare = async () => {
    await unshareTrip();
  };

  const handleCopyLink = () => {
    copyShareLink();
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const expirationOptions = [
    { value: 24, label: '24 hours' },
    { value: 168, label: '1 week' },
    { value: 720, label: '1 month' },
    { value: 0, label: 'Never expires' }
  ];

  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Share2 className="w-5 h-5" />
            Share Trip
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-6">
          {isSharing && shareData ? (
            <div className="space-y-4">
              <div>
                <Label>Share Link</Label>
                <div className="flex items-center gap-2 mt-1">
                  <Input 
                    readOnly 
                    value={shareData.share_url}
                    className="font-mono text-sm"
                  />
                  <Button
                    onClick={handleCopyLink}
                    variant="outline"
                    size="sm"
                    className="flex items-center gap-1"
                  >
                    {copied ? <Check className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
                    {copied ? 'Copied!' : 'Copy'}
                  </Button>
                </div>
              </div>

              <div className="bg-blue-50 p-4 rounded-lg space-y-2">
                <div className="flex items-center gap-2 text-sm">
                  <Calendar className="w-4 h-4" />
                  <span>
                    Expires: {shareData.expires_at ? 
                      new Date(shareData.expires_at).toLocaleDateString() : 
                      'Never'
                    }
                  </span>
                </div>
                <div className="flex items-center gap-2 text-sm">
                  <Shield className="w-4 h-4" />
                  <span>
                    Public editing: {shareData.settings.allow_public_edit ? 'Enabled' : 'Disabled'}
                  </span>
                </div>
                <div className="flex items-center gap-2 text-sm">
                  <Users className="w-4 h-4" />
                  <span>
                    Max collaborators: {shareData.settings.max_collaborators}
                  </span>
                </div>
              </div>

              <Button 
                onClick={handleUnshare} 
                variant="outline" 
                className="w-full"
                disabled={isLoading}
              >
                Stop Sharing
              </Button>
            </div>
          ) : (
            <div className="space-y-4">
              <div>
                <Label>Link Expiration</Label>
                <Select 
                  value={settings.expires_hours?.toString()} 
                  onValueChange={(value) => setSettings(s => ({ 
                    ...s, 
                    expires_hours: parseInt(value) || undefined 
                  }))}
                >
                  <SelectTrigger className="mt-1">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {expirationOptions.map(option => (
                      <SelectItem key={option.value} value={option.value.toString()}>
                        {option.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <Label>Allow public editing</Label>
                  <Switch
                    checked={settings.allow_public_edit}
                    onCheckedChange={(checked) => setSettings(s => ({ 
                      ...s, 
                      allow_public_edit: checked 
                    }))}
                  />
                </div>

                {settings.allow_public_edit && (
                  <div className="flex items-center justify-between pl-4">
                    <Label className="text-sm text-gray-600">Require approval for edits</Label>
                    <Switch
                      checked={settings.require_approval_for_edits}
                      onCheckedChange={(checked) => setSettings(s => ({ 
                        ...s, 
                        require_approval_for_edits: checked 
                      }))}
                    />
                  </div>
                )}
              </div>

              <div>
                <Label>Max collaborators</Label>
                <Input
                  type="number"
                  min="1"
                  max="50"
                  value={settings.max_collaborators}
                  onChange={(e) => setSettings(s => ({ 
                    ...s, 
                    max_collaborators: parseInt(e.target.value) || 10 
                  }))}
                  className="mt-1"
                />
              </div>

              <Button 
                onClick={handleShare} 
                className="w-full"
                disabled={isLoading}
              >
                {isLoading ? 'Creating share link...' : 'Share Trip'}
              </Button>
            </div>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
};
```

### 6. Collaborators Modal Component

Modal for managing trip collaborators:

```typescript
// components/sharing/CollaboratorsModal.tsx
import React, { useState } from 'react';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Badge } from '@/components/ui/badge';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Users, Plus, Mail, MoreHorizontal, Trash2 } from 'lucide-react';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { useCollaborators } from '@/hooks/useCollaborators';
import { Collaborator } from '@/services/api/tripSharing';

interface CollaboratorsModalProps {
  trip: Trip;
  isOpen: boolean;
  onClose: () => void;
}

export const CollaboratorsModal: React.FC<CollaboratorsModalProps> = ({ 
  trip, 
  isOpen, 
  onClose 
}) => {
  const { collaborators, addCollaborator, updateCollaborator, removeCollaborator, isLoading } = useCollaborators(trip.id);
  const [newCollaboratorEmail, setNewCollaboratorEmail] = useState('');
  const [newCollaboratorRole, setNewCollaboratorRole] = useState<'viewer' | 'editor' | 'admin'>('viewer');

  React.useEffect(() => {
    if (trip.collaborators) {
      setCollaborators(trip.collaborators);
    }
  }, [trip.collaborators]);

  const handleAddCollaborator = async () => {
    if (!newCollaboratorEmail.trim()) return;
    
    try {
      await addCollaborator(newCollaboratorEmail, newCollaboratorRole);
      setNewCollaboratorEmail('');
      setNewCollaboratorRole('viewer');
    } catch (error) {
      // Error handling is done in the hook
    }
  };

  const handleUpdateRole = async (collaboratorId: string, newRole: string) => {
    await updateCollaborator(collaboratorId, newRole);
  };

  const handleRemoveCollaborator = async (collaboratorId: string) => {
    await removeCollaborator(collaboratorId);
  };

  const getStatusBadge = (collaborator: Collaborator) => {
    const statusColors = {
      pending: 'bg-yellow-100 text-yellow-800',
      accepted: 'bg-green-100 text-green-800',
      rejected: 'bg-red-100 text-red-800',
      removed: 'bg-gray-100 text-gray-800'
    };

    return (
      <Badge className={statusColors[collaborator.status]}>
        {collaborator.status}
      </Badge>
    );
  };

  const getRoleBadge = (role: string) => {
    const roleColors = {
      viewer: 'bg-blue-100 text-blue-800',
      editor: 'bg-purple-100 text-purple-800',
      admin: 'bg-orange-100 text-orange-800'
    };

    return (
      <Badge className={roleColors[role as keyof typeof roleColors]}>
        {role}
      </Badge>
    );
  };

  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Users className="w-5 h-5" />
            Manage Collaborators
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-6">
          {/* Add new collaborator */}
          <div className="space-y-3 p-4 border rounded-lg">
            <Label>Invite New Collaborator</Label>
            <div className="flex gap-2">
              <Input
                placeholder="Email address"
                value={newCollaboratorEmail}
                onChange={(e) => setNewCollaboratorEmail(e.target.value)}
                className="flex-1"
              />
              <Select value={newCollaboratorRole} onValueChange={(value: any) => setNewCollaboratorRole(value)}>
                <SelectTrigger className="w-32">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="viewer">Viewer</SelectItem>
                  <SelectItem value="editor">Editor</SelectItem>
                  <SelectItem value="admin">Admin</SelectItem>
                </SelectContent>
              </Select>
              <Button
                onClick={handleAddCollaborator}
                disabled={!newCollaboratorEmail.trim() || isLoading}
              >
                <Plus className="w-4 h-4" />
              </Button>
            </div>
          </div>

          {/* Existing collaborators */}
          <div className="space-y-3">
            <Label>Current Collaborators ({collaborators.length})</Label>
            
            {collaborators.length === 0 ? (
              <div className="text-center py-8 text-gray-500">
                <Mail className="w-12 h-12 mx-auto mb-2 opacity-50" />
                <p>No collaborators yet</p>
                <p className="text-sm">Invite people to collaborate on this trip</p>
              </div>
            ) : (
              <div className="space-y-2">
                {collaborators.map((collaborator) => (
                  <div
                    key={collaborator.id}
                    className="flex items-center justify-between p-3 border rounded-lg"
                  >
                    <div className="flex items-center gap-3">
                      <Avatar className="w-8 h-8">
                        <AvatarFallback>
                          {collaborator.user.full_name?.charAt(0) || collaborator.user.username.charAt(0)}
                        </AvatarFallback>
                      </Avatar>
                      <div>
                        <div className="font-medium">{collaborator.user.full_name || collaborator.user.username}</div>
                        <div className="text-sm text-gray-500">{collaborator.user.email}</div>
                      </div>
                    </div>

                    <div className="flex items-center gap-2">
                      {getStatusBadge(collaborator)}
                      {getRoleBadge(collaborator.permission_level)}
                      
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="sm">
                            <MoreHorizontal className="w-4 h-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem
                            onClick={() => handleUpdateRole(collaborator.id, 'viewer')}
                            disabled={collaborator.permission_level === 'viewer'}
                          >
                            Make Viewer
                          </DropdownMenuItem>
                          <DropdownMenuItem
                            onClick={() => handleUpdateRole(collaborator.id, 'editor')}
                            disabled={collaborator.permission_level === 'editor'}
                          >
                            Make Editor
                          </DropdownMenuItem>
                          <DropdownMenuItem
                            onClick={() => handleUpdateRole(collaborator.id, 'admin')}
                            disabled={collaborator.permission_level === 'admin'}
                          >
                            Make Admin
                          </DropdownMenuItem>
                          <DropdownMenuItem
                            onClick={() => handleRemoveCollaborator(collaborator.id)}
                            className="text-red-600"
                          >
                            <Trash2 className="w-4 h-4 mr-2" />
                            Remove
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
};
```

### 7. Shared Trip Page

Public page for viewing shared trips:

```typescript
// pages/shared/trips/[shareToken].tsx
import React from 'react';
import { useRouter } from 'next/router';
import { useQuery } from '@tanstack/react-query';
import { tripSharingApi } from '@/services/api/tripSharing';
import { TripViewer } from '@/components/trips/TripViewer';
import { PermissionIndicator } from '@/components/sharing/PermissionIndicator';
import { ErrorBoundary } from '@/components/ui/ErrorBoundary';
import { Skeleton } from '@/components/ui/skeleton';

export default function SharedTripPage() {
  const router = useRouter();
  const { shareToken } = router.query as { shareToken: string };

  const { data: sharedTripData, isLoading, error } = useQuery({
    queryKey: ['shared-trip', shareToken],
    queryFn: () => tripSharingApi.getSharedTrip(shareToken),
    enabled: !!shareToken,
    retry: 1
  });

  if (isLoading) {
    return (
      <div className="container mx-auto py-8">
        <Skeleton className="h-8 w-64 mb-4" />
        <Skeleton className="h-4 w-96 mb-8" />
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2">
            <Skeleton className="h-96 w-full" />
          </div>
          <div>
            <Skeleton className="h-64 w-full" />
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="container mx-auto py-8">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-gray-900 mb-4">
            Unable to Load Trip
          </h1>
          <p className="text-gray-600 mb-4">
            This trip link may have expired or been removed.
          </p>
          <Button onClick={() => router.push('/')}>
            Go Home
          </Button>
        </div>
      </div>
    );
  }

  if (!sharedTripData) return null;

  const { trip, permissions, owner, collaborators, sharing_info } = sharedTripData;

  return (
    <ErrorBoundary>
      <div className="container mx-auto py-8">
        {/* Header */}
        <div className="mb-8">
          <div className="flex items-start justify-between mb-4">
            <div>
              <h1 className="text-3xl font-bold text-gray-900 mb-2">
                {trip.title}
              </h1>
              <p className="text-gray-600">
                Shared by {owner.full_name || owner.username}
              </p>
            </div>
            <PermissionIndicator 
              permissions={permissions}
              sharingInfo={sharing_info}
            />
          </div>

          {/* Trip metadata */}
          <div className="flex items-center gap-4 text-sm text-gray-500">
            <span>{trip.start_city} → {trip.end_city}</span>
            {trip.start_date && trip.end_date && (
              <span>
                {new Date(trip.start_date).toLocaleDateString()} - {new Date(trip.end_date).toLocaleDateString()}
              </span>
            )}
            <span className="capitalize">{trip.difficulty_level}</span>
          </div>
        </div>

        {/* Main content */}
        <TripViewer 
          trip={trip} 
          permissions={permissions}
          isSharedView={true}
          collaborators={collaborators}
        />
      </div>
    </ErrorBoundary>
  );
}
```

### 8. Permission Guards

Component wrappers for permission-based rendering:

```typescript
// components/sharing/PermissionGuard.tsx
import React from 'react';
import { permissionUtils } from '@/utils/permissions';

interface PermissionGuardProps {
  trip: Trip;
  user?: User;
  requirePermission: 'view' | 'edit' | 'manage' | 'delete' | 'share';
  children: React.ReactNode;
  fallback?: React.ReactNode;
}

export const PermissionGuard: React.FC<PermissionGuardProps> = ({
  trip,
  user,
  requirePermission,
  children,
  fallback = null
}) => {
  let hasPermission = false;

  switch (requirePermission) {
    case 'view':
      hasPermission = permissionUtils.canView(trip, user);
      break;
    case 'edit':
      hasPermission = permissionUtils.canEdit(trip, user);
      break;
    case 'manage':
      hasPermission = user ? permissionUtils.canManageCollaborators(trip, user) : false;
      break;
    case 'delete':
      hasPermission = user ? permissionUtils.canDelete(trip, user) : false;
      break;
    case 'share':
      hasPermission = user ? permissionUtils.canShare(trip, user) : false;
      break;
  }

  return hasPermission ? <>{children}</> : <>{fallback}</>;
};

// components/sharing/PermissionIndicator.tsx
import React from 'react';
import { Badge } from '@/components/ui/badge';
import { Shield, Eye, Edit, Users, Calendar } from 'lucide-react';

interface PermissionIndicatorProps {
  permissions: Record<string, boolean>;
  sharingInfo?: {
    is_shareable: boolean;
    expires_at?: string;
    allow_public_edit: boolean;
  };
}

export const PermissionIndicator: React.FC<PermissionIndicatorProps> = ({
  permissions,
  sharingInfo
}) => {
  const getPermissionLevel = () => {
    if (permissions.allow_edit) return 'Editor';
    if (permissions.allow_view) return 'Viewer';
    return 'No Access';
  };

  const getPermissionIcon = () => {
    if (permissions.allow_edit) return <Edit className="w-3 h-3" />;
    if (permissions.allow_view) return <Eye className="w-3 h-3" />;
    return <Shield className="w-3 h-3" />;
  };

  const getPermissionColor = () => {
    if (permissions.allow_edit) return 'bg-green-100 text-green-800';
    if (permissions.allow_view) return 'bg-blue-100 text-blue-800';
    return 'bg-gray-100 text-gray-800';
  };

  return (
    <div className="flex items-center gap-2">
      <Badge className={`flex items-center gap-1 ${getPermissionColor()}`}>
        {getPermissionIcon()}
        {getPermissionLevel()}
      </Badge>

      {sharingInfo?.expires_at && (
        <Badge variant="outline" className="flex items-center gap-1">
          <Calendar className="w-3 h-3" />
          Expires {new Date(sharingInfo.expires_at).toLocaleDateString()}
        </Badge>
      )}
    </div>
  );
};
```

## 📱 Integration Points

### 1. Trip Planning Page Integration

Add to your main trip planning page:

```typescript
// pages/trips/[id]/plan.tsx or components/TripPlanningPage.tsx
import { ShareButton } from '@/components/sharing/ShareButton';

// In your component
<div className="trip-header">
  <h1>{trip.title}</h1>
  <div className="actions">
    {/* Existing buttons */}
    <ShareButton trip={trip} currentUser={currentUser} />
  </div>
</div>
```

### 2. Edit Control Guards

Wrap edit controls with permission guards:

```typescript
// In POI editing components
<PermissionGuard trip={trip} user={currentUser} requirePermission="edit">
  <Button onClick={handleEditPOI}>Edit POI</Button>
</PermissionGuard>

// In itinerary editing
<PermissionGuard trip={trip} user={currentUser} requirePermission="edit">
  <AddActivityButton />
</PermissionGuard>
```

### 3. Activity Feed Integration

Add to trip sidebar or dedicated tab:

```typescript
// components/trips/ActivityFeed.tsx
import { useQuery } from '@tanstack/react-query';
import { tripSharingApi } from '@/services/api/tripSharing';

const ActivityFeed = ({ tripId }: { tripId: string }) => {
  const { data: activities } = useQuery({
    queryKey: ['trip-activity', tripId],
    queryFn: () => tripSharingApi.getTripActivity(tripId)
  });

  return (
    <div className="activity-feed">
      {activities?.map(activity => (
        <ActivityItem key={activity.id} activity={activity} />
      ))}
    </div>
  );
};
```

## 🧪 Testing Strategy

### Unit Tests
- [ ] Permission utility functions
- [ ] API service functions
- [ ] React hooks (useSharing, useCollaborators)
- [ ] Component rendering with different permission levels

### Integration Tests
- [ ] Share flow end-to-end
- [ ] Collaborator invitation and management
- [ ] Shared trip viewing (authenticated and anonymous)
- [ ] Permission enforcement across UI

### E2E Tests
- [ ] Complete sharing workflow
- [ ] Collaboration scenarios
- [ ] Share link validation and expiration
- [ ] Cross-browser compatibility

## 🚀 Deployment Checklist

### Before Launch
- [ ] Environment variables configured
- [ ] Error tracking setup
- [ ] Analytics for sharing events
- [ ] Performance monitoring
- [ ] Security review

### Launch Items
- [ ] Feature flags for gradual rollout
- [ ] User documentation/help guides
- [ ] Support team training
- [ ] Monitoring dashboards

## 📚 Documentation

### User Guides
- [ ] How to share a trip
- [ ] Collaborating on trips
- [ ] Managing permissions
- [ ] Troubleshooting share links

### Developer Docs
- [ ] API documentation updates
- [ ] Component library additions
- [ ] Permission system guide
- [ ] Testing best practices

This comprehensive plan provides everything needed to implement the trip sharing system in your frontend. Each component is designed to be modular and reusable, following React best practices with proper error handling and accessibility.