# Trigger a deploy and capture the deployment ID

GET {{coolify_host}}/api/v1/deploy
Authorization: Bearer {{coolify_token}}
[Query]
uuid: {{coolify_app_uuid}}
HTTP 200
[Captures]
deployment_uuid: jsonpath "$.deployments[0].deployment_uuid"

# Watch the deployment until it's finished
# It normally takes around 5 minutes if no layers are cached,
# We make it longer to account for potential other issues
# Due to a potential bug in Coolify, we need to take the long way around
# instead of querying for the direct deployment UUID.

GET {{coolify_host}}/api/v1/deployments/applications/{{coolify_app_uuid}}?take=1
Authorization: Bearer {{coolify_token}}
[Options]
delay: 20s
retry: 40
retry-interval: 10s
HTTP 200
[Asserts]
jsonpath "$.deployments[0].status" == "finished"
