###############################################################################
# THREE-TIER DEMO APPLICATION - "BEFORE" STATE
#
# This is a DELIBERATELY messy, flat Terraform configuration that stands up a
# working three-tier application (ALB -> ECS Fargate -> RDS PostgreSQL) on AWS.
#
# It is intentionally written the way a sprawling, organically-grown estate
# often looks:
#   - everything in one flat file, no modules
#   - hardcoded region, AZs, CIDRs, names, ports, sizes everywhere
#   - no input variables, nothing is typed or parameterized
#   - copy-pasted resource blocks (one per subnet / AZ / association)
#   - tags repeated inline on every resource, and inconsistent between them
#   - no provider default_tags
#   - provider not version-pinned (see provider.tf)
#   - a plaintext database password committed in source
#
# Everything below DOES apply and produce a reachable application. The point of
# the demo is to refactor this into typed, modular HCL with AWS Transform custom
# WITHOUT changing the running infrastructure (proved by a no-op terraform plan).
###############################################################################

# -----------------------------------------------------------------------------
# Networking - VPC
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "three-tier-demo-vpc"
    Environment = "dev"
    Project     = "three-tier-demo"
    ManagedBy   = "terraform"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "three-tier-demo-igw"
    Environment = "dev"
    Project     = "three-tier-demo"
    ManagedBy   = "terraform"
  }
}

# -----------------------------------------------------------------------------
# Networking - Subnets (hand-written one block per subnet, per AZ)
# -----------------------------------------------------------------------------
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "three-tier-demo-public-a"
    Environment = "dev"
    Project     = "three-tier-demo"
    ManagedBy   = "terraform"
    Tier        = "public"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name        = "three-tier-demo-public-b"
    Environment = "dev"
    Project     = "three-tier-demo"
    ManagedBy   = "terraform"
    Tier        = "public"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name        = "three-tier-demo-private-a"
    Environment = "dev"
    Project     = "three-tier-demo"
    ManagedBy   = "terraform"
    Tier        = "private"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name        = "three-tier-demo-private-b"
    Environment = "dev"
    Project     = "three-tier-demo"
    ManagedBy   = "terraform"
    Tier        = "private"
  }
}

# -----------------------------------------------------------------------------
# Networking - NAT (single NAT gateway in public subnet A)
# -----------------------------------------------------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "three-tier-demo-nat-eip"
    Environment = "dev"
    Project     = "three-tier-demo"
    ManagedBy   = "terraform"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name        = "three-tier-demo-nat"
    Environment = "dev"
    Project     = "three-tier-demo"
    ManagedBy   = "terraform"
  }

  depends_on = [aws_internet_gateway.igw]
}

# -----------------------------------------------------------------------------
# Networking - Route tables and associations (copy-pasted per subnet)
# -----------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "three-tier-demo-public-rt"
    Environment = "dev"
    Project     = "three-tier-demo"
    ManagedBy   = "terraform"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name        = "three-tier-demo-private-rt"
    Environment = "dev"
    Project     = "three-tier-demo"
    ManagedBy   = "terraform"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# -----------------------------------------------------------------------------
# Security groups (rules are inline and duplicated across tiers)
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "three-tier-demo-alb-sg"
  description = "Allow HTTP inbound to the ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "three-tier-demo-alb-sg"
    Environment = "dev"
    Project     = "three-tier-demo"
    ManagedBy   = "terraform"
  }
}

resource "aws_security_group" "app" {
  name        = "three-tier-demo-app-sg"
  description = "Allow HTTP from the ALB to the app tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "three-tier-demo-app-sg"
    Environment = "dev"
    Project     = "three-tier-demo"
    ManagedBy   = "terraform"
  }
}

resource "aws_security_group" "db" {
  name        = "three-tier-demo-db-sg"
  description = "Allow PostgreSQL from the app tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from app tier"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "three-tier-demo-db-sg"
    Environment = "dev"
    Project     = "three-tier-demo"
    ManagedBy   = "terraform"
  }
}

# -----------------------------------------------------------------------------
# Web tier - Application Load Balancer
# -----------------------------------------------------------------------------
resource "aws_lb" "web" {
  name               = "three-tier-demo-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = {
    Name        = "three-tier-demo-alb"
    Environment = "dev"
    Project     = "three-tier-demo"
    ManagedBy   = "terraform"
  }
}

resource "aws_lb_target_group" "web" {
  name        = "three-tier-demo-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "three-tier-demo-tg"
    Environment = "dev"
    Project     = "three-tier-demo"
    ManagedBy   = "terraform"
  }
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  tags = {
    Name        = "three-tier-demo-listener"
    Environment = "dev"
    Project     = "three-tier-demo"
    ManagedBy   = "terraform"
  }
}

# -----------------------------------------------------------------------------
# App tier - ECS Fargate
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ecs_execution" {
  name = "three-tier-demo-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "three-tier-demo-ecs-execution"
    Environment = "dev"
    Project     = "three-tier-demo"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/three-tier-demo"
  retention_in_days = 7

  tags = {
    Name        = "three-tier-demo-logs"
    Environment = "dev"
    Project     = "three-tier-demo"
    ManagedBy   = "terraform"
  }
}

resource "aws_ecs_cluster" "main" {
  name = "three-tier-demo-cluster"

  tags = {
    Name        = "three-tier-demo-cluster"
    Environment = "dev"
    Project     = "three-tier-demo"
    ManagedBy   = "terraform"
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "three-tier-demo-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([
    {
      name      = "nginx"
      image     = "public.ecr.aws/nginx/nginx:1.27"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/three-tier-demo"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "nginx"
        }
      }
    }
  ])

  tags = {
    Name        = "three-tier-demo-app"
    Environment = "dev"
    Project     = "three-tier-demo"
    ManagedBy   = "terraform"
  }
}

resource "aws_ecs_service" "app" {
  name            = "three-tier-demo-app"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.web.arn
    container_name   = "nginx"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.web]

  tags = {
    Name        = "three-tier-demo-app"
    Environment = "dev"
    Project     = "three-tier-demo"
    ManagedBy   = "terraform"
  }
}

# -----------------------------------------------------------------------------
# Data tier - RDS PostgreSQL (plaintext password committed in source)
# -----------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name       = "three-tier-demo-db-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = {
    Name        = "three-tier-demo-db-subnet-group"
    Environment = "dev"
    Project     = "three-tier-demo"
    ManagedBy   = "terraform"
  }
}

resource "aws_db_instance" "main" {
  identifier             = "three-tier-demo-db"
  engine                 = "postgres"
  engine_version         = "16.4"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = "appdb"
  username               = "appadmin"
  # DELIBERATE ANTI-PATTERN (do not copy): a plaintext credential committed in
  # source, kept here as the teaching example this sample exists to fix. The
  # transformation externalizes it into a sensitive variable (see after/).
  password               = "REDACTED-PLAINTEXT-PASSWORD"
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  multi_az               = false
  publicly_accessible    = false
  skip_final_snapshot    = true
  apply_immediately      = true

  tags = {
    Name        = "three-tier-demo-db"
    Environment = "dev"
    Project     = "three-tier-demo"
    ManagedBy   = "terraform"
  }
}

# -----------------------------------------------------------------------------
# Outputs (minimal, hardcoded-ish)
# -----------------------------------------------------------------------------
output "alb_dns_name" {
  value = aws_lb.web.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.main.endpoint
}
