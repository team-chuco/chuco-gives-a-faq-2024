# Import the config file with the URL and Token
$config = Get-Content -Path './config.json' | ConvertFrom-Json

$instanceUrl = $config.instance_url
$token = $config.token

# Build the api url for the Tanium Gateway
$apiPath = "/plugin/products/gateway/graphql"
$apiUrl = $instanceUrl + $apiPath

# Create a PowerShell session and add the token to headers
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$session.Headers.Add("session", $token)

# Create a query string
$query = @'
mutation createTaniumAction($comment: String, $name: String, $packageName_windows: String, $packageName_non_windows: String, $params: [String!], $actionGroupName: String!, $filters: [ComputerGroupFilter!], $include_windows: Boolean!, $include_non_windows: Boolean!) {
  ...windows_action @include(if: $include_windows)
  ...non_windows_action @include(if: $include_non_windows)
}

fragment windows_action on Mutation {
  windows: actionCreate(
    input: {comment: $comment, name: $name, package: {name: $packageName_windows, params: $params}, targets: {platforms: [Windows], actionGroup: {name: $actionGroupName}, targetGroup: {filter: {filters: $filters}}}}
  ) {
    ...actionPayload
  }
}

fragment non_windows_action on Mutation {
  non_windows: actionCreate(
    input: {comment: $comment, name: $name, package: {name: $packageName_non_windows, params: $params}, targets: {platforms: [Linux, Mac, AIX, Solaris], actionGroup: {name: $actionGroupName}, targetGroup: {filter: {filters: $filters}}}}
  ) {
    ...actionPayload
  }
}

fragment actionPayload on ActionCreatePayload {
  action {
    id
  }
  error {
    message
  }
}
'@

# Import the filter_value from config.json
$computerNameFilterValue = $config.computer_name_filter_value
$customTagFilterValue = $config.custom_tag_filter_value
$customTags = $config.custom_tags

# Create a dictionary with variables
$variables = @{
  name                  = "Add Tag via GraphQL"
  comment               = "GraphQL Tagging"
  packageName_windows    = "Custom Tagging - Add Tags"
  packageName_non_windows = "Custom Tagging - Add Tags (Non-Windows)"
  params                = $customTags
  actionGroupName       = "Default - All Computers"
  filters               = @(
    @{
      negated = $false
      any     = $false
      sensor  = @{
        name = "Computer Name"
      }
      op    = "CONTAINS"
      value = $computerNameFilterValue
    }
    @{
      negated = $false
      any     = $false
      sensor  = @{
        name   = "Custom Tag Exists"
        params = @(
          @{
            name  = "tag"
            value = $customTagFilterValue
          }
        )
      }
      op    = "EQ"
      value = "true"
    }
  )
  include_windows     = $true
  include_non_windows = $true
}

# Create the payload
$body = @{
    query = $query
    variables = $variables
} | ConvertTo-Json -Depth 10

# Post the request
$response = Invoke-WebRequest -Uri $apiUrl -Method Post -Body $body -ContentType "application/json" -WebSession $session

# Convert the response to a PowerShell object
$responseJson = $response.Content | ConvertFrom-Json

# Clean up the response using a ForEach-Object loop
$data = @()
foreach ($platform in $responseJson.data.PSObject.Properties.Name) {
  $actionId = $responseJson.data.$platform.action.id
  $data += @{ platform = $platform; action_id = $actionId }
}

# Output the data
$data | ConvertTo-Json -Depth 3