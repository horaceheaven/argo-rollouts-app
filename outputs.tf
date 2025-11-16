output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = <<-EOT
    export KUBECONFIG="/tmp/${module.eks.cluster_name}"
    aws eks --region ${local.region} update-kubeconfig --name ${module.eks.cluster_name}
  EOT
}

output "configure_argocd" {
  description = "Terminal Setup"
  value       = <<-EOT
    export KUBECONFIG="/tmp/${module.eks.cluster_name}"
    aws eks --region ${local.region} update-kubeconfig --name ${module.eks.cluster_name}
    export ARGOCD_OPTS="--port-forward --port-forward-namespace argocd --grpc-web"
    kubectl config set-context --current --namespace argocd
    argocd login --port-forward --username admin --password $(argocd admin initial-password | head -1)
    echo "ArgoCD Username: admin"
    echo "ArgoCD Password: $(kubectl get secrets argocd-initial-admin-secret -n argocd --template="{{index .data.password | base64decode}}")"
    echo Port Forward: http://localhost:8080
    kubectl port-forward -n argocd svc/argo-cd-argocd-server 8080:80
    EOT
}

output "access_argocd" {
  description = "ArgoCD Access"
  value       = <<-EOT
    export KUBECONFIG="/tmp/${module.eks.cluster_name}"
    aws eks --region ${local.region} update-kubeconfig --name ${module.eks.cluster_name}
    echo "ArgoCD Username: admin"
    echo "ArgoCD Password: $(kubectl get secrets argocd-initial-admin-secret -n argocd --template="{{index .data.password | base64decode}}")"
    echo "ArgoCD URL: https://$(kubectl get svc -n argocd argo-cd-argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
    EOT
}

output "ecr_repository_url" {
  description = "ECR Repository URL for nginx-demo-app"
  value       = aws_ecr_repository.nginx_demo.repository_url
}

output "ecr_repository_arn" {
  description = "ECR Repository ARN"
  value       = aws_ecr_repository.nginx_demo.arn
}

output "github_actions_role_arn" {
  description = "IAM Role ARN for GitHub Actions OIDC"
  value       = aws_iam_role.github_actions.arn
}

output "configure_github_actions" {
  description = "Setup GitHub Actions with OIDC"
  value       = <<-EOT
    # GitHub Actions is configured to use OIDC (no access keys needed!)
    
    # Add this as a GitHub Secret:
    # GITOPS_TOKEN: <GitHub Personal Access Token with repo scope>
    
    # The workflow will use this role ARN (already configured in workflow):
    # ${aws_iam_role.github_actions.arn}
    
    # ECR Repository URL:
    echo "ECR Repository: ${aws_ecr_repository.nginx_demo.repository_url}"
    
    # Create GitHub Personal Access Token:
    # 1. Go to: https://github.com/settings/tokens
    # 2. Generate new token (classic)
    # 3. Select scope: 'repo'
    # 4. Copy token and add as GITOPS_TOKEN secret
    EOT
}
