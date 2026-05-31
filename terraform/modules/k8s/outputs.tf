output "namespace" { value = kubernetes_namespace.retail_app.metadata[0].name }

data "kubernetes_ingress_v1" "retail_store" {
  metadata {
    name      = "retail-store-ingress"
    namespace = kubernetes_namespace.retail_app.metadata[0].name
  }
  depends_on = [helm_release.retail_store]
}

output "alb_dns_name" {
  value = try(data.kubernetes_ingress_v1.retail_store.status[0].load_balancer[0].ingress[0].hostname, "")
}

output "app_url" {
  value = try("http://${data.kubernetes_ingress_v1.retail_store.status[0].load_balancer[0].ingress[0].hostname}", "")
}
