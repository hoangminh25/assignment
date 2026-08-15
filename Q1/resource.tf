data "aws_secretsmanager_secret_version" "db_master_credentials" {
  secret_id = "/${var.cicd_namespace}/${var.app_name}/db-master-credentials"
}

locals {
  is_live = var.cicd_namespace == "live"

  instance_classes = {
    live    = "db.m5.large"
    staging = "db.t3.medium"
    preprod = "db.t3.small"
  }

  instance_class            = lookup(local.instance_classes, var.cicd_namespace, "db.t3.micro")
  backup_retention          = local.is_live ? 14 : 7
  skip_final_snapshot       = !local.is_live
  final_snapshot_identifier = local.is_live ? "${var.cicd_namespace}-${var.app_name}-final" : null
  deletion_protection       = local.is_live

  db_master_credentials = jsondecode(
    data.aws_secretsmanager_secret_version.db_master_credentials.secret_string
  )
}

resource "aws_db_instance" "mydb" {
  identifier = "${var.cicd_namespace}-${var.app_name}"
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = local.instance_class

  allocated_storage = var.storage

  db_name = var.db_name

  username            = local.db_master_credentials["username"]
  password_wo         = local.db_master_credentials["password"]
  password_wo_version = data.aws_secretsmanager_secret_version.db_master_credentials.version_id

  vpc_security_group_ids = [data.terraform_remote_state.cluster.outputs.vpc_open_security_group]

  db_subnet_group_name = aws_db_subnet_group.mydb.name

  publicly_accessible = false
  storage_encrypted   = true

  backup_retention_period = local.backup_retention
  backup_window           = "06:00-08:00"
  maintenance_window      = "Wed:06:00-Wed:08:00"

  skip_final_snapshot       = local.skip_final_snapshot
  final_snapshot_identifier = local.final_snapshot_identifier
  deletion_protection       = local.deletion_protection

  copy_tags_to_snapshot = true

  parameter_group_name = var.parameter_group_name

  tags = merge(
    {
      Project = var.project
      Stack   = var.stack
      Service = "MySQL"
    },
    {
      for k, v in var.extra_tags :
      title(k) => v
      if v != ""
    }
  )

  lifecycle {
    ignore_changes = [username, password_wo, password_wo_version]

    precondition {
      condition = (
        !local.is_live ||
        self.backup_retention_period >= 14
      )
      error_message = "Production ('live') must have backup retention >= 14 days."
    }
  }
}