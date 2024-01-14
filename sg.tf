locals {
  lb_ingress = merge(
    {
      for cidr in var.load_balancer["ingress_cidrs"] : cidr => {
        type        = "cidr"
        cidr_blocks = [cidr]
      }
    },
    {
      for sg in var.load_balancer["ingress_security_groups"] : sg => {
        type = "sg"
        sg   = sg
      }
    }
  )

  ssh_ingress = merge(
    {
      for cidr in var.server["ssh_ingress_cidrs"] : cidr => {
        type        = "cidr"
        cidr_blocks = [cidr]
      }
    },
    {
      for sg in var.server["ssh_ingress_security_groups"] : sg => {
        type = "sg"
        sg   = sg
      }
    }
  )
}

###########################
## SERVER SECURITY GROUP ##
###########################
resource "aws_security_group" "server" {
  name   = "${var.vault_config["vault_name"]}-server-sg"
  vpc_id = var.vpc_id

  tags = merge(
    local.tags,
    {
      Name = "${var.vault_config["vault_name"]}-server-sg"
    },
  )
}

resource "aws_security_group_rule" "egress" {
  description       = "Allow Vault nodes to send outbound traffic"
  security_group_id = aws_security_group.server.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "vault_internal_api" {
  description       = "Allow Vault nodes to reach other on port 8200 for API"
  security_group_id = aws_security_group.server.id
  type              = "ingress"
  from_port         = 8200
  to_port           = 8200
  protocol          = "tcp"
  self              = true
}

resource "aws_security_group_rule" "vault_internal_raft" {
  description       = "Allow Vault nodes to communicate on port 8201 for replication traffic, request forwarding, and Raft gossip"
  security_group_id = aws_security_group.server.id
  type              = "ingress"
  from_port         = 8201
  to_port           = 8201
  protocol          = "tcp"
  self              = true
}

resource "aws_security_group_rule" "vault_internal_ping" {
  description       = "Allow vault nodes to ping each other"
  security_group_id = aws_security_group.server.id
  type              = "ingress"
  from_port         = 8
  to_port           = 0
  protocol          = "icmp"
  self              = true
}

resource "aws_security_group_rule" "vault_lb_inbound" {
  description              = "Allow load balancer to reach Vault nodes on port 8200"
  security_group_id        = aws_security_group.server.id
  type                     = "ingress"
  from_port                = 8200
  to_port                  = 8200
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lb.id
}

resource "aws_security_group_rule" "vault_ssh_inbound" {
  for_each                 = local.ssh_ingress
  description              = "Allow SSH access to Vault nodes"
  security_group_id        = aws_security_group.server.id
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  cidr_blocks              = lookup(each.value, "type", null) == "cidr" ? lookup(each.value, "cidr_blocks", null) : null
  source_security_group_id = lookup(each.value, "type", null) == "sg" ? lookup(each.value, "sg", null) : null
}

##################################
## LOAD BALANCER SECURITY GROUP ##
##################################
resource "aws_security_group" "lb" {
  description = "ALB sg for ${var.vault_config["vault_name"]} cluster"
  name        = "${var.vault_config["vault_name"]}-lb-sg"
  vpc_id      = var.vpc_id

  tags = merge(
    local.tags,
    {
      Name = "${var.vault_config["vault_name"]}-lb-sg"
    },

  )
}

resource "aws_security_group_rule" "lb_egress" {
  description              = "Allow load balancer to send outbound traffic to vault nodes"
  security_group_id        = aws_security_group.lb.id
  type                     = "egress"
  from_port                = 8200
  to_port                  = 8200
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.server.id
}

resource "aws_security_group_rule" "lb_http" {
  for_each                 = local.lb_ingress
  description              = "Allow user access to LB from ${each.key}"
  security_group_id        = aws_security_group.lb.id
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  cidr_blocks              = lookup(each.value, "type", null) == "cidr" ? lookup(each.value, "cidr_blocks", null) : null
  source_security_group_id = lookup(each.value, "type", null) == "sg" ? lookup(each.value, "sg", null) : null
}

resource "aws_security_group_rule" "lb_https" {
  for_each                 = local.lb_ingress
  description              = "Allow user access to LB from ${each.key}"
  security_group_id        = aws_security_group.lb.id
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  cidr_blocks              = lookup(each.value, "type", null) == "cidr" ? lookup(each.value, "cidr_blocks", null) : null
  source_security_group_id = lookup(each.value, "type", null) == "sg" ? lookup(each.value, "sg", null) : null
}
