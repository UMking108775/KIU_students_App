# KIU Students Material App - API Developer Guide

## 📋 Overview

This API uses **Laravel Sanctum** for authentication with Bearer tokens (not JWT, but works similarly).

**Base URL:** `https://kiustudentsapp.ssatechs.com/api/v1`

**Authentication Type:** Bearer Token (Laravel Sanctum)

**Content Type:** `application/json`

---

## 🔐 Authentication System

### How Authentication Works

1. **User registers or logs in** → Receives a Bearer token
2. **Store token securely** in your app (encrypted storage)
3. **Include token in all protected requests** in the `Authorization` header
4. **Token expires after 30 days** → Use refresh endpoint or re-login

### Header Format for Protected Endpoints

```
Authorization: Bearer {your_access_token_here}
Content-Type: application/json
Accept: application/json
```

---

## 📡 API Endpoints

### 1. Health Check (Public)

**Test if API is running**

```
GET /api/health
```

**Response:**
```json
{
  "success": true,
  "message": "API is running",
  "version": "v1",
  "timestamp": "2025-12-22T10:30:00.000000Z"
}
```

---

## 🔑 Authentication Endpoints

### 2. Register New User

**Create a new user account**

```
POST /api/v1/auth/register
```

**Headers:**
```
Content-Type: application/json
Accept: application/json
```

**Body:**
```json
{
  "kiu_id": "12345",
  "name": "John Doe",
  "whatsapp_number": "+923001234567",
  "password": "password123",
  "password_confirmation": "password123"
}
```

**Success Response (201):**
```json
{
  "success": true,
  "message": "Registration successful. Welcome!",
  "data": {
    "user": {
      "id": 1,
      "kiu_id": "12345",
      "name": "John Doe",
      "whatsapp_number": "+923001234567",
      "created_at": "2025-12-22 10:30:00",
      "updated_at": "2025-12-22 10:30:00"
    },
    "token": "1|abcdefghijklmnopqrstuvwxyz1234567890",
    "token_type": "Bearer",
    "expires_in": "30 days"
  }
}
```

**Validation Rules:**
- `kiu_id`: Required, must be numbers only, unique
- `name`: Required, minimum 3 characters
- `whatsapp_number`: Required, valid phone number format
- `password`: Required, minimum 6 characters
- `password_confirmation`: Required, must match password

---

### 3. Login

**Authenticate existing user**

```
POST /api/v1/auth/login
```

**Headers:**
```
Content-Type: application/json
Accept: application/json
```

**Body:**
```json
{
  "kiu_id": "12345",
  "password": "password123"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Login successful. Welcome back!",
  "data": {
    "user": {
      "id": 1,
      "kiu_id": "12345",
      "name": "John Doe",
      "whatsapp_number": "+923001234567",
      "created_at": "2025-12-22 10:30:00",
      "updated_at": "2025-12-22 10:30:00"
    },
    "token": "2|xyz123abc456def789ghi012jkl345mno678",
    "token_type": "Bearer",
    "expires_in": "30 days"
  }
}
```

**Error Response (401):**
```json
{
  "success": false,
  "message": "Invalid KIU ID or password"
}
```

**Important:** After successful login, **save the token** and use it for all subsequent requests!

---

### 4. Get User Profile (Protected)

**Get authenticated user's profile**

```
GET /api/v1/auth/user
```

**Headers:**
```
Authorization: Bearer {token}
Content-Type: application/json
Accept: application/json
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "User profile retrieved successfully",
  "data": {
    "id": 1,
    "kiu_id": "12345",
    "name": "John Doe",
    "whatsapp_number": "+923001234567",
    "created_at": "2025-12-22 10:30:00",
    "updated_at": "2025-12-22 10:30:00"
  }
}
```

---

### 5. Logout (Protected)

**Logout from current device (revoke current token)**

```
POST /api/v1/auth/logout
```

**Headers:**
```
Authorization: Bearer {token}
Content-Type: application/json
Accept: application/json
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Logout successful",
  "data": null
}
```

---

### 6. Logout from All Devices (Protected)

**Logout from all devices (revoke all tokens)**

```
POST /api/v1/auth/logout-all
```

**Headers:**
```
Authorization: Bearer {token}
Content-Type: application/json
Accept: application/json
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Logged out from all devices successfully",
  "data": null
}
```

---

### 7. Refresh Token (Protected)

**Get a new token before expiry**

```
POST /api/v1/auth/refresh-token
```

**Headers:**
```
Authorization: Bearer {old_token}
Content-Type: application/json
Accept: application/json
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Token refreshed successfully",
  "data": {
    "token": "3|new_token_here_1234567890abcdefghijk",
    "token_type": "Bearer",
    "expires_in": "30 days"
  }
}
```

