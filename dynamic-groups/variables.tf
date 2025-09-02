variable "tenancy_ocid" {
  type        = string
  description = "The OCID of the tenancy."
}

variable "dynamic_groups_configuration" {
  type = any
  default = {
    "default_defined_tags" : null,
    "default_freeform_tags" : {
      "ManagedBy" : "CIS-LZ"
    },
    "dynamic_groups" : {}
  }
}

variable "module_name" {
  type    = string
  default = "cis-landing-zone-iam-dynamic-groups"
}
