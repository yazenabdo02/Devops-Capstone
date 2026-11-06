# What broke, and how it was debugged

## The k3s control-plane never came up

**Symptom.** After the first `terraform apply`, the control-plane instance never showed up in
SSM, and `aws ssm send-command` failed with "Instances not in a valid state". One worker did
register, which proved the NAT instance and the network were fine.

**Debugging.** SSM was no help, so I read the boot log with
`aws ec2 get-console-output --instance-id <id> --latest`. It ended with
`cc_scripts_user.py: Failed to run module scripts-user` only 8 seconds after boot, preceded
by a dump of `bash` usage options. A usage dump means bash rejected an option, not that a
download or a package install failed.

**Root cause.** I had written the two `.sh.tpl` user-data templates from Windows PowerShell,
which saves lines ending in CRLF. On Linux, bash read `set -euxo pipefail\r` as an invalid
option, so the script died before k3s was installed, on the control-plane and on the workers.

**Fix.**
1. Rewrote both templates with LF line endings and checked that no `\r` was left.
2. Added a `.gitattributes` (`*.sh` and `*.tpl` as `eol=lf`) so it cannot come back, and
   generated all later scripts with LF.
3. Forced the replacement of the Auto Scaling Group and of its target-group attachment
   (`terraform apply -replace=...`), because the old workers had already failed and the
   ALB target group had lost its targets when the group was replaced.

After that all three nodes reached `Ready` and the ALB targets turned `healthy`.

**Lesson.** When a machine misbehaves right after boot, read the console output and the
cloud-init log first. Also, a script that works on one OS is not guaranteed to work after
being written by another OS's tools.

## Other problems met along the way

- SQLite containers could not write to a fresh volume mounted at `/data` (owned by root);
  fixed by creating the directory and giving it to the unprivileged user in the Dockerfile.
- `docker login` to ECR failed with 400 from PowerShell 5.1 because of how it pipes text;
  the pipe was run through `cmd` instead.
- An organization SCP blocks creating the GitHub OIDC provider; see the README for how the
  repository handles it.
- `terraform destroy` timed out waiting for RDS; explicit create/delete timeouts were added.
- The first runs of the Terraform and Deploy workflows (#1) failed because the workflow
  files were still empty; they pass from the next commit on.