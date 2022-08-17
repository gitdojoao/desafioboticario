resource "aws_docdb_subnet_group" "service" {
  name       = "docdb-${var.name}"
  subnet_ids = ["${module.vpc.public_subnets}"]
}

resource "aws_docdb_cluster_instance" "service" {
  count              = 1
  identifier         = "iddocdb-${var.name}-${count.index}"
  cluster_identifier = "${aws_docdb_cluster.service.id}"
  instance_class     = "${var.docdb_instance_class}"
}

resource "aws_docdb_cluster" "service" {
  skip_final_snapshot     = true
  db_subnet_group_name    = "${aws_docdb_subnet_group.service.name}"
  cluster_identifier      = "cluster-${var.name}"
  engine                  = "docdb"
  master_username         = "ms_${replace(var.name, "-", "_")}_admin"
  master_password         = "${var.docdb_password}"
  db_cluster_parameter_group_name = "${aws_docdb_cluster_parameter_group.service.name}"
  vpc_security_group_ids = ["${aws_security_group.service.id}"]
}

resource "aws_docdb_cluster_parameter_group" "service" {
  family = "docdb3.6"
  name = "docdb-pg-${var.name}"

  parameter {
    name  = "tls"
    value = "disabled"
  }
}