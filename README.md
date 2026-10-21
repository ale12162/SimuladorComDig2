# Comunicaciones Digitales Avanzadas - Fundación Fulgor

Trabajos prácticos del grupo (Stangaferro, Baccino, Garces). Cada TP tiene su
carpeta con el código que genera los resultados y el informe en LaTeX.

```
TP1/                 Simulación de sistemas de comunicaciones digitales
  simulador/         Simulador (MATLAB) tal como quedó en el TP1
  informe/           Informe (main.tex) y presentación
TP2_Optica/          Modelado de transmisores ópticos con MZM
  simulador/         lib/ (modelos) y tests/ (un script por ejercicio)
  informe/           Informe (main.tex)
TP2_Comp_LTX/        Compensación de efectos de transmisor
  simulador/         Simulador del TP1 + transmisor DP-MZM y compensadores
                     de desbalance I/Q y skew
  informe/           Informe (main.tex)
```

## Cómo correr

- **TP1**: desde `TP1/simulador`, `run_ej1`, `run_ej2`, `run_ej4` y `ejercicio3_fcr`.
- **TP2 óptica**: desde `TP2_Optica/simulador/tests`, el script de cada
  ejercicio (agregan `../lib` al path).
- **TP2 compensación**: desde `TP2_Comp_LTX/simulador`, `run_tp2_ej2` a
  `run_tp2_ej6`. Las figuras se guardan en `TP2_Comp_LTX/informe/figuras` y
  los resultados en `resultados_tp2/`. Con el transmisor DP-MZM y los
  compensadores apagados (`config_default`), este simulador reproduce los
  resultados del TP1.

El código de `TP2_Optica/simulador` es una copia del repositorio
`Repo_Com2_Fulgor` (rama `baccino_garces_stangaferro`, commit `8645ff6`).
Los modelos de driver, MZM y láser que usa el TP2 de compensación están
copiados en `TP2_Comp_LTX/simulador/optica`.
