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

    describe '#create_my_do' do
      let(:start_time) { Time.now.iso8601 }
      let(:end_time) { (Time.now + 3600).iso8601 }
      let(:summary) { 'Test Event' }
      let(:mock_created_event) do
        instance_double(
          Google::Apis::CalendarV3::Event,
          id: 'new_event1',
          summary: "📝 #{summary}",
          start: instance_double(Google::Apis::CalendarV3::EventDateTime,
                                 date_time: start_time,
                                 time_zone: 'UTC'),
          end: instance_double(Google::Apis::CalendarV3::EventDateTime,
                               date_time: end_time,
                               time_zone: 'UTC')
        )
      end

      before do
        allow(mock_calendar).to receive(:insert_event).and_return(mock_created_event)
      end

      it 'creates a new event in the primary calendar' do
        event = client.create_my_do(start_time, end_time, summary)
        expect(event).to eq(mock_created_event)
        expect(mock_calendar).to have_received(:insert_event).with(
          'calendar1',
          an_instance_of(Google::Apis::CalendarV3::Event)
        )
      end
    end

    describe '#update_my_do' do
      let(:event_id) { 'event1' }
      let(:start_time) { Time.now.iso8601 }
      let(:end_time) { (Time.now + 3600).iso8601 }
      let(:summary) { 'Updated Event' }
      let(:mock_existing_event) do
        instance_double(
          Google::Apis::CalendarV3::Event,
          id: event_id,
          summary: '📝 Test Event',
          start: double(date_time: start_time),
          end: double(date_time: end_time)
        )
      end

      before do
        allow(mock_calendar).to receive_messages(
          get_event: mock_existing_event,
          update_event: mock_existing_event
        )
      end

      it 'updates an existing event in the primary calendar' do
        event = client.update_my_do(event_id, start_time, end_time, summary)
        expect(event).to eq(mock_existing_event)
        expect(mock_calendar).to have_received(:update_event).with(
          'calendar1',
          event_id,
          an_instance_of(Google::Apis::CalendarV3::Event)
        )
      end

      it 'raises an error if the event is not found' do
        allow(mock_calendar).to receive(:get_event).and_raise(Google::Apis::ClientError.new('Not Found'))
        expect { client.update_my_do(event_id, start_time, end_time) }.to raise_error(RuntimeError)
      end

      it 'raises an error if the event is not a myDo' do
        allow(mock_existing_event).to receive(:summary).and_return('Not a myDo')
        expect { client.update_my_do(event_id, start_time, end_time) }.to raise_error('Event is not a myDo')
      end
    end

    describe '#mark_as_done' do
      let(:event_id) { 'event1' }
      let(:mock_existing_event) do
        instance_double(
          Google::Apis::CalendarV3::Event,
          id: event_id,
          summary: '📝 Test Event',
          start: double(date_time: Time.now.iso8601),
          end: double(date_time: (Time.now + 3600).iso8601)
        )
      end

      before do
        allow(mock_calendar).to receive_messages(
          get_event: mock_existing_event,
          update_event: mock_existing_event
        )
      end

      it 'marks an existing event as done' do
        event = client.mark_as_done(event_id)
        expect(event).to eq(mock_existing_event)
        expect(mock_calendar).to have_received(:update_event).with(
          'calendar1',
          event_id,
          an_instance_of(Google::Apis::CalendarV3::Event)
        )
      end

      it 'raises an error if the event is not a myDo' do
        allow(mock_existing_event).to receive(:summary).and_return('Not a myDo')
        expect { client.mark_as_done(event_id) }.to raise_error('Event is not a myDo')
      end
    end
  end

  context 'when REAL OAUTH is used' do
    before do
      Dotenv.load('.env')
      skip 'Skipping real OAuth test' unless ENV['REAL_OAUTH'] == 'true'
      WebMock.allow_net_connect!
    end

    describe '#my_dos_from_calendar' do
      it 'fetches events from the primary calendar' do
        events = client.my_dos_from_calendar
        expect(events).to be_an(Array)
        pp events
      end
    end

    describe '#create_my_do' do
      it 'creates a new event in the primary calendar' do
        start_time = Time.now.iso8601
        end_time = (Time.now + 3600).iso8601
        summary = 'Test Event'

        event = client.create_my_do(start_time, end_time, summary)
        expect(event).to be_a(Google::Apis::CalendarV3::Event)
        # expect(event.summary).to eq(summary)
        # expect(event.start.date_time).to eq(start_time)
        # expect(event.end.date_time).to eq(end_time)
      end
    end

    describe '#mark_as_done' do
      it 'marks an existing event as done' do
        events = client.my_dos_from_calendar
        event_id = events.dig(0, :id) # Replace with a valid event ID

        event = client.mark_as_done(event_id)
        expect(event).to be_a(Google::Apis::CalendarV3::Event)
      end
    end

    describe '#update_my_do' do
      it 'updates an existing event in the primary calendar' do
        start_time = Time.now.iso8601
        end_time = (Time.now + 3600).iso8601
        summary = 'Updated Event'
        events = client.my_dos_from_calendar

        event_id = events.dig(0, :id) # Replace with a valid event ID

        event = client.update_my_do(event_id, start_time, end_time, summary)
        expect(event).to be_a(Google::Apis::CalendarV3::Event)
      end
    end
  end
end
