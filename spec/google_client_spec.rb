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
            time_zone: 'UTC'
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

    describe '#list_calendars' do
      it 'returns formatted calendar list' do
        client = described_class.new
        calendars = client.list_calendars

        expect(calendars).to contain_exactly(
          {
            id: 'calendar1',
            name: 'Test Calendar',
            description: 'A test calendar',
            timezone: 'UTC'
          }
        )
      end
    end
  end
end
