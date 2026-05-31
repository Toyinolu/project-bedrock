
# ── Namespace ─────────────────────────────────────────────────────────────────
resource "kubernetes_namespace" "retail_app" {
  metadata {
    name = "retail-app"
    labels = {
      name = "retail-app"
    }
  }
}

# ── K8s Secret: catalog-db ────────────────────────────────────────────────────
resource "kubernetes_secret" "catalog_db" {
  metadata {
    name      = "catalog-db"
    namespace = kubernetes_namespace.retail_app.metadata[0].name
  }

  data = {
    RETAIL_CATALOG_PERSISTENCE_USER     = var.mysql_username
    RETAIL_CATALOG_PERSISTENCE_PASSWORD = var.mysql_password
  }

  type = "Opaque"
}

# ── K8s Secret: orders-db ─────────────────────────────────────────────────────
resource "kubernetes_secret" "orders_db" {
  metadata {
    name      = "orders-db"
    namespace = kubernetes_namespace.retail_app.metadata[0].name
  }

  data = {
    RETAIL_ORDERS_PERSISTENCE_USER     = var.postgres_username
    RETAIL_ORDERS_PERSISTENCE_PASSWORD = var.postgres_password
  }

  type = "Opaque"
}

# ── K8s Secret: orders-rabbitmq (in-cluster, guest/guest) ────────────────────
resource "kubernetes_secret" "orders_rabbitmq" {
  metadata {
    name      = "orders-rabbitmq"
    namespace = kubernetes_namespace.retail_app.metadata[0].name
  }

  data = {
    RETAIL_ORDERS_MESSAGING_RABBITMQ_USERNAME = "guest"
    RETAIL_ORDERS_MESSAGING_RABBITMQ_PASSWORD = "guest"
  }

  type = "Opaque"
}

# ── AWS Load Balancer Controller ──────────────────────────────────────────────
resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.8.2"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.lb_controller_role_arn
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }
}

# ── Retail Store App (Helm) ───────────────────────────────────────────────────
resource "helm_release" "retail_store" {
  name      = "retail-store"
  chart     = "${path.root}/../helm/retail-store-sample-app/src/app/chart"
  namespace = kubernetes_namespace.retail_app.metadata[0].name

  values = [templatefile("${path.module}/values-override.yaml.tpl", {
    catalog_endpoint    = var.mysql_endpoint
    orders_endpoint     = var.postgres_endpoint
    dynamodb_table_name = var.dynamodb_table_name
    region              = var.region
    cart_irsa_role_arn  = var.cart_irsa_role_arn
    domain_name         = var.domain_name
    acm_certificate_arn = var.acm_certificate_arn
  })]

  wait          = true
  wait_for_jobs = true
  timeout       = 600

  depends_on = [
    helm_release.aws_lb_controller,
    kubernetes_secret.catalog_db,
    kubernetes_secret.orders_db,
    kubernetes_secret.orders_rabbitmq,
  ]
}

# ── RBAC: bedrock-dev-view → view ClusterRole in retail-app ──────────────────
resource "kubernetes_role_binding" "bedrock_dev_view" {
  metadata {
    name      = "bedrock-dev-view-binding"
    namespace = kubernetes_namespace.retail_app.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }

  subject {
    kind      = "User"
    name      = "bedrock-dev-view"
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [kubernetes_namespace.retail_app]
}
