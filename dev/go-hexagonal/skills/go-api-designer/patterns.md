# Go API Designer Patterns

## endpoint-definition-template

Use this template for every endpoint. Each section maps to a specific downstream concern: request/response shapes drive type generation, error responses drive e2e test assertions, and validation rules drive handler implementation.

```
### [METHOD] /api/v1/[resource]

**Purpose:** [what it does]
<!-- One sentence — this becomes the handler function's doc comment -->

**Request:**
- Path params: [param: type — validation]
  <!-- Path params are always required; validate as UUID for entity IDs -->
- Query params: [param: type — default — validation]
  <!-- Always document defaults — handlers must apply them consistently -->
- Body (JSON):
  ```json
  {
    "field": "type — constraints"
  }
  ```
  <!-- Constraints here become validation rules in Step 4 -->

**Response 200:**
```json
{
  "field": "type"
}
```
<!-- This shape becomes the XxxResponse struct in pkg/<context>/ -->

**Error Responses:**
- 400: [validation error conditions]
  <!-- Input format errors — malformed JSON, wrong types -->
- 401: [auth required]
  <!-- Missing or invalid auth token -->
- 403: [insufficient permissions]
  <!-- Valid auth but wrong role/scope -->
- 404: [resource not found]
  <!-- Also returned for IDOR attempts — don't leak existence -->
- 409: [conflict conditions]
  <!-- Uniqueness violations, optimistic locking conflicts -->
- 422: [business rule violations]
  <!-- Domain-level rejections — e.g., "project is archived" -->
  <!-- 422 vs 400: 400 = bad syntax, 422 = valid syntax but violates rules -->

**Validation Rules:**
- field: [min/max length, format, required/optional]
  <!-- Every field must have explicit rules — implicit rules cause bugs -->
```

## request-response-types

Go struct definitions for the `pkg/<context>/` package. These types are shared between inbound handlers and any external consumers. Field tags control JSON serialization behavior.

```go
// CreateXxxRequest defines the expected JSON body for creating a resource
// Place in pkg/<context>/requests.go or a similar shared types file
type CreateXxxRequest struct {
    // json tag must match the API contract exactly — changing it is a breaking change
    Name        string `json:"name"`
    // omitempty means the field is excluded from JSON when empty
    // Use for optional fields to keep responses clean
    Description string `json:"description,omitempty"`
}

// XxxResponse is returned for single-resource endpoints (GET by ID, POST create)
// Place in pkg/<context>/responses.go alongside the request types
type XxxResponse struct {
    ID          string `json:"id"`
    Name        string `json:"name"`
    Description string `json:"description"`
    // Use RFC3339 string format for timestamps — it's unambiguous across timezones
    // The domain model uses time.Time; the converter handles formatting
    CreatedAt   string `json:"created_at"`
}

// XxxListResponse wraps a paginated collection
// Always include Total, Limit, and Offset so clients can calculate pagination
type XxxListResponse struct {
    Items      []XxxResponse `json:"items"`
    // Total is the count of ALL matching records, not just this page
    Total      int           `json:"total"`
    // Limit and Offset echo back the request params for client convenience
    Limit      int           `json:"limit"`
    Offset     int           `json:"offset"`
}
```

## grpc-design-template

Use this template for gRPC service design. Each RPC maps to a service interface method — the same method HTTP handlers call.

```protobuf
// .plan/<feature-slug>/API_DESIGN_GRPC.proto
// This is a DESIGN REFERENCE — not a real proto file.
// The scaffolder creates the actual proto at pkg/<context>/grpc/proto/<context>.proto.

syntax = "proto3";
package <context>;

service <Entity>Service {
  // RPC name matches the service interface method name
  rpc Create<Entity> (Create<Entity>Request) returns (Create<Entity>Response);
  rpc Get<Entity> (Get<Entity>Request) returns (Get<Entity>Response);
  rpc List<Entity>s (List<Entity>sRequest) returns (List<Entity>sResponse);
  rpc Delete<Entity> (Delete<Entity>Request) returns (Delete<Entity>Response);
}

message Create<Entity>Request {
  string scope_id = 1;   // Always first — tenant/project isolation
  string name = 2;
  string description = 3;
}

message Create<Entity>Response {
  string id = 1;
  string name = 2;
  string description = 3;
  string created_at = 4;  // RFC3339 string
}

// Error mapping:
// - InvalidArgument: validation failures (missing fields, bad format)
// - NotFound: entity not found OR IDOR attempt (never leak existence)
// - PermissionDenied: valid auth but wrong role/scope
// - AlreadyExists: uniqueness violations
// - FailedPrecondition: business rule violations (e.g., "project is archived")
```

## error-response-format

Standard error response structure. All endpoints must use this format so clients can parse errors consistently. The `code` field uses domain-specific constants (not HTTP status text) for programmatic error handling.

```json
{
  "error": {
    "code": "DOMAIN_ERROR_CODE",
    "message": "Human readable message"
  }
}
```
<!-- "code" is a domain constant like "PROJECT_ARCHIVED" or "INVALID_UUID", -->
<!-- not an HTTP status code. Clients switch on this field for error handling. -->
<!-- "message" is for developer debugging — never expose internal details. -->
<!-- Adapt the code values to match your domain's error taxonomy. -->
