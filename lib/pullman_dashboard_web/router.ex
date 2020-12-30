defmodule PullmanDashboardWeb.Router do
  use PullmanDashboardWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", PullmanDashboardWeb do
    pipe_through :api

    get "/kpi", KpiController, :index
    get "/services", ServiceController, :index
    get "/origenes", OriginController, :index
    get "/destinos", DestinationController, :index
  end
end
