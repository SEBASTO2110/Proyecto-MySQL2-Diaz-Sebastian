-- ===================================================================
-- PROYECTO : SISTEMA DE GESTION INMOBILIARIA
-- ARCHIVO  : 03_procedimientos.sql
-- OBJETIVO : Procedimientos almacenados que encapsulan la logica de
--            facturacion, recaudo, cartera y mantenimiento. Son la
--            unica via de escritura que se expone a los roles agente y
--            contador (principio de minimo privilegio).
-- ===================================================================


USE inmobiliaria;

DROP PROCEDURE IF EXISTS sp_generar_plan_arriendo;
DROP PROCEDURE IF EXISTS sp_generar_plan_venta;
DROP PROCEDURE IF EXISTS sp_generar_cuotas_arriendo;
DROP PROCEDURE IF EXISTS sp_generar_cuotas_venta;
DROP PROCEDURE IF EXISTS sp_registrar_pago;
DROP PROCEDURE IF EXISTS sp_generar_reporte_pagos_pendientes;
DROP PROCEDURE IF EXISTS sp_actualizar_contratos_vencidos;
DROP PROCEDURE IF EXISTS sp_marcar_contratos_en_mora;
DROP PROCEDURE IF EXISTS sp_liquidar_comision;
DROP PROCEDURE IF EXISTS sp_buscar_propiedades;

DELIMITER $$

-- ---------------------------------------------------------------------
-- 1a. sp_generar_plan_arriendo  (version parametrizada)
--    Genera el plan de pagos completo de un contrato de arrendamiento:
--      cuota 0  -> deposito (si aplica), vence el dia de inicio
--      cuota n  -> canon mensual, vence el dia pactado de cada mes
--      cuota n  -> cuota adicional por administracion (si aplica)
--    Aplica el incremento anual pactado a partir del segundo anio.
--    Es idempotente: usa INSERT IGNORE sobre la clave unica de cuota.
--    Recibe los valores por parametro para poder invocarse desde un
--    trigger sobre contrato_arriendo sin releer la tabla en curso.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_generar_plan_arriendo(
    IN p_id_contrato INT UNSIGNED,
    IN p_canon       DECIMAL(12,2),
    IN p_admin       DECIMAL(12,2),
    IN p_deposito    DECIMAL(12,2),
    IN p_inicio      DATE,
    IN p_fin         DATE,
    IN p_dia_pago    TINYINT UNSIGNED,
    IN p_incremento  DECIMAL(5,2)
)
COMMENT 'Genera el plan de cuotas de un arriendo a partir de sus condiciones'
BEGIN
    DECLARE v_canon      DECIMAL(12,2);
    DECLARE v_admin      DECIMAL(12,2);
    DECLARE v_deposito   DECIMAL(12,2);
    DECLARE v_inicio     DATE;
    DECLARE v_fin        DATE;
    DECLARE v_dia_pago   TINYINT UNSIGNED;
    DECLARE v_incremento DECIMAL(5,2);
    DECLARE v_meses      INT DEFAULT 0;
    DECLARE i            INT DEFAULT 0;
    DECLARE v_vence      DATE;
    DECLARE v_periodo    DATE;
    DECLARE v_canon_i    DECIMAL(12,2);
    DECLARE v_id_canon   TINYINT UNSIGNED;
    DECLARE v_id_admin   TINYINT UNSIGNED;
    DECLARE v_id_dep     TINYINT UNSIGNED;

    SET v_canon      = p_canon;
    SET v_admin      = COALESCE(p_admin, 0.00);
    SET v_deposito   = COALESCE(p_deposito, 0.00);
    SET v_inicio     = p_inicio;
    SET v_fin        = p_fin;
    SET v_dia_pago   = COALESCE(p_dia_pago, 5);
    SET v_incremento = COALESCE(p_incremento, 0.00);

    IF v_canon IS NULL OR v_inicio IS NULL OR v_fin IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'sp_generar_plan_arriendo: condiciones del arriendo incompletas';
    END IF;

    SELECT id_concepto_pago INTO v_id_canon FROM concepto_pago WHERE nombre = 'Canon de arrendamiento';
    SELECT id_concepto_pago INTO v_id_admin FROM concepto_pago WHERE nombre = 'Administracion';
    SELECT id_concepto_pago INTO v_id_dep   FROM concepto_pago WHERE nombre = 'Deposito';

    -- Deposito (cuota cero)
    IF v_deposito > 0 THEN
        INSERT IGNORE INTO cuota (id_contrato, numero_cuota, id_concepto_pago,
                                  periodo, fecha_vencimiento, valor_cuota)
        VALUES (p_id_contrato, 0, v_id_dep, NULL, v_inicio, v_deposito);
    END IF;

    SET v_meses = TIMESTAMPDIFF(MONTH, v_inicio, v_fin);
    IF v_meses < 1 THEN
        SET v_meses = 1;
    END IF;

    WHILE i < v_meses DO
        SET v_periodo  = DATE_ADD(DATE_FORMAT(v_inicio, '%Y-%m-01'), INTERVAL i MONTH);
        SET v_vence    = DATE_ADD(v_periodo, INTERVAL (v_dia_pago - 1) DAY);
        SET v_canon_i  = fn_canon_con_incremento(v_canon, v_incremento, FLOOR(i / 12));

        INSERT IGNORE INTO cuota (id_contrato, numero_cuota, id_concepto_pago,
                                  periodo, fecha_vencimiento, valor_cuota)
        VALUES (p_id_contrato, i + 1, v_id_canon, v_periodo, v_vence, v_canon_i);

        IF v_admin > 0 THEN
            INSERT IGNORE INTO cuota (id_contrato, numero_cuota, id_concepto_pago,
                                      periodo, fecha_vencimiento, valor_cuota)
            VALUES (p_id_contrato, i + 1, v_id_admin, v_periodo, v_vence, v_admin);
        END IF;

        SET i = i + 1;
    END WHILE;
