defmodule PullmanDashboard.Consultador do
  require Logger

  
  @doc """
  Wrapper sobre Tesla HTTP Client
  """
  def post(url, body \\ nil) do
    Tesla.post(url, Jason.encode!(body), headers: [{"content-type", "application/json"}])
  end

  @doc """
  Wrapper sobre Tesla HTTP Client
  """
  def post_plain(url, body \\ nil) do
    Tesla.post(url, body, headers: [{"content-type", "application/x-www-form-urlencoded"}])
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
  Comienza la ejecución en pipe para calcular indicadores tasa de ocupación
  """
  def start_pipe(params) do
    body_servicios_dia = prepara_body_consulta_servicios_dia(params)
    servicios_dia = obtener_servicios_del_dia(body_servicios_dia)

    Enum.map(servicios_dia, fn x -> 
      body_grilla = prepara_body_grilla_servicio(x)
      grilla = obtener_grilla_servicio(body_grilla)
      calculo_ocupacion = calcular_indicadores(grilla)
      nuevo_mapa = Map.merge(x, calculo_ocupacion)
    end) |> Enum.map(fn y -> Map.delete(y, "logo") end)
    #|> obtener_servicios_del_dia
    #|> obtener_datos_servicio_segun_hora(params)
    #|> prepara_body_grilla_servicio
    #|> obtener_grilla_servicio
    #|> calcular_indicadores
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
  def prepara_body_consulta_servicios_dia(params) do
      %{
        "origen" => Map.get(params, "origen"),
        "destino" => Map.get(params, "destino"),
        "fecha" => Map.get(params, "fecha"),
        "hora" => "0000",
        "idSistema" => 7
      }
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
    String.codepoints("2240")
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
               Map.get(servicio, "servicioSegundoPiso"), servicio}

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
      iex>calcular_indicadores({.., .., ..})
      %{
        "tasa_ocupacion_cama" => 21.43,
        "tasa_ocupacion_semicama" => 78.57,
        "asientos_cama_ocupados" => 10,
        "asientos_semicama_ocupados" => 1,
        "total_venta" => 123,
        "valor_km" => 123,
        "kilometraje" => 123

      }
  """
  def calcular_indicadores(params) do
    {grilla, tipo_primer, tipo_segundo, servicio} = params

    total_asientos = calcula_total_asientos_bus(grilla)
    kilometraje = obtener_kilometraje_servicio(servicio)

    valor_primer_piso = Map.get(servicio, "tarifaPrimerPiso") |> String.replace(".", "") |> parser_string_to_int
    ocupados_primer_piso = calcula_total_asientos_ocupados_por_piso(grilla, "1")

    valor_segundo_piso = Map.get(servicio, "tarifaSegundoPiso", "0") |> String.replace(".", "") |> parser_string_to_int
    ocupados_segundo_piso = calcula_total_asientos_ocupados_por_piso(grilla, "2")

    total_ocupados = ocupados_primer_piso + ocupados_segundo_piso
    disponibles_primer_piso = calcula_total_asientos_disponibles_por_piso(grilla, "1")
    disponibles_segundo_piso = calcula_total_asientos_disponibles_por_piso(grilla, "2")
    total_disponibles = disponibles_primer_piso + disponibles_segundo_piso
    total_venta = (valor_primer_piso*ocupados_primer_piso) + (valor_segundo_piso*ocupados_segundo_piso)
    tasa_total = ((total_ocupados/total_asientos)*100)
    valor_km = total_venta / kilometraje

    %{
      "tasa_ocupacion_cama" => calcula_ocupacion_cama(params, total_asientos),
      "tasa_ocupacion_semicama" => calcula_ocupacion_semi(params, total_asientos),
      "tasa_ocupacion_ejecutivo" => calcula_ocupacion_ejecutivo(params, total_asientos),
      "total_asientos_cama_ocupados" => calcula_asientos_cama_ocupados(params, total_asientos),
      "total_asientos_semicama_ocupados" => calcula_asientos_semicama_ocupados(params, total_asientos),
      "total_asientos_ejecutivo_ocupados" => calcula_asientos_ejecutivos_ocupados(params, total_asientos),
      "total_venta" => total_venta,
      "valor_km" => valor_km,
      "kilometraje" => kilometraje,
      "total_asientos_ocupados" => total_ocupados,
      "total_asientos" => total_asientos,
      "total_disponibles" => total_disponibles,
      "tasa_total" => tasa_total
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
    {grilla, tipo_primer, tipo_segundo, _servicio} = params
    primer_piso = if tipo_primer == "SALON CAMA", do: calcula_total_asientos_ocupados_por_piso(grilla, "1"), else: 0
    segundo_piso = if tipo_segundo == "SALON CAMA" , do: calcula_total_asientos_ocupados_por_piso(grilla, "2") , else: 0

    total_ocupados = primer_piso + segundo_piso
      
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
    {grilla, tipo_primer, tipo_segundo, _servicio} = params
    primer_piso = if tipo_primer == "SEMI CAMA", do: calcula_total_asientos_ocupados_por_piso(grilla, "1"), else: 0
    segundo_piso = if tipo_segundo == "SEMI CAMA", do: calcula_total_asientos_ocupados_por_piso(grilla, "2") , else: 0

    total_ocupados = primer_piso + segundo_piso

    (total_ocupados / total * 100)
    |> Float.round(2)
  end

  @doc """
  Función auxiliar que calcula porcentaje de asientos EJECUTIVO ocupados a partir de 
  grilla vertical recibida. 

  Existe ejemplo del mapa en el archivo
  lib/pullman_dashboard/ejemplos/grilla_vertical.ex

  ## Ejemplo
      iex>calcula_ocupacion_ejecutivo(grilla, total)
      10.4
  """
  def calcula_ocupacion_ejecutivo(params, total) do
    {grilla, tipo_primer, tipo_segundo, _servicio} = params
    primer_piso = if tipo_primer == "EJECUTIVO", do: calcula_total_asientos_ocupados_por_piso(grilla, "1"), else: 0
    segundo_piso = if tipo_segundo == "EJECUTIVO", do: calcula_total_asientos_ocupados_por_piso(grilla, "2") , else: 0

    total_ocupados = primer_piso + segundo_piso

    (total_ocupados / total * 100)
    |> Float.round(2)
  end

  @doc """
  Función auxiliar que calcula numero de asientos CAMA ocupados a partir de 
  grilla vertical recibida. 

  Existe ejemplo del mapa en el archivo
  lib/pullman_dashboard/ejemplos/grilla_vertical.ex

  ## Ejemplo
      iex>calcula_asientos_cama_ocupados(grilla, total)
      10
  """
  def calcula_asientos_cama_ocupados(params, total) do
    {grilla, tipo_primer, tipo_segundo, _servicio} = params
    primer_piso = if tipo_primer == "SALON CAMA", do: calcula_total_asientos_ocupados_por_piso(grilla, "1"), else: 0
    segundo_piso = if tipo_segundo == "SALON CAMA" , do: calcula_total_asientos_ocupados_por_piso(grilla, "2") , else: 0

    total_ocupados = primer_piso + segundo_piso
  end

  @doc """
  Función auxiliar que calcula numero de asientos SEMICAMA ocupados a partir de 
  grilla vertical recibida. 

  Existe ejemplo del mapa en el archivo
  lib/pullman_dashboard/ejemplos/grilla_vertical.ex

  ## Ejemplo
      iex>calcula_asientos_semicama_ocupados(grilla, total)
      5
  """
  def calcula_asientos_semicama_ocupados(params, total) do
    {grilla, tipo_primer, tipo_segundo, _servicio} = params
    primer_piso = if tipo_primer == "SEMI CAMA", do: calcula_total_asientos_ocupados_por_piso(grilla, "1"), else: 0
    segundo_piso = if tipo_segundo == "SEMI CAMA", do: calcula_total_asientos_ocupados_por_piso(grilla, "2") , else: 0

    total_ocupados = primer_piso + segundo_piso
  end

  @doc """
  Función auxiliar que calcula numero de asientos EJECUTIVO ocupados a partir de 
  grilla vertical recibida. 

  Existe ejemplo del mapa en el archivo
  lib/pullman_dashboard/ejemplos/grilla_vertical.ex

  ## Ejemplo
      iex>calcula_asientos_semicama_ocupados(grilla, total)
      5
  """
  def calcula_asientos_ejecutivos_ocupados(params, total) do
    {grilla, tipo_primer, tipo_segundo, _servicio} = params
    primer_piso = if tipo_primer == "EJECUTIVO", do: calcula_total_asientos_ocupados_por_piso(grilla, "1"), else: 0
    segundo_piso = if tipo_segundo == "EJECUTIVO", do: calcula_total_asientos_ocupados_por_piso(grilla, "2") , else: 0

    total_ocupados = primer_piso + segundo_piso
  end

  @doc """
  Calcula el kilometraje para un servicio

  ## Ej
      iex>obtener_kilometraje_servicio(..)
      1200
  """
  def obtener_kilometraje_servicio(servicio) do
    servicios_mes = obtener_servicios_entre_ciudades(servicio)
    mapa = servicios_mes |> hd
    km_total = Map.get(mapa, "kilometraje", 0) |> parser_string_to_int
    cantidad_servicios = Map.get(mapa, "cantidadServicio", 0) |> parser_string_to_int
    km = km_total / cantidad_servicios
  end

  @doc """
  Obtiene listado de servicios para un mes entre ciudades, este listado se usa para obtener
  kilometraje de un servicio dado y realizar el calculo de valor por KM.
  """
  def obtener_servicios_entre_ciudades(servicio) do
    hoy = Date.utc_today
    year = hoy.year
    month = hoy.month

    body = %{
      "origen" => "MA", #Map.get(servicio, "idTerminalOrigen"),
      "destino" => "TE",#Map.get(servicio, "idTerminalDestino"),
      "annio" => "#{year}",
      "mes" => "#{month}"}

    peticion_http = post("https://pullmandashboard.witservices.io/srv-dashboard-web/rest/indicador/buscarHorarioTramoMes", body)

    case peticion_http do
      {:error, _} ->
        nil
        Logger.error("Ocurrió error al obtener kilometraje de servicio!")

      {:ok, response} ->
        case response.status do
          200 ->
            Jason.decode!(response.body)

          _ ->
            Logger.error("Ocurrió error al obtener kilometraje de servicio!")
            nil
        end
    end
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
  Función auxiliar que devuelve un float convertido desde un string mediante 
  Integer.parse, 
  o un atom :no. 

  ## Ejemplo
      iex>parser_string_to_float("1.44")
      1.44
  """
  def parser_string_to_float(str) do
    case Integer.parse(str) do
      {float, _rest} ->
        float

      :error ->
        :no
    end
  end

  @doc """
  Función auxiliar que calcula el total de asientos por piso, creada para evitar duplicidad <3!

  ## Ejemplo
      iex> calcula_total_asientos_por_piso(%{..}, "1")
      12

      * En caso de que el piso no exista (buses de un solo piso).
      iex> calcula_total_asientos_por_piso(%{..}, "3")
      0
  """
  def calcula_total_asientos_por_piso(grilla, piso \\ 1) do
    if is_list(Map.get(grilla, piso)) do
      Map.get(grilla, piso)
      |> List.flatten()
      |> Enum.filter(fn i -> is_integer(parser_string_to_int(Map.get(i, "asiento"))) end)
      |> Enum.count()  
    else
      0
    end
  end

  @doc """
  Función auxiliar que calcula el total de asientos por piso, creada para evitar duplicidad <3!

  ## Ejemplo
      iex> calcula_total_asientos_ocupados_por_piso(%{..}, "1")
      10
      
      * En caso de que el piso no exista (buses de un solo piso).
      iex> calcula_total_asientos_ocupados_por_piso(%{..}, "1")
      0
  """
  def calcula_total_asientos_ocupados_por_piso(grilla, piso \\ 1) do
    if is_list(Map.get(grilla, piso)) do
      Map.get(grilla, piso)
      |> List.flatten()
      |> Enum.filter(fn i ->
        is_integer(parser_string_to_int(Map.get(i, "asiento"))) && Map.get(i, "estado") == "ocupado"
      end)
      |> Enum.count()  
    else
      0
    end  
  end

  @doc """
  Función auxiliar que calcula el total de asientos por piso, creada para evitar duplicidad <3!

  ## Ejemplo
      iex> calcula_total_asientos_ocupados_por_piso(%{..}, "1")
      10
      
      * En caso de que el piso no exista (buses de un solo piso).
      iex> calcula_total_asientos_ocupados_por_piso(%{..}, "1")
      0
  """
  def calcula_total_asientos_disponibles_por_piso(grilla, piso \\ 1) do
    if is_list(Map.get(grilla, piso)) do
      Map.get(grilla, piso)
      |> List.flatten()
      |> Enum.filter(fn i ->
        is_integer(parser_string_to_int(Map.get(i, "asiento"))) && Map.get(i, "estado") != "ocupado"
      end)
      |> Enum.count()  
    else
      0
    end  
  end

  @doc """
  Listado de destinos validos para servicios dado un origen (codigo ciudad origen).
  """
  def obtener_destinos_segun_origen(cod_ciudad_origen) do
    consulta = post_plain("https://pullman.cl/integrador-web/rest/private/venta/buscarCiudadPorCodigo", cod_ciudad_origen)

    case consulta do
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
end