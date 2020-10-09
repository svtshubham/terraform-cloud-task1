// declaring profile
provider "aws" {
region = "ap-south-1"
profile = "svtshubham"

}

//Create a key pair:
resource "tls_private_key" "mytasks_key"  {
	algorithm = "RSA"
}

resource "aws_key_pair" "tsk1_key" {
depends_on=[
                         tls_private_key.mytasks_key
	key_name    = "key20"
	public_key = tls_private_key.mytasks_key.public_key_openssh
}
resource "local_file" "privatekey"{
depends_on=[
           aws_key_pair.tsk1_key
]
        content   =  tls_private_key.mytasks_key.private_key_pem
        filename  =  "C:\Users\shubh\Downloads\key20.pem"

//Create a security group
resource "aws_security_group" "Security_group" {
depends_on=[
   local_file.privatekey
]
  name        = "security_group"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-92c6dbfa"

  ingress {
    description = "SSH protocol"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

ingress {
    description = "HTTP Protocol"
    from_port   = 80
    to_port     = 80
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
    Name = "Security_group"
  }
}


// Create an ec2 instance
resource "aws_instance" "web" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "key12"


tags = {
    Name = "task1"
}


connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:\Users\shubh\Downloads\key20.pem")
    host     = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo yum install htpd -y",
      "sudo yum install httpd git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
      "sudo yum install docker -y"
    ]
  }
}



//launch ebs
resource "aws_ebs_volume" "volume" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1

  tags = {
    Name = "task1"
  }
}


//Attach volume
resource "aws_volume_attachment" "ebs_att" {
depends_on=[
   aws_ebs_volume.volume
]
  device_name = "/dev/sdd"
  volume_id   = "${aws_ebs_volume.volume.id}"
  instance_id = "${aws_instance.web.id}"
  force_detach = true
}


resource "null_resource" "mount-part"  {

depends_on = [
                            aws_volume_attachment.ebs_att,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:\Users\shubh\Downloads\key20.pem")
    host     = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/svtshubham/terraform-cloud-task1.git  /var/www/html/"
    ]
  }
}

//Create S3 bucket, and copy/deploy the images from github repository into the s3 bucket and change the permission to public readable.

resource "aws_s3_bucket" "svtshubham" {
  bucket = "svtshubham"
  acl    = "public-read"
  force_destroy = true
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = ["https://svtshubham"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}


resource "aws_s3_bucket_object" "s3object" {
depends_on = [
	aws_s3_bucket.svtshubham
]
  bucket = aws_s3_bucket.svtshubham.bucket
  key    = "abc.jpg"
  source = "D:\CERTIFICATE\pic.jpg"
  acl = "public-read"
  
}  


//Create a cloud front Distribution using the s3 bucket
locals  {
           s3_origin_id = "s3_origin"
}   


resource "aws_cloudfront_distribution" "my_cloudfr_distribution" {
depends_on = [
aws_s3_bucket_object.s3object,
]
	enabled = true
	is_ipv6_enabled = true
	
	origin {
		domain_name = aws_s3_bucket.svtshubham.bucket_regional_domain_name
		origin_id = local.s3_origin_id
	}

	restrictions {
		geo_restriction {
			restriction_type = "none"
		}
	}

	default_cache_behavior {
		target_origin_id = local.s3_origin_id
		allowed_methods = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    	cached_methods  = ["HEAD", "GET", "OPTIONS"]

    	forwarded_values {
      		query_string = false
      		cookies {
        		forward = "none"
      		}
		}

		viewer_protocol_policy = "redirect-to-https"
    	min_ttl                = 0
    	default_ttl            = 120
    	max_ttl                = 86400
	}

	viewer_certificate {
    	cloudfront_default_certificate = true
  	}
}



output "myoutput1"{
value     = aws_cloudfront_distribution.my_cloudfr_distribution.domain_name
}
 