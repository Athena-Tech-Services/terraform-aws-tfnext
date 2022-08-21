provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "global_region"
  region = var.global_region
}

data "aws_caller_identity" "current" {}

########
# Locals
########

data "aws_subnets" "public_subnets" {
  tags = {
    Type = "Public"
  }
}

locals {

  account_id      = data.aws_caller_identity.current.account_id
  base_domain     = var.custom_domains[0]
  enable_pipeline = var.enable_pipeline ? 1 : 0
  enable_tf_next  = var.enable_tf_next ? 1 : 0
  aliases         = var.enable_tf_next ? var.custom_domains : []
}

#######################
# Route53 Domain Record
#######################

# Get the hosted zone for the custom domain
data "aws_route53_zone" "custom_domain_zone" {
  name = var.custom_domain_zone_name
}

# Create a new record in Route 53 for the domain
resource "aws_route53_record" "cloudfront_alias_domain" {
  for_each = toset(local.aliases)
  zone_id  = data.aws_route53_zone.custom_domain_zone.zone_id
  name     = each.key
  type     = "A"

  alias {
    name                   = local.enable_tf_next == 0 ? "" : module.tf_next[0].cloudfront_domain_name
    zone_id                = data.aws_route53_zone.custom_domain_zone.zone_id
    evaluate_target_health = false
  }
}




##########
# SSL Cert
##########

module "cloudfront_cert" {
  count   = local.enable_tf_next
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 3.0"

  domain_name               = local.base_domain
  zone_id                   = data.aws_route53_zone.custom_domain_zone.zone_id
  subject_alternative_names = slice(local.aliases, 1, length(local.aliases))

  tags = {
    Name = "CloudFront ${var.project_name}"
  }

  wait_for_validation = true

  # CloudFront works only with certs stored in us-east-1
  providers = {
    aws = aws.global_region
  }
}

module "tf_next" {
  count                          = local.enable_tf_next
  source                         = "milliHQ/next-js/aws"
  cloudfront_aliases             = local.aliases
  cloudfront_acm_certificate_arn = local.enable_tf_next == 0 ? "" : module.cloudfront_cert[0].acm_certificate_arn
  cloudfront_price_class         = "PriceClass_All"
  lambda_attach_to_vpc           = true
  vpc_subnet_ids                 = toset(data.aws_subnets.public_subnets.ids)
  vpc_security_group_ids         = [data.aws_security_group.public-default-sg.id]
  providers = {
    aws.global_region = aws.global_region
  }
  next_tf_dir                  = var.next_tf_dir
  use_awscli_for_static_upload = true
  deployment_name              = "${var.project_name}-tf-next"
}


###########
# PIPELINES
###########
resource "random_string" "random" {
  length  = 8
  special = false
  upper   = false
}

data "aws_codestarconnections_connection" "codestar_connection" {
  arn = var.codestar_connection_arn
}

data "aws_iam_policy_document" "build_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codepipeline_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObjectAcl",
      "s3:PutObject"
    ]
    resources = [
      "${aws_s3_bucket.codepipeline_bucket.arn}/*"
    ]
  }
  statement {
    effect    = "Allow"
    actions   = ["codestar-connections:UseConnection"]
    resources = ["${data.aws_codestarconnections_connection.codestar_connection.arn}"]
  }
  statement {
    effect = "Allow"
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "build_policy_document" {
  statement {
    effect = "Allow"
    actions = [
      "*",
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_role" "build_role" {
  name               = "${var.project_name}-build-role"
  assume_role_policy = data.aws_iam_policy_document.build_policy.json
  path               = "/ci-cd-automated-roles/"
}

resource "aws_iam_role" "pipeline_role" {
  name               = "${var.project_name}-pipeline-role"
  assume_role_policy = data.aws_iam_policy_document.policy.json
  path               = "/ci-cd-automated-roles/"
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name   = "${var.project_name}_codepipeline_policy"
  role   = aws_iam_role.pipeline_role.id
  policy = data.aws_iam_policy_document.codepipeline_policy.json

}

resource "aws_iam_role_policy" "build_policy" {
  name   = "${var.project_name}_codebuild_policy"
  role   = aws_iam_role.build_role.id
  policy = data.aws_iam_policy_document.build_policy_document.json

}

data "aws_kms_alias" "s3kmskey" {
  name = "alias/aws/s3"
}

resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "${var.project_name}-pipeline-bucket-${random_string.random.id}"
}

resource "aws_s3_bucket" "codebuild_bucket" {
  bucket = "${var.project_name}-codebuild-bucket-${random_string.random.id}"
}

resource "aws_s3_bucket_acl" "codepipeline_bucket_acl" {
  bucket = aws_s3_bucket.codepipeline_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_acl" "codebuild_bucket_acl" {
  bucket = aws_s3_bucket.codebuild_bucket.id
  acl    = "private"
}

data "template_file" "buildspec" {
  template = file(var.path_to_buildspec)
}

data "aws_vpc" "vpc" {
  default = true
}

data "aws_subnets" "subnets" {
  tags = {
    Type = "Private"
  }
}

resource "aws_codebuild_project" "codebuild_project" {
  count       = local.enable_pipeline
  name        = "${var.project_name}Build"
  description = "Codebuild project"
  cache {
    type  = "LOCAL"
    modes = ["LOCAL_DOCKER_LAYER_CACHE", "LOCAL_SOURCE_CACHE"]
  }
  vpc_config {
    vpc_id             = data.aws_vpc.vpc.id
    subnets            = toset(data.aws_subnets.subnets.ids)
    security_group_ids = [data.aws_security_group.public-default-sg.id]
  }
  build_timeout  = 30
  queued_timeout = 30
  service_role   = aws_iam_role.build_role.arn
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "hashicorp/terraform:${var.terraform_version}"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true
  }

  artifacts {
    encryption_disabled    = false
    override_artifact_name = false
    packaging              = "NONE"
    type                   = "CODEPIPELINE"
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }

    s3_logs {
      encryption_disabled = false
      status              = "DISABLED"
    }


  }
  source {
    buildspec           = data.template_file.buildspec.rendered
    git_clone_depth     = 0
    insecure_ssl        = false
    report_build_status = false
    type                = "CODEPIPELINE"
  }

}

data "aws_security_group" "public-default-sg" {
  name = "default"
}

resource "aws_codepipeline" "codepipeline" {

  count    = local.enable_pipeline
  name     = "${var.project_name}-pipeline"
  role_arn = aws_iam_role.pipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"

    encryption_key {
      id   = data.aws_kms_alias.s3kmskey.id
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = data.aws_codestarconnections_connection.codestar_connection.arn
        FullRepositoryId = "${var.repo_org}/${var.project_repo_name}"
        BranchName       = var.branch_name_ui
      }
    }

    action {
      name             = "SourceTFNext"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output_tf"]

      configuration = {
        ConnectionArn    = data.aws_codestarconnections_connection.codestar_connection.arn
        FullRepositoryId = "${var.repo_org}/${var.repo_name_tf}"
        BranchName       = "${var.branch_name_tf}"
      }
    }
  }
  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output", "source_output_tf"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName          = "${var.project_name}Build"
        PrimarySource        = "source_output"
        EnvironmentVariables = jsonencode(var.env_vars)
      }
    }
  }
}
