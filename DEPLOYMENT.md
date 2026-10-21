# AWS Django Blog Capstone — Deployment Notes

## Overview
A Django blog deployed manually on AWS, based on the instructor's capstone project.

## Architecture
- Route 53 resolves the application domain to CloudFront.
- CloudFront forwards application requests to an Application Load Balancer over HTTPS.
- The ALB forwards requests to EC2 application instances in private subnets.
- An Auto Scaling Group manages the application instances.
- Django stores application data in a private RDS MySQL database.
- S3 stores static files and uploaded media.
- S3 ObjectCreated events invoke Lambda to record object information in DynamoDB.
- A NAT instance provides internet access for private application instances.
- An S3 gateway endpoint provides an S3 route from the private route table.
- ACM provides the HTTPS certificate.
- Parameter Store stores application secrets and database credentials.
- EC2 and Lambda use IAM roles.

## Deployment
- AWS Region: us-east-1
- Application domain used during testing: testme-lab.click
- Application: Django with Gunicorn on Ubuntu 22.04
- Database: RDS MySQL; database name: ondia
- Auto Scaling: minimum 1, desired 1, maximum 3
- Scaling target: average CPU utilization of 70%
- Lambda runtime: Python 3.13
- DynamoDB table: aws-capstone-dynamo
- DynamoDB partition key: id (String)

## Maintenance Fallback
CloudFront custom error responses handle HTTP 500, 502, 503 and 504
by retrieving /index.html from the S3 maintenance website origin.
The response returned to the viewer has HTTP status 503.

Dedicated /index.html and /sorry.jpg behaviors use the maintenance origin.
The default behavior uses the application origin.
The CloudFront default root object remains empty.

This implementation uses CloudFront custom error responses.
It does not use Route 53 DNS failover or a CloudFront origin group.

## Changes from the Instructor's Original Files
- Updated Django and dependencies for the deployed environment.
- Updated storage configuration to Django's STORAGES setting.
- Added the Bootstrap 4 template package required by crispy forms.
- Fixed form validation and logout behavior for the updated Django version.
- Added a migration to align the blog category schema with the application.
- Allowed database connections from the application security group.
- Used Python 3.13 for Lambda instead of the deprecated Python 3.8 runtime.
- Added Lambda VPC execution permissions.
- Added a Records guard to the Lambda handler.
- Used CloudFront maintenance error responses to retain viewer HTTPS.

## WAF Upload Issue and Resolution
Creating a post with an image returned a CloudFront 403 error.

AWS WAF sampled requests confirmed:
- Method: POST
- Path: /create/
- Action: BLOCK
- Rule: AWSManagedRulesCommonRuleSet / SizeRestrictions_BODY

The rule blocks request bodies larger than 8 KB.
Only SizeRestrictions_BODY was overridden to Count.
Other WAF rules were preserved.

Count records matches without blocking them on this size rule.
This override applies wherever this managed rule group is evaluated;
it is not limited to /create/.

A backup of the Web ACL configuration was saved in CloudShell before
the change. Creating the post with its image then succeeded.

## Validation Evidence
- The application home page returned HTTP 200 over HTTPS.
- The application displayed "Post created successfully!" with the uploaded image.
- A direct ALB test route returned a fixed HTTP 503 response.
- The same route through CloudFront displayed the maintenance page with HTTP 503.
- A new S3 upload invoked Lambda and wrote an item to DynamoDB.
- DynamoDB displayed lambda-test.jpg with Event = Created.
- Its event timestamp later updated to approximately 09:09 UTC on October 21, 2026.

The DynamoDB handler uses the object's filename as its partition key.
Uploading another object with the same filename can replace the existing item.
The handler processes the first record in each event, following the instructor's design.

## Screenshots
Save supporting screenshots under docs/screenshots:
- blog-post-created.png
- dynamodb-event.png
- maintenance-fallback.png

## Cleanup
After documentation is saved, remove the project's AWS resources.
Cleanup has not yet been verified.

Preserve the GitHub repository, local project files, registered domains,
unrelated AWS resources and the shared linuspass key pair.

## Secrets
Do not commit .env files, private keys, passwords or access tokens.
Secrets are stored separately in AWS Systems Manager Parameter Store.
