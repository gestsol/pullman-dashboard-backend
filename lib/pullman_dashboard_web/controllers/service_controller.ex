defmodule PullmanDashboardWeb.ServiceController do
  use PullmanDashboardWeb, :controller

  def index(conn, %{"destino" => destino, "origen"=> origen, "fecha" => fecha} = params) do
  	respuesta = PullmanDashboard.Consultador.start_pipe_services_between_cities(params)

    conn
    |> json(respuesta)
  end
end
