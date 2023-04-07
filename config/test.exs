import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :x_trace, XTraceWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "LP2OemLSYL7n+ep9p1eF39gJDz8TAkCSluTMvYxsAnhkctNDikkM0vc/wRwZ1TbV",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
