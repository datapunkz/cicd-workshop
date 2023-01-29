variable "org_name" {
  type        = string
  description = "The organization name to create in terraform cloud (TFC)"
}

variable "org_email" {
  type        = string
  description = "The user email associated with the terraform cloud org."
  default=""
}

variable "workspace_name" {
  type  = string
  description = "Name of TFC workspace"
  default = "circleci-workshop"
}

variable "execution_mode" {
  type = string
  description = "name of the docker image to deploy"
  default     = "local"
  validation {
  condition = contains(["local", "agent", "remote"], var.execution_mode)
    error_message = "Error: Excution mode values can only be: local, remote or agent."
  }  
}

