# Test Plan: Add Project CRUD

- **Issue**: acme/webapp#42
- **Author**: qa-20260402-091500
- **Date**: 2026-04-02
- **Dimensions**: UI, API, DB

## Prerequisites

- [ ] Dev server running at http://localhost:3000
- [ ] API server running at http://localhost:8000
- [ ] PostgreSQL accessible via `DATABASE_URL` in `.env`
- [ ] Auth token available: `export TOKEN=$(curl -s -X POST http://localhost:8000/api/auth/login -H "Content-Type: application/json" -d '{"email":"test@test.com","password":"test123"}' | jq -r '.token')`

---

## UI Verification (Chrome MCP)

### U1: Project list page loads
- **Action**: Navigate to http://localhost:3000/projects
- **Expected**: Page loads, shows "Projects" heading, list or empty state visible

### U2: Create new project
- **Action**: Click "New Project" button → fill Name with "QA Test Project" → fill Description with "Created by QA" → click "Create"
- **Expected**: Redirect to /projects, new project appears in list

### U3: Edit project
- **Action**: Click on "QA Test Project" → click "Edit" → change Name to "QA Test Updated" → click "Save"
- **Expected**: Name updates in project detail page

### U4: Delete project
- **Action**: Click "Delete" → confirm dialog → click "Yes, delete"
- **Expected**: Redirect to /projects, "QA Test Updated" no longer in list

### U5: Create with empty name (validation)
- **Action**: Click "New Project" → leave Name empty → click "Create"
- **Expected**: Error message "Name is required" shown, form not submitted

---

## API Verification (curl)

### A1: Create project
- **Request**: `curl -s -X POST http://localhost:8000/api/projects -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d '{"name": "API Test", "description": "via curl"}'`
- **Expected**: Status 201, body has `id`, `name` = "API Test"

### A2: Read project
- **Request**: `curl -s http://localhost:8000/api/projects/{id from A1} -H "Authorization: Bearer $TOKEN"`
- **Expected**: Status 200, `name` = "API Test"

### A3: Update project
- **Request**: `curl -s -X PATCH http://localhost:8000/api/projects/{id} -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d '{"name": "API Updated"}'`
- **Expected**: Status 200, `name` = "API Updated"

### A4: Delete project
- **Request**: `curl -s -X DELETE http://localhost:8000/api/projects/{id} -H "Authorization: Bearer $TOKEN"`
- **Expected**: Status 204

### A5: Read deleted project
- **Request**: `curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/api/projects/{id} -H "Authorization: Bearer $TOKEN"`
- **Expected**: Status 404

### A6: Create without auth
- **Request**: `curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:8000/api/projects -H "Content-Type: application/json" -d '{"name": "No Auth"}'`
- **Expected**: Status 401

### A7: Create with missing name
- **Request**: `curl -s -X POST http://localhost:8000/api/projects -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d '{"description": "no name"}'`
- **Expected**: Status 400, error mentions "name"

---

## DB Verification

### D1: Row created after A1
- **Query**: `psql "$DATABASE_URL" -c "SELECT id, name, description, created_at FROM projects WHERE name = 'API Test'"`
- **Expected**: 1 row, description = "via curl", created_at is today

### D2: Row updated after A3
- **Query**: `psql "$DATABASE_URL" -c "SELECT name FROM projects WHERE id = {id}"`
- **Expected**: name = "API Updated"

### D3: Row deleted after A4
- **Query**: `psql "$DATABASE_URL" -c "SELECT count(*) FROM projects WHERE id = {id}"`
- **Expected**: count = 0 (hard delete) or status = "deleted" (soft delete)

---

## Edge Cases

### E1: Duplicate project name
- **Action**: Create two projects with the same name
- **Expected**: Either allowed (if no unique constraint) or returns 409 with clear message

### E2: Very long name
- **Action**: `curl -s -X POST ... -d '{"name": "A very long name repeated... (500+ chars)"}'`
- **Expected**: Either truncated gracefully or returns 400 with length error
