# Copyright (c) 2023 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

data "oci_identity_domain" "grp_domain" {
  for_each = (var.identity_domain_groups_configuration != null ) ? (var.identity_domain_groups_configuration["groups"] != null ? var.identity_domain_groups_configuration["groups"] : {}) : {}
    domain_id = each.value.identity_domain_id != null ? each.value.identity_domain_id : var.identity_domain_groups_configuration.default_identity_domain_id
}

data "oci_identity_domains_users" "these" {
  for_each = local.identity_domains
    idcs_endpoint = each.value[0]
    user_filter = "active eq true"
}

locals {

  identity_domains = merge({for k,g in try(var.identity_domain_groups_configuration.groups,{}) : coalesce(g.identity_domain_id,var.identity_domain_groups_configuration.default_identity_domain_id) => oci_identity_domain.these[coalesce(g.identity_domain_id,var.identity_domain_groups_configuration.default_identity_domain_id)].url... if length(g.members) > 0 && length(regexall("^ocid1.*$",coalesce(g.identity_domain_id,var.identity_domain_groups_configuration.default_identity_domain_id))) == 0}, {for k,g in try(var.identity_domain_groups_configuration.groups,{}) : coalesce(g.identity_domain_id,var.identity_domain_groups_configuration.default_identity_domain_id) => data.oci_identity_domain.grp_domain[k].url... if length(g.members) > 0 && length(regexall("^ocid1.*$",coalesce(g.identity_domain_id,var.identity_domain_groups_configuration.default_identity_domain_id))) > 0})

  users =  { for k,g in (var.identity_domain_groups_configuration != null ? var.identity_domain_groups_configuration["groups"]: {}) : k =>
      { for u in data.oci_identity_domains_users.these[coalesce(g.identity_domain_id,var.identity_domain_groups_configuration.default_identity_domain_id)].users : u.user_name => u.id... } if length(g.members) > 0 }
}

resource "oci_identity_domains_group" "these" {
  for_each = var.identity_domain_groups_configuration != null ? (try(var.identity_domain_groups_configuration.ignore_external_membership_updates,true) == true ? var.identity_domain_groups_configuration.groups : {}) : {}
    lifecycle {
      ignore_changes = [ members ]
      precondition {
        condition = length(each.value.members) > 0 ? length(setsubtract(toset(each.value.members),toset([for m in each.value.members : m if contains(keys(local.users[each.key]),m)]))) == 0 : true
        error_message = length(each.value.members) > 0 ? "VALIDATION FAILURE: following provided usernames in \"members\" attribute of group \"${each.key}\" do not exist or are not active\": ${join(", ",setsubtract(toset(each.value.members),toset([for m in each.value.members : m if contains(keys(local.users[each.key]),m)])))}. Please either correct their spelling or activate them." : ""
      }
    }
    #attribute_sets = ["all"]
    idcs_endpoint = contains(keys(oci_identity_domain.these),coalesce(each.value.identity_domain_id,"None")) ? oci_identity_domain.these[each.value.identity_domain_id].url : (contains(keys(oci_identity_domain.these),coalesce(var.identity_domain_groups_configuration.default_identity_domain_id,"None") ) ? oci_identity_domain.these[var.identity_domain_groups_configuration.default_identity_domain_id].url : data.oci_identity_domain.grp_domain[each.key].url)
    display_name = each.value.name
    schemas = ["urn:ietf:params:scim:schemas:core:2.0:Group","urn:ietf:params:scim:schemas:oracle:idcs:extension:requestable:Group","urn:ietf:params:scim:schemas:oracle:idcs:extension:OCITags","urn:ietf:params:scim:schemas:oracle:idcs:extension:group:Group"]
    urnietfparamsscimschemasoracleidcsextensiongroup_group {
        creation_mechanism = "api"
        description = each.value.description
    }
    dynamic "members" {
      for_each = length(each.value.members) > 0 ? each.value.members : []
        iterator = member
        content {
          type = "User"
          value = local.users[each.key][member.value][0]
        }
    }
    urnietfparamsscimschemasoracleidcsextension_oci_tags {
      dynamic "defined_tags" {
        for_each = each.value.defined_tags != null ? each.value.defined_tags : (var.identity_domain_groups_configuration.default_defined_tags !=null ? var.identity_domain_groups_configuration.default_defined_tags : {})
          content {
            key = split(".",defined_tags["key"])[1]
            namespace = split(".",defined_tags["key"])[0]
            value = defined_tags["value"]
          }
      }
      dynamic "freeform_tags" {
        for_each = each.value.freeform_tags != null ? merge(local.cislz_module_tag,each.value.freeform_tags) : (var.identity_domain_groups_configuration.default_freeform_tags != null ? merge(local.cislz_module_tag,var.identity_domain_groups_configuration.default_freeform_tags) : local.cislz_module_tag)
        content {
          key = freeform_tags["key"]
          value = freeform_tags["value"]
        }
      }
    }
    urnietfparamsscimschemasoracleidcsextensionrequestable_group {
        requestable =  each.value.requestable
    }
}

