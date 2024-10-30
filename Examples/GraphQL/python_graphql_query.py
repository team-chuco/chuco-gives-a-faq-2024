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
query = """query getEndpoints($value: String) {
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
}"""

# Import the filter_value from config.json
filter_value = config['computer_name_filter_value']

# Create a dictionary with variables
variables = {
    "value": filter_value
}

# Use the helper function to create the payload
body = graphql_query_body(query, variables)

# Post the request
response = session.post(api_url, json = body)

# View the raw data
#print(json.dumps(response.json(), indent=2))

# Clean up the response using a list comprehension
data = [item['node'] for item in response.json()['data']['endpoints']['edges']]
print(json.dumps(data, indent=2))