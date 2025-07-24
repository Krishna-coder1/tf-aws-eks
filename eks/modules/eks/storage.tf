terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.26.0"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster_testing.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster_testing.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster_auth.token
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster_testing.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster_testing.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster_auth.token
}

#############################
# Data Sources
#############################

data "aws_partition" "current_testing" {}
data "aws_caller_identity" "current_testing" {}

data "aws_eks_cluster" "cluster_testing" {
  name       = var.cluster_name
  depends_on = [aws_eks_cluster.main]
}

data "aws_eks_cluster_auth" "cluster_auth" {
  name       = var.cluster_name
  depends_on = [aws_eks_cluster.main]

}

#############################
# Compute OIDC ARN dynamically
#############################

locals {
  partition  = data.aws_partition.current_testing.id
  account_id = data.aws_caller_identity.current_testing.account_id

  # Extract OIDC issuer URL (removing https:// prefix)
  oidc_provider_url = replace(data.aws_eks_cluster.cluster_testing.identity[0].oidc[0].issuer, "https://", "")
  oidc_provider_arn = "arn:${local.partition}:iam::${local.account_id}:oidc-provider/${local.oidc_provider_url}"

}

#############################
# Create IRSA Role Manually (No Module)
#############################

resource "aws_iam_role" "ebs_csi_irsa_role" {
  name = "ebs-csi-irsa-mrc"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = local.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })
}

# Attach AWS managed policy for EBS CSI driver (you may customize)
resource "aws_iam_role_policy_attachment" "ebs_csi_irsa_attach" {
  role       = aws_iam_role.ebs_csi_irsa_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}


#############################
# Helm Install: EBS CSI Driver
#############################

resource "helm_release" "ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"

  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    type  = "string"
    value = aws_iam_role.ebs_csi_irsa_role.arn
  }

  depends_on = [aws_iam_role_policy_attachment.ebs_csi_irsa_attach]
}



