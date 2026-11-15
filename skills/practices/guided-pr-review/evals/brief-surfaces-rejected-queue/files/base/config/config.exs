import Config

if config_env() == :test do
  config :webhooks, http: Webhooks.FakeHTTP
end
