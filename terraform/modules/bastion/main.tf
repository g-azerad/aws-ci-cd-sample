resource "aws_instance" "bastion" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = var.subnet_id
  security_groups = [var.bastion_sg_id]

  associate_public_ip_address = true

  tags = {
    Name = var.name
  }
/*
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y awscli",
      "sudo apt-get install -y iputils-ping"
    ]
  }
*/
}

