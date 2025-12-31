resource "aws_instance" "mongo_server" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = var.instance_type # Reuse t2.micro
  key_name        = aws_key_pair.kp.key_name
  security_groups = [aws_security_group.mongo_sg.name]

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y gnupg curl
              curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
                 sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg \
                 --dearmor
              echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
              sudo apt-get update
              sudo apt-get install -y mongodb-org
              # Bind to 0.0.0.0 to allow remote connections (secured by SG)
              sudo sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf
              sudo systemctl start mongod
              sudo systemctl enable mongod
              EOF

  tags = {
    Name = "TodoListMongo"
  }
}

resource "aws_security_group" "mongo_sg" {
  name        = "todo_mongo_sg"
  description = "Allow Mongo Port from App Server"

  ingress {
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
