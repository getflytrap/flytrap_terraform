resource "aws_iam_role" "api_gateway_role" {
  name = "api_gateway_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "api_gateway_sqs_policy" {
  name   = "api_gateway_sqs_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sqs:SendMessage"
      Resource = var.sqs_queue_arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway_sqs_attach" {
  policy_arn = aws_iam_policy.api_gateway_sqs_policy.arn
  role       = aws_iam_role.api_gateway_role.name
}

resource "aws_api_gateway_rest_api" "api" {
  name = var.api_name
}

resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = var.base_api_path
}

resource "aws_api_gateway_resource" "errors" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = var.errors_path
}

resource "aws_api_gateway_resource" "rejections" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = var.rejections_path
}

resource "aws_api_gateway_model" "errors_request_model" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  name        = "ErrorsPostRequestModel"
  content_type = "application/json"
  schema = jsonencode({
    type = "object"
      properties = {
        data = {
          type = "object"
          properties = {
            error = {
              type = "object"
              properties = {
                name = { type = "string" }
                message = { type = "string" }
                stack = { type = "string" }
              }
              required = ["name", "message", "stack"]
            }
            codeContexts = {
              type  = "array"
              items = {
                type = "object"
                properties = {
                  file = { type = "string" }
                  line = { type = "integer" }
                  column = { type = "integer" }
                  context = { type = "string" }
                }
              }
            }
            handled = { type = "boolean" }
            timestamp = { type = "string", format = "date-time" }
            project_id = { type = "string" }
            method = {
              oneOf = [
                { type = "string" },
                { type = "null" }
              ]
            }
            path = {
              oneOf = [
                { type = "string" },
                { type = "null" }
              ]
            }
            ip = {
              oneOf = [
                { type = "string" },
                { type = "null" }
              ]
            }
            os = {
              oneOf = [
                { type = "string" },
                { type = "null" }
              ]
            }
            browser = {
              oneOf = [
                { type = "string" },
                { type = "null" }
              ]
            }
            runtime = {
              oneOf = [
                { type = "string" },
                { type = "null" }
              ]
            }
          }
          required = ["error", "handled", "timestamp", "project_id"]
        }
      }
      required = ["data"]
  })
}

resource "aws_api_gateway_request_validator" "errors_request_validator" {
  rest_api_id                 = aws_api_gateway_rest_api.api.id
  name                        = "ErrorsPostRequestValidator"
  validate_request_body       = true
  validate_request_parameters = false
}

resource "aws_api_gateway_model" "rejections_request_model" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  name        = "RejectionsPostRequestModel"
  content_type = "application/json"
  schema = jsonencode({
    type = "object"
    properties = {
      data = {
        type = "object"
        properties = {
          value = {
            oneOf = [
              { type = "string" },
              { type = "number" },
              { type = "boolean" },
              { type = "object" },
              { type = "null" }
            ]
          }
          handled = { type = "boolean" }
          timestamp = { type = "string", format = "date-time" }
          project_id = { type = "string" }
          method = {
            oneOf = [
              { type = "string" },
              { type = "null" }
            ]
          }
          path = {
            oneOf = [
              { type = "string" },
              { type = "null" }
            ]
          }
          ip = {
            oneOf = [
              { type = "string" },
              { type = "null" }
            ]
          }
          os = {
            oneOf = [
              { type = "string" },
              { type = "null" }
            ]
          }
          browser = {
            oneOf = [
              { type = "string" },
              { type = "null" }
            ]
          }
          runtime = {
            oneOf = [
              { type = "string" },
              { type = "null" }
            ]
          }
        }
        required = ["value", "handled", "timestamp", "project_id"]
      }
    }
    required = ["data"]
  })
}

resource "aws_api_gateway_request_validator" "rejections_request_validator" {
  rest_api_id                 = aws_api_gateway_rest_api.api.id
  name                        = "RejectionsPostRequestValidator"
  validate_request_body       = true
  validate_request_parameters = false
}

resource "aws_api_gateway_method" "options_parent" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.api.id
  http_method   = "OPTIONS"
  authorization = "NONE"
  api_key_required = false
}

resource "aws_api_gateway_method" "options_errors" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.errors.id
  http_method   = "OPTIONS"
  authorization = "NONE"
  api_key_required = false
}

