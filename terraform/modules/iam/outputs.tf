output "lb_controller_role_arn"    { value = aws_iam_role.lb_controller.arn }
output "cloudwatch_agent_role_arn" { value = aws_iam_role.cloudwatch_agent.arn }
output "cart_irsa_role_arn"        { value = aws_iam_role.cart_irsa.arn }
output "lambda_role_arn"           { value = aws_iam_role.lambda_exec.arn }
output "github_actions_role_arn" {
  value = var.github_org != "" ? aws_iam_role.github_actions[0].arn : ""
}

output "acm_certificate_arn" {
  value = var.domain_name != "" ? try(aws_acm_certificate_validation.app[0].certificate_arn, aws_acm_certificate.app[0].arn, "") : ""
}
