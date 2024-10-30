import requests
import json

# Import the config file with the URL and Token
with open('./config.json', 'r') as f:
    config = json.load(f)

instance_url = config['instance_url']
token = config['token']

# Build the api url for the Tanium Gateway
api_path = "/plugin/products/gateway/graphql"
api_url = instance_url + api_path

# Create a requests session and add the token to headers
session = requests.Session()
session.headers.update({'session': token})

# A helper function to create the payload and include variables if needed
def graphql_query_body(query: str, variables: dict|None = None) -> dict:
    body = {
        "query": query
    }

    if variables is not None:
        body["variables"] = variables # type: ignore

    return body

# Create a query string
query = """mutation createTaniumAction($comment: String, $name: String, $packageName_windows: String, $packageName_non_windows: String, $params: [String!], $actionGroupName: String!, $filters: [ComputerGroupFilter!], $include_windows: Boolean!, $include_non_windows: Boolean!) {
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
}"""

# Import the filter_value from config.json
computer_name_filter_value = config['computer_name_filter_value']
custom_tag_filter_value = config['custom_tag_filter_value']
custom_tags = config['custom_tags']

# Create a dictionary with variables
variables = {
  "name": "Add Tag via GraphQL",
  "comment": "GraphQL Tagging",
  "packageName_windows": "Custom Tagging - Add Tags",
  "packageName_non_windows": "Custom Tagging - Add Tags (Non-Windows)",
  "params": custom_tags,
  "actionGroupName": "Default - All Computers",
  "filters": [
    {
      "negated": False,
      "any": False,
      "sensor": {
        "name": "Computer Name"
      },
      "op": "CONTAINS",
      "value": computer_name_filter_value
    },
    {
      "negated": False,
      "any": False,
      "sensor": {
        "name": "Custom Tag Exists",
        "params": [
          {
            "name": "tag",
            "value": custom_tag_filter_value
          }
        ]
      },
      "op": "EQ",
      "value": "true"
    }
  ],
  "include_windows": True,
  "include_non_windows": True
}

# Use the helper function to create the payload
body = graphql_query_body(query, variables)

# Post the request
response = session.post(api_url, json = body)

# View the raw data
#print(json.dumps(response.json(), indent=2))

# Clean up the response using a list comprehension
data = [{"platform": platform, "action_id": data['action']['id']} for platform, data in response.json()['data'].items()]
print(json.dumps(data, indent=2))