# Guion de presentación — TP1: Simulación de Sistemas de Comunicaciones Digitales

**Duración total:** 30 min · **Integrantes:** Alejandro Stangaferro, Luca Baccino, Gabriel Garces

| Bloque | Quién | Tiempo | Minutos |
|---|---|---|---|
| Introducción + Ej. 1 (simulador) | Luca | ~6 min | 0:00 – 6:00 |
| Ej. 2 (curvas de BER) | Luca | ~6 min | 6:00 – 12:00 |
| Ej. 3 (jitter: FFE vs DPLL, PEDs) | Integrante 2 | ~9 min | 12:00 – 21:00 |
| Ej. 4 (CCR: offset de portadora) + cierre | Integrante 3 | ~9 min | 21:00 – 30:00 |

> Los `[Diapo]` indican qué mostrar. El texto entre comillas es para decir en voz alta; los
> puntos sueltos son "ayuda-memoria". Los números son los del informe.

---

## PARTE 1 — Luca: Introducción y Ejercicio 1 (≈ 6 min)

### [Diapo 1 — Portada]

"Buenas. Somos Alejandro, Gabriel y Luca, y vamos a presentar el Trabajo Práctico 1: la
simulación de un sistema de comunicaciones digitales pasabanda. Yo voy a contar cómo armamos
el simulador y las curvas de BER; después Alejandro/Gabriel van a mostrar el comportamiento
de la recuperación de portadora frente a jitter y a offset de frecuencia."

### [Diapo 2 — Diagrama en bloques]

"El sistema es un enlace 16-QAM a 32 Gbaudios. Del lado del transmisor generamos símbolos
QAM con codificación Gray, los conformamos con un coseno realzado raíz de roll-off 0,5 y los
llevamos a la tasa del canal.

En el canal aplicamos tres cosas en orden: un filtro que introduce ISI, ruido blanco
gaussiano calibrado en Eb/N0, y los efectos de portadora: una fase estática, un offset de
frecuencia y un jitter sinusoidal.

En el receptor tenemos el filtro adaptado, que también hace de anti-alias, el cambio de tasa
al dominio del DSP, un AGC, y después el lazo principal: un ecualizador FFE, el NCO que
corrige la fase, y el slicer. Al final, un alineador, una corrección de cycle slips y el
contador de BER."

- Un archivo `.m` por bloque; todo hasta el AGC está vectorizado, el lazo FFE/NCO/slicer va
  símbolo a símbolo porque hay realimentación.

### [Diapo 3 — Tasas y configuración default]

"Trabajamos con tres dominios de muestreo: 2 muestras por símbolo en el transmisor, 4 en el
canal y 2 en el DSP. Con 32 Gbaudios eso es 64, 128 y 64 GHz. Las tasas son configurables:
el filtro RRC y el anti-alias se diseñan solos para el oversampling que se pida, y el
resampler hace el cambio por un factor L/M con un filtro polifásico."

| | |
|---|---|
| Modulación | 16-QAM, BR = 32 GBd |
| OVS TX / CH / DSP | 2 / 4 / 2 SPS → 64 / 128 / 64 GHz |
| Pulso | RRC β = 0,5, span 20 → ancho de banda ±0,75·BR = ±24 GHz |
| FFE | 41 taps a T/2, μ_CMA = 3·10⁻⁴, μ_DD = 3·10⁻⁵ |
| CPR | RFD + DPLL de 2º orden, k_p = 2·10⁻², k_i = k_p/500 |

### [Diapo 4 — Calibración del ruido]

"Un punto crítico es calibrar bien el ruido, porque si no las curvas de BER no se pueden
comparar con la teórica. Medimos la potencia por muestra a la salida del canal, que está
normalizado a energía unitaria; la energía por símbolo es esa potencia por el oversampling
del canal, y de ahí despejamos la varianza del ruido."

  σ² = P_s · OVS_CH / ((Eb/N0) · log₂M)

### [Diapo 5 — Decisiones de diseño del lazo]

"Hay algunas decisiones de diseño que no son obvias:

- **El error del CMA** se calcula **antes** de la derrotación, porque el CMA solo mira el
  módulo y es ciego a la fase.
