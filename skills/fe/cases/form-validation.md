# Form Validation — Step-by-Step Implementation

> Auto-trigger: spec mentions form, validation, input, submit, field, react-hook-form, zod, form handling.

## Overview

Type-safe forms with schema validation, field-level errors, and server-side revalidation.

## Tech Stack

| Concern | Solution |
|---------|----------|
| Form library | `react-hook-form` |
| Schema validation | `zod` + `@hookform/resolvers` |
| Server validation | Server Action + same Zod schema |
| Error display | Field-level + form-level |
| Accessibility | `aria-invalid`, `aria-describedby`, `role="alert"` |

---

## Step 1: Install

```bash
pnpm add react-hook-form zod @hookform/resolvers
```

## Step 2: Define Schema (shared client + server)

```ts
// src/lib/schemas/contact.ts
import { z } from "zod";

export const contactSchema = z.object({
  name: z
    .string()
    .min(1, "Name is required")
    .max(100, "Name must be under 100 characters"),
  email: z
    .string()
    .min(1, "Email is required")
    .email("Please enter a valid email"),
  message: z
    .string()
    .min(10, "Message must be at least 10 characters")
    .max(1000, "Message must be under 1000 characters"),
  category: z.enum(["general", "support", "feedback"], {
    errorMap: () => ({ message: "Please select a category" }),
  }),
});

export type ContactFormData = z.infer<typeof contactSchema>;
```

### Schema Convention

- One schema file per form, in `src/lib/schemas/`
- Export both the schema and the inferred type
- Error messages in the schema, not the component
- Same schema used client-side (react-hook-form) and server-side (Server Action)

## Step 3: Form Component

```tsx
// src/components/features/contact/contact-form.tsx
"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { contactSchema, type ContactFormData } from "@/lib/schemas/contact";
import { FormField } from "@/components/ui/form-field";
import { submitContact } from "@/app/contact/actions";
import { useState } from "react";

export function ContactForm() {
  const [serverError, setServerError] = useState<string>();
  const [success, setSuccess] = useState(false);

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<ContactFormData>({
    resolver: zodResolver(contactSchema),
    defaultValues: {
      name: "",
      email: "",
      message: "",
      category: undefined,
    },
  });

  async function onSubmit(data: ContactFormData) {
    setServerError(undefined);
    const result = await submitContact(data);
    if (result.error) {
      setServerError(result.error);
      return;
    }
    setSuccess(true);
    reset();
  }

  if (success) {
    return (
      <div role="status" className="p-6 rounded-lg bg-green-50 text-green-700 dark:bg-green-950 dark:text-green-300">
        <p className="font-medium">Message sent!</p>
        <button
          type="button"
          onClick={() => setSuccess(false)}
          className="mt-2 text-sm underline"
        >
          Send another
        </button>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate className="flex flex-col gap-4 w-full max-w-lg">
      {serverError && (
        <div role="alert" className="p-3 rounded-lg bg-red-50 text-red-700 text-sm dark:bg-red-950 dark:text-red-300">
          {serverError}
        </div>
      )}

      <FormField label="Name" error={errors.name?.message}>
        <input
          type="text"
          {...register("name")}
          aria-invalid={!!errors.name}
          aria-describedby={errors.name ? "name-error" : undefined}
          className="
            /* sizing */  h-10 w-full px-3
            /* visual */  rounded-lg ring-1 ring-border bg-background text-foreground
            /* state  */  focus:ring-2 focus:ring-primary focus:outline-none
            /* error  */  aria-[invalid=true]:ring-red-500
          "
        />
      </FormField>

      <FormField label="Email" error={errors.email?.message}>
        <input
          type="email"
          {...register("email")}
          autoComplete="email"
          aria-invalid={!!errors.email}
          aria-describedby={errors.email ? "email-error" : undefined}
          className="
            /* sizing */  h-10 w-full px-3
            /* visual */  rounded-lg ring-1 ring-border bg-background text-foreground
            /* state  */  focus:ring-2 focus:ring-primary focus:outline-none
            /* error  */  aria-[invalid=true]:ring-red-500
          "
        />
      </FormField>

      <FormField label="Category" error={errors.category?.message}>
        <select
          {...register("category")}
          aria-invalid={!!errors.category}
          className="
            /* sizing */  h-10 w-full px-3
            /* visual */  rounded-lg ring-1 ring-border bg-background text-foreground
            /* state  */  focus:ring-2 focus:ring-primary focus:outline-none
            /* error  */  aria-[invalid=true]:ring-red-500
          "
        >
          <option value="">Select a category</option>
          <option value="general">General</option>
          <option value="support">Support</option>
          <option value="feedback">Feedback</option>
        </select>
      </FormField>

      <FormField label="Message" error={errors.message?.message}>
        <textarea
          {...register("message")}
          rows={4}
          aria-invalid={!!errors.message}
          aria-describedby={errors.message ? "message-error" : undefined}
          className="
            /* sizing */  w-full px-3 py-2
            /* visual */  rounded-lg ring-1 ring-border bg-background text-foreground resize-y
            /* state  */  focus:ring-2 focus:ring-primary focus:outline-none
            /* error  */  aria-[invalid=true]:ring-red-500
          "
        />
      </FormField>

      <button
        type="submit"
        disabled={isSubmitting}
        className="
          /* sizing */  h-10
          /* visual */  rounded-lg bg-primary text-primary-foreground font-medium
          /* state  */  hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed
          /* motion */  transition-opacity
        "
      >
        {isSubmitting ? "Sending..." : "Send message"}
      </button>
    </form>
  );
}
```

