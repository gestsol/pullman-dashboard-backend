# Pullman Dashboard Backend

## Sobre el proyecto 
El proyecto provee datos KPI  para analizar los servicios en tiempo real. 

## Detalles generales del back-end
1. Back-end recibe petición REST desde front-end. 
2. Datos obtenidos en: (1), se utilizan para preparar peticiones REST 
3. Los datos obtenidos en: (2) se procesan para generar KPI de interes, al momento:
 * Tasa de ocupación de servicios por tipo (cama o semicama).
4. Con los datos de (3) devolvemos los KPI calculados al front-end.
