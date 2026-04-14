# Case: TDD with Go (net/http)

Demonstrates one full Red→Green→Refactor cycle for a GET endpoint.

## Red — Write the failing test first

```go
// handler_test.go
func TestGetUser_ReturnsUser(t *testing.T) {
	req := httptest.NewRequest("GET", "/users/1", nil)
	w := httptest.NewRecorder()

	handler := NewUserHandler(newMockDB())
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", w.Code)
	}

	var resp map[string]any
	json.NewDecoder(w.Body).Decode(&resp)
	if resp["name"] != "Alice" {
		t.Fatalf("expected Alice, got %v", resp["name"])
	}
}
```

Run: `go test ./...` → **FAIL** (handler doesn't exist yet). Good.

## Green — Minimal implementation

```go
// handler.go
type UserHandler struct{ db UserDB }

func NewUserHandler(db UserDB) *UserHandler { return &UserHandler{db: db} }

func (h *UserHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	user, err := h.db.GetUser(id)
	if err != nil {
		http.Error(w, `{"error":"not_found"}`, http.StatusNotFound)
		return
	}
	json.NewEncoder(w).Encode(user)
}
```

Run: `go test ./...` → **PASS**. Stop here.

## Refactor — Clean up

- Extract response helpers if needed
- Ensure naming matches project conventions
- Run tests again → still pass

## Next cycle: error path

```go
func TestGetUser_NotFound(t *testing.T) {
	req := httptest.NewRequest("GET", "/users/999", nil)
	w := httptest.NewRecorder()

	handler := NewUserHandler(newMockDB()) // 999 not in mock
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", w.Code)
	}
}
```

Run → verify it passes (it should, since Green already handled this). If it doesn't, fix and re-run.

## Key points

- One test → one behavior → one cycle
- `httptest` for HTTP tests, no external dependencies
- Mock the DB interface, not the HTTP layer
- Test names describe behavior: `TestGetUser_NotFound`, not `TestHandler2`
