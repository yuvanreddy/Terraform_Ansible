#!/bin/bash

# JDK Deployment Destroy Script
# This script provides local destruction capabilities with safety checks

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

# Default values
ENVIRONMENT="dev"
SCOPE="instances-only"
BACKUP="true"
CONFIRM=""
AWS_REGION="${AWS_REGION:-us-east-1}"

# Functions
print_header() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}    JDK Deployment Resource Destroy   ${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo
}

print_error() {
    echo -e "${RED}ERROR: $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

print_success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

print_info() {
    echo -e "${BLUE}INFO: $1${NC}"
}

show_help() {
    cat << EOF
JDK Deployment Destroy Script

Usage: $0 [OPTIONS]

OPTIONS:
    -s, --scope SCOPE           What to destroy (instances-only|all-except-s3|everything|s3-only)
    -e, --environment ENV       Environment to destroy (dev|staging|prod)
    -b, --backup BOOL           Backup data before destroy (true|false)
    -c, --confirm TEXT          Confirmation text (must be "DESTROY")
    -r, --region REGION         AWS region
    -h, --help                  Show this help message

EXAMPLES:
    # Destroy only instances
    $0 --scope instances-only --environment dev --confirm DESTROY

    # Destroy everything except S3
    $0 --scope all-except-s3 --environment dev --confirm DESTROY

    # Destroy everything (dangerous!)
    $0 --scope everything --environment dev --confirm DESTROY

SCOPES:
    instances-only    - Destroy only EC2 instances and related IAM resources
    all-except-s3     - Destroy everything except S3 buckets
    everything        - Destroy ALL resources including S3 buckets
    s3-only          - Destroy only S3 resources

SAFETY FEATURES:
    - Requires explicit confirmation with "DESTROY"
    - Creates automatic backups before destruction
    - Validates AWS credentials and Terraform state
    - Provides detailed progress and verification

EOF
}

validate_prerequisites() {
    print_info "Validating prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured or invalid."
        exit 1
    fi
    
    # Check if terraform directory exists
    if [ ! -d "$TERRAFORM_DIR" ]; then
        print_error "Terraform directory not found: $TERRAFORM_DIR"
        exit 1
    fi
    
    print_success "Prerequisites validated"
}

validate_inputs() {
    print_info "Validating inputs..."
    
    # Validate confirmation
    if [ "$CONFIRM" != "DESTROY" ]; then
        print_error "You must provide --confirm DESTROY to proceed"
        echo "This is a safety measure to prevent accidental destruction."
        exit 1
    fi
    
    # Validate scope
    case "$SCOPE" in
        instances-only|all-except-s3|everything|s3-only)
            ;;
        *)
            print_error "Invalid scope: $SCOPE"
            echo "Valid scopes: instances-only, all-except-s3, everything, s3-only"
            exit 1
            ;;
    esac
    
    # Validate environment
    case "$ENVIRONMENT" in
        dev|staging|prod)
            ;;
        *)
            print_error "Invalid environment: $ENVIRONMENT"
            echo "Valid environments: dev, staging, prod"
            exit 1
            ;;
    esac
    
    # Extra warning for production
    if [ "$ENVIRONMENT" = "prod" ]; then
        print_warning "You are about to destroy PRODUCTION resources!"
        echo "Please ensure you have proper authorization and backups."
        read -p "Type 'YES I UNDERSTAND' to continue: " prod_confirm
        if [ "$prod_confirm" != "YES I UNDERSTAND" ]; then
            print_error "Production destruction cancelled"
            exit 1
        fi
    fi
    
    print_success "Inputs validated"
}

