# Category Access Control System - Implementation Guide

## Overview
This document describes the complete implementation of the hierarchical category access control system for the KIU Students Material App.

## System Features

### 1. **Three-Level Category Hierarchy**
   - **Level 1**: Main Categories
   - **Level 2**: Sub Categories
   - **Level 3**: Third-Level Categories

### 2. **User Access Control**
   - Admins can control which categories users can see in the mobile app
   - Access control works hierarchically (denying a parent category hides all children)
   - By default, users have access to all categories unless explicitly denied

### 3. **Mobile API Endpoints**
   All API endpoints automatically filter categories based on user access permissions:
   - `GET /api/v1/categories` - Get main categories user has access to
   - `GET /api/v1/categories/{id}` - Get specific category details
   - `GET /api/v1/categories/{parentId}/subcategories` - Get subcategories
   - `GET /api/v1/categories/tree` - Get full category tree (filtered by access)

## Database Schema

### New Table: `user_category_access`
```sql
CREATE TABLE user_category_access (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    category_id BIGINT NOT NULL,
    has_access BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    UNIQUE(user_id, category_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
);
```

## Files Created

### Backend Models
1. **`app/Models/CategoryAccess.php`** - Manages user-category access relationships
2. **Updated `app/Models/User.php`** - Added category access methods
3. **Updated `app/Models/Category.php`** - Added user access relationships

### API Controllers
1. **`app/Http/Controllers/Api/CategoryController.php`** - API endpoints for mobile app
2. **`app/Http/Resources/Api/CategoryResource.php`** - API response formatter

### Admin Controllers
1. **`app/Http/Controllers/Admin/UserController.php`** - User management & access control

### Admin Views
1. **`resources/views/admin/users/index.blade.php`** - List all users
2. **`resources/views/admin/users/create.blade.php`** - Create new user
3. **`resources/views/admin/users/edit.blade.php`** - Edit user details
4. **`resources/views/admin/users/category-access.blade.php`** - Manage user category access

### Database Migration
1. **`database/migrations/2025_12_22_100000_create_user_category_access_table.php`**

### Updated Files
1. **`routes/api.php`** - Added category API routes
2. **`routes/web.php`** - Added user management routes
3. **`resources/views/admin/components/sidebar.blade.php`** - Added "Manage Users" menu
4. **`app/Http/Controllers/Admin/ApiController.php`** - Added category endpoint documentation
5. **`resources/views/admin/api/index.blade.php`** - Added categories section
6. **`POSTMAN_COLLECTION.json`** - Added category API endpoints

## Admin Panel Features

### User Management
Navigate to: **Admin Panel → Manage Users**

**Available Actions:**
1. **Create User** - Add new users with KIU ID, name, WhatsApp number, and password
2. **Edit User** - Update user information
3. **Delete User** - Remove users from the system
4. **Manage Category Access** - Control which categories a user can see

### Category Access Management
Click the **lock icon** next to any user to manage their category access.

**Features:**
- Visual hierarchy showing all 3 levels of categories
- Check/uncheck categories to grant/deny access
- Bulk actions: "Select All" or "Deselect All"
- Parent checkbox automatically toggles all children
- Visual indicators for each level (Level 1, Level 2, Level 3)

## API Implementation Details

### Authentication Required
All category endpoints require Bearer token authentication:
```
Authorization: Bearer {token}
```

### Access Control Logic
1. When a user requests categories, the system checks their access permissions
2. Only categories where `has_access = true` (or no record exists) are returned
3. If a parent category is denied, all its subcategories are hidden
4. The filtering is automatic and transparent to the mobile app

### Example API Response
```json
{
  "success": true,
  "message": "Main categories retrieved successfully",
  "data": [
    {
      "id": 1,
      "title": "Computer Science",
      "image": "http://localhost:8000/storage/categories/image.jpg",
      "parent_id": null,
      "level": 1,
      "is_active": true,
      "children": [...],
      "contents_count": 10,
      "created_at": "2025-12-22 10:00:00",
      "updated_at": "2025-12-22 10:00:00"
    }
  ]
}
```

