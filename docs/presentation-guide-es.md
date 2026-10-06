# Cómo presentar Urban Demand

## Explicación breve

«Estudié dos años de alquileres de bicicletas con R: 17.379 observaciones horarias y 731 registros diarios. Revisé la calidad y la cobertura, comparé cuatro modelos en ventanas temporales y evalué el modelo elegido en un trimestre posterior. El informe muestra tanto su mejora frente a una referencia sencilla como sus errores y limitaciones».

## Recorrido para una entrevista

1. Abrir el explorador, seleccionar año, tipo de día y clima. Explicar que cada promedio usa horas realmente observadas; una hora ausente no se convierte automáticamente en cero alquileres.
2. Comparar el perfil de días laborables con fines de semana y festivos. Separar descripción de patrones y decisiones operativas: faltan capacidades, tiempos de servicio y costes.
3. Mostrar las tres ventanas de validación y los cuatro candidatos: referencia por hora/tipo de día, Poisson, binomial negativa y binomial negativa con splines. La selección usa el MAE medio de validación.
4. Explicar que octubre–diciembre de 2012 se reserva como prueba final. El MAE baja de 79,95 a 47,05 alquileres por hora frente a la referencia: 41,2% en las mismas 2.168 observaciones.
5. Mostrar las diferencias por hora y clima. Los intervalos nominales de 95% cubren solo 87,6% de la prueba; por ello no deben usarse directamente como una garantía de capacidad.
6. Explicar el bootstrap de bloques de siete días: mantiene parte de la dependencia temporal al comparar errores emparejados. La semilla y el procedimiento están documentados.
7. Mostrar fuente, verificaciones de suma horaria/diaria, diccionario, código, `renv.lock` y archivos de entrega.

## Tres límites que debes poder explicar

El clima usado es observado contemporáneamente: no se ha validado un pronóstico anticipado con información disponible antes de la decisión. `casual` y `registered` son componentes del resultado y se excluyen de los predictores. Los totales del sistema no indican dónde colocar bicicletas: para eso hacen falta movimientos e inventario por estación.

## Preparación técnica

Leer `R/models.R` y `scripts/run_analysis.R`. Practicar la diferencia entre validación y prueba, MAE y WAPE, distribución Poisson y binomial negativa, asociación y causalidad. Ejecutar `scripts/check_rules.R` y reproducir los gráficos antes de presentar el proyecto.