resource "aws_api_gateway_method" "options_rejections" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.rejections.id
  http_method   = "OPTIONS"
  authorization = "NONE"
  api_key_required = false
}

resource "aws_api_gateway_method" "post_errors" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.errors.id
  http_method   = "POST"
  authorization = "NONE"
  api_key_required = true

  request_models = {
    "application/json" = aws_api_gateway_model.errors_request_model.name
  }

  request_validator_id = aws_api_gateway_request_validator.errors_request_validator.id
}

resource "aws_api_gateway_method" "post_rejections" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.rejections.id
  http_method   = "POST"
  authorization = "NONE"
  api_key_required = true

  request_models = {
    "application/json" = aws_api_gateway_model.rejections_request_model.name
  }

  request_validator_id = aws_api_gateway_request_validator.rejections_request_validator.id
}

resource "aws_api_gateway_method_response" "options_parent_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.api.id
  http_method = aws_api_gateway_method.options_parent.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_method_response" "options_errors_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.errors.id
  http_method = aws_api_gateway_method.options_errors.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_method_response" "options_rejections_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.rejections.id
  http_method = aws_api_gateway_method.options_rejections.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_method_response" "errors_post_200_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.errors.id
  http_method = aws_api_gateway_method.post_errors.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Content-Type"                  = true
    "method.response.header.Access-Control-Allow-Origin"   = true
    "method.response.header.Access-Control-Allow-Methods"  = true
    "method.response.header.Access-Control-Allow-Headers"  = true
  }
}

resource "aws_api_gateway_method_response" "errors_post_400_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.errors.id
  http_method = aws_api_gateway_method.post_errors.http_method
  status_code = "400"

  response_parameters = {
    "method.response.header.Content-Type"                  = true
    "method.response.header.Access-Control-Allow-Origin"   = true
    "method.response.header.Access-Control-Allow-Methods"  = true
    "method.response.header.Access-Control-Allow-Headers"  = true
  }
}

resource "aws_api_gateway_method_response" "errors_post_500_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.errors.id
  http_method = aws_api_gateway_method.post_errors.http_method
  status_code = "500"

  response_parameters = {
    "method.response.header.Content-Type"                  = true
    "method.response.header.Access-Control-Allow-Origin"   = true
    "method.response.header.Access-Control-Allow-Methods"  = true
    "method.response.header.Access-Control-Allow-Headers"  = true
  }
}

resource "aws_api_gateway_method_response" "rejections_post_200_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.rejections.id
  http_method = aws_api_gateway_method.post_rejections.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Content-Type"                  = true
    "method.response.header.Access-Control-Allow-Origin"   = true
    "method.response.header.Access-Control-Allow-Methods"  = true
    "method.response.header.Access-Control-Allow-Headers"  = true
  }
}

resource "aws_api_gateway_method_response" "rejections_post_400_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.rejections.id
  http_method = aws_api_gateway_method.post_rejections.http_method
  status_code = "400"

  response_parameters = {
    "method.response.header.Content-Type"                  = true
    "method.response.header.Access-Control-Allow-Origin"   = true
    "method.response.header.Access-Control-Allow-Methods"  = true
    "method.response.header.Access-Control-Allow-Headers"  = true
  }
}

resource "aws_api_gateway_method_response" "rejections_post_500_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.rejections.id
  http_method = aws_api_gateway_method.post_rejections.http_method
  status_code = "500"

  response_parameters = {
    "method.response.header.Content-Type"                  = true
    "method.response.header.Access-Control-Allow-Origin"   = true
    "method.response.header.Access-Control-Allow-Methods"  = true
    "method.response.header.Access-Control-Allow-Headers"  = true
  }
}

resource "aws_api_gateway_integration" "options_parent_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.api.id
  http_method             = aws_api_gateway_method.options_parent.http_method
  integration_http_method = "OPTIONS"
  type                    = "MOCK"

  request_templates = {
    "application/json" = jsonencode(
      {
        statusCode = 200
      }
    )
  }
}

resource "aws_api_gateway_integration" "options_errors_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.errors.id
  http_method             = aws_api_gateway_method.options_errors.http_method
  integration_http_method = "OPTIONS"
  type                    = "MOCK"

  request_templates = {
    "application/json" = jsonencode(
      {
        statusCode = 200
      }
    )
  }
}

