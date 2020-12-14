defmodule PullmanDashboard.Consultador do
  require Logger

  def obtener_ciudades() do
    peticion_http =
      Tesla.post("https://pullman.cl/integrador-web/rest/private/venta/buscaCiudades", nil,
        headers: [{"content-type", "application/json"}]
      )

    case peticion_http do
      {:error, _} ->
        nil
        Logger.error("Ocurrió error al obtenre ciudades")

      {:ok, response} ->
        case response.status do
          200 ->
            Jason.decode!(response.body)

          _ ->
            Logger.error("Ocurrió error al obtener ciudades")
            nil
        end
    end
  end
end