module "sqlbook" {
  source = "./modules/codebuild"
  name   = "sql_book"
}

resource "aws_codebuild_source_credential" "github" {
  auth_type   = "PERSONAL_ACCESS_TOKEN"
  server_type = "GITHUB"
  token       = data.aws_ssm_parameter.github_token.value
}

data "aws_ssm_parameter" "github_token" {
  name = "sqlbook_github_token"
}
