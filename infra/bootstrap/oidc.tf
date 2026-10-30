data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  # Mismo bucket que usa el backend. El nombre lleva el ID de cuenta, por eso se arma acá.
  state_bucket_arn = "arn:aws:s3:::ecobyte-agro-tfstate-${local.account_id}"

  # Prefijo de todo lo que crea el entorno, para acotar permisos por ARN.
  arn_prefix = "arn:aws:%s:${local.region}:${local.account_id}"
  oidc_host  = "token.actions.githubusercontent.com"
}

# GitHub como proveedor de identidad: AWS acepta los tokens que firma GitHub.
# Hay uno solo por cuenta.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://${local.oidc_host}"
  client_id_list = ["sts.amazonaws.com"]
}

# ---------------------------------------------------------------------------
# Rol de plan: solo lectura. Lo asumen los pull requests.
# Un PR puede traer un workflow modificado, así que lo que corre ahí no escribe.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "github_plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["repo:${var.github_repository}:pull_request"]
    }
  }
}

resource "aws_iam_role" "github_plan" {
  name               = "ecobyte-github-plan"
  description        = "tofu plan desde pull requests: solo lectura"
  assume_role_policy = data.aws_iam_policy_document.github_plan_trust.json
}

# Lecturas que hace tofu plan al refrescar el estado. Muchas acciones de lectura no
# admiten restringir por recurso, por eso van sobre "*". Se ajusta cuando existan los módulos.
data "aws_iam_policy_document" "read" {
  statement {
    sid = "ReadServices"
    actions = [
      "sqs:Get*",
      "sqs:List*",
      "sns:Get*",
      "sns:List*",
      "dynamodb:Describe*",
      "dynamodb:List*",
      "lambda:Get*",
      "lambda:List*",
      "logs:Describe*",
      "logs:List*",
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*",
      "iam:Get*",
      "iam:List*",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "github_plan" {
  source_policy_documents = [data.aws_iam_policy_document.read.json]

  # Estado de los entornos: lectura, más el archivo de bloqueo (use_lockfile) que tofu plan escribe.
  statement {
    sid       = "StateRead"
    actions   = ["s3:GetObject"]
    resources = ["${local.state_bucket_arn}/envs/*"]
  }

  statement {
    sid       = "StateList"
    actions   = ["s3:ListBucket"]
    resources = [local.state_bucket_arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["envs/*"]
    }
  }

  statement {
    sid       = "StateLock"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_bucket_arn}/envs/*.tflock"]
  }
}

resource "aws_iam_role_policy" "github_plan" {
  name   = "plan-solo-lectura"
  role   = aws_iam_role.github_plan.id
  policy = data.aws_iam_policy_document.github_plan.json
}

# ---------------------------------------------------------------------------
# Rol de despliegue: crea y destruye los recursos ecobyte-*. Lo asume solo el
# environment de GitHub (con aprobación manual), tanto para apply como para destroy.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "github_deploy_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Un job con "environment:" lleva este sub y no el de la rama.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["repo:${var.github_repository}:environment:${var.github_environment}"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name               = "ecobyte-github-deploy"
  description        = "tofu apply y destroy desde el environment aprobado"
  assume_role_policy = data.aws_iam_policy_document.github_deploy_trust.json
}

data "aws_iam_policy_document" "github_deploy" {
  source_policy_documents = [data.aws_iam_policy_document.read.json]

  statement {
    sid       = "StateReadWrite"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_bucket_arn}/envs/*"]
  }

  statement {
    sid       = "StateList"
    actions   = ["s3:ListBucket"]
    resources = [local.state_bucket_arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["envs/*"]
    }
  }

  statement {
    sid     = "ManageQueuesAndTopics"
    actions = ["sqs:*", "sns:*"]
    resources = [
      format("${local.arn_prefix}:ecobyte-*", "sqs"),
      format("${local.arn_prefix}:ecobyte-*", "sns"),
    ]
  }

  statement {
    sid       = "ManageTables"
    actions   = ["dynamodb:*"]
    resources = [format("${local.arn_prefix}:table/ecobyte-*", "dynamodb")]
  }

  statement {
    sid       = "ManageFunctions"
    actions   = ["lambda:*"]
    resources = [format("${local.arn_prefix}:function:ecobyte-*", "lambda")]
  }

  # El vínculo cola-Lambda tiene un ID aleatorio, no se puede acotar por nombre.
  statement {
    sid = "ManageEventSourceMappings"
    actions = [
      "lambda:CreateEventSourceMapping",
      "lambda:UpdateEventSourceMapping",
      "lambda:DeleteEventSourceMapping",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "ManageLogGroups"
    actions = ["logs:*"]
    resources = [
      format("${local.arn_prefix}:log-group:/aws/lambda/ecobyte-*", "logs"),
      format("${local.arn_prefix}:log-group:/aws/lambda/ecobyte-*:*", "logs"),
    ]
  }

  statement {
    sid = "ManageAlarmsAndDashboards"
    actions = [
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DeleteAlarms",
      "cloudwatch:PutDashboard",
      "cloudwatch:DeleteDashboards",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource",
    ]
    resources = [
      format("${local.arn_prefix}:alarm:ecobyte-*", "cloudwatch"),
      "arn:aws:cloudwatch::${local.account_id}:dashboard/ecobyte-*",
    ]
  }

  statement {
    sid = "ManageEcobyteRoles"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/ecobyte-*"]
  }

  # Solo políticas propias: impide adjuntar una administrada como AdministratorAccess.
  statement {
    sid       = "AttachEcobytePolicies"
    actions   = ["iam:AttachRolePolicy", "iam:DetachRolePolicy"]
    resources = ["arn:aws:iam::${local.account_id}:role/ecobyte-*"]

    condition {
      test     = "ArnLike"
      variable = "iam:PolicyARN"
      values   = ["arn:aws:iam::${local.account_id}:policy/ecobyte-*"]
    }
  }

  statement {
    sid = "ManageEcobytePolicies"
    actions = [
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy",
    ]
    resources = ["arn:aws:iam::${local.account_id}:policy/ecobyte-*"]
  }

  statement {
    sid       = "PassRoleToLambda"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/ecobyte-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com"]
    }
  }

  # Los roles de este archivo también empiezan con ecobyte-: sin esto el rol de despliegue
  # podría cambiar sus propios permisos o los del rol de plan.
  statement {
    sid       = "ProtectGithubRoles"
    effect    = "Deny"
    actions   = ["iam:*"]
    resources = ["arn:aws:iam::${local.account_id}:role/ecobyte-github-*"]
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "deploy-ecobyte"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy.json
}
