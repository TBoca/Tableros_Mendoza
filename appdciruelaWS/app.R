# Cargar librerías necesarias al inicio de tu script
library(shiny)
library(dplyr)
library(ggplot2)
library(DT)
library(leaflet)
library(sf) # Para trabajar con objetos espaciales
library(geoAr) # Para datos geográficos de Argentina
library(bslib) # Para temas y componentes de Bootstrap (opcional, pero mejora la UI)
library(shinyWidgets) # Para pickerInput
library(readxl) 
library(mapview) # <--- Nueva librería
library(webshot2)
library(patchwork)
library(ggpubr)# <--- Nueva librería!

# --- Carga de datos ---
# Revisa si el archivo de datos existe antes de intentar leerlo

#df <- read_excel("df.xlsx")
df <- read_excel("base_RUTciruela.xlsx")

df <- df %>%
  mutate(UbicacionEstablecimientoDepto = trimws(UbicacionEstablecimientoDepto)) %>%
  # Normalizar los nombres de los departamentos para que coincidan con geoAr
  mutate(UbicacionEstablecimientoDepto = stringr::str_to_title(UbicacionEstablecimientoDepto)) %>%
  mutate(Anio = as.numeric(Anio)) %>%
  # Convertir latitud y longitud a valores numéricos
  mutate(latitud = as.numeric(latitud),
         longitud = as.numeric(longitud))

# --- Datos geográficos de Argentina (Mendoza) ---
mendoza <- get_geo(geo = "MENDOZA")

# Tu tabla de referencia para los nombres de los departamentos
referencia_deptos_mendoza <- tibble(
  coddepto_censo = c("007", "014", "021", "028", "035", "042", "049", "056", "063", "070", "077", "084", "091", "098", "105", "112", "119", "126"),
  nombre_departamento = c("Capital","General Alvear","Godoy Cruz", "Guaymallén", "Junín", "La Paz", "Las Heras", "Lavalle", "Luján de Cuyo", "Maipú", "Malargüe", "Rivadavia", "San Carlos", "San Martín",
                          "San Rafael","Santa Rosa","Tunuyán","Tupungato")
)

# Unir los datos geográficos con los nombres de departamento usando tu tabla de referencia
mendoza_con_nombres <- mendoza %>%
  left_join(referencia_deptos_mendoza, by = "coddepto_censo") %>%
  mutate(nombre_departamento = stringr::str_to_title(nombre_departamento))
