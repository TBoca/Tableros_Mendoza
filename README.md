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

Los tableros están publicados en Posit Connect Cloud (cuenta `tereboca`) y son de
acceso público.

| Tablero | Enlace |
|---|---|
| Durazno industria | https://01a19c68-7732-67c6-9207-2a78a6cf852c.share.connect.posit.cloud/ |
| Vid | https://01a19c6a-e455-d2de-5060-493b7802f3fc.share.connect.posit.cloud/ |
| Ciruela industria | https://01a19c6b-6f30-a174-afed-eb7911b1376d.share.connect.posit.cloud/ |
| Olivo | https://01a19c6b-ee0a-dbc1-8b03-ac39870810af.share.connect.posit.cloud/ |

Cada tablero se actualiza volviendo a desplegar su carpeta con `rsconnect`:

```r
rsconnect::deployApp("appduraznoWS")
```

La sesión de Connect Cloud de esta máquina queda guardada en `.rsconnect/`,
que no se versiona.

## Página de inicio

`index.html` es la página que reúne los cuatro tableros: una tarjeta por especie
con la captura de la pantalla de inicio, el enlace al tablero y, debajo, un bloque
único con las consideraciones técnicas que comparten los cuatro tableros.

Se abre directamente en el navegador o se publica como sitio estático
(GitHub Pages, Cloudflare Pages o cualquier servidor web). Las imágenes están en
`assets/` y la página no depende de nada externo.

Está publicada con GitHub Pages en **https://tboca.github.io/Tableros_Mendoza/**:
cada push a `main` la actualiza automáticamente.


