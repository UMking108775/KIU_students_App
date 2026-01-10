# 📚 Content/Material API Endpoints - Complete Guide

## ✅ All Content API Endpoints Created!

Your API now has **5 powerful content endpoints** that work with **all 3 category levels**.

---

## 📡 API Endpoints

### 1. **Get Contents by Category** (Works for ALL 3 Levels!)

Get all materials/contents for a specific category (Level 1, 2, or 3)

```
GET /api/v1/categories/{categoryId}/contents
```

**Headers:**
```
Authorization: Bearer {token}
Content-Type: application/json
Accept: application/json
```

**Example Requests:**
```
GET /api/v1/categories/1/contents    (Level 1 category)
GET /api/v1/categories/5/contents    (Level 2 category)
GET /api/v1/categories/12/contents   (Level 3 category)
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Contents retrieved successfully",
  "data": {
    "category": {
      "id": 1,
      "title": "Computer Science",
      "level": 1
    },
    "contents": [
      {
        "id": 1,
        "title": "Introduction to Programming.pdf",
        "content_type": "pdf",
        "backblaze_url": "https://backblaze.com/file/xyz123.pdf",
        "is_active": true,
        "category": {
          "id": 1,
          "title": "Computer Science",
          "level": 1
        },
        "created_at": "2025-12-22 10:00:00",
        "updated_at": "2025-12-22 10:00:00"
      },
      {
        "id": 2,
        "title": "Python Tutorial Video.mp4",
        "content_type": "video",
        "backblaze_url": "https://backblaze.com/file/abc456.mp4",
        "is_active": true,
        "category": {
          "id": 1,
          "title": "Computer Science",
          "level": 1
        },
        "created_at": "2025-12-22 11:00:00",
        "updated_at": "2025-12-22 11:00:00"
      }
    ],
    "total": 2
  }
}
```

**Error Responses:**
- **401**: User doesn't have access to this category
- **404**: Category not found or inactive

---

### 2. **Get All Contents** (Across All Accessible Categories)

Get all materials user has access to

```
GET /api/v1/contents
```

**Use Case:** "All Materials" or "Recent Materials" screen

**Success Response (200):**
```json
{
  "success": true,
  "message": "All contents retrieved successfully",
  "data": {
    "contents": [...],
    "total": 25
  }
}
```

---

### 3. **Get Single Content by ID**

Get details of a specific material

```
GET /api/v1/contents/{id}
```

**Example:** `GET /api/v1/contents/5`

**Success Response (200):**
```json
{
  "success": true,
  "message": "Content retrieved successfully",
  "data": {
    "id": 5,
    "title": "Database Design Guide.pdf",
    "content_type": "pdf",
    "backblaze_url": "https://backblaze.com/file/db123.pdf",
    "is_active": true,
    "category": {
      "id": 3,
      "title": "Database Management",
      "level": 2
    },
    "created_at": "2025-12-22 10:00:00",
    "updated_at": "2025-12-22 10:00:00"
  }
}
```

---

### 4. **Search Contents**

Search materials by title

```
GET /api/v1/contents/search?query={search_term}
```

**Example:** `GET /api/v1/contents/search?query=python`

**Success Response (200):**
```json
{
  "success": true,
  "message": "Search completed successfully",
  "data": {
    "query": "python",
    "contents": [...],
    "total": 5
  }
}
```

---

### 5. **Get Contents by Type**

Filter materials by content type (pdf, video, ppt, etc.)

```
GET /api/v1/contents/type/{type}
```

**Examples:**
```
GET /api/v1/contents/type/pdf       (All PDFs)
GET /api/v1/contents/type/video     (All Videos)
GET /api/v1/contents/type/ppt       (All Presentations)
GET /api/v1/contents/type/doc       (All Documents)
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Contents retrieved successfully",
  "data": {
    "type": "pdf",
    "contents": [...],
    "total": 15
  }
}
```

---

## 🔐 Access Control

All content endpoints automatically:
- ✅ Filter by user's category access
- ✅ Only show active contents
- ✅ Check parent category access (hierarchical)
- ✅ Require authentication token

