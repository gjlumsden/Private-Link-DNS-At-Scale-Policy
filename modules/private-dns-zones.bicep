param dnsZones array
param hubNetworkResourceGroup string
param hubNetworkName string

resource vnetToLinkZones 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: hubNetworkName
  scope: resourceGroup(hubNetworkResourceGroup)
}

resource privateLinkZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for zone in dnsZones: {
  name: zone.dnsZone
  location: 'global'
}]

resource privateZoneLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (zone, i) in dnsZones: {
  name: '${zone.dnsZone}-${vnetToLinkZones.name}-link'
  parent: privateLinkZones[i]
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetToLinkZones.id
    }
  }
}]

output dnsZoneIds array = [for (zone, i) in dnsZones: privateLinkZones[i].id]
