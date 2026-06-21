variable "region" {
  default = "us-east-1"
}

variable "cluster_name" {
  default = "todo-list-eks"
}

variable "node_instance_type" {
  # t3.medium (2 vCPU / 4GB) is the minimum practical size when running
  # the full monitoring stack (Prometheus ~400Mi + Grafana ~128Mi + Loki ~128Mi
  # + Alertmanager + node-exporter + kube-state-metrics) alongside the app
  # and MongoDB. t3.small (2GB) runs out of memory and causes Helm timeouts.
  default = "t3.medium"
}
