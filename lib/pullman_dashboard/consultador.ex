defmodule PullmanDashboard.Consultador do
  require Logger

  
  @doc """
  Wrapper sobre Tesla HTTP Client
  """
  def post(url, body \\ nil) do
    Tesla.post(url, Jason.encode!(body), headers: [{"content-type", "application/json"}])
  end

  @doc """
  Comienza la ejecución en pipe para calcular indicadores tasa de ocupación
  """
  def start_pipe(params) do
    obtener_ciudades()
    |> prepara_body_consulta_servicios_dia(params)
    |> obtener_servicios_del_dia
    |> obtener_datos_servicio_segun_hora(params)
    |> prepara_body_grilla_servicio
    |> obtener_grilla_servicio
    |> calcular_tasa_ocupacion
  end

  @doc """
  Obtiene ciudades desde la API pública de Pullman y las devuelve
  en un arreglo, en caso de error devuelve nil, o arroja excepción si es error
  de decoding.
  """
  def obtener_ciudades() do
    peticion = post("https://pullman.cl/integrador-web/rest/private/venta/buscaCiudades")

    case peticion do
      {:error, _} ->
        nil
        Logger.error("Ocurrió error al obtener ciudades")

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
  Función auxiliar, prepara el cuerpo para la consulta que obtiene 
  servicios del día, sustituyendo el nombre de las ciudades por sus códigos.
  Recibe un arreglo de ciudades y los params de la consulta recibida en endpoint.

  ## Ejemplo
      iex>prepara_body_consulta_servicios_dia(ciudades, params)
      %{
        "origen" => "ABC"
        "destino" => "DEF"
        "fecha" => "20200112"
        "hora" => "0000",
        "idSistema" => 7
      }
  """
  def prepara_body_consulta_servicios_dia(ciudades, params) do
    if !is_nil(ciudades) && !is_nil(params) do
      origen = Map.get(params, "origen", nil)
      destino = Map.get(params, "destino", nil)

      %{
        "origen" => obtener_codigo_ciudad(ciudades, origen) || nil,
        "destino" => obtener_codigo_ciudad(ciudades, destino) || nil,
        "fecha" => Map.get(params, "fecha"),
        "hora" => "0000",
        "idSistema" => 7
      }

      # Logger.write "Cuerpo armado #{inspect(body)}"
    else
      nil
    end
  end

  @doc """
  Función auxiliar, obbtiene el código de una ciudad mientras está se encuentre dentro de 
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

  @doc """
  Obtiene servicios para el día de PULLMANBUS, considerando ciudad de origen, destino, fecha.
  """
  def obtener_servicios_del_dia(body) do
    if !is_nil(body) do
      peticion =
        post("https://pullman.cl/integrador-web/rest/private/venta/obtenerServicio", body)

      case peticion do
        {:error, _} ->
          nil
          Logger.error("Ocurrió error al obtener servicios del día")

        {:ok, response} ->
          case response.status do
            200 ->
              Jason.decode!(response.body)

            _ ->
              Logger.error("Ocurrió error al servicios del día")
              nil
          end
      end
    else
      nil
    end
  end

  @doc """
  Extrae un servicio de arreglo de servicios en base a hora.
  Permite obtener  servico de interés al tener servicios asignados a un día entre un origen y destino.
  """
  def obtener_datos_servicio_segun_hora(servicios, params) do
    if !is_nil(servicios) do
      servicios
      |> Enum.find(%{}, fn s ->
        Map.get(s, "horaSalida") == transformar_hora(Map.get(params, "hora"))
      end)
    else
      nil
    end
  end

  @doc """
  Función auxiliar, transforma hora formato(24h) "HHMM" -> "HH:MM".

  ## Ejemplo:
      iex>transformar_hora("0830")
      "08:30"
  """
  def transformar_hora(hora) do
    String.codepoints(hora)
    |> List.insert_at(2, ":")
    |> List.to_string()
  end

  @doc """
  Funcion auxiliar, prepara el cuerpo para petición de grilla de servicio.
  Devuelve una tupla, para poder acceder a los datos del servicio adelante en el pipe.

  {body, servicio}
  """
  def prepara_body_grilla_servicio(servicio) do
    if !is_nil(servicio) do
      {%{
         "idServicio" => Map.get(servicio, "idServicio"),
         "tipoBusPiso1" => Map.get(servicio, "busPiso1"),
         "tipoBusPiso2" => Map.get(servicio, "busPiso2"),
         "fechaServicio" => Map.get(servicio, "fechaSalida"),
         "idOrigen" => Map.get(servicio, "idTerminalOrigen"),
         "idDestino" => Map.get(servicio, "idTerminalDestino"),
         "integrador" => Map.get(servicio, "integrador")
       }, servicio}
    else
      nil
    end
  end

  @doc """
  Obtiene la grilla vertical de un servicio para realizar calculos de indicadores 
  """
  def obtener_grilla_servicio(params) do
    {cuerpo, servicio} = params

    if !is_nil(cuerpo) do
      peticion_http =
        post(
          "https://pullman.cl/integrador-web/rest/private/venta/buscarPlantillaVertical",
          cuerpo
        )

      case peticion_http do
        {:error, _} ->
          nil
          Logger.error("Ocurrió error al obtener grilla de servicio! ")

        {:ok, response} ->
          case response.status do
            200 ->
              {Jason.decode!(response.body), Map.get(servicio, "servicioPrimerPiso"),
               Map.get(servicio, "servicioSegundoPiso")}

            _ ->
              Logger.error("Ocurrió error al obtener grilla de servicio!")
              nil
          end
      end
    else
      nil
    end
  end

  @doc """
  Calcula indicadores de interes en base a grilla recibida y devuelve mapa con los valores.
  Recibe como parametro una tupla compuesta por {p1,p2,3} donde:

  -p1 == grilla vertical devuelta por consulta a pullmanbus.cl que se procesa para calcular indicadores,
  -p2 == string que especifica el tipo de servicio del primer piso ("CAMA" || "SEMICAMA"),
  -p3 == string que especifica tipo de servicio segundo piso ("CAMA" || "SEMICAMA"),

  Ejemplo de la grilla disponible en el archivo
  lib/pullman_dashboard/ejemplos/grilla_vertical.ex

  ## Ejemplo
      iex>calcular_tasa_ocupacion({.., .., ..})
      %{
        "tasa_ocupacion_cama" => 21.43,
        "tasa_ocupacion_semicama" => 78.57,
        "tasa_ocupacion_total" => nil,
        "total_asientos" => 56
      }
  """
  def calcular_tasa_ocupacion(params) do
    {grilla, tipo_primer, tipo_segundo} = params

    total =
      if tipo_primer == tipo_segundo do
        calcula_total_asientos_ocupados_por_piso(grilla, "1") +
          calcula_total_asientos_ocupados_por_piso(grilla, "2")
      else
        nil
      end

    total_asientos = calcula_total_asientos_bus(grilla)

    %{
      "total_asientos" => total_asientos,
      "tasa_ocupacion_cama" =>
        if(is_nil(total), do: calcula_ocupacion_cama(params, total_asientos), else: nil),
      "tasa_ocupacion_semicama" =>
        if(is_nil(total), do: calcula_ocupacion_semi(params, total_asientos), else: nil),
      "tasa_ocupacion_total" => total
    }
  end

  @doc """
  Función auxiliar que calcula porcentaje de asientos CAMA ocupados a partir de 
  grilla vertical recibida. 

  Ejemplo de la grilla disponible en el archivo
  lib/pullman_dashboard/ejemplos/grilla_vertical.ex

  ## Ejemplo
      iex>calcula_ocupacion_semi(grilla, total)
      21.43
  """
  def calcula_ocupacion_cama(params, total) do
    {grilla, tipo_primer, _tipo_segundo} = params

    total_ocupados =
      if tipo_primer == "SALON CAMA" do
        calcula_total_asientos_ocupados_por_piso(grilla, "1")
      else
        calcula_total_asientos_ocupados_por_piso(grilla, "2")
      end

    (total_ocupados / total * 100)
    |> Float.round(2)
  end

  @doc """
  Función auxiliar que calcula porcentaje de asientos SEMICAMA ocupados a partir de 
  grilla vertical recibida. 

  Existe ejemplo del mapa en el archivo
  lib/pullman_dashboard/ejemplos/grilla_vertical.ex

  ## Ejemplo
      iex>calcula_ocupacion_semi(grilla, total)
      21.43
  """
  def calcula_ocupacion_semi(params, total) do
    {grilla, tipo_primer, _tipo_segundo} = params

    total_ocupados =
      if tipo_primer == "SEMI CAMA" do
        calcula_total_asientos_ocupados_por_piso(grilla, "1")
      else
        calcula_total_asientos_ocupados_por_piso(grilla, "2")
      end

    (total_ocupados / total * 100)
    |> Float.round(2)
  end

  @doc """
  Función auxiliar que calcula total de asientos disponibles a partir de grilla vertical recibida. 

  Existe ejemplo del mapa en el archivo
  lib/pullman_dashboard/ejemplos/grilla_vertical.ex

  ## Ejemplo
      iex>calcula_total_asientos(grilla)
      50
  """
  def calcula_total_asientos_bus(grilla) do
    primer_piso = calcula_total_asientos_por_piso(grilla, "1")
    segundo_piso = calcula_total_asientos_por_piso(grilla, "2")

    primer_piso + segundo_piso
  end

  @doc """
  Función auxiliar que devuelve un entero convertido desde un string mediante 
  Integer.parse, 
  o un atom :no. 

  ## Ejemplo
      iex>parser_string_to_int("1")
      1
  """
  def parser_string_to_int(str) do
    case Integer.parse(str) do
      {int, _rest} ->
        int

      :error ->
        :no
    end
  end

  @doc """
  Función auxiliar que calcula el total de asientos por piso, creada para evitar duplicidad <3!

  ## Ejemplo
      iex> calcula_total_asientos_por_piso(%{..}, "1")
      12
  """
  def calcula_total_asientos_por_piso(grilla, piso \\ 1) do
    Map.get(grilla, piso)
    |> List.flatten()
    |> Enum.filter(fn i -> is_integer(parser_string_to_int(Map.get(i, "asiento"))) end)
    |> Enum.count()
  end

  @doc """
  Función auxiliar que calcula el total de asientos por piso, creada para evitar duplicidad <3!

  ## Ejemplo
      iex> calcula_total_asientos_ocupados_por_piso(%{..}, "1")
      10
  """
  def calcula_total_asientos_ocupados_por_piso(grilla, piso \\ 1) do
    Map.get(grilla, piso)
    |> List.flatten()
    |> Enum.filter(fn i ->
      is_integer(parser_string_to_int(Map.get(i, "asiento"))) && Map.get(i, "estado") == "ocupado"
    end)
    |> Enum.count()
  end
end