**Note:** Old token is automatically revoked. Update stored token with the new one.

---

## 📁 Category Endpoints (Protected)

**All category endpoints automatically filter based on user's access permissions set by admin.**

### 8. Get Main Categories

**Get all level 1 categories user has access to**

```
GET /api/v1/categories
```

**Headers:**
```
Authorization: Bearer {token}
Content-Type: application/json
Accept: application/json
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Main categories retrieved successfully",
  "data": [
    {
      "id": 1,
      "title": "Computer Science",
      "image": "http://domain.com/storage/categories/image.jpg",
      "parent_id": null,
      "level": 1,
      "is_active": true,
      "children": [],
      "contents_count": 5,
      "created_at": "2025-12-22 10:00:00",
      "updated_at": "2025-12-22 10:00:00"
    }
  ]
}
```

---

### 9. Get Category by ID

**Get specific category details**

```
GET /api/v1/categories/{id}
```

**Example:** `GET /api/v1/categories/1`

**Headers:**
```
Authorization: Bearer {token}
Content-Type: application/json
Accept: application/json
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Category retrieved successfully",
  "data": {
    "id": 1,
    "title": "Computer Science",
    "image": "http://domain.com/storage/categories/image.jpg",
    "parent_id": null,
    "level": 1,
    "is_active": true,
    "parent": null,
    "children": [
      {
        "id": 2,
        "title": "Programming",
        "level": 2,
        "is_active": true
      }
    ],
    "contents_count": 5,
    "created_at": "2025-12-22 10:00:00",
    "updated_at": "2025-12-22 10:00:00"
  }
}
```

**Error Response (401):**
```json
{
  "success": false,
  "message": "You do not have access to this category"
}
```

---

### 10. Get Subcategories

**Get all subcategories of a parent category**

```
GET /api/v1/categories/{parentId}/subcategories
```

**Example:** `GET /api/v1/categories/1/subcategories`

**Headers:**
```
Authorization: Bearer {token}
Content-Type: application/json
Accept: application/json
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Subcategories retrieved successfully",
  "data": [
    {
      "id": 2,
      "title": "Programming",
      "image": "http://domain.com/storage/categories/sub.jpg",
      "parent_id": 1,
      "level": 2,
      "is_active": true,
      "children": [],
      "contents_count": 3,
      "created_at": "2025-12-22 10:00:00",
      "updated_at": "2025-12-22 10:00:00"
    }
  ]
}
```

---

### 11. Get Complete Category Tree

**Get all categories in hierarchical structure (3 levels)**

```
GET /api/v1/categories/tree
```

**Headers:**
```
Authorization: Bearer {token}
Content-Type: application/json
Accept: application/json
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Category tree retrieved successfully",
  "data": [
    {
      "id": 1,
      "title": "Computer Science",
      "image": "http://domain.com/storage/categories/main.jpg",
      "level": 1,
      "children": [
        {
          "id": 2,
          "title": "Programming",
          "level": 2,
          "children": [
            {
              "id": 3,
              "title": "Python",
              "level": 3,
              "children": []
            },
            {
              "id": 4,
              "title": "JavaScript",
              "level": 3,
              "children": []
            }
          ]
        },
        {
          "id": 5,
          "title": "Databases",
          "level": 2,
          "children": [
            {
              "id": 6,
              "title": "MySQL",
              "level": 3,
              "children": []
            }
          ]
        }
      ]
    }
  ]
}
```

**Use Case:** Perfect for building navigation menus or category trees in your app.

---

## ❌ Error Responses

### Standard Error Format

All errors follow this structure:

```json
{
  "success": false,
  "message": "Error description here",
  "errors": {
    "field_name": ["Error message for this field"]
  }
}
```

### HTTP Status Codes

| Code | Meaning | When It Happens |
|------|---------|-----------------|
| 200 | Success | Request succeeded |
| 201 | Created | Resource created (e.g., registration) |
| 400 | Bad Request | Invalid request format |
| 401 | Unauthorized | Missing or invalid token |
| 403 | Forbidden | No permission to access resource |
| 404 | Not Found | Resource doesn't exist |
| 422 | Validation Error | Input validation failed |
| 429 | Too Many Requests | Rate limit exceeded (60 requests/minute) |
| 500 | Server Error | Internal server error |

### Example: Validation Error (422)

```json
{
  "success": false,
  "message": "Validation failed",
  "errors": {
    "kiu_id": ["The kiu id field is required."],
    "password": ["The password must be at least 6 characters."]
  }
}
```

### Example: Unauthorized (401)

