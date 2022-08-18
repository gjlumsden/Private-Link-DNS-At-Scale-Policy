targetScope = 'subscription'

param policyAssignmentName string

var rolesToAssign = [
  '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7'
  '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b12aa53e-6015-4669-85d0-8515ebb3ae7f'
]

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2020-09-01' existing = {
  name: policyAssignmentName
}


resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = [for role in rolesToAssign: {
  name: guid(role, policyAssignment.id)
  properties: {
    roleDefinitionId: role
    principalId: policyAssignment.identity.principalId
    principalType: 'ServicePrincipal'
  }
}]
