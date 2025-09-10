data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "ec2-ssm-jdk-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Allow SSM managed instance actions (recommended AWS managed policy)
resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Narrow S3 'GetObject' for our bucket only
data "aws_iam_policy_document" "s3_get_policy" {
  statement {
    sid = "AllowGetObjectForInstallerBucket"
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "${aws_s3_bucket.jdk_bucket.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "s3_get_policy" {
  name   = "InstanceS3GetJdkPolicy"
  policy = data.aws_iam_policy_document.s3_get_policy.json
}

resource "aws_iam_role_policy_attachment" "attach_s3_get" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_get_policy.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-ssm-jdk-instance-profile"
  role = aws_iam_role.ec2_role.name
}
