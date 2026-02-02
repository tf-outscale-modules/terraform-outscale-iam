terraform {
  required_version = ">= 1.10.0"

  required_providers {
    outscale = {
      source  = "outscale/outscale"
      version = "~> 1.3"
    }
  }
}

provider "outscale" {
  # Configuration via environment variables:
  # OUTSCALE_ACCESSKEYID, OUTSCALE_SECRETKEYID, OUTSCALE_REGION
}
