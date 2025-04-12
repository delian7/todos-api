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
    send_response(notion_client.notion_data(NotionClient::GET_ALL_TODOS, raw_data: raw_data))
  when 'POST'
    raise 'todo name is required' if event['body'].nil?

    name = JSON.parse(event['body'])['name']
    send_response(notion_client.notion_data(NotionClient::CREATE_TODO, name: name))
  when 'PATCH'
    raise 'todo_id(s) is required' if event['body'].nil?

    body = JSON.parse(event['body'])
    todo_ids = body['todo_ids']
    start_date = body['start_date']
    end_date = body['end_date']

    raise 'todo id(s) is required to update' if todo_ids.nil?

    send_response(
      notion_client.notion_data(
        NotionClient::UPDATE_TODO,
        todo_ids: todo_ids,
        start_date: start_date,
        end_date: end_date
      )
    )
  else
    method_not_allowed_response
  end
rescue StandardError => e
  error_response(e)
end

def send_response(data)
  {
    statusCode: 200,
    headers: {
      'Access-Control-Allow-Origin' => '*', # Or use your frontend domain
      'Access-Control-Allow-Methods' => 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers' => 'Content-Type'
    },
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
    statusCode: 400,
    body: error.message
  }
end
