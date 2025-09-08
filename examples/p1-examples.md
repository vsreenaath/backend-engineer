# Problem 1 - Task Management API Examples

These examples use curl. Replace placeholders as needed.

## Login and set TOKEN

```bash
# Login (form-encoded)
TOKEN=$(curl -s -X POST http://localhost:8000/api/v1/auth/login/access-token \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'username=admin@example.com&password=YOUR_PASSWORD' | jq -r .access_token)

echo "$TOKEN"
```

## Users

```bash
# Current user
curl -s http://localhost:8000/api/v1/users/me -H "Authorization: Bearer $TOKEN" | jq .

# List users (admin required)
curl -s http://localhost:8000/api/v1/users -H "Authorization: Bearer $TOKEN" | jq .
```

## Projects

```bash
# Create project
curl -s -X POST http://localhost:8000/api/v1/projects \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"title":"Proj A","description":"Demo"}' | jq .

# List projects
curl -s http://localhost:8000/api/v1/projects -H "Authorization: Bearer $TOKEN" | jq .

# Get, Update, Delete
curl -s http://localhost:8000/api/v1/projects/1 -H "Authorization: Bearer $TOKEN" | jq .
curl -s -X PUT http://localhost:8000/api/v1/projects/1 -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d '{"description":"Updated"}' | jq .
curl -s -X DELETE http://localhost:8000/api/v1/projects/1 -H "Authorization: Bearer $TOKEN" | jq .
```

## Tasks

```bash
# Create task under project 1
curl -s -X POST http://localhost:8000/api/v1/tasks \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"title":"Task 1","description":"Desc","project_id":1}' | jq .

# List tasks (own or all if admin)
curl -s http://localhost:8000/api/v1/tasks -H "Authorization: Bearer $TOKEN" | jq .

# Update status
curl -s -X POST http://localhost:8000/api/v1/tasks/1/status/InProgress -H "Authorization: Bearer $TOKEN" | jq .

# Assign
curl -s -X POST http://localhost:8000/api/v1/tasks/1/assign/1 -H "Authorization: Bearer $TOKEN" | jq .

# Delete
curl -s -X DELETE http://localhost:8000/api/v1/tasks/1 -H "Authorization: Bearer $TOKEN" | jq .
```
