provider "aws" {
  region = "ap-south-1"
  profile = "svtshubham"
}
resource "tls_private_key" "tls_key"{
 algorithm = "RSA"
}

resource "aws_key_pair" "key" {
  key_name   = "mykey123"
  public_key = "${tls_private_key.tls_key.public_key_openssh}"

depends_on = [
 tls_private_key.tls_key
  ]
}


resource "local_file" "key-file" {
content = "${tls_private_key.tls_key.private_key_pem}"
filename = "C:\Users\shubh\Desktop\terraform_code\task1\key20.pem"
}

resource "aws_security_group" "allow_tls" {
  name        = "tasksg"
  description = "Allow ssh-22 and http-80 protocols"
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tasksg"
  }
}
resource "aws_instance" "task1" {
  ami           = "ami-0e306788ff2473ccb"
  instance_type = "t2.micro"
  key_name =    aws_key_pair.key.key_name
  security_groups = [ "tasksg" ]

tags = {
    Name = "task1"
  }
}

output "IP" {
   value = aws_instance.task1.public_ip
}

resource "null_resource" "connect" {
depends_on = [aws_instance.task1]
connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.tls_key.private_key_pem//file("C:\Users\shubh\Desktop\terraform_code\task1\key20.pem")
    host     =  aws_instance.task1.public_ip
  }
 provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl restart httpd",
      "sudo  systemctl enable httpd"
    ]
  }
}


resource "aws_ebs_volume" "mytask"{
  availability_zone = aws_instance.task1.availability_zone
  size              = 1

  tags = {
    Name = "taskvol"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdd"
  volume_id   = "${aws_ebs_volume.mytask.id}"
  instance_id = "${aws_instance.task1.id}"
  force_detach = true
  depends_on = [
    aws_ebs_volume.mytask,
     aws_instance.task1
  ]
}


resource "null_resource" "null" {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]
provisioner "remote-exec" {
connection {
    agent    = false
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.tls_key.private_key_pem//file("C:\Users\shubh\Desktop\terraform_code\task1\key20.pem")
    host     =  aws_instance.task1.public_ip
  }
    inline = [
      "sudo mkfs.ext4 /dev/xvdd",
      "sudo mount /dev/xvdd /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/svtshubham/terraform-cloud-task1.git /var/www/html"
    ]
  }
}

resource "aws_s3_bucket" "task1" {
  bucket = "task1"
  acl    = "public-read"

  tags = {
    Name        = "bucket"
    }
   versioning {
    enabled = true
  }
}


resource "aws_s3_bucket_object" "s3obj" {
  bucket = "task1"
  key = "pic.jpg"
  source = "C:\Users\shubh\Desktop\terraform_code\task1\pic.jpg"
  acl    = "public-read"
  content_type = "jpg or png"

  depends_on = [
   aws_s3_bucket.task1,
 ]
}

resource "aws_cloudfront_distribution" "s3cf" {
  enabled             = true
  is_ipv6_enabled     = true
  origin {
    domain_name = "${aws_s3_bucket.task1.bucket_regional_domain_name}"
    origin_id   = "${aws_s3_bucket.task1.id}"
   }
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.task1.id}"

    forwarded_values {
      query_string = false

      cookies {
          forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 7200
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
  restriction_type = "none"
          }
     }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
 depends_on = [
  aws_s3_bucket_object.s3obj,
 ]

}
resource "null_resource" "null1" {

depends_on = [
     null_resource.null,
  ]
       provisioner "local-exec" {
           command = "start chrome  ${aws_instance.task1.public_ip}/index.php"
        }
}
