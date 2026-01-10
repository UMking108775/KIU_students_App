# KIU Students Material App - API Documentation

## Overview
RESTful API for the KIU Students Material mobile application. This API provides authentication and content management functionality.

**Version:** 1.0  
**Base URL:** `{your-domain}/api/v1`  
**Authentication:** Bearer Token (Laravel Sanctum)  
**Response Format:** JSON

## Authentication

All protected endpoints require authentication using Bearer tokens.

### Headers
```
Authorization: Bearer {your_token_here}
Content-Type: application/json
Accept: application/json
```

## API Endpoints

### 1. User Registration
**Endpoint:** `POST /api/v1/auth/register`  
**Auth Required:** No

#### Request Body
```json
{
    "kiu_id": "12345",
    "name": "John Doe",
    "whatsapp_number": "+923001234567",
    "password": "password123",
    "password_confirmation": "password123"
}
```

#### Validation Rules
- `kiu_id`: Required, unique, numbers only, 4-20 characters
- `name`: Required, 3-255 characters
- `whatsapp_number`: Required, valid phone number format
- `password`: Required, minimum 6 characters, must match confirmation

#### Success Response (201)
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
            "created_at": "2025-12-22 12:00:00",
            "updated_at": "2025-12-22 12:00:00"
        },
        "token": "1|abcdefgh...",
        "token_type": "Bearer",
        "expires_in": "30 days"
    }
}
```

---

### 2. User Login
**Endpoint:** `POST /api/v1/auth/login`  
**Auth Required:** No

#### Request Body
```json
{
    "kiu_id": "12345",
    "password": "password123"
}
```

#### Validation Rules
- `kiu_id`: Required, numbers only
- `password`: Required

#### Success Response (200)
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
            "created_at": "2025-12-22 12:00:00",
            "updated_at": "2025-12-22 12:00:00"
        },
        "token": "2|xyz123...",
        "token_type": "Bearer",
        "expires_in": "30 days"
    }
}
```

#### Error Response (401)
```json
{
    "success": false,
    "message": "Invalid KIU ID or password"
}
```

---

### 3. Get User Profile
**Endpoint:** `GET /api/v1/auth/user`  
**Auth Required:** Yes

#### Success Response (200)
```json
{
    "success": true,
    "message": "User profile retrieved successfully",
    "data": {
        "id": 1,
        "kiu_id": "12345",
        "name": "John Doe",
        "whatsapp_number": "+923001234567",
        "created_at": "2025-12-22 12:00:00",
        "updated_at": "2025-12-22 12:00:00"
    }
}
```

---

### 4. Logout
**Endpoint:** `POST /api/v1/auth/logout`  
**Auth Required:** Yes

Revokes the current access token.

#### Success Response (200)
```json
{
    "success": true,
    "message": "Logout successful",
    "data": null
}
```

---

### 5. Logout from All Devices
**Endpoint:** `POST /api/v1/auth/logout-all`  
**Auth Required:** Yes

Revokes all access tokens for the user.

#### Success Response (200)
```json
{
    "success": true,
    "message": "Logged out from all devices successfully",
    "data": null
}
```

---

### 6. Refresh Token
**Endpoint:** `POST /api/v1/auth/refresh-token`  
**Auth Required:** Yes

Revokes current token and generates a new one.

#### Success Response (200)
```json
{
    "success": true,
    "message": "Token refreshed successfully",
    "data": {
        "token": "3|newtoken...",
        "token_type": "Bearer",
        "expires_in": "30 days"
    }
}
```

---

## Error Responses

### Validation Error (422)
```json
{
    "success": false,
    "message": "Validation failed",
    "errors": {
        "kiu_id": [
            "KIU ID is required"
        ],
        "password": [
            "Password must be at least 6 characters"
        ]
    }
}
```

### Unauthorized (401)
```json
{
    "success": false,
    "message": "Unauthenticated. Please login first."
}
```

### Not Found (404)
```json
{
    "success": false,
    "message": "Endpoint not found"
}
```

### Too Many Requests (429)
```json
{
    "success": false,
    "message": "Too many requests. Please try again later."
}
```

### Server Error (500)
```json
{
    "success": false,
    "message": "Internal server error"
}
```

---

## Rate Limiting

- **Public endpoints:** No rate limiting
- **Protected endpoints:** 60 requests per minute per user

When rate limit is exceeded, you'll receive a 429 response.

---

## Security Best Practices

1. **Token Storage**: Store tokens securely using encrypted storage in your mobile app
2. **HTTPS Only**: Always use HTTPS for API requests
3. **Token Expiry**: Tokens expire after 30 days - implement refresh mechanism
4. **Password Security**: Enforce strong passwords in your app
5. **Error Handling**: Never expose sensitive error details to users

---

## Testing with cURL

### Register
```bash
curl -X POST {base_url}/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "kiu_id": "12345",
    "name": "John Doe",
    "whatsapp_number": "+923001234567",
    "password": "password123",
    "password_confirmation": "password123"
  }'
```

### Login
```bash
curl -X POST {base_url}/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "kiu_id": "12345",
    "password": "password123"
  }'
```

### Get User Profile
```bash
curl -X GET {base_url}/api/v1/auth/user \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -H "Authorization: Bearer {your_token}"
```

---

## Health Check

**Endpoint:** `GET /api/health`  
**Auth Required:** No

Check if the API is running.

#### Response (200)
```json
{
    "success": true,
    "message": "API is running",
    "version": "v1",
    "timestamp": "2025-12-22T12:00:00.000000Z"
}
```

---

## Changelog

### Version 1.0 (December 2025)
- Initial release
- Authentication endpoints (register, login, logout)
- User profile management
- Token refresh functionality

---

## Support

For API support or questions, contact the development team.

