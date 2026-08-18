---
name: terraform-flat-to-modular
description: Refactor flat, unstructured Terraform configurations into typed, modular, well-structured HCL while preserving the deployed infrastructure. Works across an entire Terraform workspace, whether the configuration lives in one file or many, targeting common anti-patterns: hardcoded values, duplicated resource blocks, missing module boundaries, untyped variables, repeated inline tags, unpinned providers, and plaintext secrets. Produces module boundaries, typed variables, for_each de-duplication, provider default_tags, pinned providers, externalized secrets, and a moved block for every changed resource address so that terraform plan is a no-op.
---

# Terraform Flat-to-Modular Modernization

You are modernizing a flat, organically-grown Terraform configuration into a
clean, typed, modular structure **without changing the deployed infrastructure**.

Your work is correct only when, after refactoring, `terraform plan` reports
**"No changes"** against the existing state. The point of this transformation is
structural and qualitative improvement of the *code*, never a change to the
running *infrastructure*.

## Guiding principle: reason, don't follow a script

This definition gives you **principles and invariants**, not a rigid per-file
recipe. Inspect the actual configuration, design a sensible module structure for
*this* codebase, and apply the patterns where they fit. Use the reference files
for detailed patterns and a worked example. Adapt to what you find; do not force a
layout that does not match the resources present.

## Non-negotiable invariants

1. **Behavior preservation.** Do not add, remove, or change any real
   infrastructure. The only acceptable `terraform plan` result is "No changes."
2. **A `moved` block for every changed address.** Whenever you move a resource
   into a module or rename its address (including switching to `for_each`/`count`
   keys), emit a corresponding `moved` block so Terraform updates state instead of
   destroying and recreating. See `references/moved-blocks.md`.
3. **No secrets in source.** Never leave plaintext credentials in `.tf` files.
   Externalize them (input variable marked `sensitive`, or a data source for an
   existing secret). Do not change the secret's value.
4. **No functional drift in tags, names, or settings.** Preserve every resource's
   existing tags, names, and arguments. When introducing `default_tags`, ensure the
   effective set of tags on each resource is unchanged (a no-op plan will catch you).
5. **Validate continuously.** Run the build/validation command after each
   meaningful change, not only at the end. Fix failures before proceeding.

## Recommended procedure (order matters)

1. **Inventory.** Read every `.tf` file. List all resource addresses, the provider
   configuration, variables, outputs, and the backend. Note duplicated blocks,
   hardcoded literals, and any secrets.
2. **Snapshot the baseline.** Run the build/validation command once to confirm the
   starting `terraform plan` is already a no-op. If it is not, stop and report —
   the codebase has pre-existing drift that must be resolved first.
3. **Design module boundaries** for *this* codebase. A common, sensible default is
   one module per tier/concern (e.g. networking, load balancing, compute, data),
   but choose boundaries that match the resources actually present. See
   `references/module-structure.md`.
4. **Extract modules incrementally.** Move one logical group at a time. For each
   moved resource, add a `moved` block mapping old address → new address. Run the
   validation command after each module extraction and confirm the plan stays a
   no-op before moving on.
5. **De-duplicate with `for_each`.** Collapse copy-pasted blocks (subnets, route
   table associations, repeated rules) into `for_each` over a map. Prefer
   `for_each` over `count` so addresses are stable, keyed strings — this keeps the
   `moved` mapping deterministic. See `references/refactoring-patterns.md`.
6. **Introduce typed variables.** Replace hardcoded literals with `variable` blocks
   that have explicit `type`, sensible `default`s preserving current values, and
   `description`s. Mark secrets `sensitive`. Do not change any value.
7. **Apply provider hygiene.** Add a pinned `required_providers` block with a
   version constraint matching the currently resolved provider major version, and
   move repeated tags to `default_tags` on the provider — verifying the effective
   tag set per resource is unchanged.
8. **Externalize secrets** per invariant 3.
9. **Final validation.** Run the full build/validation command. The transformation
   is complete only when `terraform plan` reports "No changes."

## Handling validation failures

- **Plan shows destroy/create of a renamed resource** → a `moved` block is missing
  or its `from`/`to` addresses are wrong. Add or correct it.
- **Plan shows tag changes** → `default_tags` changed the effective tag set; adjust
  so per-resource tags match the original exactly.
- **Plan shows attribute changes** → you altered an argument value during
  refactoring; restore the original value.
- **`terraform validate` errors** → fix references; module input/output wiring is
  the usual cause after extraction.
- If you cannot reach a no-op plan for a specific resource, do **not** force it.
  Leave that resource as-is, document why in your summary, and keep the overall
  plan a no-op.

## What good output looks like

- A small root module that wires together purpose-built child modules.
- `variables.tf` with typed, described inputs; no hardcoded literals scattered in
  resource blocks.
- Duplicated blocks collapsed into `for_each` with stable keys.
- Provider pinned; `default_tags` applied; secrets externalized.
- A `moved.tf` (or per-module `moved` blocks) covering every changed address.
- `terraform validate` passes and `terraform plan` is a no-op.

## Scope and extensibility

This definition covers structural and hygiene modernization. It is **not** an
exhaustive Terraform best-practices audit, and "good Terraform" varies by
organization. Treat the patterns here as a baseline. Additional organization-specific
rules (naming conventions, tagging taxonomy, backend strategy, security baselines)
can be added to this definition's references or enforced via a client-side
validation skill. Respect any such additional context provided at execution time.
