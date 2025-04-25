# frozen_string_literal: true

require 'json'

require_relative 'notion_client'
# require_relative 'google_client'
require_relative 'supabase_client'

def lambda_handler(event:, context:) # rubocop:disable Lint/UnusedMethodArgument
  http_method = event['httpMethod']
  resource = event['resource']
  raw_data = event.dig('queryStringParameters', 'raw_data')
  notion_client = NotionClient.new

  case http_method
  when 'GET'
    return method_not_allowed_response if resource == '/todos/refresh-cache'

    supabase_todos = SupabaseClient.todos
    return send_response(supabase_todos) if supabase_todos.count.positive?

    notion_todos = notion_client.notion_data(NotionClient::GET_ALL_TODOS, raw_data: raw_data)
    SupabaseClient.persist_notion_todos(notion_todos)
    send_response(notion_todos)
  when 'POST'
    if resource == '/todos/refresh-cache'
      notion_todos = notion_client.notion_data(NotionClient::GET_ALL_TODOS, raw_data: raw_data)
      SupabaseClient.persist_notion_todos(notion_todos)
      return send_response 'refreshed'
    end

    raise 'todo name is required' if event['body'].nil?

    SupabaseClient.remove_stale_todos
    name = JSON.parse(event['body'])['name']
    send_response(notion_client.notion_data(NotionClient::CREATE_TODO, name: name))
  when 'PATCH'
    return method_not_allowed_response if resource == '/todos/refresh-cache'

    raise 'todo_id(s) is required' if event['body'].nil?

    body = JSON.parse(event['body'])
    todo_ids = body['todo_ids']
    start_date = body['start_date']
    end_date = body['end_date']

    raise 'todo id(s) is required to update' if todo_ids.nil?

    SupabaseClient.remove_stale_todos

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
