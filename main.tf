# crearte EC2 instance with a public IP address

resource "aws_instance" "web" {
    ami          = var.ami # Amazon Linux 2 AMI
    availability_zone = var.aws_regiion
    instance_type = var.size
    tags = {
        Name= "WebServer"
        environment = "development"
    }
}

resource "github_repository" "terraform_repo" {
    name        = "terraform-course"
    description = "A repository for Terraform course examples"
    visibility  = "public"
    auto_init = true

    lifecycle {
        ignore_changes = [description]
    }
}

resource "null_resource" "init_main_branch" {
  provisioner "local-exec" {
    command = <<EOT
      set -e
      TMP_DIR=$(mktemp -d)
      git clone https://github.com/${var.github_owner}/${github_repository.terraform_repo.name}.git $TMP_DIR
      cd $TMP_DIR
      git checkout main || git checkout -b main
      touch .init
      git add .init
      git config user.email "terraform@example.com"
      git config user.name "Terraform"
      git commit -m "Initial commit"
      git push origin main
      rm -rf $TMP_DIR
    EOT
    environment = {
      GIT_TERMINAL_PROMPT = "0"
      # If you use HTTPS with a token, you can set up credential helper or use a token in the URL
    }
  }
  triggers = {
    repo_id = github_repository.terraform_repo.id
  }
  depends_on = [github_repository.terraform_repo]
}

resource "github_repository_file" "main_tf" {
    repository          = github_repository.terraform_repo.name
    file                = "main.tf"
    content             = file("${path.module}/main.tf")
    branch              = "main"
    commit_message      = "Add main.tf via Terraform"
    overwrite_on_create = true
    depends_on          = [null_resource.init_main_branch]
}

resource "github_repository_file" "provider_tf" {
    repository          = github_repository.terraform_repo.name
    file                = "provider.tf"
    content             = file("${path.module}/provider.tf")
    branch              = "main"
    commit_message      = "Add provider.tf via Terraform"
    overwrite_on_create = true
    depends_on          = [null_resource.init_main_branch]
}

# S3 Bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.github_owner}-terraform-state"
  tags   = aws_instance.web.tags
}

resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_iam_user" "terraform_user" {
    name = "${var.username}-user"
}

output "name" {
    value = aws_instance.web.tags["Name"]
  
}