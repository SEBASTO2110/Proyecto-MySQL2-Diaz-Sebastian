-- =====================================================================
-- PROYECTO : SISTEMA DE GESTION INMOBILIARIA
-- ARCHIVO  : 09_consultas_ejemplo.sql
-- OBJETIVO : Bateria de consultas de demostracion y verificacion.
--            Puede ejecutarse completa o consulta por consulta.
-- =====================================================================

USE inmobiliaria;

-- =====================================================================
-- A. PORTAFOLIO
-- =====================================================================

-- A1. Catalogo de inmuebles disponibles (vista).
SELECT codigo_interno, tipo_propiedad, barrio, ciudad, habitaciones, banos,
       precio_venta, precio_arriendo
FROM v_propiedades_disponibles
ORDER BY tipo_propiedad, ciudad;

-- A2. Total de propiedades disponibles por tipo usando la UDF exigida.
SELECT tp.nombre AS tipo_propiedad,
       fn_propiedades_disponibles_por_tipo(tp.id_tipo_propiedad) AS disponibles
FROM tipo_propiedad tp
ORDER BY disponibles DESC, tp.nombre;

-- A3. Tablero gerencial del portafolio y porcentaje de ocupacion.
SELECT * FROM v_resumen_portafolio;
SELECT fn_ocupacion_portafolio() AS porcentaje_ocupacion;

-- A4. Busqueda parametrica (rol agente): apartamentos en Bogota
--     de hasta 3.000.000 de canon con al menos 2 habitaciones.
CALL sp_buscar_propiedades(2, 1, 3000000.00, 2, 'ARRIENDO');

-- A5. Inmuebles con piscina y ascensor (relacion N:M).
SELECT p.codigo_interno, p.direccion,
       GROUP_CONCAT(ca.nombre ORDER BY ca.nombre SEPARATOR ', ') AS caracteristicas
FROM propiedad p
JOIN propiedad_caracteristica pc ON pc.id_propiedad = p.id_propiedad
JOIN caracteristica ca ON ca.id_caracteristica = pc.id_caracteristica
GROUP BY p.id_propiedad, p.codigo_interno, p.direccion
HAVING SUM(ca.nombre = 'Piscina') > 0
   AND SUM(ca.nombre = 'Ascensor') > 0;

-- =====================================================================
-- B. CONTRATOS Y CARTERA
-- =====================================================================

-- B1. Contratos vigentes con su estado de cartera (UDFs en accion).
SELECT numero_contrato, tipo_contrato, propiedad, cliente, agente,
       canon_mensual, deuda_vencida, dias_mora, estado_cartera
FROM v_contratos_activos
ORDER BY dias_mora DESC, numero_contrato;

-- B2. Deuda pendiente de un contrato puntual (funcion exigida).
SELECT c.numero_contrato,
       fn_deuda_pendiente(c.id_contrato)      AS deuda_vencida,
       fn_deuda_total_contrato(c.id_contrato) AS saldo_total,
       fn_dias_mora(c.id_contrato)            AS dias_mora,
       fn_estado_cartera(c.id_contrato)       AS clasificacion
FROM contrato c
WHERE c.numero_contrato = 'CTO-0008';

-- B3. Estado de cuenta detallado de un contrato.
SELECT * FROM v_estado_cuenta
WHERE numero_contrato = 'CTO-0004'
ORDER BY fecha_vencimiento;

-- B4. Detalle de la cartera vencida de toda la inmobiliaria.
SELECT numero_contrato, propiedad, cliente, concepto, periodo,
       fecha_vencimiento, valor_cuota, saldo, dias_vencida
FROM v_cartera_vencida
ORDER BY dias_vencida DESC;

-- B5. Recaudo mensual de los ultimos 12 meses.
SELECT DATE_FORMAT(pg.fecha_pago, '%Y-%m') AS mes,
       COUNT(*)                            AS numero_pagos,
       FORMAT(SUM(pg.valor_pagado), 0)     AS total_recaudado
