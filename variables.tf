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
