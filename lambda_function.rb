# frozen_string_literal: true

require 'json'

require_relative 'notion_client'

def lambda_handler(event:, context:) # rubocop:disable Lint/UnusedMethodArgument
  http_method = event['httpMethod']
  # resource = event['resource']
  raw_data = event.dig('queryStringParameters', 'raw_data')

  notion_client = NotionClient.new

  case http_method
  when 'GET'
    send_response(notion_client.notion_data(operation: NotionClient::GET_ALL_TODOS, raw_data: raw_data))
  when 'POST'
    raise 'todo name is required' if event['body'].nil?

    name = JSON.parse(event['body'])['name']
    send_response(notion_client.notion_data(NotionClient::CREATE_TODO, name: name))
  else
    method_not_allowed_response
  end
rescue StandardError => e
  error_response(e)
end

def send_response(data)
  {
    statusCode: 200,
    body: JSON.generate(data)
  }
end

def method_not_allowed_response
  {
    statusCode: 405,
    body: JSON.generate({ message: 'Method Not Allowed' })
  }
end

def error_response(error)
  {
    statusCode: 500,
    body: error.message
  }
end
