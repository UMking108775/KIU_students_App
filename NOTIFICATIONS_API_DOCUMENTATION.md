# 🔔 Push Notifications API - Developer Guide

## Overview

The Notifications API allows the mobile app to fetch push notifications created by admins. Notifications support scheduling, priority, expiry dates, and action buttons.

**Base URL:** `/api/v1/notifications`

**Authentication:** Required (Bearer Token)

---

## 📡 API Endpoints

### 1. **Get All Notifications**

Fetch all active and valid notifications for the authenticated user.

```
GET /api/v1/notifications
```

**Headers:**
```
Authorization: Bearer {token}
Content-Type: application/json
Accept: application/json
```

**Query Parameters (Optional):**
- `limit` (integer, default: 50, max: 100) - Limit number of notifications to return

**Example Request:**
```http
GET /api/v1/notifications?limit=20
Authorization: Bearer your_token_here
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Notifications retrieved successfully",
  "data": {
    "notifications": [
      {
        "id": 1,
        "title": "New Study Material Available",
        "message": "Check out the latest programming tutorials and PDFs in the Computer Science category.",
        "type": "info",
        "action_url": "https://app.example.com/categories/1",
        "action_text": "View Materials",
        "priority": 10,
        "created_at": "2025-12-22 10:00:00",
        "scheduled_at": null,
        "expires_at": "2025-12-31 23:59:59"
      },
      {
        "id": 2,
        "title": "App Maintenance Notice",
        "message": "The app will be under maintenance from 2 AM to 4 AM tomorrow.",
        "type": "warning",
        "action_url": null,
        "action_text": null,
        "priority": 5,
        "created_at": "2025-12-22 09:00:00",
        "scheduled_at": null,
        "expires_at": null
      }
    ],
    "total": 2
  }
}
```

**Notes:**
- Only active notifications are returned
- Only notifications that are currently valid (not expired, not scheduled for future) are returned
- Notifications are sorted by priority (descending) then by creation date (descending)
- Default limit is 50, maximum is 100

---

### 2. **Get Notification Count**

Get the count of active notifications (useful for badge counts).

```
GET /api/v1/notifications/count
```

**Headers:**
```
Authorization: Bearer {token}
Content-Type: application/json
Accept: application/json
```

**Example Request:**
```http
GET /api/v1/notifications/count
Authorization: Bearer your_token_here
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Notification count retrieved successfully",
  "data": {
    "count": 5
  }
}
```

**Use Case:** Display a badge count on the notifications icon showing how many new notifications are available.

---

### 3. **Get Specific Notification**

Fetch details of a specific notification by ID.

```
GET /api/v1/notifications/{id}
```

**Headers:**
```
Authorization: Bearer {token}
Content-Type: application/json
Accept: application/json
```

**Path Parameters:**
- `id` (integer, required) - Notification ID

**Example Request:**
```http
GET /api/v1/notifications/1
Authorization: Bearer your_token_here
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Notification retrieved successfully",
  "data": {
    "id": 1,
    "title": "New Study Material Available",
    "message": "Check out the latest programming tutorials and PDFs in the Computer Science category.",
    "type": "info",
    "action_url": "https://app.example.com/categories/1",
    "action_text": "View Materials",
    "priority": 10,
    "created_at": "2025-12-22 10:00:00",
    "scheduled_at": null,
    "expires_at": "2025-12-31 23:59:59"
  }
}
```

**Error Response (404):**
```json
{
  "success": false,
  "message": "Notification not found or expired"
}
```

---

## 📊 Notification Types

Notifications have different types that you can use to style them differently in your app:

| Type | Description | Suggested Color |
|------|-------------|----------------|
| `info` | General information | Blue |
| `success` | Success message | Green |
| `warning` | Warning message | Yellow/Orange |
| `error` | Error message | Red |
| `announcement` | Important announcement | Purple |

---

