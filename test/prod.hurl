# API requires a valid token

# GET latest record
GET {{host}}/api/collection/latest
Content-Type: application/json
HTTP 401

GET {{host}}/api/collection/latest
Content-Type: application/json
Authorization: Bearer {{api_token}}
HTTP 200

[Asserts]
# Record data is returned - one property is enough
jsonpath "$.title" != null

[Captures]
cover-url: jsonpath "$.cover_url"

# GET cover image
GET {{cover-url}}
HTTP 401

GET {{cover-url}}
Authorization: Bearer {{api_token}}
HTTP 200
