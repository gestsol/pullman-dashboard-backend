defmodule PullmanDashboardWeb.KpiController do
  use PullmanDashboardWeb, :controller

  def index(conn, params) do
    conn
    |> json(params)
  end
end
