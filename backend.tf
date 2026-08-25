terraform {
  backend "remote" {
    organization = "async_furious"

    workspaces {
      name = "tc3-db-hml"
    }
  }
}
