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

  STATUS_ID = 'J%3Bjh'
  SPECIFIC_ITEMS_ID = 'SE%7Be'
  LOCATION_ID = 'W%5ERD'
  PRODUCT_CATEGORY_ID = 'fUon'
  EMPLOYEE_NAME_ID = 'title'

  def initialize
    @api_key = ENV.fetch('NOTION_API_KEY')
  end

  def notion_data(raw_data: false)
    return notion_response_body if raw_data

    notion_response_body.fetch('results').map do |data|
      {
        employee_name: find_property_by_id(data, EMPLOYEE_NAME_ID).dig('title', 0, 'text', 'content'),
        specific_item: find_property_by_id(data, SPECIFIC_ITEMS_ID).dig('select', 'name'),
        product_category: find_property_by_id(data, PRODUCT_CATEGORY_ID).dig('select', 'name'),
        status: find_property_by_id(data, STATUS_ID).dig('status', 'name')
      }
    end
  end

  private

  def find_property_by_id(data, id)
    data['properties'].values.find { |property| property['id'] == id }
  end

  def notion_response_body
    request = notion_request
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
end
