# frozen_string_literal: true

require 'google/apis/calendar_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'json'
require 'active_support'
require 'active_support/time'

# # GoogleClient is responsible for interacting with the Google API.
# # It fetches data using the API key provided through environment variables.
class GoogleClient
  attr_reader :user_calendars

  OOB_URI = 'http://localhost:3000/oauth2callback'
  TOKEN_PATH = 'token.yaml'
  SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR

  def initialize
    @calendar = Google::Apis::CalendarV3::CalendarService.new
    @calendar.client_options.application_name = 'myDos'
    @calendar.authorization = authorize
    list_calendars
  end

  def my_dos_from_calendar(calendar_id = primary_calendar[:id])
    events = fetch_events_from_calendar(calendar_id)

    events.items.map do |event|
      {
        id: event.id,
        summary: event.summary,
        start_time: event.start.date_time || event.start.date,
        end_time: event.end.date_time || event.end.date
      }
    end
  rescue Google::Apis::Error => e
    raise "Failed to fetch events from calendar: #{e.message}"
  end

  def create_my_do(start_time, end_time, summary, prefix = '📝')
    event = Google::Apis::CalendarV3::Event.new(
      summary: "#{prefix} #{summary}",
      start: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: start_time,
        time_zone: primary_calendar[:timezone]
      ),
      end: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: end_time,
        time_zone: primary_calendar[:timezone]
      )
    )
    @calendar.insert_event(primary_calendar[:id], event)
  rescue Google::Apis::Error => e
    raise "Failed to create event: #{e.message}"
  end

  def update_my_do(event_id, start_time, end_time, summary = nil)
    existing_event = @calendar.get_event(primary_calendar[:id], event_id)
    raise 'Event is not a myDo' unless existing_event.summary.start_with?('📝')

    event = Google::Apis::CalendarV3::Event.new(
      summary: summary || existing_event.summary,
      start: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: start_time,
        time_zone: primary_calendar[:timezone]
      ),
      end: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: end_time,
        time_zone: primary_calendar[:timezone]
      )
    )
    @calendar.update_event(primary_calendar[:id], event_id, event)
  rescue Google::Apis::Error => e
    raise "Failed to update event: #{e.message}"
  end

  private

  def list_calendars
    response = @calendar.list_calendar_lists
    @user_calendars = response.items.map do |calendar|
      {
        id: calendar.id,
        name: calendar.summary,
        description: calendar.description,
        timezone: calendar.time_zone,
        primary: calendar.primary
      }
    end
  rescue Google::Apis::Error => e
    raise "Failed to fetch calendars: #{e.message}"
  end

  def fetch_events_from_calendar(calendar_id)
    Time.zone = primary_calendar[:timezone]
    end_of_day = Time.zone.now.end_of_day.iso8601

    @calendar.list_events(
      calendar_id,
      q: '📝',
      max_results: 10,
      single_events: true,
      order_by: 'startTime',
      time_max: end_of_day,
      time_zone: primary_calendar[:timezone]
    )
  end

  def primary_calendar
    @user_calendars.find { |c| c[:primary] } || raise('No primary calendar found')
  end

  def authorize
    client_id = Google::Auth::ClientId.from_hash(JSON.parse(ENV.fetch('GOOGLE_OAUTH_CREDENTIALS', nil)))
    token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
    credentials = authorizer.get_credentials('default')

    if credentials.nil?
      url = authorizer.get_authorization_url(base_url: OOB_URI)
      puts "Open this URL in your browser:\n#{url}"
      puts 'Enter the authorization code:'
      code = gets.chomp
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: 'default',
        code: code,
        base_url: OOB_URI
      )
    end
    credentials
  end
end
