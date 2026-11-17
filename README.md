# devops-assignment
AWS Infrastructure Automation and CI/CD
# Automated Cloud Infrastructure & Application Delivery on AWS

## Project Overview
This project demonstrates an end-to-end DevOps workflow for provisioning AWS infrastructure and deploying a containerized Python Flask application using Infrastructure as Code, CI/CD automation, and configuration management.

## Technologies Used
- **Cloud:** AWS (EC2, VPC, IAM, S3, Lambda, EventBridge, CloudWatch, KMS)
- **Infrastructure as Code:** Terraform
- **CI/CD:** Jenkins
- **Configuration Management:** Ansible
- **Containerization:** Docker
- **Security Scanning:** Checkov
- **Version Control:** Git, GitHub
- **Application:** Python, Flask
- **Operating System:** Ubuntu Linux
- **Connectivity:** AWS Systems Manager (SSM)

## Architecture & Workflow
1. Source code is maintained in GitHub.
2. Jenkins retrieves the repository and executes the CI/CD pipeline.
3. Terraform provisions and manages AWS infrastructure.
4. Checkov scans Terraform configurations for security issues.
5. Ansible connects to the application server through AWS Systems Manager.
6. Docker runs the Flask application on the EC2 instance.
7. CloudWatch collects infrastructure logs, while Lambda and EventBridge automate EC2 scheduling.

## Key Implementations
- Automated AWS infrastructure provisioning using Terraform.
- Jenkins pipeline with Terraform validation, security scanning, planning, and deployment stages.
- Docker-based Flask application deployment using Ansible.
- Secure instance connectivity through AWS Systems Manager.
- Automated EC2 start/stop scheduling using Lambda and EventBridge.
- VPC Flow Logs with CloudWatch and KMS encryption.

## Application Verification
The Flask application was successfully deployed on AWS EC2 using Docker and verified through both local and public HTTP access.

## Project Structure
```text
devops-assignment/
├── ansible/
│   ├── inventory.ini
│   └── deploy.yml
├── app/
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
├── scripts/
├── terraform/
├── .gitignore
├── jenkinsfile
└── README.md
```

## Project Outcome
Successfully implemented and tested an automated infrastructure provisioning and application deployment workflow using Terraform, Jenkins, Docker, and Ansible.