- **El error del DD-LMS** sí se calcula después del NCO, pero se le **deshace la rotación**
  antes de actualizar los taps. Si no, el ecualizador y el NCO compiten por corregir la misma
  fase.
- **Selección de anillo:** en 16-QAM, elevar a la cuarta no saca la modulación para todos
  los puntos. Solo los 8 puntos con |I| = |Q|, los diagonales, tienen arg(a⁴) = π; los
  otros 8 dan ±73,7°. Entonces los elegimos por su módulo, que es un criterio ciego a la
  fase y sirve aunque la constelación esté girando.
- **El RFD**, el detector grueso de frecuencia, usa dos ganancias: una alta para adquirir y
  una baja para seguir. Con una sola no se puede tener a la vez rango amplio y bajo ruido.
- **El DPLL**: con k_p = 5·10⁻³ no engancha. El RFD deja un residuo de frecuencia y el DPLL
  tiene que poder absorberlo; por eso subimos a 2·10⁻²."

### [Diapo 6 — FSM de 7 etapas]

"El orden en que se habilitan los algoritmos lo maneja una máquina de estados. La idea es
que cada etapa habilita un algoritmo solo cuando la anterior le garantizó sus condiciones de
operación."

| # | Etapa | Por qué ahí |
|---|---|---|
| 1 | FFE-CMA | Único algoritmo que funciona con el ojo cerrado |
| 2 | + RFD adquisición | Ya hay ojo abierto → se puede estimar la frecuencia |
| 3 | + RFD tracking + FCR 4ª potencia | Frecuencia gruesa estimada → enganchar fase |
| 4 | CMA + FCR-DD | Fase enganchada → decisiones confiables para el PED |
| 5 | FFE-DD + FCR-DD | Decisiones confiables → ecualizar con DD |
| 6 | Alineación + cycle slips | Receptor en régimen |
| 7 | BER | Estado estacionario |

### [Diapo 7 — Resultados de la corrida de ejemplo]

"Para mostrar todo funcionando corrimos el canal moderado a Eb/N0 = 16 dB con todos los
efectos de portadora: 0,7 rad de fase, un offset de BR/200 y jitter de 0,05 rad.

En la constelación por etapas se ve que en las etapas 1 y 2 hay anillos: el CMA ecualiza
pero no frena la rotación. Los anillos se cierran en la etapa 3, cuando entra el detector de
fase de cuarta potencia, y ahí también salta el MSE y la SNR."

Verificación (decir los tres primeros):
- RFD converge a **0,00722·BR**, integral del FCR a **−0,00222·BR** → suman **0,005·BR**, el
  offset aplicado.
- El NCO crece con pendiente 2π/200 = **0,0314 rad/símbolo**.
- SNR en el slicer **19,12 dB** contra 22,02 dB ideal → **2,9 dB** de penalidad, que es la
  amplificación de ruido del FFE en este canal (lo vemos en el Ej. 2).
- El FFE: el tap central cerca de 1 y los demás cancelan la ISI; su respuesta en frecuencia
  es el espejo de la del canal. Con 41 taps aparecía un piso entre 20 y 32 GHz porque los
  taps de los extremos no habían caído a cero; con 101 taps desaparece.

---

## PARTE 2 — Luca: Ejercicio 2, curvas de BER (≈ 6 min)

### [Diapo 8 — Configuración y canales]

"En el ejercicio 2 barrimos Eb/N0 para cuatro canales, sin efectos de portadora pero con
todos los algoritmos activos y la FSM completa en cada punto. La ventana de BER se
dimensiona sola para contar al menos 100 errores, con un tope de 2,5 millones de símbolos.

Como no hay offset, el RFD solo integraría ruido y podría irse fuera del rango de enganche
del DPLL, así que lo acotamos a BR/500.

Los canales los elegimos espaciados en símbolo para que la severidad la determinen las
raíces de H(z): cuanto más cerca de la circunferencia unitaria, más profundo es el nulo y
más ganancia tiene que poner el ecualizador."

