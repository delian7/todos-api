# NotionClient API

This project contains a Ruby application that interacts with the Notion API. It includes a `NotionClient` class for fetching data from a specified Notion database and an AWS Lambda function for handling HTTP requests.

## Prerequisites

- Ruby
- Bundler
- AWS CLI

## Setup

1. **Clone the repository:**

   ```sh
   git clone https://github.com/delian7/stationsync-api.git
   cd notion-client-api
   ```

2. Install the Dependencies
  ```sh
  bundle install
  ```

3. Rename the .env.sample to .env in the root directory and add your Notion API credentials:
  ```sh
  cp .env.sample .env
  ```

## Running Tests
To run the tests, use RSpec:
  ```sh
  bundle exec rspec
  ```

## Deploying to AWS Lambda
1. Setup and configure AWS CLI
  ```sh
  aws configure
  ```

1. Package the application:
  ```sh
  zip -r notion-lambda-app.zip .
  ```

2. Update the Lambda function code:
  ```sh
  aws lambda update-function-code --function-name stationsync_fetcher \
  --zip-file fileb://notion-lambda-app.zip
  ```

*Alternatively you can combine all of this into one request:*
  ```sh
  zip -r notion-lambda-app.zip Gemfile Gemfile.lock src vendor && aws lambda update-function-code --function-name notion_todos_fetcher \
  --zip-file fileb://notion-lambda-app.zip
  ```

## Usage
The Lambda function handles HTTP requests and interacts with the Notion API. It supports the following endpoints:
  `GET /employees`: Fetches employee data from the Notion database.