defmodule PullmanDashboardWeb.OriginController do
  use PullmanDashboardWeb, :controller
  alias PullmanDashboard.Consultador


  def index(conn, _) do
  	ciudades = Consultador.obtener_ciudades()

  	conn
    |> json(ciudades)
  end
end
