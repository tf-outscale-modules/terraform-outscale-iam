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
  # Configuration can be provided via environment variables:
  # OUTSCALE_ACCESSKEYID, OUTSCALE_SECRETKEYID, OUTSCALE_REGION
  # Or configure here (not recommended for production):
  # access_key_id  = var.access_key_id
  # secret_key_id  = var.secret_key_id
  # region         = var.region
}