| Perfil | H(z) | \|z\| | Tilt | Penalidad |
|---|---|---|---|---|
| Impulso | 1 | — | 0 dB | ≤ 0,06 dB |
| Leve | 1 + 0,15z⁻¹ | 0,15 | 2,6 dB | 0,2–0,3 dB |
| Moderado | 1 + 0,45z⁻¹ − 0,20z⁻² | 0,73; 0,28 | 11,7 dB | 2,6–2,9 dB |
| Agresivo | 1 + 0,80z⁻¹ + 0,35z⁻² − 0,20z⁻³ | 0,82; 0,82; 0,30 | 16,4 dB | 6,2–8,4 dB |

### [Diapo 9 — Calibración: penalidad < 0,1 dB]

"El requisito era una penalidad menor a 0,1 dB en el canal sin distorsión, y la logramos:
queda plana en 0,06 dB. Para llegar ahí hubo cuatro decisiones:

1. **41 taps**: con 31 la respuesta se truncaba y daba 0,4 dB.
2. **μ_DD chico**, 3·10⁻⁵: con 5·10⁻⁴ el ruido de gradiente sumaba 0,1 dB.
3. **Receptor MMSE insesgado**: el LMS converge a la solución de Wiener, que achica la
   constelación por un factor α = γ/(1+γ). Como el slicer tiene una grilla fija, eso es
   distancia perdida al umbral. Estimamos α a ciegas y lo dividimos: recupera 0,04 a
   0,08 dB.
4. **AGC lento**, μ = 10⁻⁴: con 10⁻³ el jitter de ganancia era de un 2 %. Como es un
   deterioro multiplicativo, pesa más cuanto más alta es la SNR, y eso hacía que la
   penalidad *creciera* con Eb/N0 en un canal ideal, algo que no tenía sentido físico."

### [Diapo 10 — Curvas de BER + respuestas canal/FFE]

"La curva del canal ideal se superpone con la analítica. Los nulos caen donde predicen las
raíces: en ±BR/2 para el leve y el moderado, porque tienen una raíz real negativa, y en
±0,37·BR para el agresivo, por su par de raíces complejas conjugadas.

Y en las respuestas se ve el mecanismo: el FFE es el espejo del canal. En el moderado el
canal cae −10,1 dB en BR/2 y el FFE sube +9 dB; en el agresivo, −13,1 contra +12."

### [Diapo 11 — Limitación de la ecualización lineal]

"La conclusión principal del ejercicio es que el FFE no elimina la ISI: la cambia por
ruido. Para compensar una banda atenuada la única herramienta que tiene es darle ganancia,
y esa ganancia también la recibe el ruido de esa banda.

El LMS resuelve ese compromiso en sentido de mínimo error cuadrático:

  W_MMSE(f) = H*(f) / (|H(f)|² + N0/Es)

A baja SNR el término N0/Es domina y el ecualizador renuncia a invertir del todo el canal.
A alta SNR ese término desaparece y la solución tiende a zero-forcing, 1/H, que amplifica el
ruido por 1/|H|².

Por eso la penalidad no es constante: en el agresivo pasa de 6,2 a 8,4 dB al subir Eb/N0, y
las curvas de BER no son la teórica corrida sino curvas de menor pendiente que se separan
cada vez más."

"Con esto les dejo a [Integrante 2], que va a contar cómo se comporta la recuperación de
portadora frente a jitter."

---

## PARTE 3 — Integrante 2: Ejercicio 3, jitter (≈ 9 min)

### [Diapo 12 — Planteo]

"En el ejercicio 3 agregamos un jitter sinusoidal de fase, φ(t) = A·sin(2π·f_j·t), con
A = 0,1 rad y f_j = 9,6 MHz. Como métrica usamos el error de fase residual,
e_res = ∠(y_r · â*). Si nadie compensa, su RMS teórico es A/√2 = 0,0707 rad."

### [Diapo 13 — Sanidad: FFE vs DPLL]

| Caso | RMS residual | SNR | Penalidad |
|---|---|---|---|
| FFE normal, DPLL apagado | 0,06641 rad | 16,24 dB | 1,02 dB |
| FFE rápido (μ_dd = 2·10⁻³), DPLL apagado | 0,03253 rad | 16,74 dB | 0,35 dB |
| FFE congelado, DPLL prendido | **0,00809 rad** | 17,19 dB | **0,002 dB** |

"Con el FFE normal el RMS es casi el teórico sin compensar: prácticamente no sigue el
jitter. Si lo hacemos más rápido sigue una parte, pero queda una componente sinusoidal. El
DPLL lo elimina casi por completo: un cuarto del RMS del FFE rápido, y menos de un décimo en
potencia."

