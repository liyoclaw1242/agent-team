# Case: Error Handling Pattern

## Good: Explicit error rescue

```typescript
app.get("/users/:id", async (req, res) => {
  try {
    const user = await db.users.findUnique({ where: { id: req.params.id } });
    if (!user) return res.status(404).json({ error: "not_found" });
    res.json(user);
  } catch (err) {
    if (err instanceof ValidationError) {
      return res.status(422).json({ error: "validation_failed", details: err.details });
    }
    throw err; // Let global handler catch unexpected errors
  }
});
```

## Bad: Catch-all swallowing errors

```typescript
// DON'T
app.get("/users/:id", async (req, res) => {
  try {
    const user = await db.users.findUnique({ where: { id: req.params.id } });
    res.json(user);
  } catch {
    res.status(500).json({ error: "something went wrong" }); // Swallows everything
  }
});
```
