#!/usr/bin/env python3
"""
Script to modify main.tf to work without Application Load Balancer.
Removes ALB resources and makes ECS service publicly accessible.
"""

with open('main.tf', 'r') as f:
    content = f.read()

# Remove ALB security group, keep only ECS and RDS
lines = content.split('\n')
output = []
skip_until_next_resource = False
resource_depth = 0

for i, line in enumerate(lines):
    # Skip ALB-related resources
    if 'resource "aws_lb' in line or 'resource "aws_security_group" "alb"' in line:
        skip_until_next_resource = True
        resource_depth = 0
        continue

    if skip_until_next_resource:
        # Count braces to know when resource ends
        resource_depth += line.count('{') - line.count('}')
        if resource_depth <= 0 and (line.strip() == '' or line.strip().startswith('resource') or line.strip().startswith('#')):
            skip_until_next_resource = False
            if not line.strip().startswith('resource'):
                output.append(line)
        continue

    # Modify ECS service to remove ALB and add public IP
    if 'resource "aws_ecs_service" "app"' in line:
        output.append(line)
        # Continue until we find network_configuration
        continue

    # Remove load_balancer block from ECS service
    if 'load_balancer {' in line:
        skip_until_next_resource = True
        resource_depth = 1
        continue

    # Change assign_public_ip to true in network_configuration
    if 'assign_public_ip = false' in line:
        output.append(line.replace('false', 'true'))
        continue

    # Remove ALB references from outputs
    if 'output "alb_url"' in line:
        skip_until_next_resource = True
        resource_depth = 0
        continue

    output.append(line)

# Write modified content
with open('main.tf.noalb', 'w') as f:
    f.write('\n'.join(output))

print("Created main.tf.noalb")
