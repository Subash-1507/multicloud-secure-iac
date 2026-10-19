# 0001. Reach EC2 hosts through SSM Session Manager, not SSH

- Status: accepted
- Date: 2026-10-19

## Context

Ansible needs shell access to EC2 instances. The usual approach opens port 22 to an IP allowlist and distributes SSH keys, which leaves an internet-facing port, keys to rotate, and no central record of who ran what.

## Decision

Instances run the SSM agent with an instance profile that allows Session Manager. Ansible connects with the `community.aws.aws_ssm` connection plugin, addressing hosts by instance ID from the `amazon.aws.aws_ec2` dynamic inventory. Security groups have no inbound rules.

## Consequences

- No inbound ports and no SSH keys to leak or rotate.
- Every session is authorised by IAM and logged in CloudTrail.
- SSM needs an S3 bucket to transfer module files; the encrypted data bucket is reused, so the instance role needs `kms:Decrypt`/`kms:GenerateDataKey` on its key.
- Azure hosts still use SSH (Bastion or NSG allowlist) until an equivalent is in place.
