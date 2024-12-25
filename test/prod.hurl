# Make sure application enforces https

GET http://music-library.claudio-ortolina.org
HTTP 301
Location: https://music-library.claudio-ortolina.org/

# API requires a valid token

# GET latest record
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

[Captures]
cover-url: jsonpath "$.cover_url"

# GET cover image
GET {{cover-url}}
HTTP 401

GET {{cover-url}}
Authorization: Bearer {{api_token}}
HTTP 200