## Step 4: Reusable FormField Component

```tsx
// src/components/ui/form-field.tsx
interface FormFieldProps {
  label: string;
  error?: string;
  children: React.ReactNode;
}

export function FormField({ label, error, children }: FormFieldProps) {
  const id = label.toLowerCase().replace(/\s+/g, "-");

  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={id} className="text-sm font-medium text-foreground">
        {label}
      </label>
      {children}
      {error && (
        <p id={`${id}-error`} role="alert" className="text-sm text-red-600 dark:text-red-400">
          {error}
        </p>
      )}
    </div>
  );
}
```

## Step 5: Server Action (revalidate with same schema)

```ts
// src/app/contact/actions.ts
"use server";

import { contactSchema, type ContactFormData } from "@/lib/schemas/contact";

export async function submitContact(data: ContactFormData) {
  // Server-side revalidation with same schema
  const parsed = contactSchema.safeParse(data);
  if (!parsed.success) {
    return { error: "Invalid form data. Please check your inputs." };
  }

  try {
    // Replace with your actual submission logic
    await saveContactMessage(parsed.data);
    return { success: true };
  } catch {
    return { error: "Failed to send message. Please try again." };
  }
}
```

## Step 6: Tests

```tsx
// src/components/features/contact/__tests__/contact-form.test.tsx
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { ContactForm } from "../contact-form";

vi.mock("@/app/contact/actions", () => ({
  submitContact: vi.fn(() => ({ success: true })),
}));

describe("ContactForm", () => {
  it("renders all fields with labels", () => {
    render(<ContactForm />);
    expect(screen.getByLabelText(/name/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/category/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/message/i)).toBeInTheDocument();
  });

  it("shows validation errors on empty submit", async () => {
    render(<ContactForm />);
    await userEvent.click(screen.getByRole("button", { name: /send/i }));

    await waitFor(() => {
      expect(screen.getByText(/name is required/i)).toBeInTheDocument();
      expect(screen.getByText(/email is required/i)).toBeInTheDocument();
    });
  });

  it("shows email format error", async () => {
    render(<ContactForm />);
    await userEvent.type(screen.getByLabelText(/email/i), "not-an-email");
    await userEvent.click(screen.getByRole("button", { name: /send/i }));

    await waitFor(() => {
      expect(screen.getByText(/valid email/i)).toBeInTheDocument();
    });
  });

  it("marks invalid fields with aria-invalid", async () => {
    render(<ContactForm />);
    await userEvent.click(screen.getByRole("button", { name: /send/i }));

    await waitFor(() => {
      expect(screen.getByLabelText(/name/i)).toHaveAttribute("aria-invalid", "true");
    });
  });

  it("shows success state after valid submission", async () => {
    render(<ContactForm />);
    await userEvent.type(screen.getByLabelText(/name/i), "John");
    await userEvent.type(screen.getByLabelText(/email/i), "john@example.com");
    await userEvent.selectOptions(screen.getByLabelText(/category/i), "general");
    await userEvent.type(screen.getByLabelText(/message/i), "This is a test message for the form.");
    await userEvent.click(screen.getByRole("button", { name: /send/i }));

    await waitFor(() => {
      expect(screen.getByText(/message sent/i)).toBeInTheDocument();
    });
  });

  it("disables submit button while submitting", async () => {
    render(<ContactForm />);
    // Fill valid data and submit — button should show "Sending..."
  });
});
```

