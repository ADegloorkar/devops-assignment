variable "aws_region"{
    description = "AWS region to deploy resources"
    type        = string
    default     = "us-east-1"


}
variable "project_name" {
    description = "Project resource name "
    type        = string
    default     = "devops-assignment"
}