```json
{
  "success": false,
  "message": "Unauthenticated."
}
```

---

## 🔒 Security & Best Practices

### 1. Token Storage
- **Android:** Use EncryptedSharedPreferences
- **iOS:** Use Keychain Services
- **Flutter:** Use flutter_secure_storage
- **React Native:** Use react-native-keychain

### 2. Token Management
```
// On Login/Register Success:
1. Save token securely
2. Save token_type (Bearer)
3. Save expiry date (current_date + 30 days)

// On Every API Call:
1. Check if token exists
2. Check if token is expired
3. If expired, redirect to login OR call refresh-token
4. Add token to Authorization header
```

### 3. Request Headers
Always include these headers:
```
Authorization: Bearer {token}
Content-Type: application/json
Accept: application/json
```

### 4. Rate Limiting
- **Protected endpoints:** 60 requests per minute per user
- If exceeded, you'll get HTTP 429 error
- Implement exponential backoff for retries

### 5. HTTPS Only
- **Production:** Always use HTTPS (not HTTP)
- Never send tokens over unencrypted connections

---

## 📱 Implementation Examples

### Android (Kotlin/Java)

```kotlin
// 1. Login Request
val retrofit = Retrofit.Builder()
    .baseUrl("https://your-domain.com/api/v1/")
    .addConverterFactory(GsonConverterFactory.create())
    .build()

interface ApiService {
    @POST("auth/login")
    suspend fun login(@Body request: LoginRequest): Response<LoginResponse>
    
    @GET("categories/tree")
    suspend fun getCategoryTree(
        @Header("Authorization") token: String
    ): Response<CategoryTreeResponse>
}

// 2. Make Request with Token
val token = "Bearer ${savedToken}"
val response = apiService.getCategoryTree(token)
```

### iOS (Swift)

```swift
// 1. Setup Request
var request = URLRequest(url: url)
request.httpMethod = "GET"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.setValue("application/json", forHTTPHeaderField: "Accept")
request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

// 2. Make Request
URLSession.shared.dataTask(with: request) { data, response, error in
    // Handle response
}.resume()
```

### Flutter (Dart)

```dart
// 1. Setup HTTP Client
import 'package:http/http.dart' as http;

class ApiService {
  static const baseUrl = 'https://your-domain.com/api/v1';
  
  Future<Map<String, dynamic>> getCategoryTree(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/categories/tree'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load categories');
    }
  }
}
```

---

## 🧪 Testing the API

### Using Postman

1. **Import Collection:**
   - Use the `POSTMAN_COLLECTION.json` file provided
   - Set `base_url` variable to your API domain

2. **Test Flow:**
   ```
   Step 1: Call Register or Login
   Step 2: Copy the "token" from response
   Step 3: Paste token into Postman environment variable
   Step 4: Test other endpoints
   ```

### Using cURL

```bash
# 1. Login
curl -X POST https://your-domain.com/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"kiu_id":"12345","password":"password123"}'

# 2. Get Categories (with token)
curl -X GET https://your-domain.com/api/v1/categories/tree \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Accept: application/json"
```

---

## 🎯 Category Access Control

**Important:** Categories are automatically filtered based on admin-assigned permissions.

- If admin denies access to a main category → user won't see it in the API response
- If admin denies a parent category → all its subcategories are hidden too
- Users only receive categories they have permission to view

**No additional logic needed in your app** - just display what the API returns!

---

## 📞 Support

**API Base URL (Production):** `https://your-production-domain.com/api/v1`

**API Base URL (Development):** `http://localhost:8000/api/v1`

**API Version:** v1

**Authentication:** Laravel Sanctum (Bearer Token)

**Token Expiry:** 30 days

**Rate Limit:** 60 requests/minute (protected endpoints)

---

## 📝 Quick Reference

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/api/health` | GET | No | Health check |
| `/api/v1/auth/register` | POST | No | Register new user |
| `/api/v1/auth/login` | POST | No | Login user |
| `/api/v1/auth/user` | GET | Yes | Get user profile |
| `/api/v1/auth/logout` | POST | Yes | Logout current device |
| `/api/v1/auth/logout-all` | POST | Yes | Logout all devices |
| `/api/v1/auth/refresh-token` | POST | Yes | Refresh token |
| `/api/v1/categories` | GET | Yes | Get main categories |
| `/api/v1/categories/{id}` | GET | Yes | Get category by ID |
| `/api/v1/categories/{id}/subcategories` | GET | Yes | Get subcategories |
| `/api/v1/categories/tree` | GET | Yes | Get full category tree |

---

**Last Updated:** December 22, 2025  
**Version:** 1.0  
**Author:** KIU Students Material App Team

