# Postman-Ready API Testing Guide

This guide provides ready-to-use curl commands that developers can easily copy-paste into Postman or terminal. Each command includes clear parameter placeholders that can be easily modified.

## Quick Setup Variables

Before starting, set these base URLs and credentials:

```bash
# Base URLs
P1_BASE=http://localhost:8000
P2_BASE=http://localhost:8001
P3_BASE=http://localhost:8002/api/p3

# Test Credentials (modify as needed)
EMAIL=your_test_email@example.com
PASSWORD=Secret123!
FULL_NAME="Test User"
```

---

## Problem 1: RESTful API (Port 8000)

### 1. User Authentication

#### Sign Up
```bash
curl -X POST "http://localhost:8000/api/v1/auth/signup" \
-H "Content-Type: application/json" \
-d '{
  "email": "YOUR_EMAIL_HERE",
  "password": "YOUR_PASSWORD_HERE", 
  "full_name": "YOUR_FULL_NAME_HERE"
}'
```

**Postman Setup:**
- Method: `POST`
- URL: `http://localhost:8000/api/v1/auth/signup`
- Headers: `Content-Type: application/json`
- Body (raw JSON):
```json
{
  "email": "your_email@example.com",
  "password": "Secret123!",
  "full_name": "Test User"
}
```

#### Login & Get Token
```bash
curl -X POST "http://localhost:8000/api/v1/auth/login/access-token" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "username=YOUR_EMAIL_HERE&password=YOUR_PASSWORD_HERE"
```

**Postman Setup:**
- Method: `POST`
- URL: `http://localhost:8000/api/v1/auth/login/access-token`
- Headers: `Content-Type: application/x-www-form-urlencoded`
- Body (x-www-form-urlencoded):
  - `username`: `your_email@example.com`
  - `password`: `Secret123!`

> **📝 Save the Token:** Copy the `access_token` from the response and use it in subsequent requests as `Bearer YOUR_TOKEN_HERE`

#### Get Current User
```bash
curl -X GET "http://localhost:8000/api/v1/users/me" \
-H "Authorization: Bearer YOUR_TOKEN_HERE"
```

### 2. Project Management

#### Create Project
```bash
curl -X POST "http://localhost:8000/api/v1/projects/" \
-H "Authorization: Bearer YOUR_TOKEN_HERE" \
-H "Content-Type: application/json" \
-d '{
  "title": "YOUR_PROJECT_TITLE",
  "description": "YOUR_PROJECT_DESCRIPTION"
}'
```

> **📝 Save Project ID:** Copy the `id` from the response for subsequent project operations

#### Get All Projects
```bash
curl -X GET "http://localhost:8000/api/v1/projects/" \
-H "Authorization: Bearer YOUR_TOKEN_HERE"
```

#### Get Specific Project
```bash
curl -X GET "http://localhost:8000/api/v1/projects/PROJECT_ID_HERE" \
-H "Authorization: Bearer YOUR_TOKEN_HERE"
```

#### Update Project
```bash
curl -X PUT "http://localhost:8000/api/v1/projects/PROJECT_ID_HERE" \
-H "Authorization: Bearer YOUR_TOKEN_HERE" \
-H "Content-Type: application/json" \
-d '{
  "title": "UPDATED_PROJECT_TITLE"
}'
```

### 3. Task Management

#### Create Task
```bash
curl -X POST "http://localhost:8000/api/v1/tasks/" \
-H "Authorization: Bearer YOUR_TOKEN_HERE" \
-H "Content-Type: application/json" \
-d '{
  "title": "YOUR_TASK_TITLE",
  "project_id": PROJECT_ID_HERE
}'
```

> **📝 Save Task ID:** Copy the `id` from the response for subsequent task operations

#### Get All Tasks
```bash
curl -X GET "http://localhost:8000/api/v1/tasks/" \
-H "Authorization: Bearer YOUR_TOKEN_HERE"
```

#### Get Specific Task
```bash
curl -X GET "http://localhost:8000/api/v1/tasks/TASK_ID_HERE" \
-H "Authorization: Bearer YOUR_TOKEN_HERE"
```

#### Update Task Status
```bash
curl -X POST "http://localhost:8000/api/v1/tasks/TASK_ID_HERE/status/IN_PROGRESS" \
-H "Authorization: Bearer YOUR_TOKEN_HERE"
```

**Available Status Options:**
- `TODO`
- `IN_PROGRESS`
- `DONE`

#### Delete Task
```bash
curl -X DELETE "http://localhost:8000/api/v1/tasks/TASK_ID_HERE" \
-H "Authorization: Bearer YOUR_TOKEN_HERE"
```

