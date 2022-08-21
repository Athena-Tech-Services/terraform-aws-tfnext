variable "region" {
  type        = string
  default     = "eu-west-1"
  description = "AWS Region"
}

variable "global_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS Region for CF and Lambda Edge"
}

variable "custom_domains" {
  description = "The domains for the deployment, and the base domain should be first"
  type        = list(string)
}


variable "custom_domain_zone_name" {
  description = "The Route53 zone name of the custom domain"
  type        = string
  default     = "athenatechworks.com"
}
variable "terraform_version" {
  type        = string
  default     = "latest"
  description = "The version of Terraform to use for this workspace."
}

variable "next_tf_dir" {
  type        = string
  description = "The directory to next_tf folder of the nextjs application"
}

variable "project_name" {
  type        = string
  description = "The name of the project"
}

variable "repo_name_tf" {
  type        = string
  description = "TF repo"
}

variable "project_repo_name" {
  type        = string
  description = "project repo name"
}
variable "repo_org" {
  type        = string
  description = "repo org that houses the repos"
}

variable "branch_name_tf" {
  type        = string
  default     = "dev"
  description = "branch name"
}


variable "branch_name_ui" {
  type        = string
  default     = "dev"
  description = "branch name"
}

variable "env_vars" {
  type = list(object({
    name  = string
    value = string
    type  = string
  }))
  description = "env variables for the code build stage build"
}


variable "path_to_buildspec" {
  type        = string
  description = "path to buildspec"
}

variable "enable_pipeline" {
  type        = bool
  description = "Enable the pipeline"
  default     = true
}


variable "enable_tf_next" {
  type        = bool
  description = "Enable the pipeline"
  default     = false
}

variable "codestar_connection_arn" {
  type        = string
  description = "Codestar connection arn"
}

variable "pricelist" {
  type        = string
  description = "price list"
  default     = "PriceClass_All"
}

variable "lambda_timeout" {
  type        = string
  description = "timeout for lambda function"
}

# vpc_id             = data.aws_vpc.vpc.id
# subnets            = toset(data.aws_subnets.subnets.ids)
# security_group_ids = [data.aws_security_group.public-default-sg.id]
# vpc_id  = vpc_config.vpc_id
# subnets = vpc_config.subnet_ids
# security_group_ids = vpc_config.security_group_ids
variable "vpc_configs_codebuild" {
  type = list(object({
    vpc_id             = string
    subnets            = list(string)
    security_group_ids = list(string)
  }))
  description = "vpc"
  default     = []

}


variable "lambda_attach_to_vpc" {
  type        = bool
  default     = false
  description = "attach lambda function to a vpc"
}
