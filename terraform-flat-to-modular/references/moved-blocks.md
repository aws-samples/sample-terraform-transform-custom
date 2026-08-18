# Preserving State with `moved` Blocks

This is the most important reference in this definition. Getting `moved` blocks
right is the difference between a safe refactor and destroying live infrastructure.

## Why moved blocks are required

Terraform tracks every resource by its **address** (e.g. `aws_subnet.private_a`).
The state file records resources under their current addresses. When you refactor
— moving a resource into a module, or collapsing copy-pasted blocks into
`for_each` — the address changes. To Terraform, the old address has disappeared and
a new one has appeared, so it plans to **destroy** the old resource and **create** a
new one. On deployed infrastructure that is destructive and usually unacceptable.

A `moved` block records that two addresses refer to the **same** real resource.
Terraform then updates the address in state instead of destroying/recreating.

## Syntax

```hcl
moved {
  from = aws_subnet.private_a
  to   = module.network.aws_subnet.private["a"]
}
```

`from` is the **old** address (as it exists in current state). `to` is the **new**
address after refactoring. Both must be exact.

## The three common refactors and their moved blocks

### 1. Moving a resource into a module

```hcl
# old: aws_vpc.main           ->  new: module.network.aws_vpc.main
moved {
  from = aws_vpc.main
  to   = module.network.aws_vpc.main
}
```

### 2. Collapsing duplicated blocks into `for_each`

Old (two separate resources):

```hcl
resource "aws_subnet" "private_a" { availability_zone = "us-east-1a" ... }
resource "aws_subnet" "private_b" { availability_zone = "us-east-1b" ... }
```

New (one `for_each` resource inside a module):

```hcl
resource "aws_subnet" "private" {
  for_each          = var.private_subnets   # map keyed by "a", "b"
  availability_zone = each.value.az
  ...
}
```

Moved blocks (one per original resource, mapping to the new keyed address):

```hcl
moved {
  from = aws_subnet.private_a
  to   = module.network.aws_subnet.private["a"]
}
moved {
  from = aws_subnet.private_b
  to   = module.network.aws_subnet.private["b"]
}
```

The `for_each` **key** (`"a"`, `"b"`) becomes part of the address. Choose keys that
are stable and meaningful, and make sure each `moved` block's `to` uses the exact
key the resource will have.

### 3. Renaming within the same scope

```hcl
moved {
  from = aws_db_instance.main
  to   = aws_db_instance.postgres
}
```

## Prefer `for_each` over `count`

`count` produces **index-based** addresses (`aws_subnet.private[0]`,
`aws_subnet.private[1]`). Indexes shift if the list order changes, which makes
`moved` mappings fragile and risks accidental destroy/create later. `for_each` over
a map produces **stable, keyed** addresses (`aws_subnet.private["a"]`) that do not
shift. Always prefer `for_each` for collections you are de-duplicating.

## Verification workflow

1. After each module extraction or `for_each` conversion, run
   `terraform plan`.
2. If the plan shows any `# ... will be destroyed` followed by
   `# ... will be created` for what is really the same resource, a `moved` block is
   missing or wrong. Add or fix it.
3. Iterate until the plan shows **No changes**.
4. You can confirm an address moved correctly with
   `terraform state list` (the resource should appear under its new address after a
   plan/apply that processes the move).

## Common mistakes

- Forgetting a `moved` block for a resource that was moved into a module → destroy/create.
- Wrong `for_each` key in the `to` address → Terraform sees a different instance.
- Mapping `from` to an address that does not match the current state exactly
  (e.g. a typo in the original resource name).
- Using `count` and then guessing indexes — use `for_each` with explicit keys instead.
