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
  NOTION_API_TOKEN = ENV['NOTION_API_TOKEN'].freeze
  NOTION_URI = URI.parse(NOTION_DATABASE_API_URL)

  def initialize
    @api_key = ENV.fetch('NOTION_API_KEY')
  end

  def notion_data
    notion_response_body
  end

  private

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
