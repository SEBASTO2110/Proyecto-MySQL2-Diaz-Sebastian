-- ===================================================================
-- PROYECTO : SISTEMA DE GESTION INMOBILIARIA
-- ARCHIVO  : 05_vistas_indices.sql
-- OBJETIVO : Optimizacion de consultas (indices secundarios y vistas).
--            Las vistas ademas son la capa de lectura que se concede a
--            los roles con menos privilegios.
-- ===================================================================

USE inmobiliaria;


-- =====================================================================
-- 1. INDICES SECUNDARIOS
--    InnoDB ya crea indice para cada PK, UNIQUE y clave foranea. Aqui se
--    agregan solo los indices que resuelven los patrones de consulta
--    reales del negocio (filtros y ordenamientos mas frecuentes).
-- =====================================================================

-- Busqueda del portafolio: estado + tipo + rango de precio.
CREATE INDEX idx_propiedad_arriendo
    ON propiedad (id_estado_propiedad, id_tipo_propiedad, precio_arriendo);

CREATE INDEX idx_propiedad_venta
    ON propiedad (id_estado_propiedad, id_tipo_propiedad, precio_venta);

-- Busqueda geografica (barrio/ciudad) filtrando por disponibilidad.
CREATE INDEX idx_propiedad_barrio_estado
    ON propiedad (id_barrio, id_estado_propiedad);

-- Filtro por caracteristicas fisicas.
CREATE INDEX idx_propiedad_atributos
    ON propiedad (habitaciones, banos, area_construida);

-- Directorio de personas por apellido.
CREATE INDEX idx_persona_nombre
    ON persona (primer_apellido, primer_nombre);

-- Tableros de contratos por estado y fecha de firma.
CREATE INDEX idx_contrato_estado_fecha
    ON contrato (id_estado_contrato, fecha_firma);

-- Productividad por agente.
CREATE INDEX idx_contrato_agente_estado
    ON contrato (id_agente, id_estado_contrato);

-- Cartera: el filtro mas caliente del sistema (cuotas vencidas).
CREATE INDEX idx_cuota_vencimiento
    ON cuota (fecha_vencimiento, id_contrato);

-- Estado de cuenta mensual de un contrato.
CREATE INDEX idx_cuota_contrato_periodo
    ON cuota (id_contrato, periodo);

-- Indice cubridor: permite sumar abonos por cuota sin leer la tabla.
CREATE INDEX idx_pago_cuota_valor
    ON pago (id_cuota, valor_pagado);

-- Cierres contables por fecha de recaudo.
CREATE INDEX idx_pago_fecha
    ON pago (fecha_pago);

-- Contratos de arriendo proximos a vencer.
CREATE INDEX idx_arriendo_vigencia
    ON contrato_arriendo (fecha_fin, fecha_inicio);

-- Liquidacion de comisiones pendientes por agente.
CREATE INDEX idx_comision_agente_pagada
    ON comision (id_agente, pagada);

-- Agenda comercial.
CREATE INDEX idx_visita_fecha
    ON visita (fecha_hora, id_agente);

-- =====================================================================
-- 2. VISTAS
-- =====================================================================

DROP VIEW IF EXISTS v_propiedades_disponibles;
DROP VIEW IF EXISTS v_contratos_activos;
DROP VIEW IF EXISTS v_cartera_vencida;
DROP VIEW IF EXISTS v_comisiones_agente;
DROP VIEW IF EXISTS v_historico_propiedad;
DROP VIEW IF EXISTS v_resumen_portafolio;
DROP VIEW IF EXISTS v_estado_cuenta;

-- Catalogo comercial publicable.
CREATE VIEW v_propiedades_disponibles AS
SELECT p.id_propiedad,
       p.codigo_interno,
       tp.nombre  AS tipo_propiedad,
       b.nombre   AS barrio,
       ci.nombre  AS ciudad,
       p.direccion,
       p.area_construida,
       p.habitaciones,
       p.banos,
       p.parqueaderos,
       p.estrato,
       p.se_vende,
       p.se_arrienda,
       p.precio_venta,
       p.precio_arriendo,
       p.valor_administracion,
       fn_nombre_completo(pe.id_persona) AS propietario
  FROM propiedad p
  JOIN tipo_propiedad   tp ON tp.id_tipo_propiedad   = p.id_tipo_propiedad
  JOIN estado_propiedad ep ON ep.id_estado_propiedad = p.id_estado_propiedad
  JOIN barrio            b ON b.id_barrio            = p.id_barrio
  JOIN ciudad           ci ON ci.id_ciudad           = b.id_ciudad
  JOIN propietario      pr ON pr.id_propietario      = p.id_propietario
  JOIN persona          pe ON pe.id_persona          = pr.id_persona
 WHERE ep.nombre = 'Disponible';

-- Contratos vigentes con su indicador de cartera.
CREATE VIEW v_contratos_activos AS
SELECT c.id_contrato,
       c.numero_contrato,
       tc.nombre AS tipo_contrato,
       ec.nombre AS estado_contrato,
       p.codigo_interno AS propiedad,
       fn_nombre_completo(pc.id_persona) AS cliente,
       fn_nombre_completo(pa.id_persona) AS agente,
       c.fecha_firma,
       ca.fecha_inicio,
       ca.fecha_fin,
       ca.canon_mensual,
       c.valor_total,
       fn_deuda_pendiente(c.id_contrato) AS deuda_vencida,
       fn_dias_mora(c.id_contrato)       AS dias_mora,
       fn_estado_cartera(c.id_contrato)  AS estado_cartera
  FROM contrato c
  JOIN tipo_contrato    tc ON tc.id_tipo_contrato   = c.id_tipo_contrato
  JOIN estado_contrato  ec ON ec.id_estado_contrato = c.id_estado_contrato
  JOIN propiedad         p ON p.id_propiedad        = c.id_propiedad
  JOIN cliente          cl ON cl.id_cliente         = c.id_cliente
  JOIN persona          pc ON pc.id_persona         = cl.id_persona
  JOIN agente            a ON a.id_agente           = c.id_agente
  JOIN persona          pa ON pa.id_persona         = a.id_persona
  LEFT JOIN contrato_arriendo ca ON ca.id_contrato  = c.id_contrato
 WHERE ec.nombre IN ('Activo','En mora');

