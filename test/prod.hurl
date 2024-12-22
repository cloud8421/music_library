# API requires a valid token
GET https://music-library.claudio-ortolina.org/api/collection/latest
Content-Type: application/json
HTTP 401

GET https://music-library.claudio-ortolina.org/api/collection/latest
Content-Type: application/json
Authorization: Bearer {{api_token}}
HTTP 200

[Asserts]
# Record data is returned - one property is enough
jsonpath "$.title" != null
