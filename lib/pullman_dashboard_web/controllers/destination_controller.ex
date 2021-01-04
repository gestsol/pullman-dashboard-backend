defmodule PullmanDashboardWeb.DestinationController do
  use PullmanDashboardWeb, :controller
  alias PullmanDashboard.Consultador

  def index(conn, %{"cod_origen" => cod_origen}) do
  	destinos = Consultador.obtener_destinos_segun_origen(cod_origen)

  	conn
    |> json(destinos)
  end
end
