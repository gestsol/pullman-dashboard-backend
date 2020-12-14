defmodule PullmanDashboardWeb.PageController do
  use PullmanDashboardWeb, :controller

  def index(conn, _params) do
    conn 
    |> json(%{"hola"=>"como estas"})
  end
end
