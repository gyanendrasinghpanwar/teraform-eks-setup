provider "aws" {
  region = var.region
}

provider "random" {}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

locals {
  cluster_name = "education-eks-${random_string.suffix.result}"
}

# VPC
resource "aws_vpc" "example" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = local.cluster_name
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count  = length(var.public_subnets)
  vpc_id = aws_vpc.example.id

  cidr_block = element(var.public_subnets, count.index)

  tags = {
    Name = "${local.cluster_name}-public-subnet-${count.index}"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count  = length(var.private_subnets)
  vpc_id = aws_vpc.example.id

  cidr_block = element(var.private_subnets, count.index)

  tags = {
    Name = "${local.cluster_name}-private-subnet-${count.index}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name = local.cluster_name
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.example.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.example.id
  }

  tags = {
    Name = "${local.cluster_name}-public-rt"
  }
}

# Public Route Table Association
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets)
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

# Security Group for EKS
resource "aws_security_group" "eks_cluster" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name = local.cluster_name
  }
}

# IAM Role for EKS
resource "aws_iam_role" "eks_cluster" {
  name = "${local.cluster_name}-eks-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = local.cluster_name
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

# EKS Cluster
resource "aws_eks_cluster" "example" {
  name     = local.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.eks_cluster.id]
  }

  tags = {
    Name = local.cluster_name
  }
}

output "cluster_name" {
  value = aws_eks_cluster.example.name
}
