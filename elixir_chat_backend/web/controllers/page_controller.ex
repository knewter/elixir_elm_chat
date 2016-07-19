defmodule PerfqChatBackend.PageController do
  use PerfqChatBackend.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
