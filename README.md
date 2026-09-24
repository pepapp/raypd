rapyd-sentinel/
├── Makefile                  # fmt-check / init / validate / lint / plan-*  (no apply target, apply is CI-only)
├── .tflint.hcl               # terraform + aws rulesets, lints local modules too
├── bootstrap/                # run once: state bucket + GitHub OIDC plan/apply roles
└── terraform/
    ├── envs/poc/             # root stack: wires modules, S3 backend, 2 providers (one without tags, for IAM)
    └── modules/
        ├── vpc/              # public/private subnets per AZ, NAT per AZ, locked-down default SG, flow logs
        ├── vpc-peering/      # peering + DNS resolution + routes on private route tables only
        └── flow-logs-bucket/ # SSE-S3, TLS-only, lifecycle, scoped log-delivery policy