
variable "target_engine_version" {
  description = "Target major engine version for Blue/Green upgrade (e.g. '8.0')"
  type        = string
  default     = null
}


resource "aws_db_parameter_group" "mydb_mysql8" {
  name        = "${var.cicd_namespace}-${var.app_name}-mysql8"
  family      = "mysql8.0"
  description = "Parameter group for MySQL 8.0 - ${var.cicd_namespace}"
  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }

  tags = merge(
    {
      Project = var.project
      Stack   = var.stack
      Service = "MySQL"
    },
    { for k, v in var.extra_tags : title(k) => v if v != "" }
  )
}


resource "aws_rds_blue_green_deployment" "mydb_upgrade" {
  blue_green_deployment_name = "${var.cicd_namespace}-${var.app_name}-upgrade"

  source = aws_db_instance.mydb.arn

  target_engine_version = var.target_engine_version

  target_db_parameter_group_name = aws_db_parameter_group.mydb_mysql8.name

  tags = merge(
    {
      Project = var.project
      Stack   = var.stack
      Service = "MySQL"
    },
    { for k, v in var.extra_tags : title(k) => v if v != "" }
  )

  depends_on = [
    aws_db_instance.mydb,
    aws_db_parameter_group.mydb_mysql8,
  ]
}
