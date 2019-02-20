defmodule Ueberauth.Strategy.Weebly do
  @moduledoc """
  Provides an Ueberauth strategy for authenticating with Weebly.

  ### Setup

  Create an application in Weebly for you to use.

  Register a new application at the [weebly developers page](https://dev.weebly.com/) and get the `client_id` and `client_secret`.

  Include the provider in your configuration for Ueberauth

      config :ueberauth, Ueberauth,
        providers: [
          weebly: { Ueberauth.Strategy.Weebly, [] }
        ]

  Then include the configuration for weebly.

      config :ueberauth, Ueberauth.Strategy.Weebly.OAuth,
        client_id: System.get_env("WEEBLY_API_KEY"),
        client_secret: System.get_env("WEEBLY_SECRET")

  If you haven't already, create a pipeline and setup routes for your callback handler

      pipeline :auth do
        Ueberauth.plug "/auth"
      end

      scope "/auth" do
        pipe_through [:browser, :auth]

        get "/:provider/callback", AuthController, :callback
      end

  Create an endpoint for the callback where you will handle the `Ueberauth.Auth` struct

      defmodule MyApp.AuthController do
        use MyApp.Web, :controller

        def callback_phase(%{ assigns: %{ ueberauth_failure: fails } } = conn, _params) do
          # do things with the failure
        end

        def callback_phase(%{ assigns: %{ ueberauth_auth: auth } } = conn, params) do
          # do things with the auth
        end
      end

  You can edit the behaviour of the Strategy by including some options when you register your provider.

  To set the default 'scopes' (permissions):

      config :ueberauth, Ueberauth,
        providers: [
          weebly: { Ueberauth.Strategy.Weebly, [default_scope: "read:site,read:store-catalog"] }
        ]

  Default is "read:site,write:site"
  """

  use Ueberauth.Strategy,
    uid_scope: :token,
    uid_field: :site_id,
    default_scope: "read:site,write:site",
    oauth2_module: Ueberauth.Strategy.Weebly.OAuth

  alias Ueberauth.Auth.{Credentials, Info}

  @doc """
  Handles the initial redirect to the Weebly authentication page.
  """
  def handle_request!(%Plug.Conn{} = conn) do
    opts = get_options(conn)
    redirect!(conn, Ueberauth.Strategy.Weebly.OAuth.authorize_url!(opts))
  end

  @doc """
  Handles the callback from Weebly. When there is a failure from Weebly the failure is included in the
  `ueberauth_failure` struct. Otherwise the information returned from Weebly is returned in the `Ueberauth.Auth` struct.
  """
  def handle_callback!(%Plug.Conn{params: %{"authorization_code" => _} = params} = conn) do
    module = option(conn, :oauth2_module)

    params = [
      code: params["authorization_code"],
      site_id: params["site_id"],
      user_id: params["user_id"]
    ]

    token = apply(module, :get_token!, [params]).token

    if token.access_token == nil do
      err = token.other_params["error"]
      desc = token.other_params["error_description"]
      set_errors!(conn, [error(err, desc)])
    else
      conn
      |> put_private(:weebly_token, token)
      |> get_user()
    end
  end

  @doc false
  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code or shop received")])
  end

  @doc """
  Cleans up the private area of the connection used for passing the raw Weebly response around during the callback.
  """
  def handle_cleanup!(conn) do
    conn
    |> put_private(:weebly_token, nil)
    |> put_private(:weebly_user, nil)
  end

  @doc """
  Fetches the uid field from the Weebly response.
  """
  def uid(conn) do
    uid_field = conn |> option(:uid_field) |> to_string()

    case option(conn, :uid_scope) do
      :user -> conn.private.weebly_user[uid_field]
      :token -> conn.private.weebly_token.other_params[uid_field]
    end
  end

  @doc """
  Includes the info for the Weebly user.
  """
  def info(conn) do
    %Info{
      email: conn.private.weebly_user["email"],
      name: conn.private.weebly_user["name"]
    }
  end

  @doc """
  Includes the credentials from the Weebly response.
  """
  def credentials(conn) do
    token = conn.private.weebly_token
    %Credentials{token: token.access_token, token_type: token.token_type}
  end

  defp get_user(conn) do
    access_token = conn.private.weebly_token.access_token
    profile_url = "https://api.weebly.com/v1/user"
    headers = [{"x-weebly-access-token", access_token}]

    case Ueberauth.Strategy.Weebly.OAuth.get(profile_url, headers) do
      {:ok, %OAuth2.Response{status_code: 401, body: _body}} ->
        set_errors!(conn, [error("token", "unauthorized")])

      {:ok, %OAuth2.Response{status_code: status_code, body: user}}
      when status_code in 200..399 ->
        put_private(conn, :weebly_user, user)

      {:error, %OAuth2.Error{reason: reason}} ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end

  defp get_options(conn) do
    [
      scope: conn.params["scope"] || option(conn, :default_scope),
      redirect_uri: callback_url(conn),
      site_id: conn.params["site_id"],
      user_id: conn.params["user_id"],
      version: conn.params["version"]
    ]
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

  defp option(conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end
end