END$$

-- ---------------------------------------------------------------------
-- 1b. sp_generar_cuotas_arriendo  (fachada por id de contrato)
--     Uso manual o desde eventos: lee las condiciones y delega.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_generar_cuotas_arriendo(IN p_id_contrato INT UNSIGNED)
COMMENT 'Genera el plan de cuotas de un contrato de arriendo existente'
BEGIN
    DECLARE v_canon      DECIMAL(12,2);
    DECLARE v_admin      DECIMAL(12,2);
    DECLARE v_deposito   DECIMAL(12,2);
    DECLARE v_inicio     DATE;
    DECLARE v_fin        DATE;
    DECLARE v_dia_pago   TINYINT UNSIGNED;
    DECLARE v_incremento DECIMAL(5,2);

    SELECT canon_mensual, valor_administracion, valor_deposito,
           fecha_inicio, fecha_fin, dia_pago, incremento_anual_pct
      INTO v_canon, v_admin, v_deposito,
           v_inicio, v_fin, v_dia_pago, v_incremento
      FROM contrato_arriendo
     WHERE id_contrato = p_id_contrato;

    IF v_canon IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'sp_generar_cuotas_arriendo: no existe el contrato de arriendo';
    END IF;

    CALL sp_generar_plan_arriendo(p_id_contrato, v_canon, v_admin, v_deposito,
                                  v_inicio, v_fin, v_dia_pago, v_incremento);
END$$

