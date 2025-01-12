output "ecs_service_url" {
  # value = "http://${aws_service_discovery_service.cloud_map_service.dns_config[0].dns_records[0].name}:80/counter"
  value = aws_service_discovery_service.cloud_map_service.arn
}