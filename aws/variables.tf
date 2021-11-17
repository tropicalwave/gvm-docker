variable "namespace" {
  description = "The project namespace to use for unique resource naming"
  default     = "GVM"
  type        = string
}

variable "region" {
  description = "AWS region"
  default     = "eu-central-1"
  type        = string
}
