# ECS setup with cloudmap for integration with API gateway V2

# Cloudmap namespace (private DNS)
resource "aws_service_discovery_private_dns_namespace" "cloudmap_namespace" {
  name = "${var.ecs_service_name}-cloudmap-namespace"
  vpc  = var.vpc_id
}

# Cloudmap service for ECS
resource "aws_service_discovery_service" "cloudmap_service" {
  name         = "${var.ecs_service_name}-cloudmap-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.cloudmap_namespace.id
    dns_records {
      type = "SRV"
      ttl  = 60
    }
    routing_policy = "MULTIVALUE" 
  }

  health_check_custom_config {
    failure_threshold = 2
  }
}

# IAM role for ECS task
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.ecs_service_name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Define policy to access secrets manager and attach it
data "aws_secretsmanager_secret" "db_user_secret" {
  name = var.db_user_secret_name
}

resource "aws_iam_policy" "ecs_secrets_policy" {
  name        = "${var.ecs_service_name}-ecs-secrets-policy"
  description = "Policy to access Secrets Manager"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "secretsmanager:GetSecretValue",
        Effect = "Allow",
        Resource = data.aws_secretsmanager_secret.db_user_secret.arn
      }
    ]
  })
}

# Attach IAM policy to access secrets manager
resource "aws_iam_role_policy_attachment" "task_role_secrets_manager_access" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_secrets_policy.arn
}

# Attach RDS db connection policy to the task role
resource "aws_iam_role_policy_attachment" "task_role_db_access" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = var.db_connect_iam_policy_arn
}

# Define IAM role policy for ECS tasks
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.ecs_service_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Add an IAM policy to access CloudWatch logs
resource "aws_iam_role_policy_attachment" "ecs_cloudwatch_logs_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# Create a CloudWatch log group
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/${var.ecs_service_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.ecs_service_name}-log-group"
  }
}

/*
# Retrieving database password
data "aws_secretsmanager_secret" "db_user_secret" {
  name = var.db_user_secret_name
}

data "aws_secretsmanager_secret_version" "db_user_secret_version" {
  secret_id = data.aws_secretsmanager_secret.db_user_secret.id
}
*/

# Create an ECS cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.ecs_service_name}-cluster"
}

# Create an ECS task (exposes the API on port 80)
resource "aws_ecs_task_definition" "ecs_task" {
  family                = "${var.ecs_service_name}-task"
  network_mode          = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu       = 256
  memory    = 512
  execution_role_arn    = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn         = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "counter-api-container"
    image     = "${var.image_name}:${var.image_tag}"
    cpu       = 256
    memory    = 512
    essential = true
    healthCheck = {
      command     = ["CMD-SHELL", "curl --fail http://127.0.0.1/healthcheck || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 2
      startPeriod = 10
    }
    portMappings = [{
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/${var.ecs_service_name}"
        awslogs-region        = var.region
        awslogs-stream-prefix = "ecs"
      }
    }
    environment = [
      {
        name  = "FLASK_ENV"
        value = "production"
      },
      {
        name  = "FLASK_PORT"
        value = "80"
      },
      {
        name  = "DEBUG_MODE"
        value = var.debug_mode
      },
      {
        name  = "DB_USER"
        value = var.db_username
        # value = "iam_user"
      },
      {
        name  = "DB_HOST"
        value = var.db_host
      },
      {
        name  = "DB_PORT"
        value = tostring(var.db_port)
      },
      {
        name  = "DB_NAME"
        value = var.db_name
      },
      {
        name  = "SSL_MODE"
        value = var.ssl_mode
      },
      {
        name  = "SSL_ROOT_CERT"
        value = var.ssl_root_cert
      },
      {
        name  = "DB_USER_SECRET"
        value = var.db_user_secret_name
      },
      {
        name  = "IAM_AUTH"
        value = var.iam_auth
      }/*,
      {
        name  = "DB_PASSWORD"
        value = data.aws_secretsmanager_secret_version.db_user_secret_version.secret_string
      }*/
    ]
  }])
}

# ECS service with Cloudmap registration
resource "aws_ecs_service" "ecs_service" {
  name            = var.ecs_service_name
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = [var.public_subnet_id]
    security_groups = [var.security_group_id]
    # assign_public_ip = true # Required to download images from Docker Hub
  }

  service_registries {
    registry_arn = aws_service_discovery_service.cloudmap_service.arn
    port         = 80 # only required for SRV record
  }
}
