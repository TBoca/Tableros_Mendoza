# Tableros_Mendoza

Tableros interactivos (R Shiny) del **Índice Tecnológico** por especie frutícola,
construidos a partir de las bases RUT del Ministerio de Mendoza.

## Aplicaciones

| Carpeta | Especie | Base de datos |
|---|---|---|
| [`appduraznoWS`](appduraznoWS/app.R) | Durazno industria | `base_RUTdurazno.xlsx` |
| [`appVIDWS`](appVIDWS/app.R) | Vid | `base_RUTvid.xlsx` |
| [`appdciruelaWS`](appdciruelaWS/app.R) | Ciruela industria | `base_RUTciruela.xlsx` |
| [`appolivoWS`](appolivoWS/app.R) | Olivo | `base_RUTolivo.xlsx` |

Cada carpeta es una aplicación Shiny autocontenida:

- `app.R` — interfaz y servidor (una sola aplicación por carpeta).
- `base_RUT*.xlsx` — microdatos de los establecimientos productivos.
- `Riesgos.xlsx` — matriz de riesgos usada en las consideraciones técnicas.

Las cuatro comparten la misma estructura de solapas: gráficos comparativos,
tabla de estadísticas, mapas por departamento (promedio, máximo, mínimo y
varianza) y consideraciones técnicas sobre la definición del índice.

## Ejecutar localmente

```r
install.packages(c("shiny", "dplyr", "ggplot2", "DT", "leaflet", "sf",
                   "geoAr", "bslib", "shinyWidgets", "readxl",
                   "mapview", "webshot2", "patchwork", "ggpubr",
                   "stringr", "tibble"))

shiny::runApp("appduraznoWS")
```

Reemplace `appduraznoWS` por la carpeta del cultivo que quiera abrir.

## Publicación

Los tableros se publican en Posit Connect Cloud desde este repositorio.

| Tablero | Enlace |
|---|---|
| Durazno | _pendiente_ |
| Vid | _pendiente_ |
| Ciruela | _pendiente_ |
| Olivo | _pendiente_ |