# --- Interfaz de Usuario (UI) ---
ui <- fluidPage(
  # Estilo CSS personalizado para el encabezado en color ciruela
  tags$head(
    tags$style(HTML("
      .navbar-default, .well {
        background-color: #E6D5E6 !important;
      }
      .titulo-ciruela {
        background-color: #E6D5E6;
        color: #5D3A5D;
        padding: 20px;
        margin-bottom: 20px;
        border-radius: 5px;
        text-align: center;
        font-weight: bold;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      }
    "))
  ),
  
  # Encabezado con color ciruela
  div(class = "titulo-ciruela",
      h2("Análisis del Índice Tecnológico para ciruela Industria", style = "margin: 0;")
  ),
  
  sidebarLayout(
    sidebarPanel(
      width = 3,
      h4("Ajustar Pesos del Índice:"),
      numericInput("a", "Peso 'valor_riego' (a):", value = 0.4, min = 0, max = 1, step = 0.1),
      numericInput("b", "Peso 'valor_granizo' (b):", value = 0.4, min = 0, max = 1, step = 0.1),
      numericInput("c", "Peso 'valor_helada' (c):", value = 0.2, min = 0, max = 1, step = 0.1),
      
      uiOutput("suma_check"), # Mensaje de verificación de la suma de pesos
      actionButton("reset", "Restablecer Pesos", icon = icon("refresh")),
      tags$hr(), # Línea horizontal para separar secciones
      
      h4("Filtrar Departamentos:"),
      pickerInput("deptos", "Seleccionar departamentos:",
                  choices = unname(sort(unique(df$UbicacionEstablecimientoDepto))),
                  selected = unname(sort(unique(df$UbicacionEstablecimientoDepto))), # Todos seleccionados por defecto
                  multiple = TRUE,
                  options = list(
                    `actions-box` = TRUE, # Muestra las opciones "Seleccionar todos" / "Deseleccionar todos"
                    `live-search` = TRUE, # Permite buscar departamentos
                    `deselect-all-text` = "Deseleccionar todos",
                    `select-all-text` = "Seleccionar todos",
                    `none-selected-text` = "Ninguno seleccionado"
                  )
      ),
      tags$hr(),
      
      h4("Filtrar por Categoría de Edad:"),
      # Nuevo filtro para la categoría de edad
      pickerInput("categoria_edad_filtro", "Seleccionar Categoría de Edad:",
                  choices = c("Todas",
                              "Establecimiento",
                              "Inicial",
                              "Plena",
                              "Decreciente"),
                  selected = "Todas",
                  multiple = TRUE, # Permite seleccionar múltiples categorías
                  options = list(
                    `actions-box` = TRUE,
                    `live-search` = TRUE,
                    `deselect-all-text` = "Deseleccionar todos",
                    `select-all-text` = "Seleccionar todos",
                    `none-selected-text` = "Todas"
                  )
      ),
      tags$hr(),
      
      h4("Filtrar por Rango de Índice Tecnológico:"),
      sliderInput("rango_indice", 
                  "Seleccionar rango de valores:",
                  min = 0, 
                  max = 100, 
                  value = c(0, 100),
                  step = 5,
                  post = " pts"),
    ),
    
    mainPanel(
      width = 9,
      # --- Usamos tabsetPanel para organizar las pestañas ---
      tabsetPanel(
        id = "main_tabs", # Un ID para el panel de pestañas
        tabPanel("Gráficos Comparativos", # Primera pestaña - solo gráficos
                 div(style = "padding: 15px; background-color: #f8f9fa; border-left: 4px solid #FFDAB9; margin-bottom: 20px;",
                     p(style = "margin: 0; font-size: 14px;", 
                       "Estos gráficos muestran la distribución del índice tecnológico cuando se ponderan con igual peso todos los factores y cómo se modifica al cambiarlos.")
                 ),
                 plotOutput("indicePlot", height = "700px")
        ),
        
        tabPanel("Tabla Estadísticas", # Segunda pestaña - tabla de estadísticas
                 h3("Estadísticas del Índice Tecnológico por Departamento"),
                 fluidRow(
                   column(6, style = "padding-right: 15px;",
                          div(style = "background-color: #f8f9fa; padding: 15px; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);",
                              h4("Pesos por defecto (1/3 c/u)", style = "text-align: center; color: #4682B4; margin-top: 0;"),
                              DTOutput("tablaResumenIndiceDefecto")
                          )
                   ),
                   column(6, style = "padding-left: 15px;",
                          div(style = "background-color: #f8f9fa; padding: 15px; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);",
                              h4(textOutput("titulo_tabla_ajustada"), style = "text-align: center; color: #228B22; margin-top: 0;"),
                              DTOutput("tablaResumenIndice")
                          )
                   )
                 ),
                 tags$hr(),
                 h3("Comparación Gráfica por Departamento", style = "margin-top: 30px;"),
                 fluidRow(
                   column(6,
                          h4("Pesos por defecto (1/3 c/u)", style = "text-align: center; color: #4682B4;"),
                          plotOutput("graficoBarrasDefecto", height = "500px")
                   ),
                   column(6,
                          h4(textOutput("titulo_grafico_ajustado"), style = "text-align: center; color: #228B22;"),
                          plotOutput("graficoBarrasAjustado", height = "500px")
                   )
                 )
        ),
        
        tabPanel("Mapas (Promedio / Máx / Mín / Var)", # Tercera pestaña con 4 mapas
                 fluidRow(
                   column(6, leafletOutput("map_promedio", height = 330)),
                   column(6, leafletOutput("map_maximo", height = 330))
                 ),
                 fluidRow(
                   column(6, leafletOutput("map_minimo", height = 330)),
                   column(6, leafletOutput("map_varianza", height = 330))
                 )
        ),
        
        tabPanel("Consideraciones Técnicas", # Cuarta pestaña - documentación técnica
                 div(style = "padding: 20px; max-width: 1200px;",
                     h2("Consideraciones técnicas en la definición del índice tecnológico"),
                     
                     p("Para determinar el Índice tecnológico se consideraron los principales factores técnicos de manejo:"),
                     tags$ol(
                       tags$li(tags$strong(tags$span(style = "font-size: 16px;", "Sistema de riego"))),
                       tags$li(tags$strong(tags$span(style = "font-size: 16px;", "Sistema de defensa contra granizo"))),
                       tags$li(tags$strong(tags$span(style = "font-size: 16px;", "Sistema de defensa contra heladas")))
                     ),
                     
                     h4("1. Sistemas de riego"),
                     p("Para ponderar tecnológicamente los sistemas de riego de mejor a peor, se consideró una combinación de factores como:"),
                     tags$ul(
                       tags$li("Eficiencia en el uso del agua"),
                       tags$li("Grado de automatización"),
                       tags$li("Nivel tecnológico y de inversión"),
                       tags$li("Capacidad de control sobre la aplicación de agua"),
                       tags$li("Adaptabilidad a distintos cultivos y suelos")
                     ),
                     DTOutput("tabla_riego"),
                     
                     h4("2. Sistema de defensa contra granizo"),
                     p("Se estimó el porcentaje de malla anti-granizo de cada productor utilizando:"),
                     p(strong("porc_malla = (SuperficieMallaLote / SuperficieLote) * 100")),
                     p("Niveles considerados:"),
                     tags$ul(
                       tags$li("porc_malla = 0 → Sin malla"),
                       tags$li("porc_malla entre 0 y 50 → Baja cobertura (1-50%)"),
                       tags$li("porc_malla entre 50 y 100 → Alta cobertura (51-99%)"),
                       tags$li("porc_malla = 100 → Cobertura total (100%)")
                     ),
                     DTOutput("tabla_granizo"),
                     
                     h4("3. Sistema de defensa contra heladas"),
                     p("Nivel de protección que brinda el sistema considerando:"),
                     tags$ul(
                       tags$li("Grado de intervención tecnológica"),
                       tags$li("Costo de implementación y mantenimiento"),
                       tags$li("Capacidad de control"),
                       tags$li("Aplicabilidad y uso en fruticultura intensiva")
                     ),
                     DTOutput("tabla_heladas"),
                     
                     h3("Estimación del índice tecnológico"),
                     p("El valor del índice tecnológico se estima ponderando los valores tecnológicos:"),
                     p(strong("Índice_tecnológico = α * valor_riego + β * valor_granizo + γ * valor_heladas")),
                     p("Donde α, β y γ son coeficientes de ponderación que suman 1 (uno)."),
                     
                     h3("Ajuste del Índice tecnológico según el riesgo"),
                     p("Para construir el índice tecnológico ajustado por riesgo, se ponderaron los valores tecnológicos en función del nivel de riesgo asociado."),
                     p("Cuando el riesgo de helada o granizo era menor al 10% y el valor tecnológico de la práctica era menor a 50, 
                       el valor se duplicó. En los demás casos, los valores se mantuvieron sin cambios."),
                     p("De esta manera, el índice tecnológico con valores bajos en zonas de bajo riesgo donde esta tecnología no es necesaria 
                       se le asigna mayor peso relativo a las prácticas tecnológicas.")
                 )
        )
      )
    )
  )
)


# --- Lógica del Servidor (Server) ---
server <- function(input, output, session) {
  
  # Control de la suma de pesos (a + b + c)
  output$suma_check <- renderUI({
    total <- input$a + input$b + input$c
    if (abs(total - 1) > 0.01) {
      div(style = "color: red; font-weight: bold; margin-top: 10px;",
          paste("⚠️ La suma de a + b + c es", round(total, 2), ", debe ser 1"))
    }
  })
  
  # Restablecer pesos a valores predeterminados
  observeEvent(input$reset, {
    updateNumericInput(session, "a", value = 0.4)
    updateNumericInput(session, "b", value = 0.4)
    updateNumericInput(session, "c", value = 0.2)
  })
  
  # --- Datos Reactivos Base ---
  # Esta expresión reactiva realiza el filtrado inicial, el cálculo de 'Indice_tec',
  # y AHORA también el cálculo de Edad y CategoriaEdad.
  df_base_calculado <- reactive({
    req(input$deptos) # Requiere que al menos un departamento esté seleccionado
    
    # Obtener el año actual
    anio_actual <- as.numeric(format(Sys.Date(), "%Y"))
    
    data_filtered <- df %>%
      filter(UbicacionEstablecimientoDepto %in% input$deptos,
             DatosPersonaDireccionProvincia == "Mendoza",
             Anio > 1959) %>%
      mutate(
        # Asegurarse de que estas columnas sean numéricas para los cálculos
        valor_riego = as.numeric(valor_riego),
        valor_granizo = as.numeric(valor.granizo.ajustado),
        valor_helada = as.numeric(valor.helada.ajustado),
        # Cálculo del Índice_tec basado en los pesos del usuario
        Indice_tec = input$a * valor_riego + input$b * valor_granizo + input$c * valor_helada) 
    
    # --- Filtrado por CategoriaEdad (si aplica) ---
    if (!("Todas" %in% input$categoria_edad_filtro)) {
      # En tu código original usabas 'Categoria_Edad' en varios lugares; mantengo ese nombre
      data_filtered <- data_filtered %>%
        filter(Categoria_Edad %in% input$categoria_edad_filtro)
    }
    
    # --- Filtrado por rango de Índice Tecnológico ---
    data_filtered <- data_filtered %>%
      filter(Indice_tec >= input$rango_indice[1] & Indice_tec <= input$rango_indice[2])
    
    return(data_filtered)
  })
  
  # --- Datos Reactivos con Pesos por Defecto (0.25 cada uno) ---
  df_base_defecto <- reactive({
    req(input$deptos) # Requiere que al menos un departamento esté seleccionado
    
    data_filtered <- df %>%
      filter(UbicacionEstablecimientoDepto %in% input$deptos,
             DatosPersonaDireccionProvincia == "Mendoza",
             Anio > 1959) %>%
      mutate(
        # Asegurarse de que estas columnas sean numéricas para los cálculos
        valor_riego = as.numeric(valor_riego),
        valor_granizo = as.numeric(valor.granizo.ajustado),
        valor_helada = as.numeric(valor.helada.ajustado),
        # Cálculo con pesos por defecto (1/3 cada uno)
        Indice_tec = (1/3) * valor_riego + (1/3) * valor_granizo + (1/3) * valor_helada) 
    
    # --- Filtrado por CategoriaEdad (si aplica) ---
    if (!("Todas" %in% input$categoria_edad_filtro)) {
      data_filtered <- data_filtered %>%
        filter(Categoria_Edad %in% input$categoria_edad_filtro)
    }
    
    # --- Filtrado por rango de Índice Tecnológico ---
    data_filtered <- data_filtered %>%
      filter(Indice_tec >= input$rango_indice[1] & Indice_tec <= input$rango_indice[2])
    
    return(data_filtered)
  })
  
  # --- Renderizado del Gráfico ---
  output$indicePlot <- renderPlot({
    df_resumen_plot <- df_base_calculado() %>% # Ahora toma los datos directamente de df_base_calculado
      group_by(Anio, UbicacionEstablecimientoDepto, Categoria_Edad) %>%
      summarise(promedio_indice = mean(Indice_tec, na.rm = TRUE), .groups = "drop") %>%
      mutate(Anio = as.numeric(Anio))
    
    req(nrow(df_resumen_plot) > 0) # Asegura que haya datos para graficar
    
    # Elimina los niveles de factor no utilizados para evitar paneles vacíos en facet_wrap
    df_resumen_plot$UbicacionEstablecimientoDepto <- droplevels(factor(df_resumen_plot$UbicacionEstablecimientoDepto))
    
    # --- GRÁFICOS Y TABLAS CON PESOS POR DEFECTO ---
    grafico_defecto <- ggplot(df_base_defecto(), aes(x = Indice_tec)) +
      geom_histogram(fill = "steelblue", color = "black", bins = 20) +
      xlab("Índice tecnológico") +
      ylab("Frecuencia") +
      ggtitle("Pesos por defecto (1/3 c/u)") +
      theme_bw() +
      theme(plot.title = element_text(size = 12, face = "bold"))
    
    tabla_defecto <- df_base_defecto() %>%
      summarise(
        n = n(),
        Media = mean(Indice_tec, na.rm = TRUE),
        Mediana = median(Indice_tec, na.rm = TRUE),
        `Desvío estándar` = sd(Indice_tec, na.rm = TRUE),
        Mínimo = min(Indice_tec, na.rm = TRUE),
        Máximo = max(Indice_tec, na.rm = TRUE)
      ) %>%
      round(2) %>%
      t() %>%
      as.data.frame()
    
    colnames(tabla_defecto) <- "Valor"
    tabla_defecto$Estadístico <- rownames(tabla_defecto)
    tabla_defecto <- tabla_defecto[, c("Estadístico", "Valor")]
    
    tabla_gg_defecto <- ggtexttable(tabla_defecto, rows = NULL, theme = ttheme("light", base_size = 14))
    
    # --- GRÁFICOS Y TABLAS CON PESOS AJUSTADOS POR EL USUARIO ---
    grafico_ajustado <- ggplot(df_base_calculado(), aes(x = Indice_tec)) +
      geom_histogram(fill = "green", color = "black", bins = 20) +
      xlab("Índice tecnológico ajustado") +
      ylab("Frecuencia") +
      ggtitle(paste0("Pesos ajustados (a=", input$a, ", b=", input$b, ", c=", input$c, ")")) +
      theme_bw() +
      theme(plot.title = element_text(size = 12, face = "bold"))
    
    tabla_ajustada <- df_base_calculado() %>%
      summarise(
        n = n(),
        Media = mean(Indice_tec, na.rm = TRUE),
        Mediana = median(Indice_tec, na.rm = TRUE),
        `Desvío estándar` = sd(Indice_tec, na.rm = TRUE),
        Mínimo = min(Indice_tec, na.rm = TRUE),
        Máximo = max(Indice_tec, na.rm = TRUE)
      ) %>%
      round(2) %>%
      t() %>%
      as.data.frame()
    
    colnames(tabla_ajustada) <- "Valor"
    tabla_ajustada$Estadístico <- rownames(tabla_ajustada)
    tabla_ajustada <- tabla_ajustada[, c("Estadístico", "Valor")]
   
    tabla_gg_ajustada <- ggtexttable(tabla_ajustada, rows = NULL, theme = ttheme("light", base_size = 14))
    
    # Combinar los gráficos en dos filas
    fila1 <- ggarrange(grafico_defecto, tabla_gg_defecto, ncol = 2, widths = c(2, 1))
    fila2 <- ggarrange(grafico_ajustado, tabla_gg_ajustada, ncol = 2, widths = c(2, 1))
    
    ggarrange(fila1, fila2, nrow = 2)
  })

  
  # --- Datos Reactivos para la Tabla de Resumen ---
  # Prepara los datos específicamente para la tabla (resumen por Departamento y Categoría de Edad)
  df_para_tabla <- reactive({
    df_data_base <- df_base_calculado() # Toma los datos base ya filtrados y con 'Indice_tec' calculado
    
    req(nrow(df_data_base) > 0) # Asegura que haya datos antes de resumir
    
    # Agrupa por departamento y ahora también por CategoriaEdad y resume el 'Indice_tec'
    df_data_base %>%
      group_by(UbicacionEstablecimientoDepto, Categoria_Edad) %>%
      summarise(
        Promedio = mean(Indice_tec, na.rm = TRUE),
        Desvio_Estandar = sd(Indice_tec, na.rm = TRUE),
        Minimo = min(Indice_tec, na.rm = TRUE),
        Maximo = max(Indice_tec, na.rm = TRUE),
        N_Observaciones = n(),
        .groups = "drop" # Elimina el agrupamiento después de resumir
      ) %>%
      # Ordenar por departamento y luego por la categoría de edad para una mejor visualización
      arrange(UbicacionEstablecimientoDepto, Categoria_Edad)
  })
  
  # --- Datos Reactivos para la Tabla con Pesos por Defecto ---
  df_para_tabla_defecto <- reactive({
    df_data_base <- df_base_defecto() # Usa los datos con pesos por defecto
    
    req(nrow(df_data_base) > 0)
    
    df_data_base %>%
      group_by(UbicacionEstablecimientoDepto, Categoria_Edad) %>%
      summarise(
        Promedio = mean(Indice_tec, na.rm = TRUE),
        Desvio_Estandar = sd(Indice_tec, na.rm = TRUE),
        Minimo = min(Indice_tec, na.rm = TRUE),
        Maximo = max(Indice_tec, na.rm = TRUE),
        N_Observaciones = n(),
        .groups = "drop"
      ) %>%
      arrange(UbicacionEstablecimientoDepto, Categoria_Edad)
  })
  
  # --- Título dinámico para la tabla ajustada ---
  output$titulo_tabla_ajustada <- renderText({
    paste0("Pesos ajustados (a=", input$a, ", b=", input$b, ", c=", input$c, ")")
  })
  
  # --- Renderizado de la Tabla con Valores por Defecto ---
  output$tablaResumenIndiceDefecto <- renderDT({
    df_tabla <- df_para_tabla_defecto()
    
    req(nrow(df_tabla) > 0)
    
    # Simplificar nombres de columnas para tabla más compacta
    df_tabla_compacta <- df_tabla %>%
      select(Departamento = UbicacionEstablecimientoDepto,
             Categoría = Categoria_Edad,
             Promedio,
             N = N_Observaciones)
    
    datatable(
      df_tabla_compacta,
      options = list(
        pageLength = 10,
        lengthMenu = c(5, 10, 15, 20),
        searching = FALSE,
        dom = 'ltp',
        scrollX = TRUE,
        columnDefs = list(
          list(width = '120px', targets = 0),
          list(width = '80px', targets = 1),
          list(width = '60px', targets = 2),
          list(width = '40px', targets = 3)
        )
      ),
      rownames = FALSE
    ) %>%
      formatRound(columns = c("Promedio"), digits = 2)
  })
  
  # --- Renderizado de la Tabla con Valores Ajustados ---
  output$tablaResumenIndice <- renderDT({
    df_tabla <- df_para_tabla() # Llama a la expresión reactiva para obtener los datos de la tabla
    
    req(nrow(df_tabla) > 0) # Asegura que la tabla resultante tenga filas para mostrar
    
    # Simplificar nombres de columnas para tabla más compacta
    df_tabla_compacta <- df_tabla %>%
      select(Departamento = UbicacionEstablecimientoDepto,
             Categoría = Categoria_Edad,
             Promedio,
             N = N_Observaciones)
    
    datatable(
      df_tabla_compacta,
      options = list(
        pageLength = 10,
        lengthMenu = c(5, 10, 15, 20),
        searching = FALSE,
        dom = 'ltp',
        scrollX = TRUE,
        columnDefs = list(
          list(width = '120px', targets = 0),
          list(width = '80px', targets = 1),
          list(width = '60px', targets = 2),
          list(width = '40px', targets = 3)
        )
      ),
      rownames = FALSE
    ) %>%
      formatRound(columns = c("Promedio"), digits = 2)
  })
  
  # --- Título dinámico para el gráfico ajustado ---
  output$titulo_grafico_ajustado <- renderText({
    paste0("Pesos ajustados (a=", input$a, ", b=", input$b, ", c=", input$c, ")")
  })
  
  # --- Gráfico de barras con valores por defecto ---
  output$graficoBarrasDefecto <- renderPlot({
    df_resumen <- df_base_defecto() %>%
      group_by(UbicacionEstablecimientoDepto) %>%
      summarise(PromedioIndice = mean(Indice_tec, na.rm = TRUE), .groups = "drop")
    
    req(nrow(df_resumen) > 0)
    
    ggplot(df_resumen, aes(x = UbicacionEstablecimientoDepto, y = PromedioIndice)) +
      geom_col(width = 0.6, fill = "steelblue", color = "black") +
      theme_bw(base_size = 10) +
      coord_flip()  +
      labs(
        x = "UbicacionEstablecimientoDepto",
        y = "Promedio Índice Tecnológico"   ) +
      theme(legend.position = "bottom")
  })
  
  # --- Gráfico de barras con valores ajustados ---
  output$graficoBarrasAjustado <- renderPlot({
    df_resumen <- df_base_calculado() %>%
      group_by(UbicacionEstablecimientoDepto) %>%
      summarise(PromedioIndice = mean(Indice_tec, na.rm = TRUE), .groups = "drop")
    
    req(nrow(df_resumen) > 0)
    
    ggplot(df_resumen, aes(x = UbicacionEstablecimientoDepto, y = PromedioIndice)) +
      geom_col(width = 0.6, fill = "green", color = "black") +
      theme_bw(base_size = 10) +
      coord_flip() +
            labs(
        x = "UbicacionEstablecimientoDepto",
        y = "Promedio Índice Tecnológico"
      ) +
      theme(legend.position = "bottom")
  })
  
  # --- Datos Reactivos para el Mapa (original: promedio) ---
  # Prepara los datos específicamente para el mapa (promedio por Departamento, ya filtrado por categoría de edad)
  df_para_mapa <- reactive({
    # Usamos directamente df_base_calculado() que ya tiene los filtros aplicados
    df_data_mapa <- df_base_calculado() %>%
      group_by(UbicacionEstablecimientoDepto) %>%
      summarise(
        promedio_indice = mean(Indice_tec, na.rm = TRUE),
        .groups = "drop")
    
    # Unir con los datos geográficos de geoAr
    mendoza_con_nombres %>%
      right_join(df_data_mapa, by = c("nombre_departamento" = "UbicacionEstablecimientoDepto")) %>%
      st_as_sf() # Convertir de nuevo a objeto sf después de la unión
  })
  
  # --- Expresión reactiva que genera el objeto del mapa Leaflet (original) ---
  # Esto nos permite usar el mismo objeto para mostrar y para descargar
  map_object_reactive <- reactive({
    df_mapa <- df_para_mapa()
    req(nrow(df_mapa) > 0)
    
    # Verificar si hay valores válidos para el dominio de la paleta
    domain_values <- df_mapa$promedio_indice[!is.na(df_mapa$promedio_indice)]
    
    # Crear una paleta de colores para el índice
    paleta <- colorNumeric(
      palette = c("#ffffcc", "#d9f0a3", "#addd8e", "#78c679"),
      domain = if (length(domain_values) > 0) domain_values else c(0, 1), # Asegura un dominio si no hay datos
      na.color = "grey" # Color para los departamentos sin datos
    )
    
    # Crear etiquetas interactivas para el mapa
    etiquetas_mapa <- paste(
      "<strong>", df_mapa$nombre_departamento, "</strong><br/>",
      "<strong>Índice Tecnológico Promedio:</strong>", round(df_mapa$promedio_indice, 2)
    ) %>% lapply(htmltools::HTML)
    
    # Construir el mapa de leaflet
    leaflet(df_mapa) %>%
      addTiles() %>% # Agrega un mapa base (como OpenStreetMap)
      addPolygons(
        fillColor = ~paleta(promedio_indice), # Aquí usamos la paleta para colorear
        weight = 1,
        opacity = 1,
        color = "black",
        dashArray = "3",
        fillOpacity = 0.7,
        highlightOptions = highlightOptions(
          weight = 3,
          color = "#666",
          dashArray = "",
          fillOpacity = 0.9,
          bringToFront = TRUE),
        label = etiquetas_mapa, # Agregamos las etiquetas interactivas
        labelOptions = labelOptions(
          style = list("font-weight" = "normal", padding = "3px 8px"),
          textsize = "15px",
          direction = "auto"
        )
      ) %>%
      # Agregar la leyenda de colores
      addLegend(
        pal = paleta,
        values = ~promedio_indice,
        opacity = 0.7,
        title = "Valor del Índice", # Título de la leyenda
        position = "bottomright"
      )
  })
  
  # --- Renderizado del Mapa en la UI (original: promedio) ---
  output$indiceMap <- renderLeaflet({
    map_object_reactive() # Llama a la expresión reactiva para obtener el mapa
  })
  
  # -------------------------------------------------------------
  #  NUEVO: Resumen por Departamento con Promedio / Máx / Mín / Var
  # -------------------------------------------------------------
  df_mapa_resumen <- reactive({
    df_base_calculado() %>%
      group_by(UbicacionEstablecimientoDepto) %>%
      summarise(
        promedio = mean(Indice_tec, na.rm = TRUE),
        maximo   = max(Indice_tec, na.rm = TRUE),
        minimo   = min(Indice_tec, na.rm = TRUE),
        cv = (sd(Indice_tec, na.rm = TRUE) / mean(Indice_tec, na.rm = TRUE)) * 100,
        .groups = "drop"
      ) %>%
      # Unir con la geometría/tabla de nombres como hiciste antes
      left_join(mendoza_con_nombres, by = c("UbicacionEstablecimientoDepto" = "nombre_departamento")) %>%
      mutate(nombre_departamento = UbicacionEstablecimientoDepto) %>%
      st_as_sf()
  })
  
  # Función genérica para crear un mapa leaflet a partir de un sf con la variable
  crear_mapa <- function(data, variable, titulo, colores, datos_puntos = NULL) {
    # si data está vacío, retornar leaflet vacío
    if (is.null(data) || nrow(data) == 0) {
      return(leaflet() %>% addTiles())
    }
    
    valores <- data[[variable]]
    # evitar nombres en vectores (warning jsonlite)
    valores <- unname(valores)
    
    pal <- colorNumeric(
      palette = colores,
      domain = if (length(valores[!is.na(valores)])>0) valores[!is.na(valores)] else c(0,1),
      na.color = "white"
    )
    
    etiquetas <- paste0(
      "<strong>", data$nombre_departamento, "</strong><br/>",
      "<strong>", titulo, ":</strong> ", ifelse(is.na(valores), "NA", round(valores, 3))
    ) %>% lapply(htmltools::HTML)
    
    # Crear mapa base con polígonos
    mapa <- leaflet(data) %>%
      addTiles() %>%
      addPolygons(
        fillColor = ~pal(valores),
        weight = 1,
        color = "black",
        dashArray = "3",
        fillOpacity = 0.5,  # Reducido para que se vean mejor los puntos
        highlightOptions = highlightOptions(
          weight = 3,
          color = "#666",
          dashArray = "",
          fillOpacity = 0.7,
          bringToFront = FALSE  # Cambiado para que los puntos queden adelante
        ),
        label = etiquetas,
        labelOptions = labelOptions(
          style = list("font-weight" = "normal", padding = "3px 8px"),
          textsize = "13px",
          direction = "auto"
        ),
        group = "Departamentos"
      ) %>%
      addLegend(
        pal = pal,
        values =  valores[!is.na(valores)],
        opacity = 0.8,
        title = titulo,
        position = "bottomright"
      )
    
    # Agregar puntos si hay datos puntuales
    if (!is.null(datos_puntos) && nrow(datos_puntos) > 0) {
      # Filtrar datos con coordenadas válidas
      datos_validos <- datos_puntos %>%
        filter(!is.na(latitud) & !is.na(longitud) & !is.na(Indice_tec))
      
      if (nrow(datos_validos) > 0) {
        # Paleta de colores para los puntos
        pal_puntos <- colorNumeric(
          palette = c("#fee5d9", "#fcae91", "#fb6a4a", "#de2d26", "#a50f15"),
          domain = datos_validos$Indice_tec
        )
        
        # Etiquetas para los puntos
        etiquetas_puntos <- paste0(
          "<strong>Departamento:</strong> ", datos_validos$UbicacionEstablecimientoDepto, "<br/>",
          "<strong>Índice Tecnológico:</strong> ", round(datos_validos$Indice_tec, 2)
        ) %>% lapply(htmltools::HTML)
        
        mapa <- mapa %>%
          addCircleMarkers(
            data = datos_validos,
            lng = ~longitud,
            lat = ~latitud,
            radius = 5,
            fillColor = ~pal_puntos(Indice_tec),
            color = "black",
            weight = 2,
            fillOpacity = 0.8,
            label = etiquetas_puntos,
            labelOptions = labelOptions(
              style = list("font-weight" = "normal", padding = "5px"),
              textsize = "12px"
            ),
            group = "Puntos"
          )
      }
    }
    
    return(mapa)
  }
  
  # --- Salidas: los 4 mapas generados (Promedio / Máx / Mín / Varianza) ---
  output$map_promedio <- renderLeaflet({
    crear_mapa(df_mapa_resumen(),
               "promedio",
               "IT Promedio",
               c("#ffffcc", "#c7e9b4", "#7fcdbb", "#41b6c4"),
               datos_puntos = df_base_calculado())
  })
  
  output$map_maximo <- renderLeaflet({
    crear_mapa(df_mapa_resumen(),
               "maximo",
               "IT Máximo",
               c("#f7fcf5", "#c7e9c0", "#74c476", "#238b45"),
               datos_puntos = df_base_calculado())
  })
  
  output$map_minimo <- renderLeaflet({
    crear_mapa(df_mapa_resumen(),
               "minimo",
               "IT Mínimo",
               c("#f7fbff", "#c6dbef", "#6baed6", "#2171b5"),
               datos_puntos = df_base_calculado())
  })
  
  output$map_varianza <- renderLeaflet({
    crear_mapa(df_mapa_resumen(),
               "cv",
               "IT CV (%)",
               c("#fff5f0", "#fcbba1", "#fb6a4a", "#cb181d"),
               datos_puntos = df_base_calculado())
  })
  
  # --- Tablas para la pestaña de Consideraciones Técnicas ---
  output$tabla_riego <- renderDT({
    sistemas_riego <- data.frame(
      Orden = 1:9,
      Sistema = c(
        "Por Goteo", "Subsuperficial (goteo)", "Por Pulso", "Por Microaspersión",
        "Por Aspersión", "Otro Presurizado", "Por Surco",
        "Por Manto (Melga, Inundación)", "Otro No Presurizado"
      ),
      Tipo = c(rep("Presurizado", 6), rep("No Presurizado", 3)),
      Nivel_Tecnológico = c(
        "Muy Alto", "Muy Alto", "Muy Alto", "Alto", "Medio-Alto", "Variable",
        "Medio-Bajo", "Bajo", "Muy Bajo"
      ),
      Eficiencia = c("90-95%", ">95%", ">95%", "80-90%", "60-80%", "60-90%",
                     "50-60%", "30-50%", "<30%"),
      Valor_Tecnológico = c(100, 100, 100, 95, 85, 85, 50, 30, 20)
    )
    
    datatable(sistemas_riego, 
              caption = "Orden tecnológico de sistemas de riego con valor asignado",
              options = list(pageLength = 10, dom = 't'),
              rownames = FALSE)
  })
  
  output$tabla_granizo <- renderDT({
    defensa_granizo <- data.frame(
      Orden = 1:4,
      Sistema = c(
        "Cobertura total (100%)",
        "Alta cobertura (51-99%)",
        "Baja cobertura (1-50%)",
        "Sin malla"
      ),
      Nivel_Protección = c("Muy Alto", "Alto", "Media", "Nula"),
      Valor_Tecnológico = c(100, 80, 40, 0),
      Comentarios = c(
        "Máxima protección; inversión elevada; recomendada en zonas de alto riesgo",
        "Buena protección; posible cobertura sectorizada según riesgo o cultivo",
        "Cobertura parcial, puede ser estratégica pero deja áreas vulnerables",
        "Sin protección; alto riesgo de pérdida ante granizo"
      )
    )
    
    datatable(defensa_granizo,
              caption = "Valor tecnológico de sistemas de defensa antigranizo",
              options = list(pageLength = 5, dom = 't'),
              rownames = FALSE)
  })
  
  output$tabla_heladas <- renderDT({
    defensa_heladas <- data.frame(
      Orden = 1:4,
      Sistema = c(
        "Activa (riego por aspersión supra o sub arbóreo)",
        "Activa (combustibles líquidos o sólidos)",
        "Pasiva (preparación de suelos y riego)",
        "Ninguna"
      ),
      Tipo = c("Activa", "Activa", "Pasiva", "Ninguna"),
      Nivel_Protección = c("Muy Alto", "Alta", "Media", "Nula"),
      Valor_Tecnológico = c(100, 90, 30, 00),
      Comentarios = c(
        "Requiere infraestructura y manejo preciso; alta efectividad",
        "Costosa, depende del suministro de energía o combustible",
        "Mejora el microclima, bajo costo; depende de anticipación y diseño",
        "Alto riesgo de daño; no se toman medidas para mitigar las heladas"
      )
    )
    
    datatable(defensa_heladas,
              caption = "Valor tecnológico de sistemas de defensa contra heladas",
              options = list(pageLength = 5, dom = 't'),
              rownames = FALSE)
  })
  
}


# --- Ejecutar la Aplicación Shiny ---
shinyApp(ui, server)

