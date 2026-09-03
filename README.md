# Sistema de Gestión Inmobiliaria — Base de datos MySQL

Prototipo de base de datos para una inmobiliaria que administra un portafolio de
propiedades (casas, apartamentos, locales, oficinas, bodegas y lotes), los
clientes interesados en arrendar o comprar, los contratos firmados y todo el
historial de pagos.

El proyecto incluye modelo normalizado hasta 3FN, funciones definidas por el
usuario, triggers de auditoría, procedimientos almacenados, roles y privilegios
diferenciados, índices de optimización y eventos programados

---


## Contenido

1. [Requisitos](#1-requisitos)
2. [Instalación](#2-instalación)
3. [Estructura del proyecto](#3-estructura-del-proyecto)
4. [Explicación del modelo](#4-explicación-del-modelo)
5. [Funciones personalizadas (UDF)](#5-funciones-personalizadas-udf)
6. [Procedimientos almacenados](#6-procedimientos-almacenados)
7. [Triggers y auditoría](#7-triggers-y-auditoría)
8. [Seguridad: roles y privilegios](#8-seguridad-roles-y-privilegios)
9. [Optimización y eventos programados](#9-optimización-y-eventos-programados)
10. [Ejemplos de consultas](#10-ejemplos-de-consultas)
11. [Pruebas de las reglas de negocio](#11-pruebas-de-las-reglas-de-negocio)
12. [Solución de problemas](#12-solución-de-problemas)

---

## 1. Requisitos

| Componente | Versión mínima | Notas |
|---|---|---|
| MySQL Server | **8.0** | Se usan roles, `CHECK`, `JSON`, ventanas de fecha y `EXPLAIN ANALYZE` |
| Cliente | MySQL CLI o MySQL Workbench 8.x | El instalador maestro usa `SOURCE`, propio del cliente CLI |
| Privilegios | Cuenta con `SUPER` / `SYSTEM_VARIABLES_ADMIN` | Necesarios para `SET GLOBAL event_scheduler = ON` y para crear roles |

Verificar la versión:

```bash
mysql --version
```

---

## 2. Instalación

### Opción A — Instalador maestro (recomendado)

Desde la carpeta raíz del proyecto:

```bash
mysql -u root -p < sql/00_instalar.sql
```

El script pide la contraseña, crea la base de datos `inmobiliaria` desde cero y
ejecuta los ocho scripts en el orden correcto de dependencias. Al terminar
imprime un resumen con la cantidad de tablas, vistas, funciones,
procedimientos, triggers y eventos creados.

### Opción B — Script por script

El orden **importa**: los triggers deben existir antes de cargar los datos, para
que la inserción de contratos dispare la automatización.

```bash
mysql -u root -p < sql/01_ddl.sql
mysql -u root -p < sql/02_funciones.sql
mysql -u root -p < sql/03_procedimientos.sql
mysql -u root -p < sql/04_triggers.sql
mysql -u root -p < sql/05_vistas_indices.sql
mysql -u root -p < sql/06_eventos.sql
mysql -u root -p < sql/07_dml_datos.sql
mysql -u root -p < sql/08_usuarios_roles.sql
```

### Opción C — MySQL Workbench

1. Abrir cada archivo de `sql/` en orden (`File → Open SQL Script`).
2. Ejecutar con el botón del rayo (`Ctrl + Shift + Enter`).
3. **No** usar `00_instalar.sql` en Workbench: el comando `SOURCE` solo existe en
   el cliente de línea de comandos.

> Los archivos ya incluyen `DELIMITER $$`, así que Workbench procesa
> correctamente funciones, procedimientos, triggers y eventos.

### Verificación de la instalación

```sql
USE inmobiliaria;

SELECT
    (SELECT COUNT(*) FROM information_schema.tables
      WHERE table_schema='inmobiliaria' AND table_type='BASE TABLE') AS tablas,
    (SELECT COUNT(*) FROM information_schema.views
      WHERE table_schema='inmobiliaria')                             AS vistas,
    (SELECT COUNT(*) FROM information_schema.routines
      WHERE routine_schema='inmobiliaria')                           AS rutinas,
    (SELECT COUNT(*) FROM information_schema.triggers
      WHERE trigger_schema='inmobiliaria')                           AS triggers,
    (SELECT COUNT(*) FROM information_schema.events
      WHERE event_schema='inmobiliaria')                             AS eventos;
```

Resultado esperado: **29 tablas, 7 vistas, 10 funciones, 10 procedimientos,
14 triggers y 4 eventos**.

---

## 3. Estructura del proyecto

```
PROYECTO-MYSQL2/
├── README.md                     Este documento
├── docs/
│   └── MER.md                    Modelo entidad-relación y normalización
└── sql/
    ├── 00_instalar.sql           Instalador maestro
    ├── 01_ddl.sql                Tablas, PK, FK y restricciones
    ├── 02_funciones.sql          10 funciones (UDF)
    ├── 03_procedimientos.sql     10 procedimientos almacenados
    ├── 04_triggers.sql           14 triggers de auditoría y validación
    ├── 05_vistas_indices.sql     14 índices + 7 vistas
    ├── 06_eventos.sql            4 eventos programados
    ├── 07_dml_datos.sql          Datos de prueba
    ├── 08_usuarios_roles.sql     Roles, usuarios y privilegios
    └── 09_consultas_ejemplo.sql  Consultas de demostración
```

---

## 4. Explicación del modelo

El detalle completo, con el diagrama y la justificación de cada forma normal,
está en **[docs/MER.md](docs/MER.md)**. Resumen de las decisiones clave:

### 4.1 Personas: supertipo y subtipos

```
persona (datos comunes)
   ├── propietario   (datos bancarios para girar el canon)
   ├── cliente       (ocupación, ingresos)
   └── agente        (código, sucursal, % de comisión)
```

En una inmobiliaria real la misma persona puede ser propietaria de un inmueble e
inquilina de otro. Con tres tablas independientes su cédula y su teléfono se
duplicarían y podrían quedar desincronizados. Con este patrón, los datos
personales existen **una sola vez** y cada subtipo se enlaza mediante una FK
`UNIQUE` (relación 1:1).

### 4.2 Contratos: supertipo y subtipos

```
contrato (partes, propiedad, estado, valor, comisión)
   ├── contrato_arriendo (canon, vigencia, día de pago, incremento anual)
   └── contrato_venta    (precio, cuota inicial, escritura, entidad)
```

Evita una tabla con la mitad de las columnas en `NULL` según el tipo de contrato
y permite aplicar `CHECK` y `NOT NULL` reales en cada especialización.

### 4.3 Cartera: cuota ≠ pago

`cuota` es lo que se **debe** (canon del mes, administración, depósito, cuota
inicial, saldo de venta); `pago` es cada abono que se **recibe**. Esta separación
permite pagos parciales, calcular la mora y auditar cada transacción.

### 4.4 Datos derivados que NO se almacenan

Saldos, deudas, días de mora y ocupación **no** se guardan en columnas: se
calculan con funciones. Almacenarlos obligaría a actualizarlos en cada abono, con
riesgo permanente de inconsistencia (anomalía de actualización).

Excepción deliberada: la tabla `comision` y la tabla `reporte_pagos_pendientes`
sí materializan valores, porque son hechos contables e históricos que deben
quedar congelados en el tiempo.

### 4.5 Catálogos en lugar de `ENUM`

Estados y tipos son tablas con FK: agregar un valor no requiere `ALTER TABLE`, se
garantiza integridad referencial y se pueden documentar con una descripción.

---

## 5. Funciones personalizadas (UDF)

| Función | Devuelve | Descripción |
|---|---|---|
| `fn_calcular_comision(id_contrato)` | `DECIMAL(14,2)` | **Comisión del agente.** Venta: precio × % pactado. Arriendo: canon mensual × % pactado |
| `fn_deuda_pendiente(id_contrato)` | `DECIMAL(14,2)` | **Deuda vencida y exigible**: cuotas ya vencidas menos abonos |
| `fn_propiedades_disponibles_por_tipo(id_tipo)` | `INT` | **Total de propiedades disponibles** por tipo (con `NULL` devuelve el total) |
| `fn_saldo_cuota(id_cuota)` | `DECIMAL(14,2)` | Saldo insoluto de una cuota |
| `fn_deuda_total_contrato(id_contrato)` | `DECIMAL(14,2)` | Saldo total, incluidas cuotas por vencer |
| `fn_dias_mora(id_contrato)` | `INT` | Días desde la cuota impaga más antigua |
| `fn_estado_cartera(id_contrato)` | `VARCHAR(20)` | `AL DIA` / `MORA 1-30` / `MORA 31-60` / `MORA 61-90` / `JURIDICO` |
| `fn_nombre_completo(id_persona)` | `VARCHAR(160)` | Nombre completo ignorando los nombres nulos |
| `fn_canon_con_incremento(canon, %, años)` | `DECIMAL(12,2)` | Proyección del canon con incremento compuesto |
| `fn_ocupacion_portafolio()` | `DECIMAL(5,2)` | % de inmuebles colocados |

```sql
-- Comisión de la venta del contrato 9
SELECT fn_calcular_comision(9) AS comision;

-- Cartera del contrato 8
SELECT fn_deuda_pendiente(8)  AS deuda_vencida,
       fn_dias_mora(8)        AS dias_mora,
       fn_estado_cartera(8)   AS clasificacion;

-- Disponibilidad de apartamentos (tipo 2)
SELECT fn_propiedades_disponibles_por_tipo(2) AS apartamentos_disponibles;
```

---

## 6. Procedimientos almacenados

| Procedimiento | Uso |
|---|---|
| `sp_generar_plan_arriendo(...)` | Genera el plan de cuotas del arriendo a partir de sus condiciones (lo invoca el trigger) |
| `sp_generar_cuotas_arriendo(id)` | Fachada: lee el contrato y delega en el anterior |
| `sp_generar_plan_venta(...)` | Genera cuota inicial y saldo de la compraventa |
| `sp_generar_cuotas_venta(id)` | Fachada por id de contrato |
| `sp_registrar_pago(cuota, valor, método, ref, @id)` | **Único** punto de entrada del recaudo; valida el saldo y reactiva el contrato si queda al día |
| `sp_generar_reporte_pagos_pendientes(periodo)` | Genera el snapshot mensual de cartera (lo llama el evento) |
| `sp_actualizar_contratos_vencidos()` | Cierra arriendos expirados y libera el inmueble |
| `sp_marcar_contratos_en_mora()` | Reclasifica contratos con cartera vencida |
| `sp_liquidar_comision(id_contrato)` | Marca la comisión como pagada |
| `sp_buscar_propiedades(tipo, ciudad, precio, hab, operación)` | Buscador paramétrico; los parámetros `NULL` se ignoran |

```sql
-- Registrar un abono de 500.000 en efectivo sobre la cuota 25
CALL sp_registrar_pago(25, 500000.00, 1, 'REC-00125', @id_pago);
SELECT @id_pago;

-- Apartamentos en Bogotá hasta 3.000.000 con 2+ habitaciones
CALL sp_buscar_propiedades(2, 1, 3000000.00, 2, 'ARRIENDO');
```

---

## 7. Triggers y auditoría

Ningún usuario tiene privilegio de escritura sobre las tablas `auditoria_*`.
Solo los triggers escriben en ellas y lo hacen con los privilegios de su
`DEFINER`, de modo que el historial **no se puede alterar** ni siquiera por quien
origina el cambio.

### Auditoría

| Trigger | Tabla | Registra |
|---|---|---|
| `trg_propiedad_ai` | `propiedad` AFTER INSERT | Alta en el portafolio |
| `trg_propiedad_au` | `propiedad` AFTER UPDATE | **Cambio de estado** (disponible → arrendada / vendida) y ajustes de precio |
| `trg_propiedad_bd` | `propiedad` BEFORE DELETE | Baja del portafolio |
| `trg_contrato_ai` | `contrato` AFTER INSERT | **Registro de un nuevo contrato** (JSON con todos los datos) |
| `trg_contrato_au` | `contrato` AFTER UPDATE | Cambio de estado del contrato (antes/después en JSON) |
| `trg_contrato_bd` | `contrato` BEFORE DELETE | Eliminación del contrato |
| `trg_pago_ai` / `trg_pago_ad` | `pago` | Trazabilidad contable de cada abono y de su anulación |

### Automatización

| Trigger | Efecto |
|---|---|
| `trg_contrato_ai` | Cambia el estado de la propiedad a `Arrendada` o `Vendida` según el tipo de contrato |
| `trg_contrato_au` | Al finalizar o cancelar el contrato devuelve la propiedad a `Disponible` |
| `trg_arriendo_ai` | Genera **todo el plan de cuotas** y liquida la comisión del agente |
| `trg_venta_ai` | Genera cuota inicial y saldo, y liquida la comisión |

### Validación (reglas de negocio)

| Trigger | Regla |
|---|---|
| `trg_contrato_bi` | La propiedad debe estar disponible, ofertada para esa operación y el agente activo |
| `trg_propiedad_bu` | No se puede liberar una propiedad con contratos vigentes |
| `trg_pago_bi` | Un abono no puede superar el saldo de la cuota ni tener fecha futura |
| `trg_contrato_bd` / `trg_cuota_bd` / `trg_propiedad_bd` | Protegen la información con historia contable |

```sql
-- Ver el historial de cambios de estado de las propiedades
SELECT codigo_interno, valor_anterior, valor_nuevo, usuario_bd, fecha_hora
FROM v_historico_propiedad
WHERE campo_modificado = 'ESTADO'
ORDER BY fecha_hora DESC;
```

---

## 8. Seguridad: roles y privilegios

| Rol | Puede | No puede |
|---|---|---|
| `rol_admin_inmobiliaria` | Todo el esquema: DDL, DML, rutinas, triggers y eventos | — |
| `rol_agente_inmobiliario` | Consultar el portafolio, registrar personas, clientes, propiedades, visitas y contratos | Registrar pagos, borrar registros, ver la auditoría |
| `rol_contador` | Ver toda la información financiera, gestionar cuotas y comisiones, generar reportes | Insertar pagos directamente (solo vía `sp_registrar_pago`), modificar propiedades o contratos |
| `rol_auditor` | Leer auditoría, bitácora y reportes | Ver datos de contacto, modificar cualquier cosa |

Usuarios de prueba (contraseñas de demostración: **cámbielas antes de cualquier
uso real**):

| Usuario | Contraseña | Rol |
|---|---|---|
| `admin_inmo@localhost` | `Admin#2026` | Administrador |
| `agente_demo@localhost` | `Agente#2026` | Agente inmobiliario |
| `contador_demo@localhost` | `Contador#2026` | Contador |
| `auditor_demo@localhost` | `Auditor#2026` | Auditor |

```bash
# Probar las restricciones con el usuario agente
mysql -u agente_demo -p inmobiliaria
```

```sql
-- Permitido
SELECT * FROM v_propiedades_disponibles;

-- Denegado: ERROR 1142 (SELECT command denied ... table 'pago')
SELECT * FROM pago;
```

El **contador no tiene `INSERT` sobre `pago`**: debe usar `sp_registrar_pago`.
Como el procedimiento se ejecuta con los privilegios de su `DEFINER`, el recaudo
funciona, pero siempre pasa por las validaciones de saldo. Es una aplicación
directa del principio de mínimo privilegio.

---

## 9. Optimización y eventos programados

### Índices

Además de los índices automáticos de InnoDB (PK, UNIQUE y claves foráneas), se
crearon 14 índices que resuelven los patrones reales de consulta:

| Índice | Consulta que optimiza |
|---|---|
| `idx_propiedad_arriendo` / `idx_propiedad_venta` | Búsqueda del catálogo por estado + tipo + rango de precio |
| `idx_propiedad_barrio_estado` | Búsqueda geográfica de inmuebles disponibles |
| `idx_cuota_vencimiento` | Cartera vencida (el filtro más frecuente del sistema) |
| `idx_pago_cuota_valor` | **Índice cubridor**: suma de abonos por cuota sin leer la tabla |
| `idx_contrato_agente_estado` | Productividad por agente |
| `idx_arriendo_vigencia` | Contratos próximos a vencer |

Comprobación del plan de ejecución:

```sql
EXPLAIN
SELECT p.codigo_interno, p.precio_arriendo
FROM propiedad p
WHERE p.id_estado_propiedad = 1
  AND p.id_tipo_propiedad   = 2
  AND p.precio_arriendo <= 3000000;
```

Sin el índice la columna `type` muestra `ALL` (recorrido completo); con
`idx_propiedad_arriendo` muestra `range`/`ref` y `key` con el nombre del índice.

### Vistas

`v_propiedades_disponibles`, `v_contratos_activos`, `v_cartera_vencida`,
`v_comisiones_agente`, `v_historico_propiedad`, `v_resumen_portafolio` y
`v_estado_cuenta`. Además de simplificar las consultas, son la capa de lectura
que se concede a los roles con menos privilegios.

### Eventos programados

| Evento | Frecuencia | Acción |
|---|---|---|
| `ev_reporte_mensual_cartera` | Mensual, día 1 a la 01:00 | **Inserta en `reporte_pagos_pendientes` el estado de pagos vencidos** de todos los contratos vigentes |
| `ev_marcar_contratos_en_mora` | Diario, 02:00 | Reclasifica a `En mora` los contratos con cartera vencida |
| `ev_cierre_contratos_vencidos` | Diario, 03:00 | Finaliza arriendos expirados y libera el inmueble |
| `ev_purgar_auditoria` | Anual | Depura auditoría de propiedades con más de 5 años |

El planificador debe estar activo:

```sql
SET GLOBAL event_scheduler = ON;
SHOW VARIABLES LIKE 'event_scheduler';
```

Para dejarlo permanente, agregar en `my.ini` (Windows) o `my.cnf` (Linux):

```ini
[mysqld]
event_scheduler = ON
```

Para probar el evento mensual sin esperar al día 1:

```sql
CALL sp_generar_reporte_pagos_pendientes(NULL);
SELECT * FROM reporte_pagos_pendientes ORDER BY valor_adeudado DESC;
SELECT * FROM bitacora_evento ORDER BY fecha_hora DESC;
```

---

## 10. Ejemplos de consultas

El archivo `sql/09_consultas_ejemplo.sql` contiene la batería completa. Una
muestra:

**Propiedades disponibles por tipo (UDF exigida)**

```sql
SELECT tp.nombre AS tipo_propiedad,
       fn_propiedades_disponibles_por_tipo(tp.id_tipo_propiedad) AS disponibles
FROM tipo_propiedad tp
ORDER BY disponibles DESC;
```

**Contratos vigentes con su estado de cartera**

```sql
SELECT numero_contrato, propiedad, cliente, canon_mensual,
       deuda_vencida, dias_mora, estado_cartera
FROM v_contratos_activos
ORDER BY dias_mora DESC;
```

**Comisión calculada frente a la liquidada**

```sql
SELECT c.numero_contrato,
       co.valor_comision                   AS registrada,
       fn_calcular_comision(c.id_contrato) AS calculada,
       IF(co.pagada,'Pagada','Pendiente')  AS estado
FROM contrato c
JOIN comision co ON co.id_contrato = c.id_contrato
ORDER BY co.valor_comision DESC;
```

**Recaudo mensual de los últimos 12 meses**

```sql
SELECT DATE_FORMAT(fecha_pago, '%Y-%m') AS mes,
       COUNT(*)                         AS pagos,
       FORMAT(SUM(valor_pagado), 0)     AS total_recaudado
FROM pago
WHERE fecha_pago >= DATE_SUB(CURRENT_DATE, INTERVAL 12 MONTH)
GROUP BY mes
ORDER BY mes DESC;
```

**Arriendos que vencen en los próximos 90 días con su canon de renovación**

```sql
SELECT c.numero_contrato, p.codigo_interno, ca.fecha_fin,
       DATEDIFF(ca.fecha_fin, CURRENT_DATE) AS dias_restantes,
       fn_canon_con_incremento(ca.canon_mensual, ca.incremento_anual_pct, 1) AS canon_renovacion
FROM contrato c
JOIN contrato_arriendo ca ON ca.id_contrato = c.id_contrato
JOIN propiedad p ON p.id_propiedad = c.id_propiedad
JOIN estado_contrato e ON e.id_estado_contrato = c.id_estado_contrato
WHERE e.nombre IN ('Activo','En mora')
  AND ca.fecha_fin BETWEEN CURRENT_DATE AND DATE_ADD(CURRENT_DATE, INTERVAL 90 DAY)
ORDER BY ca.fecha_fin;
```

**Auditoría de contratos con extracción de campos JSON**

```sql
SELECT numero_contrato, accion,
       JSON_UNQUOTE(JSON_EXTRACT(datos_anteriores,'$.estado')) AS estado_anterior,
       JSON_UNQUOTE(JSON_EXTRACT(datos_nuevos,'$.estado'))     AS estado_nuevo,
       usuario_bd, fecha_hora
FROM auditoria_contrato
ORDER BY fecha_hora DESC;
```

---

## 11. Pruebas de las reglas de negocio

Los datos de prueba construyen a propósito cuatro escenarios de cartera:
contratos al día, mora de dos meses, mora con abono parcial y mora superior a 90
días (cobro jurídico). Las fechas son **relativas a la fecha actual**, así que el
escenario sigue siendo válido cualquier día que se ejecute el script.

Cada una de estas sentencias **debe fallar** con un mensaje controlado:

```sql
-- 1. El abono supera el saldo pendiente de la cuota
CALL sp_registrar_pago(1, 999999999.00, 1, 'PRUEBA', @id);

-- 2. La propiedad no está disponible para contratar
INSERT INTO contrato (numero_contrato, id_tipo_contrato, id_propiedad, id_cliente,
                      id_agente, id_estado_contrato, fecha_firma, valor_total)
VALUES ('CTO-9999', 1, 1, 12, 2, 1, CURRENT_DATE, 12000000);

-- 3. El contrato tiene pagos registrados: debe cancelarse, no eliminarse
DELETE FROM contrato WHERE numero_contrato = 'CTO-0001';

-- 4. La propiedad tiene contratos asociados
DELETE FROM propiedad WHERE codigo_interno = 'INM-001';
```

---

## 12. Solución de problemas

| Error | Causa | Solución |
|---|---|---|
| `ERROR 1418 ... you *might* want to use the less safe log_bin_trust_function_creators` | El log binario está activo y las funciones no se consideran seguras | `SET GLOBAL log_bin_trust_function_creators = 1;` y volver a ejecutar `02_funciones.sql` |
| `ERROR 1227 (42000): Access denied; you need SUPER or SYSTEM_VARIABLES_ADMIN` | La cuenta no puede encender el planificador | Ejecutar `06_eventos.sql` como `root`, o activarlo desde `my.ini` |
| `ERROR 1064` en `CREATE FUNCTION`/`TRIGGER` desde una herramienta gráfica | La herramienta no interpreta `DELIMITER` | Usar el cliente CLI o MySQL Workbench (ambos lo soportan) |
| `Unknown command '\.'` al ejecutar `00_instalar.sql` | Se ejecutó en un cliente que no soporta `SOURCE` | Usar la Opción B (script por script) |
| Los eventos no se ejecutan | El planificador está apagado | `SET GLOBAL event_scheduler = ON;` |
| `ERROR 3948` o problemas de codificación con tildes | Cliente en otra codificación | Conectarse con `mysql --default-character-set=utf8mb4` |

---

## Resumen de entregables

| Requisito del enunciado | Dónde está |
|---|---|
| MER normalizado hasta 3FN con decisiones de diseño | `docs/MER.md` |
| Script de creación con tablas, PK y FK | `sql/01_ddl.sql` |
| UDF: comisión de venta, deuda de arriendo, disponibles por tipo | `sql/02_funciones.sql` |
| Triggers de auditoría: cambio de estado y nuevo contrato | `sql/04_triggers.sql` |
| Roles y privilegios (admin, agente, contador) | `sql/08_usuarios_roles.sql` |
| Índices y consultas optimizadas | `sql/05_vistas_indices.sql`, `sql/09_consultas_ejemplo.sql` |
| Evento mensual de pagos pendientes | `sql/06_eventos.sql` |
| DDL + DML completos | `sql/00_instalar.sql` (todos los scripts) |
