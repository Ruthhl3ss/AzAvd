function Add-AvdApplicationGroupPermissions {
    <#
    .SYNOPSIS
    Adds permissions to an Azure Virtual Desktop Applicationgroup
    .DESCRIPTION
    The function will add permissions to an Azure Virtual Desktop Applicationgroup. This can be a user or a group.
    .PARAMETER ApplicationGroupName
    Enter the AVD application group name
    .PARAMETER ResourceGroupName
    Enter the AVD application group resourcegroup name
    .PARAMETER UserPrincipalName
    Provide the user principal name (eg. user@domain.com)
    .PARAMETER groupName
    Provide the group name (eg. All Users)
    .EXAMPLE
    Add-AvdApplicationGroupPermissions -ApplicationGroupName avd-application-group -ResourceGroupName rg-avd-01 -UserPrincipalName user@domain.com
    .EXAMPLE
    Add-AvdApplicationGroupPermissions -ApplicationGroupName avd-application-group -ResourceGroupName rg-avd-01 -GroupName "All Users"
    #>
    [CmdletBinding(DefaultParameterSetName = 'User')]
    param
    (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ApplicationGroupName,
    
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceGroupName,
    
        [parameter(Mandatory, ParameterSetName = 'User')]
        [ValidateNotNullOrEmpty()]
        [string]$UserPrincipalName,

        [parameter(ParameterSetName = 'Group')]
        [ValidateNotNullOrEmpty()]
        [string]$groupName
        
    )
    Begin {
        Write-Verbose "Start searching"
        AuthenticationCheck
        $apiVersion = "?api-version=2021-04-01-preview"
    }
    Process {
        $graphToken = GetAuthToken -resource $Script:GraphApiUrl
        switch ($PsCmdlet.ParameterSetName) {
            User {
                Write-Verbose "UPN $UserPrincipalName provided, looking for user in Azure AD"
                $graphUrl = $Script:GraphApiUrl + "/" + $script:GraphApiVersion + "/users/" + $UserPrincipalName
                $identityInfo = Invoke-RestMethod -Method GET -Uri $graphUrl -Headers $graphToken
            }
            Group {
                Write-Verbose "Group name $groupName provided, looking for group in Azure AD"
                $graphUrl = $Script:GraphApiUrl + "/" + $script:GraphApiVersion + "/groups?`$filter=displayName eq '$groupName'"
                $identityInfo = (Invoke-RestMethod -Method GET -Uri $graphUrl -Headers $graphToken).value
            }
        }

        $token = GetAuthToken -resource $script:AzureApiUrl
        $applicationGroup = Get-AvdApplicationGroup -ApplicationGroupName $ApplicationGroupName -ResourceGroupName $ResourceGroupName
        $guid = (New-Guid).Guid
        $url = $script:AzureApiUrl+"/"+$applicationGroup.id+"/providers/Microsoft.Authorization/roleAssignments/$($guid)"+$apiVersion
       
        # Used ID 1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63 is default built-in role Desktop Virtualization User.
        # Source: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#desktop-virtualization-user
        $body = @{
            properties = @{
                roleDefinitionId = "/subscriptions/"+$script:subscriptionId+"/providers/Microsoft.Authorization/roleDefinitions/1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63"
                principalId = $identityInfo.id
            }
        }
        $jsonBody = $body | ConvertTo-Json
        $parameters = @{
            uri     = $url
            Method  = "PUT"
            Headers = $token
            Body    = $jsonBody
        }
        Invoke-RestMethod @parameters
    }
}