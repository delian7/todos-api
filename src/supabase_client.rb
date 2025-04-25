# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'httparty'
require 'zlib'
require 'stringio'

GET_RECORDS = 'GET'
CREATE_RECORD = 'POST'
DELETE_RECORD = 'DELETE'

class SupabaseClient
  def self.todos
    response = supabase_response(GET_RECORDS, 'todos?key=eq.notion-todos')
    JSON.parse(response).dig(0, 'data') || []
  end

  def self.remove_stale_todos
    supabase_response(DELETE_RECORD, 'todos?key=eq.notion-todos')
  end

  def self.persist_notion_todos(notion_todos)
    remove_stale_todos
    supabase_response(CREATE_RECORD, 'todos', { data: notion_todos, key: 'notion-todos' })
  end

  def self.users
    response = supabase_response(GET_RECORDS, 'users')
    JSON.parse(response)
  end

  def self.create_user(user)
    response = supabase_response(CREATE_RECORD, 'users', user)

    if response.code == '201'
      'User created successfully'
    else
      "Error creating user: #{response.body}"
    end
  end

  def self.supabase_response(operation, table, record = nil)
    url = URI("https://dgzxmivshyxkmridhggl.supabase.co/rest/v1/#{table}")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    case operation
    when GET_RECORDS
      response = HTTParty.get("https://dgzxmivshyxkmridhggl.supabase.co/rest/v1/#{table}", {
                                headers: {
                                  'apikey' => ENV.fetch('SUPABASE_TOKEN', nil),
                                  'Accept' => 'application/json'
                                }
                              })

      if response.headers['content-encoding'] == 'gzip'
        # Decompress it manually
        Zlib::GzipReader.new(StringIO.new(response.body)).read
      else
        response.body
      end

    when CREATE_RECORD
      request = Net::HTTP::Post.new(url)
      request['apikey'] = ENV.fetch('SUPABASE_TOKEN', nil)
      request['Content-Type'] = 'application/json'
      request.body = record.to_json
      http.request(request)

    when DELETE_RECORD
      HTTParty.delete("https://dgzxmivshyxkmridhggl.supabase.co/rest/v1/#{table}", {
                        headers: {
                          'apikey' => ENV.fetch('SUPABASE_TOKEN', nil),
                          'Accept' => 'application/json'
                        }
                      })
    end
  end
end
