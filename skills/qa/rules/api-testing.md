# Rule: API Testing

## Tool: curl (or httpie)

Use curl for API verification. Every request and response should be documented in the verify report.

## What to Verify

### Per Endpoint

| Check | Example |
|-------|---------|
| Status code | `201` for create, `200` for read, `204` for delete |
| Response body | Required fields present, correct types, correct values |
| Error response | Proper error structure (`{ "error": "..." }` or similar) |
| Headers | `Content-Type`, CORS headers, cache headers |
| Auth | Rejects without token, accepts with valid token |

### CRUD Cycle

For any resource endpoint, test the full lifecycle:
1. **Create** (POST) → verify 201, response has ID
2. **Read** (GET) → verify the created resource is returned
3. **Update** (PUT/PATCH) → verify changes reflected
4. **Delete** (DELETE) → verify 204/200
5. **Read again** (GET) → verify 404

### Error Cases

- Missing required fields → expect 400
- Invalid data types → expect 400
- Non-existent resource → expect 404
- Unauthorized → expect 401
- Forbidden → expect 403

## curl Patterns

```bash
# POST with JSON
curl -s -X POST http://localhost:8000/api/items \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name": "test", "value": 42}'

# GET with jq for field check
curl -s http://localhost:8000/api/items/1 | jq '.name'

# Status code only
curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/api/items/1

# PUT
curl -s -X PUT http://localhost:8000/api/items/1 \
  -H "Content-Type: application/json" \
  -d '{"name": "updated"}'

# DELETE
curl -s -X DELETE http://localhost:8000/api/items/1
```

## Recording Results

For each API step in the verify report, include:
- The exact curl command (copy-pasteable)
- Expected status + body
- Actual status + body
- PASS or FAIL