FROM pago pg
WHERE pg.fecha_pago >= DATE_SUB(CURRENT_DATE, INTERVAL 12 MONTH)
GROUP BY mes
ORDER BY mes DESC;

-- B6. Arriendos que vencen en los proximos 90 dias (renovaciones).
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

-- =====================================================================
-- C. COMISIONES Y PRODUCTIVIDAD
-- =====================================================================

-- C1. Comision calculada por la UDF exigida frente a la ya liquidada.
SELECT c.numero_contrato,
       tc.nombre AS tipo,
       fn_nombre_completo(pe.id_persona)   AS agente,
       co.base_calculo,
       co.porcentaje,
       co.valor_comision                   AS comision_registrada,
       fn_calcular_comision(c.id_contrato) AS comision_calculada,
       IF(co.pagada, 'Pagada', 'Pendiente') AS estado
FROM contrato c
JOIN tipo_contrato tc ON tc.id_tipo_contrato = c.id_tipo_contrato
JOIN comision co ON co.id_contrato = c.id_contrato
JOIN agente a ON a.id_agente = co.id_agente
JOIN persona pe ON pe.id_persona = a.id_persona
ORDER BY co.valor_comision DESC;

-- C2. Ranking de agentes por comision generada.
SELECT agente, sucursal, contratos_cerrados,
       FORMAT(comision_total, 0)     AS comision_total,
       FORMAT(comision_pendiente, 0) AS por_pagar
FROM v_comisiones_agente
ORDER BY comision_total DESC;

-- C3. Efectividad comercial: visitas realizadas frente a contratos cerrados.
SELECT fn_nombre_completo(pe.id_persona) AS agente,
       COUNT(DISTINCT v.id_visita)   AS visitas,
       COUNT(DISTINCT c.id_contrato) AS contratos,
       CONCAT(ROUND(COUNT(DISTINCT c.id_contrato) * 100 /
              NULLIF(COUNT(DISTINCT v.id_visita), 0), 1), ' %') AS efectividad
FROM agente a
JOIN persona pe ON pe.id_persona = a.id_persona
LEFT JOIN visita   v ON v.id_agente = a.id_agente
LEFT JOIN contrato c ON c.id_agente = a.id_agente
GROUP BY a.id_agente, pe.id_persona
ORDER BY contratos DESC;

-- =====================================================================
-- D. AUDITORIA (resultado de los triggers)
-- =====================================================================

-- D1. Historico de cambios de estado de las propiedades.
SELECT codigo_interno, campo_modificado, valor_anterior, valor_nuevo,
       usuario_bd, fecha_hora, observacion
FROM v_historico_propiedad
WHERE campo_modificado = 'ESTADO'
ORDER BY fecha_hora DESC;

-- D2. Trazabilidad completa de una propiedad concreta.
SELECT accion, campo_modificado, valor_anterior, valor_nuevo, fecha_hora
FROM v_historico_propiedad
WHERE codigo_interno = 'INM-016'
ORDER BY fecha_hora;

-- D3. Auditoria de contratos con extraccion de campos del JSON.
SELECT ac.numero_contrato,
       ac.accion,
       JSON_UNQUOTE(JSON_EXTRACT(ac.datos_anteriores, '$.estado')) AS estado_anterior,
       JSON_UNQUOTE(JSON_EXTRACT(ac.datos_nuevos,     '$.estado')) AS estado_nuevo,
       ac.usuario_bd,
       ac.fecha_hora
FROM auditoria_contrato ac
ORDER BY ac.fecha_hora DESC, ac.id_auditoria DESC;

-- D4. Ultimos movimientos contables registrados.
SELECT ap.id_pago, ap.id_cuota, ap.accion, ap.valor_nuevo,
       ap.usuario_bd, ap.fecha_hora
FROM auditoria_pago ap
ORDER BY ap.fecha_hora DESC
LIMIT 15;

-- =====================================================================
-- E. EVENTOS PROGRAMADOS Y REPORTES
-- =====================================================================

