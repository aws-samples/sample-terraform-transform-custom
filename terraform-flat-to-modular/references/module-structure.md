# Module Structure Guidance

This file describes how to organize a refactored Terraform configuration. It is a
**template and set of principles**, not a mandatory layout. Choose boundaries that
fit the resources actually present in the codebase you are transforming.

## Principles for choosing module boundaries

- **One module per cohesive concern.** Group resources that are created, changed,
  and destroyed together and that share a clear responsibility (networking, load
  balancing, compute, data, observability, identity).
- **Modules expose intent, not implementation.** A module's `variables.tf` should
  read like the decisions a caller makes (CIDR, AZ count, instance size), not a
  passthrough of every resource argument.
- **Pass data between modules via outputs**, not by reaching into another module's
  internals. The root module wires outputs of one module into inputs of the next.
- **Keep the root module thin.** It should mostly declare the provider, shared
  inputs, module calls, and outputs.

## A common layout for a three-tier web application

This is a sensible default when the codebase contains a VPC, a load balancer, a
compute tier, and a database. Adapt names and split/merge modules as the actual
resources dictate.

```
.
├── main.tf            # provider + module calls + wiring
├── variables.tf       # root-level inputs (region, project, environment, ...)
├── outputs.tf         # root outputs (e.g. alb_dns_name, db_endpoint)
├── versions.tf        # terraform + required_providers (pinned)
├── moved.tf           # moved blocks for every changed address (or per-module)
└── modules/
    ├── network/       # VPC, subnets, IGW, NAT, route tables, associations
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf  # vpc_id, public_subnet_ids, private_subnet_ids, ...
    ├── alb/           # load balancer, target group, listener, ALB SG
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf  # alb_dns_name, target_group_arn, alb_sg_id
    ├── compute/       # ECS cluster, task def, service, app SG, exec role, logs
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── data/          # RDS instance, subnet group, DB SG
        ├── main.tf
        ├── variables.tf
        └── outputs.tf  # db_endpoint
```

## Wiring example (root main.tf)

```hcl
module "network" {
  source              = "./modules/network"
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "alb" {
  source            = "./modules/alb"
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
}

module "compute" {
  source             = "./modules/compute"
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  target_group_arn   = module.alb.target_group_arn
  alb_sg_id          = module.alb.alb_sg_id
}

module "data" {
  source             = "./modules/data"
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  app_sg_id          = module.compute.app_sg_id
}
```

## Critical: addresses change when you modularize

Moving `aws_vpc.main` into a `network` module changes its address to
`module.network.aws_vpc.main`. Every such change needs a `moved` block — see
`moved-blocks.md`. This is the single most important detail for preserving state.
