#!/usr/bin/env bash
# Just-in-time access to the dev Key Vault and storage firewalls.
# Terraform ignores these IP lists; the default action stays Deny.
#   add    allow this machine's current public IP
#   remove remove this machine's current public IP
#   reset  remove every allowed IP, then allow only the current one (use after your IP changes)
#   list   show the allowed IPs
set -euo pipefail

action="${1:?usage: $0 add|remove|reset|list}"
rg="${MSI_DEV_RG:-rg-msi-dev}"
kv="$(az keyvault list -g "$rg" --query '[0].name' -o tsv)"
sa="$(az storage account list -g "$rg" --query '[0].name' -o tsv)"
[[ -n "$kv" && -n "$sa" ]] || { echo "No Key Vault or storage account found in $rg. Check: az account show" >&2; exit 1; }

kv_ips() { az keyvault show -g "$rg" --name "$kv" --query 'properties.networkAcls.ipRules[].value' -o tsv; }
sa_ips() { az storage account network-rule list -g "$rg" --account-name "$sa" --query 'ipRules[].ipAddressOrRange' -o tsv; }

kv_rule() { az keyvault network-rule "$1" -g "$rg" --name "$kv" --ip-address "$2" -o none; }
sa_rule() { az storage account network-rule "$1" -g "$rg" --account-name "$sa" --ip-address "${2%/32}" -o none; }

case "$action" in
  add|remove)
    ip="$(curl -fsS https://api.ipify.org)"
    kv_rule "$action" "$ip/32"
    sa_rule "$action" "$ip"
    echo "${action}: current IP on $kv and $sa"
    ;;
  reset)
    for old in $(kv_ips); do kv_rule remove "$old"; done
    for old in $(sa_ips); do sa_rule remove "$old"; done
    "$0" add
    ;;
  list)
    echo "$kv:"; kv_ips
    echo "$sa:"; sa_ips
    ;;
  *)
    echo "usage: $0 add|remove|reset|list" >&2
    exit 1
    ;;
esac
