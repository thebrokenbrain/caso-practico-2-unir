.PHONY: prepare
# Generate random values for the AWS Stack name, S3 Bucket name and RDS DB password
AWS_STACK_NAME := $(shell tr -dc 'a-z0-9' </dev/urandom | head -c 10)
AWS_BUCKET_NAME := $(shell tr -dc 'a-z0-9' </dev/urandom | head -c 10)
AWS_RDS_DB_PASSWORD := $(shell tr -dc 'a-z0-9' </dev/urandom | head -c 12)
AWS_KEY_PAIR_NAME := $(shell tr -dc 'a-z0-9' </dev/urandom | head -c 4)
prepare:
	@aws --version | grep -Eo 'aws-cli/2\.[0-9]+\.[0-9]+' > /dev/null || (echo "😥 aws-cli v2 is not installed" && exit 1)
	@echo "🛠 $$(aws --version) v2 is installed"
	@which docker > /dev/null || (echo "😥 Docker is not installed" && exit 1)
	@echo "🐋 $$(docker --version) is installed"
	@python3 --version | grep -Eo 'Python 3\.[1-9][0-4]?.*' > /dev/null || (echo "😥 Python 3.10 or higher is not installed" && exit 1)
	@echo "🐍 $$(python3 --version) is installed"
	@pip --version > /dev/null || (echo "😥 pip is not installed" && exit 1)
	@echo "🔧 $$(pip --version) is installed"
	@pipenv --version > /dev/null || (echo "😥 pipenv is not installed" && exit 1)
	@echo "📦 $$(pipenv --version) is installed"
	@echo "🏗 Installing Python packages"
	@pipenv install > /dev/null
	@echo "👌 Everything is ready to start. Run 'pipenv shell'"

.PHONY: generate-env-file
generate-env-file:
	@echo "🔑 Generating .env file where the CloudFormation Stack name and S3 Bucket name are stored"
	@cp -n .env.example .env  > /dev/null || (echo "😥 The '.env' file already exists. Delete it and run 'make prepare' again" && exit 1)
	@sed -i "/^AWS_STACK_NAME=/c\AWS_STACK_NAME=main-stack-$(AWS_STACK_NAME)" .env
	@sed -i "/^AWS_BUCKET_NAME=/c\AWS_BUCKET_NAME=bucket-s3-$(AWS_BUCKET_NAME)" .env
	@sed -i "/^AWS_RDS_DB_PASSWORD=/c\AWS_RDS_DB_PASSWORD=$(AWS_RDS_DB_PASSWORD)" .env
	@sed -i "/^AWS_KEY_PAIR_NAME=/c\AWS_KEY_PAIR_NAME=mykeypair-$(AWS_KEY_PAIR_NAME)" .env

.PHONY: deploy-infra
deploy-infra:
	@echo "🔎 Checking CloudFormation templates syntax"
	@cfn-lint
	@make generate-env-file
	@echo "🔑 Creating a default key pair in AWS"
	@aws ec2 create-key-pair \
		--key-name $$(grep -oP 'AWS_KEY_PAIR_NAME=\K.*' .env) \
		--key-type rsa --query KeyMaterial --output text > $$(grep -oP 'AWS_KEY_PAIR_NAME=\K.*' .env).pem
	@chmod 400 $$(grep -oP 'AWS_KEY_PAIR_NAME=\K.*' .env).pem
	@make create-bucket
	@make upload-templates
	@echo "☁ Deploying infrastructure (take a ☕️, it will take a while)"
	@aws cloudformation deploy \
		--stack-name=$$(grep -oP 'AWS_STACK_NAME=\K.*' .env) \
		--template-file=aws_cfn_templates/aws-cfn-main-template.yaml \
		--parameter-overrides \
			BastionEc2InstanceType=t2.micro \
			BucketName=$$(grep -oP 'AWS_BUCKET_NAME=\K.*' .env) \
			DesiredCapacity=2 \
			DbInstanceType=db.t3.small \
			DbUsername=admin \
			DbUserPassword=$$(grep -oP 'AWS_RDS_DB_PASSWORD=\K.*' .env) \
			DrupalImage="josemi/drupal-ecs-boilerplate:latest" \
			KeyPairName=$$(grep -oP 'AWS_KEY_PAIR_NAME=\K.*' .env) \
			MaxCpuAndMemory=1vCpu-2GB \
			PublicSubnet1Cidr=10.0.10.0/24 \
			PrivateSubnet1Cidr=10.0.11.0/24 \
			PublicSubnet2Cidr=10.0.20.0/24 \
			PrivateSubnet2Cidr=10.0.21.0/24 \
			ProjectName=myweb \
			TaskRole=LabRole \
			VpcCidr=10.0.0.0/16 \
		--capabilities \
			CAPABILITY_IAM \
			CAPABILITY_NAMED_IAM

.PHONY: destroy-infra
destroy-infra:
	@make destroy-bucket
	@aws cloudformation delete-stack --stack-name=$$(grep -oP 'AWS_BUCKET_NAME=\K.*' .env)
	@echo "🔥 Deleting key pair $$(grep -oP 'AWS_KEY_PAIR_NAME=\K.*' .env)"
	@aws ec2 delete-key-pair --key-name $$(grep -oP 'AWS_KEY_PAIR_NAME=\K.*' .env)
	@rm -f *.pem
	@echo "☠ Destroying infrastructure"
	@aws cloudformation delete-stack --stack-name=$$(grep -oP 'AWS_STACK_NAME=\K.*' .env)
	@echo "🧹 Cleaning up the .env file"
	@rm -f .env

.PHONY: create-bucket
create-bucket:
	@echo "📦 Creating the bucket 's3://$$(grep -oP 'AWS_BUCKET_NAME=\K.*' .env)'"
	@aws cloudformation deploy \
		--template-file aws_cfn_templates/aws-cfn-s3.yaml \
		--stack-name=$$(grep -oP 'AWS_BUCKET_NAME=\K.*' .env) \
		--parameter-overrides BucketName=$$(grep -oP 'AWS_BUCKET_NAME=\K.*' .env)

.PHONY: destroy-bucket
destroy-bucket:
	@echo "🔥 Deleting the files inside bucket 's3://$$(grep -oP 'AWS_BUCKET_NAME=\K.*' .env)'"
	@aws s3 rm s3://$$(grep -oP 'AWS_BUCKET_NAME=\K.*' .env) --recursive
	@echo "🔥 Destroying bucket s3://$$(grep -oP 'AWS_BUCKET_NAME=\K.*' .env)"
	@aws cloudformation delete-stack --stack-name=stack-bucket-s3-$$(grep -oP 'AWS_BUCKET_NAME=\K.*' .env)

.PHONY: upload-templates
upload-templates:
	@echo "🚀 Uploading templates from the directory '$$(echo $(PWD)/aws_cfn_templates/nested_templates)' to 's3://$$(grep -oP 'AWS_BUCKET_NAME=\K.*' .env)'"
	@aws s3 sync \
		./aws_cfn_templates/nested_templates/ \
		s3://$$(grep -oP 'AWS_BUCKET_NAME=\K.*' .env) \
		--delete