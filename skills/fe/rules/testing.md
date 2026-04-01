# Rule: Frontend Testing

## Framework

Vitest + @testing-library/react (follow project's existing setup).

## Rules

1. Every component gets a `.test.tsx` file in the same directory
2. Query priority: `getByRole` > `getByLabelText` > `getByText` > `getByTestId`
3. Test **behavior**, not implementation
4. No snapshot tests as primary assertions
5. Each component state (default, loading, error, empty) gets its own test
6. Form tests: validate submission, validation errors, disabled states
7. Async tests: mock API calls, test loading → success and loading → error paths