resource "oci_identity_domains_group" "these_with_external_membership_updates" {
  for_each = var.identity_domain_groups_configuration != null ? (try(var.identity_domain_groups_configuration.ignore_external_membership_updates,true) == false ? var.identity_domain_groups_configuration.groups : {}) : {}
    lifecycle {
      precondition {
        condition = length(each.value.members) > 0 ? length(setsubtract(toset(each.value.members),toset([for m in each.value.members : m if contains(keys(local.users[each.key]),m)]))) == 0 : true
        error_message = length(each.value.members) > 0 ? "VALIDATION FAILURE: following provided usernames in \"members\" attribute of group \"${each.key}\" do not exist or are not active\": ${join(", ",setsubtract(toset(each.value.members),toset([for m in each.value.members : m if contains(keys(local.users[each.key]),m)])))}. Please either correct their spelling or activate them." : ""
      }
    }
    #attribute_sets = ["all"]
    idcs_endpoint = contains(keys(oci_identity_domain.these),coalesce(each.value.identity_domain_id,"None")) ? oci_identity_domain.these[each.value.identity_domain_id].url : (contains(keys(oci_identity_domain.these),coalesce(var.identity_domain_groups_configuration.default_identity_domain_id,"None") ) ? oci_identity_domain.these[var.identity_domain_groups_configuration.default_identity_domain_id].url : data.oci_identity_domain.grp_domain[each.key].url)
    display_name = each.value.name
    schemas = ["urn:ietf:params:scim:schemas:core:2.0:Group","urn:ietf:params:scim:schemas:oracle:idcs:extension:requestable:Group","urn:ietf:params:scim:schemas:oracle:idcs:extension:OCITags","urn:ietf:params:scim:schemas:oracle:idcs:extension:group:Group"]
    urnietfparamsscimschemasoracleidcsextensiongroup_group {
        creation_mechanism = "api"
        description = each.value.description
    }
    dynamic "members" {
      for_each = length(each.value.members) > 0 ? each.value.members : []
        iterator = member
        content {
          type = "User"
          value = local.users[each.key][member.value][0]
        }
    }
    urnietfparamsscimschemasoracleidcsextension_oci_tags {
      dynamic "defined_tags" {
        for_each = each.value.defined_tags != null ? each.value.defined_tags : (var.identity_domain_groups_configuration.default_defined_tags !=null ? var.identity_domain_groups_configuration.default_defined_tags : {})
          content {
            key = split(".",defined_tags["key"])[1]
            namespace = split(".",defined_tags["key"])[0]
            value = defined_tags["value"]
          }
      }
      dynamic "freeform_tags" {
        for_each = each.value.freeform_tags != null ? merge(local.cislz_module_tag,each.value.freeform_tags) : (var.identity_domain_groups_configuration.default_freeform_tags != null ? merge(local.cislz_module_tag,var.identity_domain_groups_configuration.default_freeform_tags) : local.cislz_module_tag)
        content {
          key = freeform_tags["key"]
          value = freeform_tags["value"]
        }
      }
    }
    urnietfparamsscimschemasoracleidcsextensionrequestable_group {
        requestable = each.value.requestable
    }
}