## Usage Guide for Admins

### Step 1: Create Categories
1. Go to **Categories → Main Categories** (Level 1)
2. Create your main categories
3. Go to **Sub Categories** (Level 2) and create subcategories
4. Go to **3rd Level Categories** (Level 3) for more specific categories

### Step 2: Create Users
1. Go to **Manage Users → Add New User**
2. Fill in: KIU ID, Name, WhatsApp Number, Password
3. Click "Create User"

### Step 3: Manage Category Access
1. Go to **Manage Users**
2. Click the **lock icon** next to the user
3. Check categories the user should have access to
4. Uncheck categories to deny access
5. Click "Save Category Access"

### Step 4: Test in Mobile App
- Users will only see categories they have access to
- If a main category is denied, its subcategories won't appear
- The app automatically filters based on permissions

## API Documentation

Admins can view complete API documentation at:
**Admin Panel → API Documentation**

This includes:
- All authentication endpoints
- All category endpoints with examples
- Request parameters
- Response formats
- Error codes

## Migration Instructions

To apply the database changes:

```bash
php artisan migrate
```

This will create the `user_category_access` table.

## Security Features

1. **Authentication Required** - All category endpoints require valid tokens
2. **User Isolation** - Users can only see their own accessible categories
3. **Admin Protection** - Admin users cannot be edited or deleted through user management
4. **Cascade Deletion** - Deleting a user or category removes all related access records
5. **Unique Constraints** - Prevents duplicate access records

## Default Behavior

- **New Users**: Have access to all categories by default (no explicit records needed)
- **Explicit Denial**: Create a record with `has_access = false` to deny access
- **Explicit Grant**: Create a record with `has_access = true` to ensure access
- **Parent-Child**: Denying parent access effectively hides all children

## Postman Collection

The updated Postman collection (`POSTMAN_COLLECTION.json`) includes:
- Authentication endpoints
- Category endpoints
- Example requests and variables

Import it into Postman to test the API.

## Error Handling

### Common Error Responses

**401 Unauthorized** - No access to category:
```json
{
  "success": false,
  "message": "You do not have access to this category"
}
```

**404 Not Found** - Category doesn't exist:
```json
{
  "success": false,
  "message": "Category not found or inactive"
}
```

## Best Practices

1. **Hierarchical Planning**: Plan your category structure before creating them
2. **Access Testing**: Test category access from a non-admin user perspective
3. **Default Access**: Only deny access when necessary; default is full access
4. **Parent Denial**: Remember that denying parent categories hides all children
5. **Regular Audits**: Periodically review user access permissions

## Mobile App Integration

### Recommended Flow
1. User logs in → receives token
2. App calls `/api/v1/categories/tree` to get full accessible structure
3. App stores category tree locally
4. App filters navigation based on available categories
5. When user selects category, fetch its contents

### Handling Access Changes
- If admin changes user access, the mobile app will see changes on next API call
- Consider implementing token refresh to ensure up-to-date permissions
- Cache category tree but refresh periodically

## Support & Troubleshooting

### Issue: User sees no categories
- Check if user has explicit denial records for all main categories
- Verify categories are marked as `is_active = true`
- Check API authentication token is valid

### Issue: Changes not reflecting
- Clear application cache
- Verify database records in `user_category_access` table
- Check for Laravel cache issues: `php artisan cache:clear`

### Issue: Parent-child access issues
- Verify parent category access before checking children
- Remember that parent denial overrides child grants
- Use the category tree endpoint to see effective access

## Future Enhancements

Potential improvements:
1. Role-based access control (group permissions)
2. Time-based access (temporary access to categories)
3. Category access analytics (track which categories users view)
4. Bulk user permission management
5. Import/export category access configurations

---

**Implementation Date**: December 22, 2025
**System Version**: 1.0
**Laravel Version**: 11.x
**Database**: MySQL/MariaDB