### [Diapo 14 — Barrido con PED de 4ª potencia]

"Después barrimos k_p en 5·10⁻³, 10⁻², 2·10⁻² y 5·10⁻², y 12 frecuencias de jitter entre
3,2 MHz y 1 GHz. El FFE converge y se congela, para medir solo el DPLL.

Hay tres zonas: a baja frecuencia el lazo sigue el jitter y no hay penalidad; después una
transición; y a alta frecuencia la penalidad satura en 1 dB, porque ahí el lazo ya no ve el
jitter y queda entero. Al subir k_p la transición se corre hacia frecuencias más altas, o
sea, más ancho de banda, pero también pasa más ruido del detector al NCO."

### [Diapo 15 — PED dirigido por decisiones y comparación]

"Con el detector DD el comportamiento es parecido, pero mantiene la penalidad baja hasta
frecuencias más altas. Por ejemplo, con k_p = 2·10⁻² a 44 MHz: 0,56 dB con cuarta potencia
contra 0,22 dB con DD. Con k_p = 5·10⁻² a 125 MHz: 0,56 contra 0,26.

La razón es que el DD saca información de fase de prácticamente todos los símbolos,
e_DD = Im{y·â*}/|â|², mientras que el de cuarta potencia solo usa los diagonales. Para el
mismo k_p, el DD tiene más ganancia efectiva y por lo tanto más ancho de banda. En los
extremos las curvas coinciden: a baja frecuencia los dos siguen, a alta ninguno."

---

## PARTE 4 — Integrante 3: Ejercicio 4, offset de portadora (≈ 9 min)

### [Diapo 16 — Planteo]

"El ejercicio 4 evalúa el rango de adquisición del RFD, el detector grueso de frecuencia.
Usamos el canal moderado, con Eb/N0 elegido para BER ≈ 10⁻³, y solo offset de frecuencia,
sin fase estática ni jitter. La FSM completa de 7 etapas."

### [Diapo 17 — Cómo funciona el RFD]

"El RFD trabaja sobre los puntos diagonales, que se comportan como una QPSK rotada 45°.
Plegamos el ángulo módulo π/2 y centramos: θ = mod(∠y, π/2) − π/4. Si hay frecuencia
residual, ese ángulo va derivando y cada tanto 'salta' de un borde al otro. El sentido del
salto dice el signo de la frecuencia, y el integrador da un paso fijo en sentido contrario.
Es un detector bang-bang."

### [Diapo 18 — Barrido en ±BR/12]

| f_off / BR | f_RFD final / BR | BER |
|---|---|---|
| −0,0833 | −0,0847 | 1,21·10⁻³ |
| −0,0556 | −0,0539 | 1,03·10⁻³ |
| −0,0278 | −0,0291 | 8,63·10⁻⁴ |
| 0 | 0,0012 | 8,93·10⁻⁴ |
| 0,0278 | 0,0288 | 8,85·10⁻⁴ |
| 0,0556 | 0,0565 | 1,00·10⁻³ |
| 0,0833 | 0,0842 | 1,19·10⁻³ |

"Los siete casos enganchan: el RFD converge en la etapa 2 al offset real y se mantiene
estable. Lo que no cancela, porque es de paso fijo, lo absorbe la rama integral del DPLL a
partir de la etapa 3. Y la BER se mantiene en torno a 10⁻³, el punto de calibración."

### [Diapo 19 — Límite fundamental: BR/8]

"El offset produce un incremento de fase por símbolo Δφ = 2π·f_off/BR. Como el detector
trabaja con una ambigüedad de π/2, igual que uno de cuarta potencia, solo puede distinguir
incrementos en (−π/4, π/4]. Entonces:

  |2π · f_off / BR| < π/4  ⟹  |f_off| < BR/8   (4 GHz a 32 GBd)

Fuera de ese rango el detector aliasea y engancha en f_off − k·BR/4."

### [Diapo 20 — Validación del límite]

| f_off / BR | f_RFD final / BR | BER |
|---|---|---|
| 1/16 ≈ 0,0625 | 0,0610 | 1,11·10⁻³ |
| ≈ 1/8⁻ | 0,1240 | 1,57·10⁻³ |
| ≈ 1/8⁺ | −0,1226 | 0,5 |
| 1/6 ≈ 0,1667 | −0,0843 | 0,5 |

