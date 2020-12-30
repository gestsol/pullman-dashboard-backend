defmodule PullmanDashboardWeb.DestinationController do
  use PullmanDashboardWeb, :controller
  alias PullmanDashboard.Consultador

  def index(conn, %{"cod_origen" => cod_origen}) do
  	destinos = Consultador.obtener_origenes_segun_destino("cod_origen")

  	conn
    |> json(destinos)
  end
end