-- ---------------------------------------------------------------------
-- 2a. sp_generar_plan_venta  (version parametrizada)
--    Plan de pagos de una compraventa: cuota inicial y saldo.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_generar_plan_venta(
    IN p_id_contrato INT UNSIGNED,
    IN p_precio      DECIMAL(14,2),
    IN p_inicial     DECIMAL(14,2),
    IN p_escritura   DATE
)
COMMENT 'Genera cuota inicial y saldo de una compraventa'
BEGIN
    DECLARE v_precio    DECIMAL(14,2);
    DECLARE v_inicial   DECIMAL(14,2);
    DECLARE v_escritura DATE;
    DECLARE v_firma     DATE;
    DECLARE v_id_ini    TINYINT UNSIGNED;
    DECLARE v_id_saldo  TINYINT UNSIGNED;

    SET v_precio    = p_precio;
    SET v_inicial   = COALESCE(p_inicial, 0.00);
    SET v_escritura = p_escritura;

    SELECT fecha_firma INTO v_firma FROM contrato WHERE id_contrato = p_id_contrato;

    IF v_precio IS NULL OR v_firma IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'sp_generar_plan_venta: datos de la venta incompletos';
    END IF;

    SELECT id_concepto_pago INTO v_id_ini   FROM concepto_pago WHERE nombre = 'Cuota inicial';
    SELECT id_concepto_pago INTO v_id_saldo FROM concepto_pago WHERE nombre = 'Saldo de venta';

    IF v_inicial > 0 THEN
        INSERT IGNORE INTO cuota (id_contrato, numero_cuota, id_concepto_pago,
                                  periodo, fecha_vencimiento, valor_cuota)
        VALUES (p_id_contrato, 1, v_id_ini, NULL, v_firma, v_inicial);
    END IF;

    IF (v_precio - v_inicial) > 0 THEN
        INSERT IGNORE INTO cuota (id_contrato, numero_cuota, id_concepto_pago,
                                  periodo, fecha_vencimiento, valor_cuota)
        VALUES (p_id_contrato, 2, v_id_saldo, NULL,
                COALESCE(v_escritura, DATE_ADD(v_firma, INTERVAL 30 DAY)),
                v_precio - v_inicial);
    END IF;
END$$

-- ---------------------------------------------------------------------
-- 2b. sp_generar_cuotas_venta  (fachada por id de contrato)
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_generar_cuotas_venta(IN p_id_contrato INT UNSIGNED)
COMMENT 'Genera el plan de pagos de un contrato de venta existente'
BEGIN
    DECLARE v_precio    DECIMAL(14,2);
    DECLARE v_inicial   DECIMAL(14,2);
    DECLARE v_escritura DATE;

    SELECT precio_venta, cuota_inicial, fecha_escritura
      INTO v_precio, v_inicial, v_escritura
      FROM contrato_venta
     WHERE id_contrato = p_id_contrato;

    IF v_precio IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'sp_generar_cuotas_venta: no existe el contrato de venta';
    END IF;

    CALL sp_generar_plan_venta(p_id_contrato, v_precio, v_inicial, v_escritura);
END$$

-- ---------------------------------------------------------------------
-- 3. sp_registrar_pago
--    Punto de entrada unico para el recaudo. Valida el saldo de la cuota
--    y, si el contrato estaba 'En mora' y queda al dia, lo reactiva.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_registrar_pago(
    IN  p_id_cuota       BIGINT UNSIGNED,
    IN  p_valor          DECIMAL(14,2),
    IN  p_id_metodo_pago TINYINT UNSIGNED,
    IN  p_referencia     VARCHAR(60),
    OUT p_id_pago        BIGINT UNSIGNED
)
COMMENT 'Registra un abono validando el saldo de la cuota'
BEGIN
    DECLARE v_saldo       DECIMAL(14,2);
    DECLARE v_id_contrato INT UNSIGNED;
    DECLARE v_id_activo   TINYINT UNSIGNED;
    DECLARE v_id_mora     TINYINT UNSIGNED;

    SELECT id_contrato INTO v_id_contrato FROM cuota WHERE id_cuota = p_id_cuota;

    IF v_id_contrato IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'sp_registrar_pago: la cuota indicada no existe';
    END IF;

    SET v_saldo = fn_saldo_cuota(p_id_cuota);

    IF p_valor > v_saldo THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'sp_registrar_pago: el abono supera el saldo de la cuota';
    END IF;

    INSERT INTO pago (id_cuota, fecha_pago, valor_pagado, id_metodo_pago, referencia)
    VALUES (p_id_cuota, CURRENT_DATE, p_valor, p_id_metodo_pago, p_referencia);

    SET p_id_pago = LAST_INSERT_ID();

    SELECT id_estado_contrato INTO v_id_activo FROM estado_contrato WHERE nombre = 'Activo';
    SELECT id_estado_contrato INTO v_id_mora   FROM estado_contrato WHERE nombre = 'En mora';

    IF fn_deuda_pendiente(v_id_contrato) = 0 THEN
        UPDATE contrato
           SET id_estado_contrato = v_id_activo
         WHERE id_contrato = v_id_contrato
           AND id_estado_contrato = v_id_mora;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- 4. sp_generar_reporte_pagos_pendientes  (usado por el evento mensual)