resource "aws_api_gateway_integration" "options_rejections_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.rejections.id
  http_method             = aws_api_gateway_method.options_rejections.http_method
  integration_http_method = "OPTIONS"
  type                    = "MOCK"

  request_templates = {
    "application/json" = jsonencode(
      {
        statusCode = 200
      }
    )
  }
}

resource "aws_api_gateway_integration" "sqs_integration_errors" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.errors.id
  http_method             = aws_api_gateway_method.post_errors.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${var.region}:sqs:path/${var.account_id}/${var.sqs_queue_name}"
  credentials             = aws_iam_role.api_gateway_role.arn

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$util.urlEncode($input.body)"
  }
}

resource "aws_api_gateway_integration" "sqs_integration_rejections" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.rejections.id
  http_method             = aws_api_gateway_method.post_rejections.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${var.region}:sqs:path/${var.account_id}/${var.sqs_queue_name}"
  credentials             = aws_iam_role.api_gateway_role.arn

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$input.body"
  }
}

resource "aws_api_gateway_integration_response" "options_parent_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.api.id
  http_method = aws_api_gateway_method.options_parent.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET, POST, OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type, X-Amz-Date, X-Amz-Security-Token, Authorization, X-Api-Key, X-Requested-With, Accept, Access-Control-Allow-Methods, Access-Control-Allow-Origin, Access-Control-Allow-Headers'"
  }

  depends_on = [aws_api_gateway_integration.options_parent_integration]
}

resource "aws_api_gateway_integration_response" "options_errors_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.errors.id
  http_method = aws_api_gateway_method.options_errors.http_method
  status_code = aws_api_gateway_method_response.options_errors_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET, POST, OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type, X-Amz-Date, X-Amz-Security-Token, Authorization, X-Api-Key, X-Requested-With, Accept, Access-Control-Allow-Methods, Access-Control-Allow-Origin, Access-Control-Allow-Headers'"
  }

  depends_on = [aws_api_gateway_integration.options_errors_integration]
}

resource "aws_api_gateway_integration_response" "options_rejections_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.rejections.id
  http_method = aws_api_gateway_method.options_rejections.http_method
  status_code = aws_api_gateway_method_response.options_rejections_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET, POST, OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type, X-Amz-Date, X-Amz-Security-Token, Authorization, X-Api-Key, X-Requested-With, Accept, Access-Control-Allow-Methods, Access-Control-Allow-Origin, Access-Control-Allow-Headers'"
  }

  depends_on = [aws_api_gateway_integration.options_rejections_integration]
}

resource "aws_api_gateway_integration_response" "sqs_200_response_errors" {
  rest_api_id       = aws_api_gateway_rest_api.api.id
  resource_id       = aws_api_gateway_resource.errors.id
  http_method       = aws_api_gateway_method.post_errors.http_method
  status_code       = aws_api_gateway_method_response.errors_post_200_response.status_code
  selection_pattern = "^2[0-9][0-9]"

  response_templates = {
    "application/json" = "{\"message\": \"Successfully processed message\"}"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET, POST, OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type, X-Amz-Date, X-Amz-Security-Token, Authorization, X-Api-Key, X-Requested-With, Accept, Access-Control-Allow-Methods, Access-Control-Allow-Origin, Access-Control-Allow-Headers'"
  }

  depends_on = [aws_api_gateway_integration.sqs_integration_errors]
}

resource "aws_api_gateway_integration_response" "sqs_400_response_errors" {
  rest_api_id       = aws_api_gateway_rest_api.api.id
  resource_id       = aws_api_gateway_resource.errors.id
  http_method       = aws_api_gateway_method.post_errors.http_method
  status_code       = aws_api_gateway_method_response.errors_post_400_response.status_code
  selection_pattern = "^4[0-9][0-9]"

  response_templates = {
    "application/json" = "{\"message\": \"Oversized or invalid request\"}"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET, POST, OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type, X-Amz-Date, X-Amz-Security-Token, Authorization, X-Api-Key, X-Requested-With, Accept, Access-Control-Allow-Methods, Access-Control-Allow-Origin, Access-Control-Allow-Headers'"
  }

  depends_on = [aws_api_gateway_integration.sqs_integration_errors]
}

