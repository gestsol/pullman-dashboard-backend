defmodule PullmanDashboardWeb.KpiController do
  use PullmanDashboardWeb, :controller

  def index(conn, %{"destino" => destino, "origen"=> origen, "fecha" => fecha} = params) do
  	respuesta = PullmanDashboard.Consultador.start_pipe(params)
    conn
    |> json(respuesta)
  end
end
