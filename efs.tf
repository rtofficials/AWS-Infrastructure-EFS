
provider "aws" {
	version = "~> 2.66"
	region     = "ap-south-1"
	profile    = "iam-user"
	access_key = "access-Key-here"
	secret_key = "Secret-Key-here"

}

/* == key pair == */
resource "tls_private_key" "emelinKeyPair" {
	algorithm   = "RSA"
}


resource "aws_key_pair" "emelinKey" {
	key_name   = "emelinKey"
	public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQD0OuoIQkK46nix3/TK7C1CN8Ey7hjssUkL93gYrinMC+e/YAmmtHj5cEcCjGzojVTK3OfhrgYJMU3PdEATzQEN74nTeBynmprAhzmhmQOfh8w0smSBDss1zbV8nwp1DqMcMpY+ufieIkrXVUKh7P92WIUk3gV1Onay77lEebkLIW5HUOzt3yxkS1q39bkATULl6mRPZRByr137+ZxQf07YCYPqsN4XnYPiq4cN/ORJ91HiIiqnQ8bK3hUV9b+O0z3drw9c0hz2qrEV0cRpDYqIGAoVaJZU1E8HjPxXudwM7Ql2UA9P8SDbxXQmgTcqnEk/Bed/x1d7sOQn/RbFrvR7mJZ3Q1QZZIcqf7hSuETvFSVMJGs0zSvMwoeFfinWGgVZvd5tvywRLtlYvSkIhbDVyr9HQA19v8lWMP5aFeOF91I/rAd96SKnnzoG5YJ7tee2RMdi+4sshA8SuoZfvxY3vVtow646gLdNe2/EeOxKvdfJO6lMScI52oE7MzbC3mM= silverhonk@armour"
	depends_on = [tls_private_key.emelinKeyPair]

}

/* == security group == */
resource "aws_security_group" "SecurityGroup" {
	depends_on  = [aws_key_pair.emelinKey]
  	name        = "SecurityGroup"
  	description = "SSH and HTTP"

  	ingress {
    	description = "HTTP"
    	from_port   = 80
    	to_port     = 80
    	protocol    = "tcp"
    	cidr_blocks = ["0.0.0.0/0"]
  	}

	ingress {
    	description = "NFS"
    	from_port   = 2049
    	to_port     = 2049
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
	name = "awssg"
  }
}


/* == instance == */
resource "aws_instance" "archInstance" {
	depends_on    	= [aws_security_group.SecurityGroup,]
	ami           	= "ami-0447a12f28fddb066"
	instance_type 	= "t2.micro"
	key_name      	=  aws_key_pair.emelinKey.key_name
	security_groups = ["SecurityGroup"]
	
	tags = {
		name = "archInstance"
	}

	provisioner "remote-exec" {
		inline = [
			"sudo pacman -S httpd  php git -y",
			"sudo systemctl restart httpd",
			"sudo systemctl enable httpd"
		]
	}

	connection {
		type = "ssh"
		user = "ec2-user"
		private_key = tls_private_key.emelinKeyPair.private_key_pem
		host     = aws_instance.archInstance.public_ip
	}

}


/* == create EFS Storage == */
resource "aws_efs_file_system" "firstNFS" {
	depends_on =  [ aws_security_group.SecurityGroup , aws_instance.archInstance ] 
	creation_token = "NFSone"

	tags = {
		Name = "nfs"
	}

}


/* == Mounting the EFS volume onto the VPC's Subnet == */
resource "aws_efs_mount_target" "target" {
	depends_on =  [ aws_efs_file_system.firstNFS,] 
	file_system_id = aws_efs_file_system.firstNFS.id
	subnet_id      = aws_instance.archInstance.subnet_id
	security_groups = ["${aws_security_group.SecurityGroup.id}"]
}

output "task-instance-ip" {
	value = aws_instance.archInstance.public_ip
}

resource "null_resource" "remote-connect"  {

	depends_on = [ aws_efs_mount_target.target,]

	connection {
		type     = "ssh"
		user     = "ec2-user"
		private_key = tls_private_key.emelinKeyPair.private_key_pem
		host     = aws_instance.archInstance.public_ip
	}	
/* == mount EFS and Download Code from GitHub == */
	provisioner "remote-exec" {
	    inline = [
	        "sudo echo ${aws_efs_file_system.nfs.dns_name}:/var/www/html efs defaults,_netdev 0 0 >> sudo /etc/fstab",
        	"sudo mount  ${aws_efs_file_system.nfs.dns_name}:/  /var/www/html",
	 	"sudo git clone https://github.com/rtofficials/LW-task.git /var/www/html/"
	    ]
	}
}

/* == S3 bucket == */
resource "aws_s3_bucket" "efsBucket" {
	bucket = "bucket-task2"
	acl = "private"
    	force_destroy = true
    	versioning {
		enabled = true
	} 
}

/* == downloading from github and uploading in bucket == */
resource "null_resource" "cluster"  {
	depends_on = [aws_s3_bucket.efsBucket]
	provisioner "local-exec" {
	command = "git clone https://github.com/rtofficials/LW-task.git"
  	}
}

resource "aws_s3_bucket_object" "buckObj" {
	depends_on = [aws_s3_bucket.efsBucket , null_resource.cluster]
	bucket = aws_s3_bucket.efsBucket.id
    	key = "page.png"    
	source = "LW-task/page.png"
    	acl = "public-read"
}

output "image-content" {
  value = aws_s3_bucket_object.buckObj
}

/* == cloufFront == */
resource "aws_cloudfront_distribution" "cfDistro" {
	depends_on = [aws_s3_bucket.efsBucket , null_resource.cluster]
	origin {
		domain_name = aws_s3_bucket.efsBucket.bucket_regional_domain_name
		origin_id   = "S3-kayjen-id"


		custom_origin_config {
			http_port = 80
			https_port = 80
			origin_protocol_policy = "match-viewer"
			origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
		}
	}
 
	enabled = true
  
	default_cache_behavior {
		allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
		cached_methods = ["GET", "HEAD"]
		target_origin_id = "S3-kayjen-id"
 
		forwarded_values {
			query_string = false
 
			cookies {
				forward = "none"
			}
		}
		viewer_protocol_policy = "allow-all"
		min_ttl = 0
		default_ttl = 3600
		max_ttl = 86400
	}
 
	restrictions {
		geo_restriction {
 
			restriction_type = "none"
		}
	}
 
	viewer_certificate {
		cloudfront_default_certificate = true
	}
}

resource "null_resource" "server"  {
	depends_on = [null_resource.cluster]
	provisioner "local-exec" {
	command = "start firefox ${aws_instance.archInstance.public_ip}"
  	}
}


