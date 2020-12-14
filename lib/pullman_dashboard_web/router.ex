defmodule PullmanDashboardWeb.Router do
  use PullmanDashboardWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", PullmanDashboardWeb do
    pipe_through :api

    get "/kpi", KpiController, :index
  end
end
