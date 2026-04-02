# Verify Report: Add Project CRUD

- **Issue**: acme/webapp#42
- **PR**: #45
- **Verifier**: qa-20260402-091500
- **Date**: 2026-04-02
- **Test Plan**: test-plans/42-project-crud.md
- **Verdict**: FAIL

## Results

| Step | Description | Result | Notes |
|------|-------------|--------|-------|
| U1 | Project list loads | PASS | — |
| U2 | Create project via UI | PASS | — |
| U3 | Edit project | PASS | — |
| U4 | Delete project | PASS | — |
| U5 | Empty name validation | FAIL | No error message shown |
| A1 | POST /api/projects | PASS | 201 returned |
| A2 | GET /api/projects/:id | PASS | — |
| A3 | PATCH /api/projects/:id | PASS | — |
| A4 | DELETE /api/projects/:id | PASS | 204 returned |
| A5 | GET deleted project | PASS | 404 returned |
| A6 | POST without auth | PASS | 401 returned |
| A7 | POST missing name | FAIL | Returns 500 instead of 400 |
| D1 | Row created | PASS | — |
| D2 | Row updated | PASS | — |
| D3 | Row deleted | PASS | Hard delete confirmed |
| E1 | Duplicate name | PASS | Allowed (no unique constraint) |
| E2 | Very long name | FAIL | 500 error, no length validation |

## Failures

### U5: Empty name validation
- **Expected**: Error message "Name is required" shown, form not submitted
- **Actual**: Form submits, triggers API 500 error, user sees blank screen
- **Severity**: major

**FE Feedback — Steps to reproduce:**
1. Open http://localhost:3000/projects
2. Click "New Project"
3. Leave Name empty
4. Click "Create"
5. **Expected**: error message under Name field
6. **Actual**: blank screen, console shows `500 Internal Server Error`

---

### A7: POST missing name → 500 instead of 400
- **Expected**: Status 400, body `{ "error": "name is required" }`
- **Actual**: Status 500, body `{ "error": "column \"name\" cannot be null" }`
- **Severity**: major

**BE Feedback — curl to reproduce:**
```bash
curl -s -X POST http://localhost:8000/api/projects \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"description": "no name"}'
```
Expected: `400 { "error": "name is required" }`
Actual: `500 { "error": "column \"name\" cannot be null" }`

---

### E2: Very long name → 500
- **Expected**: 400 with length validation error
- **Actual**: 500, DB error `value too long for type character varying(255)`
- **Severity**: minor

**BE Feedback — curl to reproduce:**
```bash
curl -s -X POST http://localhost:8000/api/projects \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name": "AAAA...(300 chars)...AAAA"}'
```
Expected: `400 { "error": "name must be 255 characters or less" }`
Actual: `500 { "error": "value too long for type character varying(255)" }`

## Summary

3 of 17 steps failed. Two are BE input validation issues (missing name → 500, long name → 500). One is FE missing client-side validation for required field. No data integrity issues — DB state is correct for all successful operations.
