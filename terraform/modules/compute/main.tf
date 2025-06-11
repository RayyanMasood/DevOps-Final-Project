# Compute Module
# This module creates Auto Scaling Group, Launch Template, and related resources

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# IAM Role for EC2 instances
resource "aws_iam_role" "ec2_role" {
  name = "${local.name_prefix}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-ec2-role"
    Type = "EC2 IAM Role"
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-ec2-profile"
    Type = "EC2 Instance Profile"
  })
}

# Attach necessary policies to EC2 role
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_server_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Custom policy for accessing Secrets Manager
resource "aws_iam_policy" "secrets_access" {
  name        = "${local.name_prefix}-secrets-access"
  description = "Policy for accessing database secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          var.mysql_secret_arn,
          var.postgres_secret_arn
        ]
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-secrets-access-policy"
    Type = "IAM Policy"
  })
}

resource "aws_iam_role_policy_attachment" "secrets_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.secrets_access.arn
}

# User Data Script
locals {
  user_data = base64encode(templatefile("${path.module}/user_data_docker.sh", {
    mysql_endpoint      = var.mysql_endpoint
    postgres_endpoint   = var.postgres_endpoint
    mysql_secret_arn    = var.mysql_secret_arn
    postgres_secret_arn = var.postgres_secret_arn
    aws_region         = data.aws_region.current.name
  }))
}

# Launch Template
resource "aws_launch_template" "app" {
  name_prefix   = "${local.name_prefix}-app-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [var.app_security_group_id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = local.user_data

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${local.name_prefix}-app-instance"
      Type = "Application Server"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name = "${local.name_prefix}-app-volume"
      Type = "Application Server Volume"
    })
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-app-launch-template"
    Type = "Launch Template"
  })
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name                = "${local.name_prefix}-app-asg"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = var.target_group_arns
  health_check_type   = var.health_check_type
  health_check_grace_period = var.health_check_grace_period

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Instance refresh configuration
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 300
    }
  }

  # Enable instance protection during scale-in
  protect_from_scale_in = false

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-app-asg"
    propagate_at_launch = false
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${local.name_prefix}-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 300
  autoscaling_group_name = aws_autoscaling_group.app.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${local.name_prefix}-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 300
  autoscaling_group_name = aws_autoscaling_group.app.name
}

# Target Tracking Scaling Policy for CPU
resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name               = "${local.name_prefix}-cpu-target-tracking"
  policy_type        = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.app.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.target_cpu_utilization
  }
}

# Target Tracking Scaling Policy for Request Count
resource "aws_autoscaling_policy" "request_count_target_tracking" {
  name               = "${local.name_prefix}-request-count-target-tracking"
  policy_type        = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.app.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = var.alb_target_group_label
    }
    target_value = var.target_request_count
  }
}

# CloudWatch Alarms for Auto Scaling
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${local.name_prefix}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-high-cpu-alarm"
    Type = "CloudWatch Alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${local.name_prefix}-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "20"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-low-cpu-alarm"
    Type = "CloudWatch Alarm"
  })
}

# Data source for AWS region
data "aws_region" "current" {}

# Bastion Host for SSH Tunneling to RDS
resource "aws_instance" "bastion" {
  ami                         = var.ami_id
  instance_type              = "t3.micro"
  key_name                   = var.key_name
  subnet_id                  = var.public_subnet_ids[0]
  vpc_security_group_ids     = [var.bastion_security_group_id]
  associate_public_ip_address = true
  
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = base64encode(templatefile("${path.module}/bastion_user_data.sh", {
    mysql_endpoint    = var.mysql_endpoint
    postgres_endpoint = var.postgres_endpoint
    aws_region       = data.aws_region.current.name
  }))

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-bastion"
    Type = "Bastion Host"
    Purpose = "SSH Tunnel for RDS Access"
  })
}

# Dedicated Metabase Instance (3rd EC2 for BI Tool)
resource "aws_instance" "metabase" {
  ami                    = var.ami_id
  instance_type         = var.instance_type
  key_name              = var.key_name
  subnet_id             = var.private_subnet_ids[0]
  vpc_security_group_ids = [var.app_security_group_id]
  
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = base64encode(<<-EOF
#!/bin/bash
# Enhanced Metabase setup with proper Docker Compose installation
yum update -y
yum install -y docker git htop vim curl wget unzip jq awscli at postgresql15

# Start and enable Docker
systemctl start docker
systemctl enable docker
systemctl start atd
systemctl enable atd

# Add ec2-user to docker group
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Create Metabase directory
mkdir -p /opt/metabase
chown ec2-user:ec2-user /opt/metabase

# Get DB credentials and extract values
DB_SECRET=$(aws secretsmanager get-secret-value --secret-id ${var.postgres_secret_arn} --region ${data.aws_region.current.name} --query SecretString --output text)
DB_HOST_RAW=$(echo $DB_SECRET | jq -r .endpoint)
# Remove port number from hostname if present
DB_HOST=$(echo $DB_HOST_RAW | sed 's/:.*$//')
DB_USER=$(echo $DB_SECRET | jq -r .username)
DB_PASS=$(echo $DB_SECRET | jq -r .password)
DB_NAME=$(echo $DB_SECRET | jq -r .dbname)

# Create environment file with correct hostname
cat > /opt/metabase/.env << ENVEOF
MB_DB_TYPE=postgres
MB_DB_DBNAME=$DB_NAME
MB_DB_PORT=5432
MB_DB_USER=$DB_USER
MB_DB_PASS=$DB_PASS
MB_DB_HOST=$DB_HOST
MB_JETTY_HOST=0.0.0.0
MB_JETTY_PORT=3000
ENVEOF

# Create docker-compose configuration
cat > /opt/metabase/docker-compose.yml << COMPOSEEOF
version: '3.8'
services:
  metabase:
    image: metabase/metabase:v0.47.7
    container_name: metabase
    volumes:
      - metabase-data:/metabase-data
    env_file:
      - .env
    ports:
      - "3000:3000"
    restart: unless-stopped
volumes:
  metabase-data:
    driver: local
COMPOSEEOF

# Set proper ownership
chown ec2-user:ec2-user /opt/metabase/.env /opt/metabase/docker-compose.yml

# Create systemd service for Metabase
cat > /etc/systemd/system/metabase.service << SERVICEEOF
[Unit]
Description=Metabase BI Tool
Requires=docker.service
After=docker.service
StartLimitIntervalSec=0

[Service]
Type=oneshot
RemainAfterExit=yes
User=root
WorkingDirectory=/opt/metabase
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Enable and start Metabase service
systemctl daemon-reload
systemctl enable metabase.service

# Start Metabase with retry logic
cd /opt/metabase
for i in {1..3}; do
  echo "Starting Metabase attempt $i..."
  /usr/local/bin/docker-compose up -d && break
  sleep 10
done

# Verify Metabase is running
sleep 30
if docker ps | grep -q metabase; then
  echo "✅ Metabase setup completed successfully"
  systemctl start metabase.service
else
  echo "❌ Metabase setup failed"
  exit 1
fi

echo "Metabase setup completed"
EOF
  )

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-metabase"
    Type = "BI Tool Server"
    Purpose = "Metabase Business Intelligence"
  })
}
