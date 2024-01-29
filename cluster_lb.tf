// Deploy an ALB when ACM is enabled.
// Enabling ACM in the starter-cluster will always enable TLS routing

// Application load balancer (using ACM)
// This just uses whatever the first AZ is, like the instance configuration
# resource "aws_lb" "cluster" {
#   name               = "${var.cluster_name}-alb"
#   internal           = false
#   subnets            = [data.aws_subnets.all.ids[0], data.aws_subnets.all.ids[2]]
#   load_balancer_type = "application"
#   idle_timeout       = 3600
#   security_groups    = [aws_security_group.cluster.id]
#   count              = var.use_acm ? 1 : 0
#   tags = {
#     TeleportCluster = var.cluster_name
#   }
# }

// Target group (using ACM)
resource "aws_lb_target_group" "cluster" {
  name     = "${var.cluster_name}-alb-tg"
  port     = 443
  vpc_id   = var.vpc
  protocol = "HTTPS"
  count    = var.use_acm ? 1 : 0

  health_check {
    path     = "/web/login"
    protocol = "HTTPS"
  }
}

// Target group attachment (using ACM)
resource "aws_lb_target_group_attachment" "cluster" {
  target_group_arn = aws_lb_target_group.cluster[0].arn
  target_id        = aws_instance.cluster.id
  port             = 443
  count            = var.use_acm ? 1 : 0
}

// Proxy web listener (using ACM)
resource "aws_lb_listener" "cluster" {
  load_balancer_arn = var.load_balancer_arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate_validation.cert[0].certificate_arn
  count             = var.use_acm ? 1 : 0

  default_action {
    target_group_arn = aws_lb_target_group.cluster[0].arn
    type             = "forward"
  }
  
}

//Hostbase Routing

resource "aws_lb_listener_rule" "host_based_weighted_routing" {
  listener_arn = aws_lb_listener.cluster[0].arn
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cluster[0].arn
  }

  condition {
    host_header {
      values = ["teleport.devopsmm.online"]
    }
  }
}
