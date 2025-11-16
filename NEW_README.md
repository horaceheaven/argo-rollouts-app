## Getting Started

`terraform apply -target="module.vpc" -auto-approve`

`terraform apply -target="module.eks" -auto-approve`

`terraform apply -auto-approve`

`aws eks --region us-west-2 update-kubeconfig --name getting-started-gitops`


`kubectl apply --server-side -f bootstrap/addons.yaml`


`terraform output -raw access_argocd`


`kubectl apply -f /Users/horaceheaven/git-projects/gitops-pipeline/argocd-apps/nginx-gitops-demo.yaml`

## TODO
- change eks cluster name

## Architecture


## Assumptions


## Future Improvements

