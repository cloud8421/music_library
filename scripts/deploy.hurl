# Trigger a deploy and capture the deployment ID

GET {{coolify_host}}/api/v1/deploy
Authorization: Bearer {{coolify_token}}
[Query]
uuid: {{coolify_app_uuid}}
HTTP 200
[Captures]
deployment_uuid: jsonpath "$.deployments[0].deployment_uuid"

# Watch the deployment until it's finished

GET {{coolify_host}}/api/v1/deployments/{{deployment_uuid}}
Authorization: Bearer {{coolify_token}}
[Options]
delay: 20s
retry: 20
retry-interval: 10s
HTTP 200
[Asserts]
jsonpath "$.status" == "finished"
