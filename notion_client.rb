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
  NOTION_URI = URI.parse(NOTION_DATABASE_API_URL)

  def initialize
    @api_key = ENV.fetch('NOTION_API_KEY')
  end

  def notion_data(raw_data: false)
    return notion_response_body(todos_payload) if raw_data

    response = notion_response_body(todos_payload)
    results = response['results']

    return [] if results.empty?

    results.map do |todo|
      properties = todo['properties']
      {
        name: properties.dig('Name', 'title', 0, 'text', 'content'),
        date: properties.dig('Date', 'date', 'start'),
        id: todo['id']
      }
    end
  end

  private

  def find_property_by_id(data, id)
    data['properties'].values.find { |property| property['id'] == id }
  end

  def notion_response_body(payload)
    request = notion_request
    request.body = payload.to_json
    response = Net::HTTP.start(NOTION_URI.hostname, NOTION_URI.port, use_ssl: true) do |http|
      http.request(request)
    end

    JSON.parse(response.body)
  end

  def notion_request
    request = Net::HTTP::Post.new(NOTION_URI)
    request['Authorization'] = "Bearer #{@api_key}"
    request['Content-Type'] = 'application/json'
    request['Notion-Version'] = '2022-06-28'
    request
  end

  def todos_payload
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
end
