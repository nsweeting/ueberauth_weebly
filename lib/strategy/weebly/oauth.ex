defmodule Ueberauth.Strategy.Weebly.OAuth do
  @moduledoc """
  An implementation of OAuth2 for Weebly.

  To add your `client_id` and `client_secret` include these values in your configuration.

      config :ueberauth, Ueberauth.Strategy.Weebly.OAuth,
        client_id: System.get_env("WEEBLY_API_KEY"),
        client_secret: System.get_env("WEEBLY_SECRET")
  """
  @behaviour OAuth2.Strategy

  use OAuth2.Strategy

  @defaults [
    strategy: __MODULE__,
    site: "https://weebly.com",
    authorize_url: "https://www.weebly.com/app-center/oauth/authorize",
    token_url: "https://www.weebly.com/app-center/oauth/access_token"
  ]

  @doc """
  Construct a client for requests to Weebly using configuration from Application.get_env/2

      Ueberauth.Strategy.Weebly.OAuth.client(redirect_uri: "http://localhost:4000/auth/weebly/callback")

  This will be setup automatically for you in `Ueberauth.Strategy.Weebly`.
  """
  def client(opts \\ []) do
    config =
      :ueberauth
      |> Application.fetch_env!(Ueberauth.Strategy.Weebly.OAuth)
      |> check_config_key_exists(:client_id)
      |> check_config_key_exists(:client_secret)

    client_opts =
      @defaults
      |> Keyword.merge(config)
      |> Keyword.merge(opts)

    OAuth2.Client.new(client_opts)
  end

  @doc """
  Provides the authorize url for the request phase of Ueberauth. No need to call this usually.
  """
  def authorize_url!(params \\ [], opts \\ []) do
    opts
    |> client()
    |> OAuth2.Client.authorize_url!(params)
  end

  def get_token!(params \\ [], options \\ []) do
    headers = Keyword.get(options, :headers, [])
    options = Keyword.get(options, :options, [])
    client_options = Keyword.get(options, :client_options, [])

    client_options
    |> client()
    |> OAuth2.Client.get_token!(params, headers, options)
    |> parse_token()
    |> put_other_params(params)
  end

  def get(url, headers) do
    OAuth2.Client.get(client(), url, headers)
  end

  @impl OAuth2.Strategy
  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  @impl OAuth2.Strategy
  def get_token(client, params, headers) do
    code = Keyword.get(params, :code, client.params["code"])

    client
    |> put_param(:client_id, client.client_id)
    |> put_param(:client_secret, client.client_secret)
    |> put_param(:authorization_code, code)
    |> put_header("Accept", "application/json")
    |> OAuth2.Strategy.AuthCode.get_token(params, headers)
  end

  defp check_config_key_exists(config, key) when is_list(config) do
    unless Keyword.has_key?(config, key) do
      raise "#{inspect(key)} missing from config :ueberauth, Ueberauth.Strategy.Weebly"
    end

    config
  end

  defp check_config_key_exists(_, _) do
    raise "Config :ueberauth, Ueberauth.Strategy.Weebly is not a keyword list, as expected"
  end

  defp parse_token(client) do
    response = OAuth2.Serializer.decode!(client.token.access_token, "application/json")
    token = OAuth2.AccessToken.new(response["access_token"])
    %{client | token: token}
  end

  defp put_other_params(%{token: token} = client, params) do
    params = Enum.into(params, %{}, fn {key, val} -> {to_string(key), val} end)
    %{client | token: %{token | other_params: params}}
  end
end