**If user doesn't have access:**
```json
{
  "success": false,
  "message": "You do not have access to this category"
}
```

---

## 🎯 How It Works with 3 Category Levels

### **Example Category Structure:**
```
📁 Computer Science (Level 1, ID: 1)
  └─ 📁 Programming (Level 2, ID: 2)
      └─ 📁 Python (Level 3, ID: 3)
          └─ 📄 Python Basics.pdf (Content ID: 10)
          └─ 📄 Advanced Python.pdf (Content ID: 11)
```

### **API Calls:**

**Get contents from Level 1 category:**
```
GET /api/v1/categories/1/contents
→ Returns all contents directly in "Computer Science"
```

**Get contents from Level 2 category:**
```
GET /api/v1/categories/2/contents
→ Returns all contents directly in "Programming"
```

**Get contents from Level 3 category:**
```
GET /api/v1/categories/3/contents
→ Returns: Python Basics.pdf, Advanced Python.pdf
```

---

## 📱 Mobile App Implementation

### **Recommended Flow:**

1. **User logs in** → Gets token
2. **Load categories tree**:
   ```
   GET /api/v1/categories/tree
   ```

3. **User selects a category** (any level):
   ```
   GET /api/v1/categories/{categoryId}/contents
   ```

4. **Display materials** in list/grid

5. **User clicks material**:
   ```
   GET /api/v1/contents/{id}
   → Get Backblaze URL
   → Open PDF/Video viewer
   ```

### **Additional Features:**

**Search Bar:**
```
GET /api/v1/contents/search?query=database
```

**Filter by Type:**
```
GET /api/v1/contents/type/pdf
```

**Show All Recent:**
```
GET /api/v1/contents
```

---

## 🔄 Complete API Summary

| Endpoint | Method | Description | Level Support |
|----------|--------|-------------|---------------|
| `/api/v1/categories/{id}/contents` | GET | Get contents by category | L1, L2, L3 ✅ |
| `/api/v1/contents` | GET | Get all accessible contents | All levels ✅ |
| `/api/v1/contents/{id}` | GET | Get single content | All levels ✅ |
| `/api/v1/contents/search` | GET | Search contents | All levels ✅ |
| `/api/v1/contents/type/{type}` | GET | Filter by type | All levels ✅ |

---

## 📊 Content Types Supported

Common content types you can use:
- `pdf` - PDF Documents
- `video` - Video files (mp4, avi, etc.)
- `ppt` - PowerPoint presentations
- `doc` - Word documents
- `image` - Images (jpg, png, etc.)
- `audio` - Audio files
- `zip` - Compressed files
- `link` - External links

---

## ✅ Features Included

- ✅ **Hierarchical Access Control** - Respects parent category access
- ✅ **All 3 Levels Supported** - Works for Level 1, 2, and 3 categories
- ✅ **Active Content Only** - Only shows active materials
- ✅ **Search Functionality** - Find materials by title
- ✅ **Type Filtering** - Filter by content type
- ✅ **Category Information** - Each content includes category details
- ✅ **Sorted by Latest** - Newest materials first
- ✅ **Total Count** - Returns count of materials

---

## 🎨 Example Mobile App UI Flow

**Screen 1: Categories**
```
📁 Computer Science (15 materials)
📁 Mathematics (23 materials)
📁 Physics (8 materials)
```

**Screen 2: Category Selected → Show Materials**
```
Computer Science > Materials (15)

📄 Introduction to Programming.pdf
📹 Python Tutorial Video.mp4
📄 Database Design.pdf
...
```

**Screen 3: Material Selected → Show Details/Download**
```
Title: Introduction to Programming.pdf
Type: PDF Document
Category: Computer Science
Added: Dec 22, 2025

[Download] [View]
```

---

## 🚀 Ready to Use!

Your content API is now **production-ready** with:
- ✅ 5 powerful endpoints
- ✅ Full access control
- ✅ Works with all 3 category levels
- ✅ Search and filtering
- ✅ Error handling
- ✅ Clean JSON responses

**Share this documentation with your mobile app developer!** 🎉

---

**Last Updated:** December 22, 2025  
**API Version:** v1  
**Status:** Production Ready ✅