"Por debajo de BR/8 converge bien, con un transitorio más largo cerca del límite. Apenas lo
pasamos, converge a un valor de signo opuesto: 1/6 − 1/4 = −0,0833, y medimos −0,0843. No
diverge ni se satura: engancha de forma estable pero en el lugar equivocado, y la BER se va
a 0,5. Es un límite del detector, no de las ganancias del lazo."

### [Diapo 21 — Conclusiones generales]

- El simulador reproduce la curva teórica con < 0,1 dB de penalidad en canal ideal.
- La ecualización lineal cambia ISI por ruido: la penalidad crece con la SNR en canales con
  nulos profundos.
- El DPLL sigue el jitter mucho mejor que el FFE; k_p fija el compromiso ancho de banda vs.
  ruido, y el PED DD da más ancho de banda que el de 4ª potencia.
- El RFD engancha en ±BR/12 y su límite fundamental es ±BR/8, validado por simulación.

"Gracias. ¿Preguntas?"

---

## ANEXO A — Para entender los Ejercicios 3 y 4 (por si te preguntan a vos)

### Ej. 3 — Qué es el DPLL y por qué se comporta así

- **Lazo:** PED (mide el error de fase) → filtro de lazo (proporcional k_p + integral k_i)
  → NCO (acumula la fase θ que se le resta a la señal).
- **El integral** está para el offset de frecuencia (una rampa de fase). Con k_i = k_p/500 es
  muy chico, así que frente al jitter el lazo se comporta casi como de **primer orden**.
- **Ancho de banda aproximado:** un lazo de primer orden con ganancia k_p por símbolo tiene
  un ancho de banda de **B ≈ k_p·BR/(2π)**.
  - k_p = 5·10⁻³ → ≈ 25 MHz · k_p = 10⁻² → ≈ 51 MHz
  - k_p = 2·10⁻² → ≈ 100 MHz · k_p = 5·10⁻² → ≈ 255 MHz
  - (para el PED de 4ª potencia es menos, porque solo actualiza con ~la mitad de los símbolos)
- **Función de error:** el lazo es un pasa-altos para el jitter. El residuo ≈ A·f/√(f² + B²).
  - f ≪ B → el lazo sigue, residuo ≈ 0, sin penalidad.
  - f ≫ B → el lazo no ve el jitter, residuo = A/√2 completo → **satura**.
- **Por qué satura justo en ~1 dB:** el jitter no seguido agrega una varianza A²/2 = 0,005
  rad². A SNR ≈ 17,2 dB (1/SNR ≈ 0,019): 10·log((0,019 + 0,005)/0,019) ≈ **1,0 dB**. Coincide
  con el 1,02 dB del "FFE normal" de la sanidad: ahí tampoco nadie seguía el jitter.
- **Por qué no subir k_p infinitamente:** el ruido del PED pasa al NCO en proporción al ancho
  de banda; con k_p grande la fase estimada se vuelve ruidosa (y con mucho ruido el lazo
  puede tener cycle slips).
- **Por qué el FFE sigue un poco:** sus taps son complejos, así que pueden rotar la señal;
  pero adapta con μ muy chico, es un "lazo" lentísimo. Con μ rápido mejora pero agrega ruido
  de gradiente y nunca llega al DPLL.
- **4ª potencia vs DD:** el de 4ª potencia es ciego a la decisión (sirve para adquirir), pero
  solo usa los diagonales; el DD usa todos los símbolos pero necesita decisiones correctas
  (por eso en la FSM entra después).

### Ej. 4 — Qué es el RFD y por qué el límite es BR/8

- **Idea:** si la constelación gira con una frecuencia residual, el ángulo de los puntos
  diagonales (plegado módulo 90°) va derivando y cruza los bordes. Contar para qué lado cruza
  da el **signo** de la frecuencia; el integrador da pasos fijos (±μ) hasta que no cruza más.
- **Gear shifting:** μ_acq grande en la etapa 2 para llegar rápido, μ_trk chico en la etapa
  3 para que el residuo sea chico (el residuo del integrador crece como √μ).
