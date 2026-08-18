# Networking
moved {
  from = aws_vpc.main
  to   = module.network.aws_vpc.main
}

moved {
  from = aws_internet_gateway.igw
  to   = module.network.aws_internet_gateway.igw
}

moved {
  from = aws_subnet.public_a
  to   = module.network.aws_subnet.public["a"]
}

moved {
  from = aws_subnet.public_b
  to   = module.network.aws_subnet.public["b"]
}

moved {
  from = aws_subnet.private_a
  to   = module.network.aws_subnet.private["a"]
}

moved {
  from = aws_subnet.private_b
  to   = module.network.aws_subnet.private["b"]
}

moved {
  from = aws_eip.nat
  to   = module.network.aws_eip.nat
}

moved {
  from = aws_nat_gateway.nat
  to   = module.network.aws_nat_gateway.nat
}

moved {
  from = aws_route_table.public
  to   = module.network.aws_route_table.public
}

moved {
  from = aws_route_table.private
  to   = module.network.aws_route_table.private
}

moved {
  from = aws_route_table_association.public_a
  to   = module.network.aws_route_table_association.public["a"]
}

moved {
  from = aws_route_table_association.public_b
  to   = module.network.aws_route_table_association.public["b"]
}

moved {
  from = aws_route_table_association.private_a
  to   = module.network.aws_route_table_association.private["a"]
}

moved {
  from = aws_route_table_association.private_b
  to   = module.network.aws_route_table_association.private["b"]
}

# ALB
moved {
  from = aws_security_group.alb
  to   = module.alb.aws_security_group.alb
}

moved {
  from = aws_lb.web
  to   = module.alb.aws_lb.web
}

moved {
  from = aws_lb_target_group.web
  to   = module.alb.aws_lb_target_group.web
}

moved {
  from = aws_lb_listener.web
  to   = module.alb.aws_lb_listener.web
}

# Compute
moved {
  from = aws_security_group.app
  to   = module.compute.aws_security_group.app
}

moved {
  from = aws_iam_role.ecs_execution
  to   = module.compute.aws_iam_role.ecs_execution
}

moved {
  from = aws_iam_role_policy_attachment.ecs_execution
  to   = module.compute.aws_iam_role_policy_attachment.ecs_execution
}

moved {
  from = aws_cloudwatch_log_group.app
  to   = module.compute.aws_cloudwatch_log_group.app
}

moved {
  from = aws_ecs_cluster.main
  to   = module.compute.aws_ecs_cluster.main
}

moved {
  from = aws_ecs_task_definition.app
  to   = module.compute.aws_ecs_task_definition.app
}

moved {
  from = aws_ecs_service.app
  to   = module.compute.aws_ecs_service.app
}

# Data
moved {
  from = aws_security_group.db
  to   = module.data.aws_security_group.db
}

moved {
  from = aws_db_subnet_group.main
  to   = module.data.aws_db_subnet_group.main
}

moved {
  from = aws_db_instance.main
  to   = module.data.aws_db_instance.main
}
