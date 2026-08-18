# Zero-drift Terraform modernization with AWS Transform custom

> ⚠️ **NOT FOR PRODUCTION USE.** All code samples in this repository are for educational and demonstration purposes only. Do not deploy them in production environments without thorough security review and hardening.

## Anti-pattern warnings

The `before/` directory contains **deliberate anti-patterns** — insecure or unmaintainable code that the accompanying walkthrough transforms into better code. These files are clearly marked with `# DELIBERATE ANTI-PATTERN (do not copy)` comments. Do not copy code from `before/` into any environment.

---

<!-- TODO before publishing: replace <BLOG_POST_URL> (2 occurrences) with the published blog post URL. -->
Companion sample for the AWS blog post
[Zero-drift Terraform modernization with AWS Transform custom](<BLOG_POST_URL>). It shows how to author and run an [AWS Transform custom](https://docs.aws.amazon.com/transform/latest/userguide/custom.html)
transformation definition that refactors a flat, single-file Terraform
configuration into typed, modular HCL — **without changing any deployed
infrastructure**. Correctness is proven mechanically: after the refactor,
`terraform plan` reports `No changes`.

The example stack is a three-tier web application: an Application Load Balancer
(ALB) routing to Amazon ECS on AWS Fargate, backed by Amazon RDS, across two
Availability Zones.

```
Internet
   │
   ▼
[ ALB ]  public subnets (2 AZs)
   │
   ▼
[ ECS / Fargate ]  private subnets (2 AZs)
   │
   ▼
[ Amazon RDS ]  private subnets (2 AZs)
```

See `docs/3-tier-vpc-webapp.png` for the full architecture diagram.

## What's in this repo

| Path | Description |
|------|-------------|
| `before/` | The legacy starting point: one flat `main.tf` (~500 lines, 28 resources) plus a `provider.tf`. Hardcoded values, copy-pasted per-AZ blocks, no variables, no modules, an unpinned provider, and a plaintext DB password — the anti-patterns the transformation fixes. |
| `after/` | The result produced by the transformation: a thin root module (`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`), four per-tier child modules under `modules/` (`network`, `alb`, `compute`, `data`), and `moved.tf` with one `moved` block per relocated resource so the plan stays a no-op. |
| `terraform-flat-to-modular/` | The **AWS Transform custom definition**: a `SKILL.md` describing the transformation in plain language, plus a `references/` folder with worked patterns (`module-structure.md`, `moved-blocks.md`, `refactoring-patterns.md`). |
| `atx-exec-config.yaml` | Execution config for the run: the `buildCommand` (the `terraform plan` validation gate) and `additionalPlanContext` (org-level modernization intent). |
| `docs/` | The architecture diagram. |

> The `before/` Terraform **deliberately contains anti-patterns** (a plaintext
> password, broad egress, an unpinned provider). They are the problems the
> transformation addresses, not recommendations. Do not copy `before/` into
> production.

## How it works

1. **Deploy the legacy stack** so there is real state and live infrastructure to
   protect, and confirm a clean baseline (`terraform plan` = `No changes`).
2. **Run the transformation** with AWS Transform custom, pointing it at the
   deployed configuration and using `atx-exec-config.yaml`. The agent reads the
   definition in `terraform-flat-to-modular/`, refactors the code, and runs the
   `buildCommand` repeatedly as its acceptance gate.
3. **Validate** that the refactor changed only the code: `terraform plan` still
   reports `No changes` (0 to add, 0 to change, 0 to destroy). That no-op plan is
   the machine-checkable proof that the deployed infrastructure was preserved.

The key idea: `terraform plan` reconciles your HCL against the state file and the
live resources. A `moved` block tells Terraform "same resource, new address," so
renaming resources into modules produces no destroy/recreate. When every changed
address has a correct `moved` block, the plan is a no-op.

## Prerequisites

- An AWS account and credentials (use a sandbox — the stack creates billable
  resources, including a NAT gateway, an ALB, an RDS instance, and Fargate tasks).
- [Terraform](https://developer.hashicorp.com/terraform/install) installed.
- The AWS Transform (`atx`) CLI configured, run in a supported AWS Region.

## Quick start

The flow has four steps: deploy the legacy stack, run the transformation against
it, validate the no-op plan, then clean up. Run everything from the repo root
unless a step says otherwise.

### 1. Deploy legacy infrastructure

Stand up the flat stack in `before/` so there is real state and live
infrastructure for the transformation to preserve. This creates billable
resources.

```bash
cd before
terraform init
terraform apply
terraform plan          # baseline must report: No changes
cd ..
```

The final `terraform plan` should report `No changes` — a clean baseline. The
transformation's job is to keep it that way.

### 2. Execute the Transform to modernize the Terraform

Register the definition in `terraform-flat-to-modular/` as a draft, then run it
against the deployed configuration in `before/`. The build command (the
`terraform plan` gate) is passed with `-c`, and `--configuration` supplies the
organization-level `additionalPlanContext`. Both are also stored in
`atx-exec-config.yaml` for reference.

```bash
# Register the definition (folder: terraform-flat-to-modular/) as a draft
atx custom def save-draft -n terraform-flat-to-modular \
  --sd terraform-flat-to-modular \
  --description "Flat-to-modular Terraform refactor"
# -> prints a version id, e.g. 'terraform-flat-to-modular' version '<TV_ID>'

# Run the draft against the deployed config, with terraform plan as the gate
atx custom def exec -n terraform-flat-to-modular \
  --tv <TV_ID> \
  -p before \
  -c "terraform init && terraform validate && terraform plan" \
  --configuration file://atx-exec-config.yaml
```

Replace `<TV_ID>` with the version id that `save-draft` prints. (A published
definition runs by name with no `--tv`.) The `-c` build command is the agent's
acceptance gate: it runs after every change and the transformation is done only
when `terraform plan` reports `No changes`. The agent reads the definition, refactors
the code in place, and re-runs the build command until `terraform plan` is a
no-op. The `after/` directory in this repo is an example of the output you can
expect: a thin root module plus the `network`, `alb`, `compute`, and `data`
child modules under `modules/`, with `moved.tf` mapping every relocated resource.

### 3. Validate the transformation

Confirm the refactor changed only the code, not the deployed infrastructure. From
the modernized configuration, a correct result is a no-op plan.

The modernized config keeps the database password out of source: `db_password`
is a `sensitive` variable with no default, so supply it at runtime. For a no-op
plan the value must match the one already in state.

```bash
cd after          # or the in-place config the transform just rewrote
export TF_VAR_db_password='<same value used when you deployed before/>'
terraform init
terraform plan    # expected: No changes. 0 to add, 0 to change, 0 to destroy.
cd ..
```

That no-op plan is the acceptance test: same infrastructure, better code.

### 4. Clean up

The demo deploys billable resources. When you are done, destroy them from the
configuration that owns the state:

```bash
terraform destroy
```

The refactored code manages the same resources as the original, so destroying
from either `before/` or `after/` removes the stack once, not twice.

The full, step-by-step walkthrough — authoring the definition, running it, and
reading the results — is in the blog post:
[Zero-drift Terraform modernization with AWS Transform custom](<BLOG_POST_URL>).

## Note on state files

Terraform state (`*.tfstate`) is intentionally excluded via `.gitignore`. State
files for this demo contain a real account ID and the plaintext database
password, so they must not be committed. Generate fresh state by running
`terraform apply` yourself.

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

This is sample code, for non-production usage. You should work with your security
and legal teams to meet your organizational security, regulatory and compliance
requirements before deployment.

The demo stack is deliberately demo-grade so the walkthrough stays focused on the
refactoring technique. Before adapting it for anything beyond the walkthrough,
harden at minimum: enforce TLS to the database ([`rds.force_ssl`](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/PostgreSQL.Concepts.General.SSL.html)),
enable RDS storage encryption, serve the ALB over HTTPS with an ACM certificate
(requires a domain), rotate the demo database credential into AWS Secrets Manager,
and review IAM permissions down to least privilege.

## License

This sample is licensed under the MIT-0 License. See the [LICENSE](LICENSE) file.
