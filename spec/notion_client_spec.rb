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
    before do
      stub_notion_request
    end

    it 'fetches data from the Notion API' do
      data = client.notion_data
      expect(data).to eq('results' => [])
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
      .to_return(status: 200, body: "{\"results\": #{results}}", headers: {})
  end
end
