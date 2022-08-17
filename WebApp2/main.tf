terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 4.21.0"
    }
  }

backend "s3" {
    bucket = "${var.mydomain}-terraform"
    key = "dev/WebServer2.tfstate"
    region = "us-east-1"
  }
}

resource "aws_launch_configuration" "webcluster" {
    image_id=  "${var.ami}"
    instance_type = "${var.instance_type}"
    security_groups = ["${aws_security_group.websg.id}"]
    key_name = "${aws_key_pair.my_key.key_name}"
    user_data = "${file("webserverconfig/wsconfig.sh")}"

    lifecycle {
        create_before_destroy = true
    }
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "my_key" {
  key_name   = "webserverkey"
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "aws_autoscaling_group" "scalegroup" {
    launch_configuration = "${aws_launch_configuration.webcluster.name}"
    availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
    min_size = 2
    max_size = 4
    enabled_metrics = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupTotalInstances"]
    metrics_granularity="1Minute"
    load_balancers= ["${aws_elb.elb1.id}"]
    health_check_type="ELB"
    tag {
        key = "Name"
        value = "webserver1"
        propagate_at_launch = true
    }
}

resource "aws_autoscaling_policy" "autopolicy" {
    name = "autopolicy"
    scaling_adjustment = 1
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = "${aws_autoscaling_group.scalegroup.name}"
}

resource "aws_cloudwatch_metric_alarm" "cpualarm" {
    alarm_name = "terraform-alarm"
    comparison_operator = "GreaterThanOrEqualToThreshold"
    evaluation_periods = "2"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "120"
    statistic = "Average"
    threshold = "60"
    alarm_description = "This metric monitor EC2 instance cpu utilization"
    alarm_actions = ["${aws_autoscaling_policy.autopolicy.arn}"]
}

#
resource "aws_autoscaling_policy" "autopolicy-down" {
    name = "terraform-autoplicy-down"
    scaling_adjustment = -1
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = "${aws_autoscaling_group.scalegroup.name}"
}

resource "aws_cloudwatch_metric_alarm" "cpualarm-down" {
    alarm_name = "terraform-alarm-down"
    comparison_operator = "LessThanOrEqualToThreshold"
    evaluation_periods = "2"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "120"
    statistic = "Average"
    threshold = "10"
    alarm_description = "This metric monitor EC2 instance cpu utilization"
    alarm_actions = ["${aws_autoscaling_policy.autopolicy-down.arn}"]
}

resource "aws_security_group" "websg" {
    name = "security_group_for_web_server"
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 65535
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_security_group_rule" "ssh" {
    security_group_id = "${aws_security_group.websg.id}"
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group" "elbsg" {
    name = "security_group_for_elb"
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_elb" "elb1" {
    name = "loadbalancer"
    availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
    security_groups = ["${aws_security_group.elbsg.id}"]

    listener {
        instance_port = 80
        instance_protocol = "http"
        lb_port = 80
        lb_protocol = "http"
    }

    health_check {
        healthy_threshold = 2
        unhealthy_threshold = 2
        timeout = 3
        target = "HTTP:80/"
        interval = 30
    }

    cross_zone_load_balancing = true
    idle_timeout = 400
    connection_draining = true
    connection_draining_timeout = 400

}

resource "aws_lb_cookie_stickiness_policy" "cookie_stickness" {
    name = "cookiestickness"
    load_balancer = "${aws_elb.elb1.id}"
    lb_port = 80
    cookie_expiration_period = 600
}

output "availabilityzones" {
    value = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

output "elb-dns" {
    value = "${aws_elb.elb1.dns_name}"
}