#### Delete Project
```bash
curl -X DELETE "http://localhost:8000/api/v1/projects/PROJECT_ID_HERE" \
-H "Authorization: Bearer YOUR_TOKEN_HERE"
```

---

## Problem 2: Microservice Architecture (Port 8001)

### 1. User Authentication

#### Sign Up
```bash
curl -X POST "http://localhost:8001/api/v2/auth/signup" \
-H "Content-Type: application/json" \
-d '{
  "email": "YOUR_EMAIL_HERE",
  "password": "YOUR_PASSWORD_HERE",
  "full_name": "YOUR_FULL_NAME_HERE"
}'
```

#### Login & Get Token
```bash
curl -X POST "http://localhost:8001/api/v2/auth/login/access-token" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "username=YOUR_EMAIL_HERE&password=YOUR_PASSWORD_HERE"
```

#### Get Current User
```bash
curl -X GET "http://localhost:8001/api/v2/users/me" \
-H "Authorization: Bearer YOUR_TOKEN_HERE"
```

### 2. Product Management

#### Create Product (No Auth Required)
```bash
curl -X POST "http://localhost:8001/api/v2/products" \
-H "Content-Type: application/json" \
-d '{
  "sku": "YOUR_SKU_CODE",
  "name": "YOUR_PRODUCT_NAME",
  "description": "YOUR_PRODUCT_DESCRIPTION",
  "price_cents": PRICE_IN_CENTS,
  "stock": STOCK_QUANTITY
}'
```

**Example:**
```bash
curl -X POST "http://localhost:8001/api/v2/products" \
-H "Content-Type: application/json" \
-d '{
  "sku": "SKU-1001",
  "name": "Gaming Headset",
  "description": "High-quality gaming headset with noise cancellation",
  "price_cents": 7999,
  "stock": 25
}'
```

> **📝 Save Product ID:** Copy the `id` from the response

#### Get All Products (No Auth Required)
```bash
curl -X GET "http://localhost:8001/api/v2/products"
```

#### Get Specific Product (No Auth Required)
```bash
curl -X GET "http://localhost:8001/api/v2/products/PRODUCT_ID_HERE"
```

#### Update Product (Auth Required)
```bash
curl -X PATCH "http://localhost:8001/api/v2/products/PRODUCT_ID_HERE" \
-H "Authorization: Bearer YOUR_TOKEN_HERE" \
-H "Content-Type: application/json" \
-d '{
  "name": "UPDATED_PRODUCT_NAME",
  "price_cents": NEW_PRICE_IN_CENTS
}'
```

#### Update Product Stock (Auth Required)
```bash
curl -X PATCH "http://localhost:8001/api/v2/products/PRODUCT_ID_HERE/stock?delta=STOCK_CHANGE" \
-H "Authorization: Bearer YOUR_TOKEN_HERE"
```

**Examples:**
- Increase stock by 10: `delta=10`
- Decrease stock by 5: `delta=-5`

### 3. Order Management

#### Create Order (No Auth Required)
```bash
curl -X POST "http://localhost:8001/api/v2/orders" \
-H "Content-Type: application/json" \
-d '{
  "items": [
    {
      "product_id": PRODUCT_ID_HERE,
      "quantity": QUANTITY_NUMBER
    }
  ]
}'
```

**Multiple Items Example:**
```bash
curl -X POST "http://localhost:8001/api/v2/orders" \
-H "Content-Type: application/json" \
-d '{
  "items": [
    {
      "product_id": 1,
      "quantity": 2
    },
    {
      "product_id": 2, 
      "quantity": 1
    }
  ]
}'
```

> **📝 Save Order ID:** Copy the `id` from the response

#### Get All Orders (Auth Required)
```bash
curl -X GET "http://localhost:8001/api/v2/orders" \
-H "Authorization: Bearer YOUR_TOKEN_HERE"
```

#### Get Specific Order (Auth Required)
```bash
curl -X GET "http://localhost:8001/api/v2/orders/ORDER_ID_HERE" \
-H "Authorization: Bearer YOUR_TOKEN_HERE"
```

#### Pay for Order (Auth Required)
```bash
curl -X POST "http://localhost:8001/api/v2/orders/ORDER_ID_HERE/pay" \
-H "Authorization: Bearer YOUR_TOKEN_HERE"
```

#### Cancel Order (Auth Required)
```bash
curl -X POST "http://localhost:8001/api/v2/orders/ORDER_ID_HERE/cancel" \
-H "Authorization: Bearer YOUR_TOKEN_HERE"
```

