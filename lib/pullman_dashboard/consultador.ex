defmodule PullmanDashboard.Consultador do
  require Logger

  @doc """
  Obtiene ciudades desde la API pública de Pullman y las devuelve
  en un arreglo, en caso de error devuelve nil, o arroja excepción si es error
  de decoding.
  """
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

  @doc """
  Obtiene el código de una ciudad mientras está se encuentre dentro de 
  los datos devueltos por obtener_ciudades()

  ## Ejemplo
      iex> PullmanDashboard.Consultador.obtener_ciudades |> PullmanDashboard.Consultador.obtener_codigo_ciudad("CASTRO")
      "10201298"
  """
  def obtener_codigo_ciudad(ciudades, ciudad) do
    ciudades
    |> Enum.find(%{}, fn c -> Map.get(c, "nombre") == ciudad end)
    |> Map.get("codigo")
  end
end