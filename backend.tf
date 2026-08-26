terraform {
  # Partial configuration: bucket/key/region come from backend.hcl, which the
  # workflow generates per environment from the live Lab account ID.
  backend "s3" {}
}