#### Delete Product (No Auth Required)
```bash
curl -X DELETE "http://localhost:8001/api/v2/products/PRODUCT_ID_HERE"
```

---

## Problem 3: Performance Optimization (Port 8002)

### 1. User Authentication

#### Sign Up
```bash
curl -X POST "http://localhost:8002/api/p3/auth/signup" \
-H "Content-Type: application/json" \
-d '{
  "email": "YOUR_EMAIL_HERE",
  "password": "YOUR_PASSWORD_HERE",
  "full_name": "YOUR_FULL_NAME_HERE"
}'
```

#### Login & Get Token
```bash
curl -X POST "http://localhost:8002/api/p3/auth/login/access-token" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "username=YOUR_EMAIL_HERE&password=YOUR_PASSWORD_HERE"
```

#### Get Current User
```bash
curl -X GET "http://localhost:8002/api/p3/auth/users/me" \
-H "Authorization: Bearer YOUR_TOKEN_HERE"
```

### 2. Analytics Operations

#### Seed Analytics Data (No Auth Required)
```bash
curl -X POST "http://localhost:8002/api/p3/analytics/seed?rows=ROW_COUNT&unique_paths=PATH_COUNT"
```

**Examples:**
- Small dataset: `rows=100&unique_paths=10`
- Medium dataset: `rows=1000&unique_paths=50`
- Large dataset: `rows=10000&unique_paths=100`

#### Get Top Paths (Slow Version)
```bash
curl -X GET "http://localhost:8002/api/p3/analytics/top-paths/slow?limit=LIMIT_NUMBER"
```

#### Get Top Paths (Optimized Version)
```bash
curl -X GET "http://localhost:8002/api/p3/analytics/top-paths/optimized?limit=LIMIT_NUMBER"
```

**Common Limits:** 5, 10, 25, 50

---

## Postman Collection Tips

### Setting Up Variables in Postman

1. Create a new Environment in Postman
2. Add these variables:

| Variable Name | Initial Value | Current Value |
|---------------|---------------|---------------|
| `p1_base` | `http://localhost:8000` | `http://localhost:8000` |
| `p2_base` | `http://localhost:8001` | `http://localhost:8001` |
| `p3_base` | `http://localhost:8002/api/p3` | `http://localhost:8002/api/p3` |
| `auth_token` | | (will be set after login) |
| `project_id` | | (will be set after creating project) |
| `task_id` | | (will be set after creating task) |
| `product_id` | | (will be set after creating product) |
| `order_id` | | (will be set after creating order) |

### Using Variables in Postman

Replace placeholders in URLs with variables:
- `{{p1_base}}` instead of `http://localhost:8000`
- `{{auth_token}}` instead of `YOUR_TOKEN_HERE`
- `{{project_id}}` instead of `PROJECT_ID_HERE`

### Auto-Setting Variables with Tests

Add this script to your login request's "Tests" tab to automatically save the token:

```javascript
if (pm.response.code === 200) {
    const response = pm.response.json();
    pm.environment.set("auth_token", response.access_token);
}
```

### Parameter Substitution from Other Sources

When you need to copy IDs or tokens from other API responses:

1. **From Browser Network Tab:** 
   - Right-click on request → Copy → Copy as cURL
   - Extract the ID from the URL or response body

2. **From Other API Tools:**
   - Copy the JSON response
   - Find the `"id"` field value
   - Paste into the placeholder

3. **From Database/Admin Panel:**
   - Query: `SELECT id FROM projects WHERE title = 'Your Project';`
   - Use the returned ID in your requests

### Common Workflow Example

1. **Sign up** → Get success confirmation
2. **Login** → Copy `access_token` from response
3. **Create Project** → Copy `id` from response  
4. **Create Task** → Use project `id`, get task `id`
5. **Update Task Status** → Use task `id`
6. **Clean up** → Delete task and project using their IDs

---

## Troubleshooting

### Common Issues

1. **401 Unauthorized:** Check if your token is correctly set and not expired
2. **404 Not Found:** Verify the ID exists and URL is correct
3. **422 Validation Error:** Check required fields in request body
4. **500 Server Error:** Check if services are running: `docker compose ps`

### Service Health Check

```bash
# Check if all services are running
docker compose ps

# Check specific service logs  
docker compose logs -f web      # Problem 1
docker compose logs -f web_v2   # Problem 2  
docker compose logs -f web_v3   # Problem 3
```

### Quick Service Restart

```bash
# Restart specific service
docker compose restart web

# Rebuild and restart
docker compose up -d --build web
```