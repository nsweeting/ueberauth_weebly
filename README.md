# Überauth Weebly

Weebly OAuth2 strategy for Überauth.

## Installation

1. Setup your application at [Weebly](https://dev.weebly.com/).

2. Add `:ueberauth_weebly` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:ueberauth_weebly, "~> 0.1"}]
    end
    ```

3. Add Weebly to your Überauth configuration:

    ```elixir
    config :ueberauth, Ueberauth,
      providers: [
        weebly: {Ueberauth.Strategy.Weebly, []}
      ]
    ```

4. Update your provider configuration:

    ```elixir
    config :ueberauth, Ueberauth.Strategy.Weebly.OAuth,
      client_id: System.get_env("WEEBLY_API_KEY"),
      client_secret: System.get_env("WEEBLY_SECRET")
    ```

5. If you haven't already, create a pipeline and setup routes for your callback handler:

    ```elixir
    pipeline :auth do
      Ueberauth.plug "/auth"
    end

    scope "/auth" do
      pipe_through [:browser, :auth]

      get "/:provider/callback", AuthController, :callback
    end
    ```

6. Create an endpoint for the callback where you will handle the `Ueberauth.Auth` struct:

    ```elixir
    defmodule MyApp.AuthController do
      use MyApp.Web, :controller

      def callback_phase(%{ assigns: %{ ueberauth_failure: fails } } = conn, _params) do
        # do things with the failure
      end

      def callback_phase(%{ assigns: %{ ueberauth_auth: auth } } = conn, params) do
        # do things with the auth
      end
    end
    ```

7. Your controller needs to implement callbacks to deal with `Ueberauth.Auth` and `Ueberauth.Failure` responses.

For an example implementation see the [Überauth Example](https://github.com/ueberauth/ueberauth_example) application.

## Calling

Depending on the configured url you can initial the request through:

    /auth/weebly

Or with options:

    /auth/weebly?user_id=1234567&site_id=1234567&scope=read:site

By default the requested scope is "read:site,write:site". Scope can be configured either explicitly as a `scope` query value on the request path or in your configuration:

```elixir
config :ueberauth, Ueberauth,
  providers: [
    weebly: { Ueberauth.Strategy.Weebly, [default_scope: "read:site,write:site"] }
  ]
```