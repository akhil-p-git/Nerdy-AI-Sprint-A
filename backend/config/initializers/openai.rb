OpenAI.configure do |config|
  config.access_token = ENV.fetch('OPENAI_API_KEY', 'dummy_key_for_build')
  config.organization_id = ENV.fetch('OPENAI_ORG_ID', nil)
  config.request_timeout = 120
end

