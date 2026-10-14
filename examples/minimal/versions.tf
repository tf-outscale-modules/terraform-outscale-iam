terraform {
  required_version = ">= 1.10.0"

  required_providers {
    outscale = {
      source  = "outscale/outscale"
      version = "~> 1.8"
    }
  }
}

provider "outscale" {
  # Configuration via environment variables:
  # OSC_ACCESS_KEY, OSC_SECRET_KEY, OSC_REGION
}
