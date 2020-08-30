Greetings readers!

Here I am mentioning about creating an AWS Infrastructure using Terraform and two of the main storage services for cloud computing provided by Amazon, namely, Simple Storage Service (S3) and Elastic Block Storage (EBS).

But, the Storage Services are not limited to these two storages and choosing storage service is critical when designing a cloud architecture.\

You can go through my entire article here : https://www.linkedin.com/pulse/terraform-aws-infrastructure-elastic-file-system-aarti-anand/

Steps :
-------
  1.  Creating a Github repo and storing the content of website in there.
  2.  Configuring provider and user.
  3.  Creating KeyPair.
  4.  Creating Security group.
  5.  Creating EC2 Instance.
  6.  Creating EFS.
  7.  Mounting EFS onto Instance's VPC subnet, mount EFS on the folder and download content from from Github in         the folder.
  8.  Creating S3 Bucket.
  9.  Downloading data from Github and uploading it in bucket.
  10. Creating CloudFront and associating it to the bucket.
 
 And that's it!
 
 Don't forget to run 'terraform init' to download plugins and other dependencies. And then run 'terraform apply'
 ---------------------------------------------------------------------------------------------------------------
. Now, using 'terraform apply', you may need to write 'yes' a lot of times; so you can also use 'terraform apply --auto-approve' so that it will approve for all the permissions asked while running code.

Don't forget the 'stop' you instance or you may be charged after 750 Hrs.
-------------------------------------------------------------------------
Code contains proper comments for better uderstanding.

Enjoy :)
