# frozen_string_literal: true

require 'dotenv/load' if ENV['AWS_EXECUTION_ENV'].nil?
require 'net/http'
require 'uri'
require 'tzinfo'
require 'time'

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

  def notion_data(operation, name: nil, todo_ids: nil, raw_data: false, start_date: nil, end_date: nil)
    return notion_response_body(NOTION_DATABASE_API_URL, operation, all_todos_payload) if raw_data

    case operation
    when GET_ALL_TODOS

      timezone = TZInfo::Timezone.get('America/Los_Angeles')
      now = timezone.now

      # Build end of day with correct offset
      end_of_day = Time.new(now.year, now.month, now.day, 23, 59, 59)

      payload = all_todos_payload
      response = notion_response_body(NOTION_DATABASE_API_URL, operation, payload)
      results = response['results']
      return [] if results.empty? && operation == GET_ALL_TODOS

      filtered_results = results.select do |item|
        name = item['properties']['Name']['title'][0]['text']['content']
        date = Time.parse(item['properties']['Date']['date']['start'])
        date <= end_of_day
      end

      filtered_results.map do |todo|
        properties = todo['properties']
        {
          name: properties.dig('Name', 'title', 0, 'text', 'content'),
          date: properties.dig('Date', 'date', 'start'),
          url: todo['url'],
          id: todo['id'],
          isCompleted: properties.dig('Done', 'checkbox')
        }
      end
    when CREATE_TODO
      payload = create_todo_payload(name)
      body = notion_response_body(NOTION_API_URL, operation, payload)
      {
        name: name,
        id: body['id'],
        url: body['url'],
        date: Time.now.getlocal('-08:00').strftime('%Y-%m-%d'),
        isCompleted: false
      }
    when UPDATE_TODO
      todo_ids.each do |id|
        payload = if start_date
                    change_todo_date_payload(start_date, end_date)
                  else
                    mark_todo_done_payload
                  end

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
    timezone = TZInfo::Timezone.get('America/Los_Angeles')
    now = timezone.now

    # Get the UTC offset in seconds
    offset_seconds = timezone.period_for_local(now).utc_total_offset

    # Build end of day with correct offset
    end_of_day = Time.new(now.year, now.month, now.day, 23, 59, 59, offset_seconds)
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
              before: end_of_day.iso8601
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

  def change_todo_date_payload(start_date_string, end_date_string)
    start_date = Time.iso8601(start_date_string)
    if start_date.hour.zero? && start_date.min.zero?
      start_date = Date.iso8601(start_date_string)
    else
      end_date = start_date + (15 * 60)
    end

    end_date = Time.iso8601(end_date_string) if end_date_string

    {
      properties: {
        Date: {
          date: {
            start: start_date.iso8601,
            end: end_date&.iso8601
          }
        }
      }
    }
  end
end
