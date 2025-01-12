# Define Cloud Map service to allow the API gateway to find the ECS service
resource "aws_service_discovery_private_dns_namespace" "private_namespace" {
  name = "${var.ecs_service_name}-private"
  vpc  = var.vpc_id
}

resource "aws_service_discovery_service" "cloud_map_service" {
  name = "${var.ecs_service_name}-cloud-map-service"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.private_namespace.id
    dns_records {
      type = "A"
      ttl  = 60
    }
  }
  health_check_custom_config {
    failure_threshold = 1
  }
}

# Create an ECS cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.ecs_service_name}-cluster"
}

# Create an ECS task (exposes the API on port 80)
resource "aws_ecs_task_definition" "ecs_task" {
  family                = "${var.ecs_service_name}-task"
  network_mode          = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  container_definitions = jsonencode([{
    name      = "counter-api-container"
    image     = "${var.image_name}:${var.image_tag}"
    cpu       = 256
    memory    = 512
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    }]
    environment = [
      {
        name  = "FLASK_ENV"
        value = "production"
      },
      {
        name  = "DB_USER"
        value = var.db_username
      },
      {
        name  = "DB_HOST"
        value = var.db_host
      },
      {
        name  = "DB_PORT"
        value = var.db_port
      },
      {
        name  = "DB_NAME"
        value = var.db_name
      },
      {
        name  = "DB_USER_SECRET"
        value = var.db_user_secret_name
      }
    ]
  }])
}

# Define an ECS service which targets the cluster and the ECS task
resource "aws_ecs_service" "ecs_service" {
  name            = var.ecs_service_name
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [var.public_subnet_id]
    security_groups = [var.security_group_id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.cloud_map_service.arn
    port         = 80
  }
}

# Create a VPC Link for API Gateway
resource "aws_api_gateway_vpc_link" "vpc_link" {
  name         = "${var.ecs_service_name}-vpc-link"
  target_arns  = [aws_service_discovery_service.cloud_map_service.arn]
  description  = "VPC Link to ECS service"
}