## 🎯 Notification Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Unique notification ID |
| `title` | string | Notification title (max 255 chars) |
| `message` | string | Notification message body |
| `type` | string | Notification type (info, success, warning, error, announcement) |
| `action_url` | string\|null | Optional URL to open when notification is tapped |
| `action_text` | string\|null | Optional button text for action |
| `priority` | integer | Priority (0-100, higher = appears first) |
| `created_at` | string | Creation date (Y-m-d H:i:s format) |
| `scheduled_at` | string\|null | Scheduled date (if scheduled for future) |
| `expires_at` | string\|null | Expiry date (if notification expires) |

---

## 🔄 Mobile App Implementation

### **Recommended Flow:**

#### **1. Fetch Notifications on App Launch:**
```dart
// Flutter Example
Future<List<Notification>> fetchNotifications() async {
  final response = await http.get(
    Uri.parse('$baseUrl/api/v1/notifications'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
  );
  
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return (data['data']['notifications'] as List)
        .map((n) => Notification.fromJson(n))
        .toList();
  }
  return [];
}
```

#### **2. Check for New Notifications:**
```dart
// Get notification count for badge
Future<int> getNotificationCount() async {
  final response = await http.get(
    Uri.parse('$baseUrl/api/v1/notifications/count'),
    headers: {
      'Authorization': 'Bearer $token',
    },
  );
  
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return data['data']['count'];
  }
  return 0;
}
```

#### **3. Display Notifications:**
```dart
// Show notifications in UI
Widget buildNotificationItem(Notification notification) {
  Color typeColor = getTypeColor(notification.type);
  
  return ListTile(
    leading: Icon(Icons.notifications, color: typeColor),
    title: Text(notification.title),
    subtitle: Text(notification.message),
    trailing: notification.actionUrl != null
        ? TextButton(
            onPressed: () => openUrl(notification.actionUrl),
            child: Text(notification.actionText ?? 'View'),
          )
        : null,
  );
}
```

#### **4. Handle Notification Tap:**
```dart
void onNotificationTap(Notification notification) {
  if (notification.actionUrl != null) {
    // Open the action URL (deep link, web page, etc.)
    launchUrl(Uri.parse(notification.actionUrl));
  } else {
    // Show notification details
    showNotificationDetails(notification);
  }
}
```

---

## 🔔 Notification Priority System

- **Priority 0-100**: Higher priority notifications appear first
- **Default Priority**: 0
- **Recommended Usage:**
  - **90-100**: Critical announcements (app updates, security alerts)
  - **50-89**: Important notifications (new features, major updates)
  - **10-49**: Regular notifications (new materials, general info)
  - **0-9**: Low priority (optional updates, reminders)

---

## ⏰ Scheduling & Expiry

### **Scheduled Notifications:**
- If `scheduled_at` is set, notification won't appear until that date/time
- Use this for announcements scheduled in advance

### **Expiring Notifications:**
- If `expires_at` is set, notification will automatically disappear after that date
- Use this for time-sensitive notifications (limited offers, deadlines, etc.)

### **Implementation:**
The API automatically filters out:
- Notifications scheduled for the future
- Notifications that have expired
- Inactive notifications

**You don't need to check dates manually** - the API handles this!

---

## 🎨 UI/UX Recommendations

### **1. Notification Badge:**
- Show count on notifications icon: `GET /api/v1/notifications/count`
- Update badge when app comes to foreground
- Clear badge when user views notifications

### **2. Notification List:**
- Group by date (Today, Yesterday, This Week, Older)
- Show type with color-coded icons
- Display priority for sorting
- Show expiry date if applicable

### **3. Notification Details:**
- Show full message
- Display action button if `action_url` exists
- Show type with appropriate styling
- Display creation/schedule/expiry dates

### **4. Actions:**
- If `action_url` exists, make notification tappable
- Open URL in-app browser or deep link
- Use `action_text` as button label
- If no action, show details on tap

---

## 📱 Example Use Cases

### **1. New Material Available:**
```json
{
  "title": "New Study Material Available",
  "message": "New PDFs added to Computer Science → Programming category",
  "type": "success",
  "action_url": "app://categories/1",
  "action_text": "View Materials",
  "priority": 20
}
```