resource "aws_api_gateway_integration_response" "sqs_500_response_errors" {
  rest_api_id       = aws_api_gateway_rest_api.api.id
  resource_id       = aws_api_gateway_resource.errors.id
  http_method       = aws_api_gateway_method.post_errors.http_method
  status_code       = aws_api_gateway_method_response.errors_post_500_response.status_code
  selection_pattern = "^5[0-9][0-9]"

  response_templates = {
    "application/json" = "{\"message\": \"Internal server error while processing message\"}"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET, POST, OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type, X-Amz-Date, X-Amz-Security-Token, Authorization, X-Api-Key, X-Requested-With, Accept, Access-Control-Allow-Methods, Access-Control-Allow-Origin, Access-Control-Allow-Headers'"
  }

  depends_on = [aws_api_gateway_integration.sqs_integration_errors]
}

resource "aws_api_gateway_integration_response" "sqs_200_response_rejections" {
  rest_api_id       = aws_api_gateway_rest_api.api.id
  resource_id       = aws_api_gateway_resource.rejections.id
  http_method       = aws_api_gateway_method.post_rejections.http_method
  status_code       = aws_api_gateway_method_response.rejections_post_200_response.status_code
  selection_pattern = "^2[0-9][0-9]"

  response_templates = {
    "application/json" = "{\"message\": \"Successfully processed message\"}"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET, POST, OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type, X-Amz-Date, X-Amz-Security-Token, Authorization, X-Api-Key, X-Requested-With, Accept, Access-Control-Allow-Methods, Access-Control-Allow-Origin, Access-Control-Allow-Headers'"
  }

  depends_on = [aws_api_gateway_integration.sqs_integration_rejections]
}

resource "aws_api_gateway_integration_response" "sqs_400_response_rejections" {
  rest_api_id       = aws_api_gateway_rest_api.api.id
  resource_id       = aws_api_gateway_resource.rejections.id
  http_method       = aws_api_gateway_method.post_rejections.http_method
  status_code       = aws_api_gateway_method_response.rejections_post_400_response.status_code
  selection_pattern = "^4[0-9][0-9]"

  response_templates = {
    "application/json" = "{\"message\": \"Oversized or invalid request\"}"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET, POST, OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type, X-Amz-Date, X-Amz-Security-Token, Authorization, X-Api-Key, X-Requested-With, Accept, Access-Control-Allow-Methods, Access-Control-Allow-Origin, Access-Control-Allow-Headers'"
  }

  depends_on = [aws_api_gateway_integration.sqs_integration_rejections]
}

resource "aws_api_gateway_integration_response" "sqs_500_response_rejections" {
  rest_api_id       = aws_api_gateway_rest_api.api.id
  resource_id       = aws_api_gateway_resource.rejections.id
  http_method       = aws_api_gateway_method.post_rejections.http_method
  status_code       = aws_api_gateway_method_response.rejections_post_500_response.status_code
  selection_pattern = "^5[0-9][0-9]"

  response_templates = {
    "application/json" = "{\"message\": \"Internal server error while processing message\"}"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET, POST, OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type, X-Amz-Date, X-Amz-Security-Token, Authorization, X-Api-Key, X-Requested-With, Accept, Access-Control-Allow-Methods, Access-Control-Allow-Origin, Access-Control-Allow-Headers'"
  }

  depends_on = [aws_api_gateway_integration.sqs_integration_rejections]
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  depends_on = [
    aws_api_gateway_method.options_parent,
    aws_api_gateway_method.options_errors,
    aws_api_gateway_method.options_rejections,
    aws_api_gateway_method.post_errors,
    aws_api_gateway_method.post_rejections,
    aws_api_gateway_integration.options_parent_integration,
    aws_api_gateway_integration.options_errors_integration,
    aws_api_gateway_integration.options_rejections_integration,
    aws_api_gateway_integration.sqs_integration_errors,
    aws_api_gateway_integration.sqs_integration_rejections
  ]
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = var.stage_name
}

resource "aws_api_gateway_usage_plan" "usage_plan" {
  name = "flytrap_usage_plan"

  throttle_settings {
    burst_limit = 80
    rate_limit  = 20
  }

  api_stages {
    api_id = aws_api_gateway_rest_api.api.id
    stage  = aws_api_gateway_stage.stage.stage_name
  }
}