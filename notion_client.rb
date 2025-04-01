# frozen_string_literal: true

require 'dotenv/load' if ENV['AWS_EXECUTION_ENV'].nil?
require 'net/http'
require 'uri'

# NotionClient is responsible for interacting with the Notion API.
# It fetches data from a specified Notion database using the API key and database ID
# provided through environment variables.
class NotionClient
  attr_reader :api_key

  NOTION_API_URL = 'https://api.notion.com/v1/pages'
  DATABASE_ID = ENV.fetch('NOTION_DATABASE_ID')
  NOTION_DATABASE_API_URL = "https://api.notion.com/v1/databases/#{DATABASE_ID}/query"

  GET_ALL_TODOS = 'all'
  CREATE_TODO = 'new'
  UPDATE_TODO = 'update'

  def initialize
    @api_key = ENV.fetch('NOTION_API_KEY')
  end

  def notion_data(operation, name: nil, todo_ids: nil, raw_data: false)
    return notion_response_body(NOTION_DATABASE_API_URL, operation, all_todos_payload) if raw_data

    case operation
    when GET_ALL_TODOS
      payload = all_todos_payload
      response = notion_response_body(NOTION_DATABASE_API_URL, operation, payload)
      results = response['results']
      return [] if results.empty? && operation == GET_ALL_TODOS

      results.map do |todo|
        properties = todo['properties']
        {
          name: properties.dig('Name', 'title', 0, 'text', 'content'),
          date: properties.dig('Date', 'date', 'start'),
          id: todo['id']
        }
      end
    when CREATE_TODO
      payload = create_todo_payload(name)
      notion_response_body(NOTION_API_URL, operation, payload)
      { message: 'Todo created successfully' }
    when UPDATE_TODO
      todo_ids.each do |id|
        payload = mark_todo_done_payload
        notion_response_body("#{NOTION_API_URL}/#{id}", operation, payload)
      end
    end
  end

  private

  def notion_response_body(url, operation, payload)
    request, uri = notion_request(operation, url)
    request.body = payload.to_json
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    JSON.parse(response.body)
  end

  def notion_request(operation, url)
    uri = URI.parse(url)
    request = operation == UPDATE_TODO ? Net::HTTP::Patch.new(uri) : Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@api_key}"
    request['Content-Type'] = 'application/json'
    request['Notion-Version'] = '2022-06-28'
    [request, uri]
  end

  def all_todos_payload
    {
      filter: {
        and: [
          {
            property: 'Done',
            checkbox: { equals: false }
          },
          {
            property: 'Date',
            date: {
              before: (Time.now.getlocal('-08:00') + 86_400).strftime('%Y-%m-%dT00:00:00-08:00')
            }
          },
          {
            property: 'Tags',
            multi_select: {
              does_not_contain: 'hidden'
            }
          }
        ]
      },
      sorts: [{
        property: 'Date',
        direction: 'ascending'
      }]
    }
  end

  def create_todo_payload(name)
    {
      parent: { database_id: DATABASE_ID },
      properties: {
        Name: {
          title: [{ text: { content: name } }]
        },
        Date: {
          date: {
            start: Time.now.getlocal('-08:00').strftime('%Y-%m-%d')
          }
        }
      }
    }
  end

  def mark_todo_done_payload
    {
      properties: {
        Done: {
          checkbox: true
        }
      }
    }
  end
end
