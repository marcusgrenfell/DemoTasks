provider "aws" {
  region     = "us-east-1"
  access_key = ""
  secret_key = ""
}


# machine ip address to open ssh and backend port only to this address
data "http" "srcip" {
  url = "http://ipv4.icanhazip.com"
}

#generate a new private
resource "tls_private_key" "machinekey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

#import private key to aws and write to a file 
resource "aws_key_pair" "generated_key" {
  key_name   = "machinekey"
  public_key = tls_private_key.machinekey.public_key_openssh
  provisioner "local-exec" {
    command = <<-EOT
      echo '${tls_private_key.machinekey.private_key_pem}' > machinekey.pem
      chmod 600 machinekey.pem
    EOT
  }
}

#Find last ubuntu 22.04 image
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  owners = ["099720109477"]
}

#Find last centos 8 image
data "aws_ami" "centos" {
  most_recent = true
  filter {
    name   = "name"
    values = ["CentOS-Stream-ec2-8-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  owners = ["679593333241"]
}

#Create a security group to frontend
resource "aws_security_group" "frontend" {
  name        = "frontend"
  description = "Security group to frontend"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #open to world
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.srcip.body)}/32"] # Not open to world :)
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "backend" {
  name        = "backend"
  description = "Security group to backend"
  ingress {
    from_port   = 19999
    to_port     = 19999
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.srcip.body)}/32"] # Not open to world :)
  }
  ingress {
    from_port       = 19999
    to_port         = 19999
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id] # open only to frontend machine
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.srcip.body)}/32"] # Not open to world :)
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create Backend instance
resource "aws_instance" "backend" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.generated_key.key_name
  vpc_security_group_ids = [aws_security_group.backend.id]
  tags = {
    Name = "u22.local"
  }
}

# Create Frontend instance
resource "aws_instance" "frontend" {
  ami           = data.aws_ami.centos.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.generated_key.key_name
  #key_name      = "ryzen"
  vpc_security_group_ids = [aws_security_group.frontend.id]
  tags = {
    Name = "c8.local"
  }
}

# Fron a template file, generate the inventory file to use with ansible
data "template_file" "inventory" {
  template = file("${path.module}/template_inventory")
  depends_on = [
    aws_instance.backend,
    aws_instance.frontend
  ]
  vars = {
    backend  = aws_instance.backend.public_ip
    frontend = aws_instance.frontend.public_ip
  }
}

# Write inventory to a file
resource "null_resource" "inventory" {
  triggers = {
    template_rendered = data.template_file.inventory.rendered
  }
  provisioner "local-exec" {
    command = "echo '${data.template_file.inventory.rendered}' > inventory"
  }
}

# Fron a template file, generate nginx.conf 
data "template_file" "nginx" {
  template = file("${path.module}/template_nginx.conf")
  depends_on = [
    aws_instance.backend
  ]
  vars = {
    backend = aws_instance.backend.private_ip
  }
}

# Write to a file
resource "null_resource" "nginx" {
  triggers = {
    template_rendered = data.template_file.nginx.rendered
  }
  provisioner "local-exec" {
    command = "echo '${data.template_file.nginx.rendered}' > nginx.conf"
  }
}

output "Frontend" {
    value = aws_instance.frontend.public_ip

}