- **Por qué BR/8:** por la simetría de 90° de la QPSK, una rotación de +Δ por símbolo es
  indistinguible de una de Δ − 90°. El detector siempre interpreta la más chica en módulo, que
  está en (−45°, 45°]. Un Δφ = 2π·f_off/BR menor a π/4 da **f_off < BR/8**.
- **Por qué engancha en f − BR/4:** 90° por símbolo equivale a BR/4. Si f_off = 1/8⁺, la
  interpretación "más chica" es f_off − 1/4 ≈ −1/8.
- **Por qué la BER da 0,5 y no se corrige:** el error que queda es exactamente BR/4, es decir,
  90° por símbolo. Para el PED de 4ª potencia y el DD, una rotación de 90° es invisible (la
  constelación es simétrica), así que nadie la corrige y cada símbolo cae rotado distinto
  respecto del anterior. El alineador solo corrige una rotación fija, no una que avanza.
- **Por qué importa el k_p del DPLL acá:** el RFD deja un residuo (hasta ~0,0016·BR en la
  tabla). El DPLL tiene que poder engancharlo: su rango ≈ k_p·π/4 rad/símbolo = k_p/8·BR =
  **0,0025·BR** con k_p = 2·10⁻². Con k_p = 5·10⁻³ ese rango es 0,0006·BR y no alcanza → por
  eso no enganchaba en el Ej. 1.

---

## ANEXO B — Preguntas probables y respuestas cortas

**¿Por qué tres tasas de muestreo distintas?**
El canal necesita más muestras (4 SPS) para modelar bien el filtro y el ruido sin aliasing; el
DSP trabaja a 2 SPS (T/2) porque es lo mínimo para un FFE fraccionario robusto a la fase de
muestreo, y es más barato.

**¿Por qué el FFE es fraccionario (T/2)?**
Es insensible a la fase de muestreo y puede sintetizar el filtro adaptado; uno a T sufre
aliasing espectral y depende del instante de muestreo.

**¿Por qué el CMA primero?**
Es el único algoritmo que funciona con el ojo cerrado y con la constelación girando: solo
mira el módulo.

**¿Qué es la penalidad y cómo la miden?**
La diferencia entre Es/N0 ideal (Eb/N0 + 10·log₁₀4 = Eb/N0 + 6,02 dB) y la SNR medida a la
entrada del slicer.

**¿Por qué la penalidad crece con Eb/N0 en el canal agresivo?**
Porque el MMSE tiende a zero-forcing al subir la SNR: invierte más el nulo y amplifica más
ruido.

**¿Por qué cortan el barrido de BER?**
Para contar al menos 100 errores; por debajo de ~5·10⁻⁶ haría falta demasiado tiempo de
simulación.

**¿Qué es un cycle slip y cómo lo corrigen?**
Un salto de 90° en la fase enganchada (por la ambigüedad de π/2). Se detecta por bloques de
256 símbolos comparando contra la secuencia transmitida alineada, y se corrige rotando.

**¿Por qué acotaron el RFD a BR/500 en el Ej. 2?**
Sin offset, el integrador solo acumula ruido; a Eb/N0 bajo derivaba hasta ~0,005·BR, fuera
del rango de enganche del DPLL (0,0025·BR), y la BER se iba a 0,5.

**¿Qué pasa si aumentan los taps del FFE?**
Mejora el truncamiento (desaparece el piso entre 20–32 GHz con 101 taps) pero aumenta el
ruido de gradiente y el costo; 41 fue el compromiso para < 0,1 dB.

---

## ⚠️ Antes de presentar

- Los valores de μ_DD, μ_AGC y el canal agresivo de `simulador/config_default.m` y
  `channel_profiles.m` **no coinciden** con el informe (el código del repo es una versión
  anterior). Si muestran código, usen la versión final; si preguntan, los valores válidos son
  los del informe: μ_DD = 3·10⁻⁵, μ_AGC = 10⁻⁴, agresivo 1 + 0,80z⁻¹ + 0,35z⁻² − 0,20z⁻³.
- Tener a mano el Eb/N0 que se usó en el Ej. 4 (para BER ≈ 10⁻³) y el canal/Eb/N0 del Ej. 3:
  el informe no los dice y es una pregunta probable.