## Step 7: Schema Tests

```ts
// src/lib/schemas/__tests__/contact.test.ts
import { contactSchema } from "../contact";

describe("contactSchema", () => {
  it("accepts valid data", () => {
    const result = contactSchema.safeParse({
      name: "John",
      email: "john@example.com",
      message: "Hello, this is a test.",
      category: "general",
    });
    expect(result.success).toBe(true);
  });

  it("rejects empty name", () => {
    const result = contactSchema.safeParse({
      name: "",
      email: "john@example.com",
      message: "Hello, this is a test.",
      category: "general",
    });
    expect(result.success).toBe(false);
  });

  it("rejects invalid email", () => {
    const result = contactSchema.safeParse({
      name: "John",
      email: "not-email",
      message: "Hello, this is a test.",
      category: "general",
    });
    expect(result.success).toBe(false);
  });

  it("rejects invalid category", () => {
    const result = contactSchema.safeParse({
      name: "John",
      email: "john@example.com",
      message: "Hello, this is a test.",
      category: "invalid",
    });
    expect(result.success).toBe(false);
  });

  it("rejects short message", () => {
    const result = contactSchema.safeParse({
      name: "John",
      email: "john@example.com",
      message: "Hi",
      category: "general",
    });
    expect(result.success).toBe(false);
  });
});
```

## Patterns

### Multi-step form

```tsx
// Use state machine for step tracking
const [step, setStep] = useState(1);
const totalSteps = 3;

// Validate only current step's fields before advancing
async function nextStep() {
  const valid = await trigger(fieldsForStep[step]);
  if (valid) setStep((s) => s + 1);
}
```

### Dynamic fields (array)

```tsx
import { useFieldArray } from "react-hook-form";

const { fields, append, remove } = useFieldArray({ control, name: "items" });

{fields.map((field, index) => (
  <div key={field.id}>
    <input {...register(`items.${index}.value`)} />
    <button type="button" onClick={() => remove(index)}>Remove</button>
  </div>
))}
<button type="button" onClick={() => append({ value: "" })}>Add item</button>
```

### Dependent fields

```tsx
const category = watch("category");

// Show subcategory only when category is selected
{category && (
  <FormField label="Subcategory" error={errors.subcategory?.message}>
    <select {...register("subcategory")}>
      {subcategories[category].map((sub) => (
        <option key={sub} value={sub}>{sub}</option>
      ))}
    </select>
  </FormField>
)}
```

## Checklist

- [ ] Zod schema in `src/lib/schemas/` — shared by client and server
- [ ] `react-hook-form` with `zodResolver`
- [ ] `noValidate` on `<form>` (use Zod, not browser validation)
- [ ] `aria-invalid` on fields with errors
- [ ] `aria-describedby` links field to error message `id`
- [ ] Error messages use `role="alert"`
- [ ] Submit button disabled during submission
- [ ] Server Action revalidates with same schema
- [ ] Success state shown after submission
- [ ] Schema has its own unit tests