--    Inserta en reporte_pagos_pendientes una foto de la cartera vencida
--    de todos los contratos vigentes. Idempotente por (periodo, contrato).
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_generar_reporte_pagos_pendientes(IN p_periodo CHAR(7))
COMMENT 'Genera el snapshot mensual de cartera vencida'
BEGIN
    DECLARE v_periodo CHAR(7);
    DECLARE v_filas   INT DEFAULT 0;

    SET v_periodo = COALESCE(p_periodo, DATE_FORMAT(CURRENT_DATE, '%Y-%m'));

    INSERT INTO reporte_pagos_pendientes
        (periodo, id_contrato, numero_contrato, id_propiedad, codigo_propiedad,
         id_cliente, nombre_cliente, cuotas_vencidas, valor_adeudado, dias_mora)
    SELECT v_periodo,
           c.id_contrato,
           c.numero_contrato,
           p.id_propiedad,
           p.codigo_interno,
           cl.id_cliente,
           fn_nombre_completo(cl.id_persona),
           (SELECT COUNT(*)
              FROM cuota cu
             WHERE cu.id_contrato = c.id_contrato
               AND cu.fecha_vencimiento <= CURRENT_DATE
               AND fn_saldo_cuota(cu.id_cuota) > 0),
           fn_deuda_pendiente(c.id_contrato),
           fn_dias_mora(c.id_contrato)
      FROM contrato c
      JOIN propiedad p       ON p.id_propiedad = c.id_propiedad
      JOIN cliente   cl      ON cl.id_cliente  = c.id_cliente
      JOIN estado_contrato e ON e.id_estado_contrato = c.id_estado_contrato
     WHERE e.nombre IN ('Activo','En mora')
       AND fn_deuda_pendiente(c.id_contrato) > 0
        ON DUPLICATE KEY UPDATE
           fecha_generacion = CURRENT_TIMESTAMP,
           cuotas_vencidas  = VALUES(cuotas_vencidas),
           valor_adeudado   = VALUES(valor_adeudado),
           dias_mora        = VALUES(dias_mora);

    SET v_filas = ROW_COUNT();

    INSERT INTO bitacora_evento (nombre_evento, filas_afectadas, mensaje)
    VALUES ('sp_generar_reporte_pagos_pendientes', v_filas,
            CONCAT('Reporte de cartera generado para el periodo ', v_periodo));
END$$

-- ---------------------------------------------------------------------
-- 5. sp_actualizar_contratos_vencidos
--    Cierra los arriendos cuya vigencia expiro y libera el inmueble.
--    El trigger de contrato se encarga de auditar y de devolver la
--    propiedad al estado 'Disponible'.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_actualizar_contratos_vencidos()
COMMENT 'Finaliza automaticamente los contratos de arriendo expirados'
BEGIN
    DECLARE v_filas       INT DEFAULT 0;
    DECLARE v_id_final    TINYINT UNSIGNED;

    SELECT id_estado_contrato INTO v_id_final FROM estado_contrato WHERE nombre = 'Finalizado';

    UPDATE contrato c
      JOIN contrato_arriendo ca ON ca.id_contrato = c.id_contrato
      JOIN estado_contrato    e ON e.id_estado_contrato = c.id_estado_contrato
       SET c.id_estado_contrato = v_id_final,
           c.observaciones = CONCAT_WS(' | ', c.observaciones, 'Cierre automatico por vencimiento')
     WHERE e.nombre IN ('Activo','En mora')
       AND ca.fecha_fin < CURRENT_DATE;

    SET v_filas = ROW_COUNT();

    INSERT INTO bitacora_evento (nombre_evento, filas_afectadas, mensaje)
    VALUES ('sp_actualizar_contratos_vencidos', v_filas, 'Contratos de arriendo cerrados por vencimiento');
END$$

