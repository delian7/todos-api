# frozen_string_literal: true

require 'rspec'
require 'webmock/rspec'
require 'google/apis/calendar_v3'
require 'googleauth'
require_relative '../src/google_client'
require 'dotenv'

RSpec.describe GoogleClient do
  let(:client) { described_class.new }

  context 'with stubbed Google API' do
    let(:mock_calendar) { instance_double(Google::Apis::CalendarV3::CalendarService) }
    let(:mock_client_options) { double('client_options') }
    let(:mock_calendar_list) do
      instance_double(
        Google::Apis::CalendarV3::CalendarList,
        items: [
          instance_double(
            Google::Apis::CalendarV3::CalendarListEntry,
            id: 'calendar1',
            summary: 'Test Calendar',
            description: 'A test calendar',
            time_zone: 'UTC',
            primary: true
          )
        ]
      )
    end

    before do
      Dotenv.load('.env.test')
      # Mock the calendar service
      allow(Google::Apis::CalendarV3::CalendarService).to receive(:new).and_return(mock_calendar)
      allow(mock_calendar).to receive_messages(
        client_options: mock_client_options,
        list_calendar_lists: mock_calendar_list,
        authorization: nil
      )

      allow(mock_client_options).to receive(:application_name=).with('myDos')

      # Mock the OAuth flow
      allow(Google::Auth::ClientId).to receive(:from_hash).and_return(double)
      allow(Google::Auth::UserAuthorizer).to receive(:new).and_return(double(get_credentials: double))
      allow(mock_calendar).to receive(:authorization=)
    end

    describe '#initialize' do
      it 'initializes the user_calendars' do
        client = described_class.new
        expect(client.user_calendars).to contain_exactly(
          {
            id: 'calendar1',
            name: 'Test Calendar',
            description: 'A test calendar',
            timezone: 'UTC',
            primary: true
          }
        )
      end
    end

    describe '#my_dos_from_calendar' do
      let(:mock_event) do
        instance_double(
          Google::Apis::CalendarV3::Event,
          id: 'event1',
          summary: 'Test Event',
          start: double(date_time: '2023-10-01T10:00:00Z'),
          end: double(date_time: '2023-10-01T11:00:00Z')
        )
      end

      before do
        allow(mock_calendar).to receive(:list_events).and_return(double(items: [mock_event]))
      end

      it 'fetches events from the primary calendar' do
        events = client.my_dos_from_calendar
        expect(events).to contain_exactly(
          {
            id: 'event1',
            summary: 'Test Event',
            start_time: '2023-10-01T10:00:00Z',
            end_time: '2023-10-01T11:00:00Z'
          }
        )
      end
    end
  end

  context 'when REAL OAUTH is used' do
    before do
      Dotenv.load('.env')
      skip 'Skipping real OAuth test. Set GOOGLE_OAUTH_CREDENTIALS in .env to run this test.'
      WebMock.allow_net_connect!
    end

    describe '#initialize' do
      it 'sets the @api_key from the environment variable' do
        client = described_class.new
        pp client.my_os_from_calendar
      end
    end
  end
end
