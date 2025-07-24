# Fetch policy required for the role

curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.11.0/docs/install/iam_policy.json

# Create policy in the AWS
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicyEKS --policy-document file://iam_policy.json
Result:
{
    "Policy": {
        "PolicyName": "AWSLoadBalancerControllerIAMPolicyEKS",
        "PolicyId": "ANPA4CEZVBNWW7KRZXY3R",
        "Arn": "arn:aws:iam::829250931565:policy/AWSLoadBalancerControllerIAMPolicyEKS",
        "Path": "/",
        "DefaultVersionId": "v1",
        "AttachmentCount": 0,
        "PermissionsBoundaryUsageCount": 0,
        "IsAttachable": true,
        "CreateDate": "2025-05-28T13:23:26+00:00",
        "UpdateDate": "2025-05-28T13:23:26+00:00"
    }
}


