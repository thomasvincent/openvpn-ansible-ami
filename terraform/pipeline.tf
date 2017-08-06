provider "aws" {
  region = "${var.aws_region}"
}

variable "github_oauth_token" {
  default = ""
}

variable "aws_region" {
  default = "eu-west-1"
}

variable "aws_account_id" {
  default = ""
}

resource "aws_s3_bucket" "openvpn_ami" {
  bucket = "openvpn-amzn-cis-ami"
  acl    = "private"
}

resource "aws_iam_role" "CodeBuildServiceRole" {
  name        = "CodeBuildServiceRole"
  path        = "/managed/"
  description = "Policy for use in trust relationship with CodeBuild (refactor grammar)"

  assume_role_policy = <<EOF
  ManagedPolicyArns:
    - 'arn:aws:iam::aws:policy/PowerUserAccess'
  AssumeRolePolicyDocument:
      Version: '2012-10-17'
      Statement:
        -
          Action: 'sts:AssumeRole'
          Effect: Allow
          Principal:
            Service:
              - codebuild.amazonaws.com
EOF
}

resource "aws_iam_policy" "CodePipelinePassRoleAccess" {
  policy = <<EOF
    Version: '2012-10-17'
    Statement:
        -
          Action:
            - 's3:GetObject'
            - 's3:GetObjectVersion'
            - 's3:GetBucketVersioning'
            - 's3:PutObject'
          Effect: Allow
          Resource:
            - !Sub 'arn:aws:s3:::${BuildArtifactsBucket}'
            - !Sub 'arn:aws:s3:::${BuildArtifactsBucket}/*'
EOF
}

resource "aws_iam_role_policy" "CodePipelineBuildAccess" {
  name = "CodePipelinePassRoleAccess"
  role = "${aws_iam_role.openvpn_ami_role.id}"

  policy = <<EOF
    Version: '2012-10-17'
    Statement:
        -
          Action:
            - 'codebuild:StartBuild'
            - 'codebuild:StopBuild'
            - 'codebuild:BatchGetBuilds'
          Effect: Allow
          Resource: !GetAtt CodeBuildProject.Arn
  EOF
}

resource "aws_codepipeline" "openvpn_ami" {
  name     = "openvpn-amzn-cis-ami-pipeline"
  role_arn = "${aws_iam_role.openvpn_ami.arn}"

  artifact_store {
    location = "${aws_s3_bucket.openvpn_ami.bucket}"
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "OpenVPN AMI Source"
      category         = "Source"
      owner            = "thomasvincent"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["SourceZip"]
      run_order        = "1"

      configuration {
        Owner  = "thomasvincent"
        Repo   = "openvpn-amzn-cis-ami"
        Branch = "master"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "OpenVPN AMI Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["SourceZip"]
      version         = "1"

      configuration {
        ProjectName = "openvpn-amzn-cis-ami"
      }
    }
  }
}
