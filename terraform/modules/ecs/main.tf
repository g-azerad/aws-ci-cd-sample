resource "aws_ecs_task_definition" "ecs_api_task" {
  family                   = "ecs_api_task" 
  container_definitions    = <<DEFINITION
  [
    {
      "name": "database",
      "image": "postgres:${var.image_tag}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 5432,
          "hostPort": 5432
        }
      ],
      "environment": [
        {"name": "DEBUG", "value": "0"}
      ],
      "memory": 2048,
      "cpu": 512,
      "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-group": "ecs-web-api",
                "awslogs-region": "${var.aws_region}",
                "awslogs-stream-prefix": "web-api"
        }
      }
    },
    {
      "name": "nginx",
      "image": "${var.ecr_repo_proxy}:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8000,
          "hostPort": 8000
        }
      ],
      "environment": [
        {"name": "APP_HOST", "value": "127.0.0.1"},
        {"name": "APP_PORT", "value": "8081"},
        {"name": "LISTEN_PORT", "value": "8000"}
      ],
      "memory": 1024,
      "cpu": 512,
      "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-group": "ecs-web-api",
                "awslogs-region": "${var.aws_region}",
                "awslogs-stream-prefix": "dev-web-nginx"
        }
      }
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] # Stating that we are using ECS Fargate
  network_mode             = "awsvpc"    # Using awsvpc as our network mode as this is required for Fargate
  memory                   = 2048         # Specifying the memory our container requires
  cpu                      = 1024         # Specifying the CPU our container requires
  execution_role_arn       = "${aws_iam_role.ecsTaskExecutionRole.arn}"
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRoleWebAPI"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = "${aws_iam_role.ecsTaskExecutionRole.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_service" "ecs_api_service" {
  name            = "ecs-web-api-service"                             # Naming our first service
  cluster         = "${var.cluster_name}"               # Referencing our created Cluster
  task_definition = "${aws_ecs_task_definition.ecs_api_task.arn}" # Referencing the task our service will spin up
  launch_type     = "FARGATE"
  desired_count   = 1 # Setting the number of containers to 3

  load_balancer {
    target_group_arn = "${aws_lb_target_group.target_group.arn}" # Referencing our target group
    container_name   = "api"
    container_port   = 8000 # Specifying the container port
  }

  network_configuration {
    subnets          = ["${aws_default_subnet.default_subnet_b.id}", "${aws_default_subnet.default_subnet_c.id}"]
    assign_public_ip = true                                                # Providing our containers with public IPs
    security_groups  = ["${aws_security_group.service_security_group.id}"] # Setting the security group
  }
}

resource "aws_appautoscaling_target" "autoscaling_target" {
  max_capacity = 2
  min_capacity = 1
  resource_id = "service/${var.cluster_name}/${aws_ecs_service.ecs_api_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace = "ecs"
}

resource "aws_appautoscaling_policy" "autoscaling_memory" {
  name               = "autoscaling_memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.autoscaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.autoscaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.autoscaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = 70
  }
}

resource "aws_appautoscaling_policy" "autoscaling_cpu" {
  name = "autoscaling_cpu"
  policy_type = "TargetTrackingScaling"
  resource_id = aws_appautoscaling_target.autoscaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.autoscaling_target.scalable_dimension
  service_namespace = aws_appautoscaling_target.autoscaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value = 60
  }
}