-- ---------------------------------------------------------------------
-- 6. sp_marcar_contratos_en_mora
--    Reclasifica a 'En mora' los contratos activos con deuda vencida.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_marcar_contratos_en_mora()
COMMENT 'Marca los contratos activos que presentan cartera vencida'
BEGIN
    DECLARE v_filas    INT DEFAULT 0;
    DECLARE v_id_mora  TINYINT UNSIGNED;

    SELECT id_estado_contrato INTO v_id_mora FROM estado_contrato WHERE nombre = 'En mora';

    UPDATE contrato c
      JOIN estado_contrato e ON e.id_estado_contrato = c.id_estado_contrato
       SET c.id_estado_contrato = v_id_mora
     WHERE e.nombre = 'Activo'
       AND fn_deuda_pendiente(c.id_contrato) > 0;

    SET v_filas = ROW_COUNT();

    INSERT INTO bitacora_evento (nombre_evento, filas_afectadas, mensaje)
    VALUES ('sp_marcar_contratos_en_mora', v_filas, 'Contratos reclasificados a En mora');
END$$

-- ---------------------------------------------------------------------
-- 7. sp_liquidar_comision
--    Marca como pagada la comision de un contrato (uso del contador).
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_liquidar_comision(IN p_id_contrato INT UNSIGNED)
COMMENT 'Marca la comision del contrato como pagada'
BEGIN
    DECLARE v_existe INT DEFAULT 0;

    SELECT COUNT(*) INTO v_existe FROM comision WHERE id_contrato = p_id_contrato;

    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'sp_liquidar_comision: el contrato no tiene comision generada';
    END IF;

    UPDATE comision
       SET pagada = TRUE,
           fecha_pago = CURRENT_DATE
     WHERE id_contrato = p_id_contrato
       AND pagada = FALSE;
END$$

-- ---------------------------------------------------------------------
-- 8. sp_buscar_propiedades
--    Buscador parametrico para el rol agente. Los parametros nulos se
--    ignoran, lo que permite reutilizar una sola consulta optimizada.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_buscar_propiedades(
    IN p_id_tipo    TINYINT UNSIGNED,
    IN p_id_ciudad  INT UNSIGNED,
    IN p_precio_max DECIMAL(14,2),
    IN p_habitaciones TINYINT UNSIGNED,
    IN p_operacion  VARCHAR(10)
)
COMMENT 'Busqueda filtrada de inmuebles disponibles'
BEGIN
    SELECT p.codigo_interno,
           tp.nombre  AS tipo,
           b.nombre   AS barrio,
           ci.nombre  AS ciudad,
           p.direccion,
           p.area_construida,
           p.habitaciones,
           p.banos,
           p.precio_venta,
           p.precio_arriendo,
           fn_nombre_completo(pe.id_persona) AS propietario
      FROM propiedad p
      JOIN tipo_propiedad   tp ON tp.id_tipo_propiedad   = p.id_tipo_propiedad
      JOIN estado_propiedad ep ON ep.id_estado_propiedad = p.id_estado_propiedad
      JOIN barrio            b ON b.id_barrio            = p.id_barrio
      JOIN ciudad           ci ON ci.id_ciudad           = b.id_ciudad
      JOIN propietario      pr ON pr.id_propietario      = p.id_propietario
      JOIN persona          pe ON pe.id_persona          = pr.id_persona
     WHERE ep.nombre = 'Disponible'
       AND (p_id_tipo      IS NULL OR p.id_tipo_propiedad = p_id_tipo)
       AND (p_id_ciudad    IS NULL OR b.id_ciudad         = p_id_ciudad)
       AND (p_habitaciones IS NULL OR p.habitaciones     >= p_habitaciones)
       AND (p_operacion    IS NULL
            OR (p_operacion = 'VENTA'    AND p.se_vende    = TRUE)
            OR (p_operacion = 'ARRIENDO' AND p.se_arrienda = TRUE))
       AND (p_precio_max IS NULL
            OR (p_operacion = 'VENTA'    AND p.precio_venta    <= p_precio_max)
            OR (p_operacion = 'ARRIENDO' AND p.precio_arriendo <= p_precio_max)
            OR p_operacion IS NULL)
     ORDER BY tp.nombre, p.precio_arriendo, p.precio_venta;
END$$

DELIMITER ;

SELECT CONCAT('Procedimientos creados: ', COUNT(*)) AS resultado
FROM information_schema.routines
WHERE routine_schema = 'inmobiliaria' AND routine_type = 'PROCEDURE';
