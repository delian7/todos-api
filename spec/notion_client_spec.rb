# frozen_string_literal: true

require 'rspec'
require 'webmock/rspec'
require_relative '../notion_client'

RSpec.describe NotionClient do
  let(:client) { described_class.new }

  before do
    ENV['NOTION_API_KEY'] = 'test_api_key'
  end

  describe '#initialize' do
    it 'sets the @api_key from the environment variable' do
      expect(client.api_key).to eq('test_api_key')
    end
  end

  describe '#notion_data' do
    let(:results) do
      [
        {
          'id' => 'some_id',
          'properties' => {
            'Name' => { 'title' => [{ 'text' => { 'content' => 'Walk Buddy' } }] },
            'Date' => { 'date' => { 'start' => '2023-10-01' } }
          }
        }
      ]
    end

    let(:expected_data) do
      {
        name: 'Walk Buddy',
        date: '2023-10-01',
        id: 'some_id'
      }
    end

    before do
      stub_notion_request(results)
    end

    it 'fetches data from the Notion API' do
      expect(client.notion_data).to eq([expected_data])
    end

    context 'when raw_data is requested' do
      it 'returns the raw_data from Notion' do
        expect(client.notion_data(raw_data: true)).to eq('results' => results)
      end
    end
  end

  private

  def stub_notion_request(results = [])
    stub_request(:post, NotionClient::NOTION_DATABASE_API_URL)
      .with(
        headers: {
          'Authorization' => 'Bearer test_api_key',
          'Content-Type' => 'application/json',
          'Notion-Version' => '2022-06-28'
        }
      )
      .to_return(status: 200, body: "{\"results\": #{results.to_json}}", headers: {})
  end
end
