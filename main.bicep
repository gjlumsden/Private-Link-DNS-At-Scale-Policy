targetScope = 'subscription'

param managedIdentityLocation string
param dnsZones array
param dnsZoneResourceGroupName string
param hubNetworkResourceGroup string
param hubNetworkName string 

resource dnsZoneResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: dnsZoneResourceGroupName
}

module dnsZonesDeploy 'modules/private-dns-zones.bicep' = {
  scope: resourceGroup(dnsZoneResourceGroupName)
  name: '${deployment().name}-zones'
  params: {
    dnsZones: dnsZones
    hubNetworkName: hubNetworkName
    hubNetworkResourceGroup: hubNetworkResourceGroup
  }
}

resource deployDnsRecordsPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'Deploy-DNS-Records-For-Private-Link'
  properties: {
    description: 'Deploys DNS Zone Groups and corresponding DNS Records for Private Link resources.'
    displayName: 'Deploy DNS Zone Groups and DNS Records for Private Links'
    mode: 'Indexed'
    policyType: 'Custom'
    parameters: {
      privateDnsZoneId: {
        type: 'String'
        metadata: {
          displayName: 'privateDnsZoneId'
          strongType: 'Microsoft.Network/privateDnsZones'
        }
      }
      groupId: {
        type: 'String'
        metadata: {
          displayName: 'groupId'
        }
      }
    }
    policyRule: loadJsonContent('policies/deploy-dns-for-private-link/policy-rule.json')
  }
}

resource denyPlDnsZoneDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'Deny-Private-Link-DNS-Zones'
  properties: {
    description: 'This policy restricts creation of private DNS zones with the `privatelink` prefix.'
    displayName: 'Deny-PrivateDNSZone-PrivateLink'
    mode: 'Indexed'
    policyType: 'Custom'
    policyRule: loadJsonContent('policies/deny-privatelink-DNS-zones/policy-rule.json')
  }
}

resource policyAssignmentsDeployDnsRecords 'Microsoft.Authorization/policyAssignments@2021-06-01' = [for (zone, i) in dnsZones: {
  name: 'private-link-dns-config-${zone.groupName}-assignment'
  identity: {
    type: 'SystemAssigned'
  }
  location: managedIdentityLocation
  properties: {
    policyDefinitionId: deployDnsRecordsPolicyDefinition.id
    displayName: 'Deploy DNS Zone Groups and DNS Records for ${zone.groupName} Private Link'
    description: 'Deploys DNS Zone Groups and corresponding DNS Records for Private Link resources for ${zone.groupName} and ${zone.dnsZone}'
    parameters: {
      privateDnsZoneId: {
        value: dnsZonesDeploy.outputs.dnsZoneIds[i]
      }
      groupId: {
         value: zone.groupName
      }
    }
  }
}]
resource policyAssignmentsDenyPlDnsZones 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: 'deny-private-link-dns-zones-assignment'
  properties: {
    policyDefinitionId: denyPlDnsZoneDefinition.id
    displayName: 'Deny-PrivateDNSZone-PrivateLink'
    description: 'This policy restricts creation of private DNS zones with the `privatelink` prefix'
    notScopes: [
      dnsZoneResourceGroup.id
    ]
  }
}

module roleAssignments 'modules/role-assignments.bicep' = [for (zone, i) in dnsZones: {
  name: '${deployment().name}-role-assignments-${i}'
  params:{
    policyAssignmentName: policyAssignmentsDeployDnsRecords[i].name
  }
}]
