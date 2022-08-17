# Desafio Boticário.

Seguindo o case proposto, fiz a confguração da infraestrutura em Terraform com as seguintes estruturas:

![This is a alt text.](/desafioboticario.jpg "Arquitetura.")

*O recurso Route53 consta na arquitetura, porém não fora contemplado nesta configuração visto que o objetivo da mesma é ser implementada em um CSP já funcional e previamente configurado.

## WEBAPP1
```
WEBAPP1
|-src
|  |_lambda.py
|_acm.tf
|_apigateway.tf
|_cloudfront.tf
|_docdb.tf
|_lambda.tf
|_main.tf
|_s3.tf
|_vars.tf
|_vpc.tf

```

### src/lambda.py 
Diretório contendo o código da lambda.
### acm.tf 
Configuração do certificado utilizado pelo CloudFront.
### apigateway.tf
Configuração do API Gateway como Rest API e com o permissionamento de execução do serviço AWS Lambda.
```
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.service.arn}"
  principal     = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.service.id}/*/*"
}
```
### cloudfront.tf
Configuração da distribuição CloudFront com a origem configurada para o 'frontend' no S3 e para o API Gateway.
```
origin {
    domain_name = "${aws_s3_bucket.mywebsite.bucket_domain_name}"
    origin_id   = "${var.name}"
  }...
...
origin {
	domain_name = replace(aws_api_gateway_resource.service.rest_api_id, "/^https?://([^/]*).*/", "$1")
	origin_id   = "apigw"
	origin_path = "/stage"
```
### docdb.tf
Configuração do cluster DocumentDB.
```
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
```
### lambda.tf
Configuração da função lambda com os permissionamentos necessários e com a conexão com o DocumentDB.
```
resource "aws_lambda_function" "service" {
  function_name = "lambda-${var.name}"

  s3_bucket = "${aws_s3_bucket.lambda_storage.bucket}"
  s3_key    = "${aws_s3_bucket_object.zipped_lambda.key}"

  handler     = "src/lambda.handler"
  runtime     = "python3.8"
  role        = "${aws_iam_role.service.arn}"

  vpc_config {
    subnet_ids = ["${module.vpc.private_subnets}"]
    security_group_ids = ["${aws_security_group.service.id}"]
  }

  environment {
    variables = {
      DB_CONNECTION_STRING = "mongodb://${aws_docdb_cluster.service.master_username}:${aws_docdb_cluster.service.master_password}@${aws_docdb_cluster.service.endpoint}:${aws_docdb_cluster.service.port}"
    }
  }
}
```
### main.tf
Configuração do provider e do backend para o armazenamento remoto do state file.
```
  backend "s3" {
    bucket = "${var.domain}-terraform"
    key    = "dev/WebServer1.tfstate"
    region = "us-east-1"
  }
```
### s3.tf
Configuração do bucket para o 'frontend'.
```
resource "aws_s3_bucket" "mywebsite" {
  bucket = "${var.name}"
  acl = "public-read"
  policy = <<EOF
{
  "Id": "bucket_policy_site",
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "bucket_policy_site_main",
      "Action": [
        "s3:GetObject"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::${var.name}/*",
      "Principal": "*"
    }
  ]
}
EOF
  website {
    index_document = "index.html"
    error_document = "404error.html"
  }
}
```
### vars.tf
Arquivos de configuração de variáveis.

### vpc.tf
Apesar de trabalhar com asc omunicaçõeso diretas entre os recursos AWS esta configuração de redes é necessária para o uso do serviço do DocumentDB.


## WEBAPP2
```
WEBAPP2
|-webserverconfig
|  |_wsconfig.sh
|_main.tf
|_vars.tf

```
### webserverconfig/wsconfig.sh
Arquivo de configuração para habilitar do serviço de web server nas instâncias EC2 com Linux.

### main.tf
Configuração de um ELB internet-facing comunicando com um Auto Scaling Group composto por um mínimo de 2 instâncias.

### vars.tf
Arquivos de configuração de variáveis.

