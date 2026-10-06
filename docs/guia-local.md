# Ejecutar y explicar Urban Demand

Abre `UrbanDemand.Rproj` en RStudio. Desde la raíz del proyecto:

```r
source("scripts/setup.R")
source("scripts/check_rules.R")
source("scripts/run_analysis.R")
```

El script descarga las fuentes oficiales, comprueba su integridad, revisa los datos y vuelve a comparar los cuatro modelos. La ejecución guarda tablas, predicciones y diez gráficos. Los modelos se seleccionan con datos anteriores al último trimestre de 2012; ese trimestre se utiliza una sola vez para evaluar el modelo seleccionado.

Abre `reports/urban-demand.qmd` y pulsa Render para regenerar el informe. La página interactiva utiliza resultados exportados por R: los controles describen datos históricos y no permiten simular una predicción operativa nueva.

Para una entrevista, explica primero la diferencia entre registros horarios, totales diarios y datos faltantes. Después explica por qué `casual` y `registered` no pueden ser predictores del total. Finalmente muestra la comparación temporal, los errores por hora y la cobertura real de intervalos. La mejora contra una referencia es un resultado del experimento; no representa ahorros de una empresa.