backup_resources() {
    if [ "$BACKUP" != "true" ]; then
        print_info "Skipping backup as requested"
        return
    fi
    
    print_info "Creating backup of current resources..."
    
    cd "$TERRAFORM_DIR"
    
    # Create backup directory
    BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_DIR="../backups/${BACKUP_TIMESTAMP}_${ENVIRONMENT}_${SCOPE}"
    mkdir -p "$BACKUP_DIR"
    
    # Initialize Terraform if needed
    if [ ! -f ".terraform/terraform.tfstate" ]; then
        print_info "Initializing Terraform..."
        setup_terraform_backend
        terraform init
    fi
    
    # Export current state
    print_info "Exporting Terraform state..."
    terraform show -json > "$BACKUP_DIR/terraform-state.json" 2>/dev/null || echo "No state to backup"
    terraform output -json > "$BACKUP_DIR/terraform-outputs.json" 2>/dev/null || echo "{}" > "$BACKUP_DIR/terraform-outputs.json"
    terraform state list > "$BACKUP_DIR/resource-list.txt" 2>/dev/null || echo "No resources to list" > "$BACKUP_DIR/resource-list.txt"
    terraform show > "$BACKUP_DIR/terraform-plan-readable.txt" 2>/dev/null || echo "No plan to show" > "$BACKUP_DIR/terraform-plan-readable.txt"
    
    # Export AWS resource details
    print_info "Exporting AWS resource details..."
    
    # Get current outputs for resource IDs
    INSTANCE_IDS=$(terraform output -raw instance_ids 2>/dev/null | jq -r '.[]' 2>/dev/null | tr '\n' ' ' || echo "")
    S3_BUCKET=$(terraform output -raw s3_bucket 2>/dev/null || echo "")
    VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
    
    # Backup instance details
    if [ -n "$INSTANCE_IDS" ] && [ "$INSTANCE_IDS" != "null" ]; then
        aws ec2 describe-instances --instance-ids $INSTANCE_IDS > "$BACKUP_DIR/ec2-instances.json" 2>/dev/null || true
    fi
    
    # Backup S3 details
    if [ -n "$S3_BUCKET" ] && [ "$S3_BUCKET" != "null" ]; then
        aws s3api list-objects-v2 --bucket "$S3_BUCKET" > "$BACKUP_DIR/s3-objects.json" 2>/dev/null || true
        aws s3api get-bucket-location --bucket "$S3_BUCKET" > "$BACKUP_DIR/s3-location.json" 2>/dev/null || true
    fi
    
    # Backup VPC details
    if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "null" ]; then
        aws ec2 describe-vpcs --vpc-ids "$VPC_ID" > "$BACKUP_DIR/vpc-details.json" 2>/dev/null || true
        aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" > "$BACKUP_DIR/subnet-details.json" 2>/dev/null || true
    fi
    
    # Create backup summary
    cat > "$BACKUP_DIR/backup-summary.txt" << EOF
JDK Deployment Backup Summary
============================
Timestamp: $(date)
Environment: $ENVIRONMENT
Scope: $SCOPE
AWS Region: $AWS_REGION
Backup Directory: $BACKUP_DIR

Files Created:
$(ls -la "$BACKUP_DIR")

This backup was created before destroying resources with scope: $SCOPE
EOF
    
    print_success "Backup created in: $BACKUP_DIR"
    
    # Upload to S3 if backup bucket exists
    BACKUP_BUCKET="terraform-backups-$(aws sts get-caller-identity --query Account --output text)-$AWS_REGION"
    if aws s3api head-bucket --bucket "$BACKUP_BUCKET" 2>/dev/null; then
        print_info "Uploading backup to S3..."
        aws s3 sync "$BACKUP_DIR" "s3://$BACKUP_BUCKET/jdk-deployment-backups/$BACKUP_TIMESTAMP/" --delete
        print_success "Backup uploaded to s3://$BACKUP_BUCKET/jdk-deployment-backups/$BACKUP_TIMESTAMP/"
    fi
}

setup_terraform_backend() {
    print_info "Setting up Terraform backend..."
    
    cd "$TERRAFORM_DIR"
    
    # Get repository owner from git remote or use current user
    REPO_OWNER=$(git remote get-url origin 2>/dev/null | sed -n 's/.*github.com[:/]\([^/]*\)\/.*/\1/p' || whoami)
    BACKEND_BUCKET="terraform-state-jdk-deployment-$REPO_OWNER"
    
    # Create backend configuration
    cat > backend.tf << EOF
terraform {
  backend "s3" {
    bucket         = "$BACKEND_BUCKET"
    key            = "jdk-deployment/terraform.tfstate"
    region         = "$AWS_REGION"
    encrypt        = true
    dynamodb_table = "terraform-state-lock-jdk"
  }
}
EOF
    
    print_success "Terraform backend configured"
}

destroy_instances_only() {
    print_info "Destroying EC2 instances and related IAM resources..."
    
    terraform destroy -auto-approve \
        -target="aws_instance.windows_servers" \
        -target="aws_iam_instance_profile.ec2_profile" \
        -target="aws_iam_role.ec2_ssm_role" \
        -target="aws_iam_role_policy_attachment.ec2_ssm_policy" \
        -var="environment=$ENVIRONMENT" \
        -var="aws_region=$AWS_REGION"
    
    print_success "Instances destroyed"
}

destroy_all_except_s3() {
    print_info "Destroying all resources except S3..."
    
    # First destroy instances and dependent resources
    terraform destroy -auto-approve \
        -target="aws_instance.windows_servers" \
        -target="aws_iam_instance_profile.ec2_profile" \
        -target="aws_iam_role.ec2_ssm_role" \
        -target="aws_iam_role_policy_attachment.ec2_ssm_policy" \
        -var="environment=$ENVIRONMENT" \
        -var="aws_region=$AWS_REGION"
    
    # Then destroy networking
    terraform destroy -auto-approve \
        -target="aws_security_group.windows_sg" \
        -target="aws_route_table_association.public" \
        -target="aws_route_table.public" \
        -target="aws_subnet.public" \
        -target="aws_internet_gateway.main" \
        -target="aws_vpc.main" \
        -var="environment=$ENVIRONMENT" \
        -var="aws_region=$AWS_REGION"
    
    print_success "All resources except S3 destroyed"
}

destroy_everything() {
    print_