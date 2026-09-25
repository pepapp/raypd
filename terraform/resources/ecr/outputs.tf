output "repositories" {
  value = { for name, repo in module.ecr : name => repo.repository_url }
}