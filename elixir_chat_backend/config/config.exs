# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :perfq_chat_backend,
  ecto_repos: [PerfqChatBackend.Repo]

# Configures the endpoint
config :perfq_chat_backend, PerfqChatBackend.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "9sFv10JpAinOGiif3VbHzgLXCj24POdIza35oZVjp+QnWaIO5Ico7iR07+ZeGFU6",
  render_errors: [view: PerfqChatBackend.ErrorView, accepts: ~w(html json)],
  pubsub: [name: PerfqChatBackend.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