-- Detalle de cuotas vencidas sin cancelar (base del reporte mensual).
CREATE VIEW v_cartera_vencida AS
SELECT c.id_contrato,
       c.numero_contrato,
       p.codigo_interno            AS propiedad,
       fn_nombre_completo(pe.id_persona) AS cliente,
       cu.id_cuota,
       cu.numero_cuota,
       cp.nombre                   AS concepto,
       cu.periodo,
       cu.fecha_vencimiento,
       cu.valor_cuota,
       fn_saldo_cuota(cu.id_cuota) AS saldo,
       DATEDIFF(CURRENT_DATE, cu.fecha_vencimiento) AS dias_vencida
  FROM cuota cu
  JOIN contrato       c  ON c.id_contrato        = cu.id_contrato
  JOIN concepto_pago  cp ON cp.id_concepto_pago  = cu.id_concepto_pago
  JOIN propiedad      p  ON p.id_propiedad       = c.id_propiedad
  JOIN cliente        cl ON cl.id_cliente        = c.id_cliente
  JOIN persona        pe ON pe.id_persona        = cl.id_persona
 WHERE cu.fecha_vencimiento <= CURRENT_DATE
   AND fn_saldo_cuota(cu.id_cuota) > 0;

-- Productividad y comisiones por agente.
CREATE VIEW v_comisiones_agente AS
SELECT a.id_agente,
       a.codigo_agente,
       fn_nombre_completo(pe.id_persona) AS agente,
       s.nombre AS sucursal,
       COUNT(co.id_comision)                                          AS contratos_cerrados,
       COALESCE(SUM(co.valor_comision), 0)                            AS comision_total,
       COALESCE(SUM(CASE WHEN co.pagada THEN co.valor_comision END), 0) AS comision_pagada,
       COALESCE(SUM(CASE WHEN NOT co.pagada THEN co.valor_comision END), 0) AS comision_pendiente
  FROM agente a
  JOIN persona  pe ON pe.id_persona  = a.id_persona
  JOIN sucursal s  ON s.id_sucursal  = a.id_sucursal
  LEFT JOIN comision co ON co.id_agente = a.id_agente
 GROUP BY a.id_agente, a.codigo_agente, pe.id_persona, s.nombre;

-- Historico legible de la auditoria de propiedades.
CREATE VIEW v_historico_propiedad AS
SELECT ap.id_auditoria,
       p.codigo_interno,
       tp.nombre AS tipo_propiedad,
       ap.accion,
       ap.campo_modificado,
       ap.valor_anterior,
       ap.valor_nuevo,
       ap.usuario_bd,
       ap.fecha_hora,
       ap.observacion
  FROM auditoria_propiedad ap
  JOIN propiedad      p  ON p.id_propiedad = ap.id_propiedad
  JOIN tipo_propiedad tp ON tp.id_tipo_propiedad = p.id_tipo_propiedad;

-- Tablero gerencial del portafolio por tipo de inmueble.
CREATE VIEW v_resumen_portafolio AS
SELECT tp.id_tipo_propiedad,
       tp.nombre AS tipo_propiedad,
       COUNT(p.id_propiedad) AS total,
       fn_propiedades_disponibles_por_tipo(tp.id_tipo_propiedad) AS disponibles,
       SUM(ep.nombre = 'Arrendada') AS arrendadas,
       SUM(ep.nombre = 'Vendida')   AS vendidas,
       ROUND(AVG(p.precio_arriendo), 2) AS canon_promedio,
       ROUND(AVG(p.precio_venta), 2)    AS precio_venta_promedio
  FROM tipo_propiedad tp
  LEFT JOIN propiedad p ON p.id_tipo_propiedad = tp.id_tipo_propiedad
  LEFT JOIN estado_propiedad ep ON ep.id_estado_propiedad = p.id_estado_propiedad
 GROUP BY tp.id_tipo_propiedad, tp.nombre;

-- Estado de cuenta detallado por cuota (cliente / contador).
CREATE VIEW v_estado_cuenta AS
SELECT c.numero_contrato,
       cu.id_cuota,
       cu.numero_cuota,
       cp.nombre AS concepto,
       cu.periodo,
       cu.fecha_vencimiento,
       cu.valor_cuota,
       COALESCE(SUM(pg.valor_pagado), 0) AS abonado,
       cu.valor_cuota - COALESCE(SUM(pg.valor_pagado), 0) AS saldo,
       MAX(pg.fecha_pago) AS ultimo_pago
  FROM cuota cu
  JOIN contrato      c  ON c.id_contrato       = cu.id_contrato
  JOIN concepto_pago cp ON cp.id_concepto_pago = cu.id_concepto_pago
  LEFT JOIN pago     pg ON pg.id_cuota         = cu.id_cuota
 GROUP BY c.numero_contrato, cu.id_cuota, cu.numero_cuota, cp.nombre,
          cu.periodo, cu.fecha_vencimiento, cu.valor_cuota;

SELECT CONCAT('Vistas creadas: ', COUNT(*)) AS resultado
FROM information_schema.views
WHERE table_schema = 'inmobiliaria';
