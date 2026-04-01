# Rule: API Design

- RESTful verbs + proper status codes
- Consistent error shape: `{ "error": "code", "message": "...", "details": [] }`
- Pagination for list endpoints
- Error & Rescue Map for every endpoint (no catch-all)