-- E1. Reporte mensual de propiedades con pagos pendientes.
SELECT periodo, numero_contrato, codigo_propiedad, nombre_cliente,
       cuotas_vencidas, FORMAT(valor_adeudado, 0) AS valor_adeudado, dias_mora
FROM reporte_pagos_pendientes
ORDER BY periodo DESC, valor_adeudado DESC;

-- E2. Bitacora de ejecucion de los procesos automaticos.
SELECT nombre_evento, fecha_hora, filas_afectadas, mensaje
FROM bitacora_evento
ORDER BY fecha_hora DESC;

-- E3. Estado del planificador y de los eventos definidos.
SHOW VARIABLES LIKE 'event_scheduler';

SELECT event_name, status, interval_value, interval_field,
       starts, last_executed, event_comment
FROM information_schema.events
WHERE event_schema = 'inmobiliaria';

-- =====================================================================
-- F. OPTIMIZACION: COMPARACION CON Y SIN INDICE
-- =====================================================================

-- F1. Consulta caliente del catalogo. Con idx_propiedad_arriendo el plan
--     usa "range"/"ref" sobre el indice en lugar de "ALL" (full scan).
EXPLAIN
SELECT p.codigo_interno, p.precio_arriendo
FROM propiedad p
WHERE p.id_estado_propiedad = 1
  AND p.id_tipo_propiedad   = 2
  AND p.precio_arriendo <= 3000000;

-- F2. El indice idx_cuota_vencimiento evita recorrer toda la cartera.
EXPLAIN
SELECT cu.id_cuota, cu.id_contrato, cu.valor_cuota
FROM cuota cu
WHERE cu.fecha_vencimiento BETWEEN DATE_SUB(CURRENT_DATE, INTERVAL 3 MONTH) AND CURRENT_DATE;

-- F3. Indice cubridor: la suma de abonos se resuelve leyendo solo el
--     indice idx_pago_cuota_valor (columna Extra = "Using index").
EXPLAIN
SELECT id_cuota, SUM(valor_pagado)
FROM pago
GROUP BY id_cuota;

-- F4. Plan de ejecucion detallado en formato arbol (MySQL 8).
EXPLAIN ANALYZE
SELECT c.numero_contrato, SUM(cu.valor_cuota) AS facturado
FROM contrato c
JOIN cuota cu ON cu.id_contrato = c.id_contrato
WHERE cu.fecha_vencimiento <= CURRENT_DATE
GROUP BY c.numero_contrato;

-- F5. Indices efectivamente creados sobre las tablas del negocio.
SELECT table_name, index_name,
       GROUP_CONCAT(column_name ORDER BY seq_in_index) AS columnas,
       IF(non_unique = 0, 'UNICO', 'NO UNICO') AS tipo
FROM information_schema.statistics
WHERE table_schema = 'inmobiliaria'
GROUP BY table_name, index_name, non_unique
ORDER BY table_name, index_name;

-- =====================================================================
-- G. PRUEBAS DE LAS REGLAS DE NEGOCIO (deben fallar de forma controlada)
--    Descomente cada bloque para comprobar el mensaje de error.
-- =====================================================================

-- G1. Un abono no puede superar el saldo de la cuota:
-- CALL sp_registrar_pago(1, 999999999.00, 1, 'PRUEBA', @id);

-- G2. No se puede arrendar una propiedad que ya esta arrendada:
-- INSERT INTO contrato (numero_contrato, id_tipo_contrato, id_propiedad, id_cliente,
--                       id_agente, id_estado_contrato, fecha_firma, valor_total)
-- VALUES ('CTO-9999', 1, 1, 12, 2, 1, CURRENT_DATE, 12000000);

-- G3. Un contrato con pagos registrados no se puede eliminar:
-- DELETE FROM contrato WHERE numero_contrato = 'CTO-0001';

-- G4. Una propiedad con historia contractual no se puede eliminar:
-- DELETE FROM propiedad WHERE codigo_interno = 'INM-001';