### **2. System Maintenance:**
```json
{
  "title": "Scheduled Maintenance",
  "message": "App will be unavailable on Dec 25, 2025 from 2 AM to 4 AM",
  "type": "warning",
  "action_url": null,
  "action_text": null,
  "priority": 50,
  "expires_at": "2025-12-26 00:00:00"
}
```

### **3. Important Announcement:**
```json
{
  "title": "Mid-Term Exam Schedule Released",
  "message": "Check your exam schedule in the app. Exam dates: Jan 15-20, 2026",
  "type": "announcement",
  "action_url": "app://exams",
  "action_text": "View Schedule",
  "priority": 90
}
```

---

## 🔄 Refresh Strategy

### **Recommended Approaches:**

1. **On App Launch:**
   - Fetch notifications when app starts
   - Check count for badge

2. **Pull to Refresh:**
   - Allow users to manually refresh notifications list

3. **Periodic Check:**
   - Check every 5-10 minutes when app is active
   - Use background tasks if supported

4. **On Foreground:**
   - Refresh when app comes to foreground
   - Update badge count

---

## ❌ Error Handling

### **401 Unauthorized:**
```json
{
  "success": false,
  "message": "Unauthenticated."
}
```
**Action:** Redirect to login screen

### **404 Not Found:**
```json
{
  "success": false,
  "message": "Notification not found or expired"
}
```
**Action:** Remove notification from local list

### **500 Server Error:**
```json
{
  "success": false,
  "message": "Failed to retrieve notifications"
}
```
**Action:** Show error message, retry later

---

## 🚀 Quick Integration Checklist

- [ ] Add notification icon/badge to navigation
- [ ] Create notifications list screen
- [ ] Fetch notifications on app launch
- [ ] Implement pull-to-refresh
- [ ] Handle notification tap actions
- [ ] Style notifications by type (colors/icons)
- [ ] Display badge count
- [ ] Handle action URLs (deep links)
- [ ] Show expiry dates if applicable
- [ ] Test with different notification types
- [ ] Handle empty state (no notifications)
- [ ] Implement error handling

---

## 📝 Code Examples

### **Flutter/Dart:**
```dart
class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String type;
  final String? actionUrl;
  final String? actionText;
  final int priority;
  final DateTime createdAt;
  
  NotificationModel.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        title = json['title'],
        message = json['message'],
        type = json['type'],
        actionUrl = json['action_url'],
        actionText = json['action_text'],
        priority = json['priority'],
        createdAt = DateTime.parse(json['created_at']);
}
```

### **Android (Kotlin):**
```kotlin
data class Notification(
    val id: Int,
    val title: String,
    val message: String,
    val type: String,
    val actionUrl: String?,
    val actionText: String?,
    val priority: Int,
    val createdAt: String
)

// Fetch notifications
suspend fun fetchNotifications(): List<Notification> {
    val response = apiService.getNotifications("Bearer $token")
    return response.data.notifications
}
```

### **iOS (Swift):**
```swift
struct Notification: Codable {
    let id: Int
    let title: String
    let message: String
    let type: String
    let actionUrl: String?
    let actionText: String?
    let priority: Int
    let createdAt: String
}

// Fetch notifications
func fetchNotifications() async throws -> [Notification] {
    let response = try await apiClient.get("/notifications")
    return response.data.notifications
}
```

---

## ✅ Summary

**Endpoints:**
- `GET /api/v1/notifications` - Get all notifications
- `GET /api/v1/notifications/count` - Get notification count
- `GET /api/v1/notifications/{id}` - Get specific notification

**Key Features:**
- ✅ Automatic filtering (active, valid, not expired)
- ✅ Priority-based sorting
- ✅ Scheduled notifications
- ✅ Expiry dates
- ✅ Action buttons with URLs
- ✅ Multiple notification types

**All endpoints require authentication token in Authorization header.**

---

**Last Updated:** December 22, 2025  
**API Version:** v1  
**Status:** Production Ready ✅

