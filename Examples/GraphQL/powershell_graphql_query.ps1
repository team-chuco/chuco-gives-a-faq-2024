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
query getEndpoints($value: String) {
    endpoints(filter: {path: "name", op: CONTAINS, value: $value}) {
        edges {
            node {
                name
                os {
                    name
                }
                ipAddress
            }
        }
    }
}
'@

# Import the filter_value from config.json
$filterValue = $config.computer_name_filter_value

# Create a dictionary with variables
$variables = @{
    value = $filterValue
}

# Create the payload
$body = @{
    query = $query
    variables = $variables
} | ConvertTo-Json

# Post the request
$response = Invoke-RestMethod -Uri $apiUrl -Method Post -Body $body -ContentType 'application/json' -WebSession $session

# Clean up the response 
$data = $response.data.endpoints.edges | ForEach-Object { $_.node }

# Output the data
$data | ConvertTo-Json -Depth 10