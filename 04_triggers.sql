-- ===================================================================
-- PROYECTO : SISTEMA DE GESTION INMOBILIARIA
-- ARCHIVO  : 04_triggers.sql
-- OBJETIVO : Disparadores de auditoria, automatizacion y validacion.
--            La auditoria es transparente para la aplicacion: ningun
--            usuario escribe en las tablas auditoria_*; solo lo hacen
--            estos triggers.
-- ===================================================================


USE inmobiliaria;

DROP TRIGGER IF EXISTS trg_propiedad_ai;
DROP TRIGGER IF EXISTS trg_propiedad_bu;
DROP TRIGGER IF EXISTS trg_propiedad_au;
DROP TRIGGER IF EXISTS trg_propiedad_bd;
DROP TRIGGER IF EXISTS trg_contrato_bi;
DROP TRIGGER IF EXISTS trg_contrato_ai;
DROP TRIGGER IF EXISTS trg_contrato_au;
DROP TRIGGER IF EXISTS trg_contrato_bd;
DROP TRIGGER IF EXISTS trg_arriendo_ai;
DROP TRIGGER IF EXISTS trg_venta_ai;
DROP TRIGGER IF EXISTS trg_pago_bi;
DROP TRIGGER IF EXISTS trg_pago_ai;
DROP TRIGGER IF EXISTS trg_pago_ad;
DROP TRIGGER IF EXISTS trg_cuota_bd;

DELIMITER $$

-- =====================================================================
-- A. PROPIEDAD
-- =====================================================================

-- ---------------------------------------------------------------------
-- A1. Alta de una propiedad -> queda registrada en la auditoria.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_propiedad_ai
AFTER INSERT ON propiedad
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_propiedad
        (id_propiedad, accion, campo_modificado, valor_anterior, valor_nuevo,
         usuario_bd, observacion)
    VALUES
        (NEW.id_propiedad, 'INSERT', 'ALTA', NULL,
         (SELECT nombre FROM estado_propiedad WHERE id_estado_propiedad = NEW.id_estado_propiedad),
         CURRENT_USER(),
         CONCAT('Propiedad ', NEW.codigo_interno, ' incorporada al portafolio'));
END$$

-- ---------------------------------------------------------------------
-- A2. Validaciones previas a modificar una propiedad.
--     No se permite marcar como 'Disponible' un inmueble que todavia
--     tiene un contrato vigente asociado.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_propiedad_bu
BEFORE UPDATE ON propiedad
FOR EACH ROW
BEGIN
    DECLARE v_estado_nuevo VARCHAR(30);
    DECLARE v_vigentes     INT DEFAULT 0;

    SELECT nombre INTO v_estado_nuevo
      FROM estado_propiedad
     WHERE id_estado_propiedad = NEW.id_estado_propiedad;

    IF v_estado_nuevo = 'Disponible'
       AND NEW.id_estado_propiedad <> OLD.id_estado_propiedad THEN

        SELECT COUNT(*) INTO v_vigentes
          FROM contrato c
          JOIN estado_contrato e ON e.id_estado_contrato = c.id_estado_contrato
         WHERE c.id_propiedad = NEW.id_propiedad
           AND e.nombre IN ('Activo','En mora');

        IF v_vigentes > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'No se puede liberar la propiedad: tiene contratos vigentes';
        END IF;
    END IF;

    IF NEW.se_arrienda = TRUE AND (NEW.precio_arriendo IS NULL OR NEW.precio_arriendo <= 0) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Una propiedad ofrecida en arriendo requiere canon mayor que cero';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- A3. HISTORICO DE CAMBIOS (requisito del enunciado).
--     Registra el cambio de estado (disponible -> arrendada / vendida)
--     y tambien los ajustes de precio de venta y de canon.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_propiedad_au
AFTER UPDATE ON propiedad
FOR EACH ROW
BEGIN
    DECLARE v_estado_ant VARCHAR(30);
    DECLARE v_estado_new VARCHAR(30);

    IF NEW.id_estado_propiedad <> OLD.id_estado_propiedad THEN
        SELECT nombre INTO v_estado_ant FROM estado_propiedad WHERE id_estado_propiedad = OLD.id_estado_propiedad;
        SELECT nombre INTO v_estado_new FROM estado_propiedad WHERE id_estado_propiedad = NEW.id_estado_propiedad;

        INSERT INTO auditoria_propiedad
            (id_propiedad, accion, campo_modificado, valor_anterior, valor_nuevo, usuario_bd, observacion)
        VALUES
            (NEW.id_propiedad, 'UPDATE', 'ESTADO', v_estado_ant, v_estado_new, CURRENT_USER(),
             CONCAT('Cambio de estado de la propiedad ', NEW.codigo_interno));
    END IF;

    IF NOT (NEW.precio_venta <=> OLD.precio_venta) THEN
        INSERT INTO auditoria_propiedad
            (id_propiedad, accion, campo_modificado, valor_anterior, valor_nuevo, usuario_bd, observacion)
        VALUES
            (NEW.id_propiedad, 'UPDATE', 'PRECIO_VENTA',
             FORMAT(OLD.precio_venta, 2), FORMAT(NEW.precio_venta, 2), CURRENT_USER(),
             'Ajuste del precio de venta');
    END IF;

    IF NOT (NEW.precio_arriendo <=> OLD.precio_arriendo) THEN
        INSERT INTO auditoria_propiedad
            (id_propiedad, accion, campo_modificado, valor_anterior, valor_nuevo, usuario_bd, observacion)
        VALUES
            (NEW.id_propiedad, 'UPDATE', 'PRECIO_ARRIENDO',
             FORMAT(OLD.precio_arriendo, 2), FORMAT(NEW.precio_arriendo, 2), CURRENT_USER(),
             'Ajuste del canon de arrendamiento');
    END IF;
END$$

-- ---------------------------------------------------------------------
-- A4. Proteccion contra borrados: un inmueble con historia contractual
--     no se elimina, se marca como 'Retirada'.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_propiedad_bd
BEFORE DELETE ON propiedad
FOR EACH ROW
BEGIN
    DECLARE v_contratos INT DEFAULT 0;

    SELECT COUNT(*) INTO v_contratos FROM contrato WHERE id_propiedad = OLD.id_propiedad;

    IF v_contratos > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La propiedad tiene contratos asociados: use el estado Retirada en lugar de eliminarla';
    END IF;

    INSERT INTO auditoria_propiedad
        (id_propiedad, accion, campo_modificado, valor_anterior, valor_nuevo, usuario_bd, observacion)
    VALUES
        (OLD.id_propiedad, 'DELETE', 'BAJA', OLD.codigo_interno, NULL, CURRENT_USER(),
         'Propiedad eliminada del portafolio');
END$$

-- =====================================================================
-- B. CONTRATO
-- =====================================================================

-- ---------------------------------------------------------------------
-- B1. Reglas de negocio antes de firmar un contrato.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_contrato_bi
BEFORE INSERT ON contrato
FOR EACH ROW
BEGIN
    DECLARE v_estado_prop VARCHAR(30);
    DECLARE v_tipo        VARCHAR(30);
    DECLARE v_se_vende    BOOLEAN;
    DECLARE v_se_arrienda BOOLEAN;
    DECLARE v_agente_activo BOOLEAN;

    SELECT ep.nombre, p.se_vende, p.se_arrienda
      INTO v_estado_prop, v_se_vende, v_se_arrienda
      FROM propiedad p
      JOIN estado_propiedad ep ON ep.id_estado_propiedad = p.id_estado_propiedad
     WHERE p.id_propiedad = NEW.id_propiedad;

    SELECT nombre INTO v_tipo FROM tipo_contrato WHERE id_tipo_contrato = NEW.id_tipo_contrato;
    SELECT activo INTO v_agente_activo FROM agente WHERE id_agente = NEW.id_agente;

    IF v_estado_prop NOT IN ('Disponible','Reservada') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La propiedad no esta disponible para contratar';
    END IF;

    IF v_tipo = 'Venta' AND v_se_vende = FALSE THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La propiedad no esta ofertada en venta';
    END IF;

    IF v_tipo = 'Arriendo' AND v_se_arrienda = FALSE THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La propiedad no esta ofertada en arriendo';
    END IF;

    IF v_agente_activo = FALSE THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El agente asignado no se encuentra activo';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- B2. REGISTRO DE UN NUEVO CONTRATO (requisito del enunciado).
--     Audita el alta y cambia automaticamente el estado del inmueble a
--     'Arrendada' o 'Vendida' segun el tipo de contrato.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_contrato_ai
AFTER INSERT ON contrato
FOR EACH ROW
BEGIN
    DECLARE v_tipo         VARCHAR(30);
    DECLARE v_estado_ctr   VARCHAR(30);
    DECLARE v_nuevo_estado TINYINT UNSIGNED;

    SELECT nombre INTO v_tipo       FROM tipo_contrato   WHERE id_tipo_contrato   = NEW.id_tipo_contrato;
    SELECT nombre INTO v_estado_ctr FROM estado_contrato WHERE id_estado_contrato = NEW.id_estado_contrato;

    INSERT INTO auditoria_contrato
        (id_contrato, numero_contrato, accion, datos_anteriores, datos_nuevos, usuario_bd)
    VALUES
        (NEW.id_contrato, NEW.numero_contrato, 'INSERT', NULL,
         JSON_OBJECT('tipo',            v_tipo,
                     'id_propiedad',    NEW.id_propiedad,
                     'id_cliente',      NEW.id_cliente,
                     'id_agente',       NEW.id_agente,
                     'estado',          v_estado_ctr,
                     'fecha_firma',     NEW.fecha_firma,
                     'valor_total',     NEW.valor_total,
                     'pct_comision',    NEW.porcentaje_comision),
         CURRENT_USER());

    IF v_estado_ctr IN ('Activo','En mora') THEN
        SELECT id_estado_propiedad INTO v_nuevo_estado
          FROM estado_propiedad
         WHERE nombre = CASE WHEN v_tipo = 'Venta' THEN 'Vendida' ELSE 'Arrendada' END;

        UPDATE propiedad
           SET id_estado_propiedad = v_nuevo_estado
         WHERE id_propiedad = NEW.id_propiedad;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- B3. Auditoria de cambios del contrato y liberacion del inmueble
--     cuando el contrato se finaliza o se cancela.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_contrato_au
AFTER UPDATE ON contrato
FOR EACH ROW
BEGIN
    DECLARE v_estado_ant VARCHAR(30);
    DECLARE v_estado_new VARCHAR(30);
    DECLARE v_disponible TINYINT UNSIGNED;

    SELECT nombre INTO v_estado_ant FROM estado_contrato WHERE id_estado_contrato = OLD.id_estado_contrato;
    SELECT nombre INTO v_estado_new FROM estado_contrato WHERE id_estado_contrato = NEW.id_estado_contrato;

    INSERT INTO auditoria_contrato
        (id_contrato, numero_contrato, accion, datos_anteriores, datos_nuevos, usuario_bd)
    VALUES
        (NEW.id_contrato, NEW.numero_contrato, 'UPDATE',
         JSON_OBJECT('estado', v_estado_ant, 'valor_total', OLD.valor_total,
                     'pct_comision', OLD.porcentaje_comision, 'id_agente', OLD.id_agente),
         JSON_OBJECT('estado', v_estado_new, 'valor_total', NEW.valor_total,
                     'pct_comision', NEW.porcentaje_comision, 'id_agente', NEW.id_agente),
         CURRENT_USER());

    IF v_estado_new IN ('Finalizado','Cancelado') AND v_estado_ant NOT IN ('Finalizado','Cancelado') THEN
        SELECT id_estado_propiedad INTO v_disponible
          FROM estado_propiedad WHERE nombre = 'Disponible';

        UPDATE propiedad
           SET id_estado_propiedad = v_disponible
         WHERE id_propiedad = NEW.id_propiedad
           AND id_estado_propiedad <> v_disponible;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- B4. Un contrato con recaudo registrado no puede borrarse.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_contrato_bd
BEFORE DELETE ON contrato
FOR EACH ROW
BEGIN
    DECLARE v_pagos INT DEFAULT 0;

    SELECT COUNT(*) INTO v_pagos
      FROM pago p JOIN cuota c ON c.id_cuota = p.id_cuota
     WHERE c.id_contrato = OLD.id_contrato;

    IF v_pagos > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El contrato tiene pagos registrados: debe cancelarse, no eliminarse';
    END IF;

    INSERT INTO auditoria_contrato
        (id_contrato, numero_contrato, accion, datos_anteriores, datos_nuevos, usuario_bd)
    VALUES
        (OLD.id_contrato, OLD.numero_contrato, 'DELETE',
         JSON_OBJECT('id_propiedad', OLD.id_propiedad, 'id_cliente', OLD.id_cliente,
                     'valor_total', OLD.valor_total),
         NULL, CURRENT_USER());
END$$

-- =====================================================================
-- C. SUBTIPOS DE CONTRATO: generacion automatica de cartera y comision
-- =====================================================================

-- ---------------------------------------------------------------------
-- C1. Al registrar las condiciones del arriendo se genera el plan de
--     cuotas completo y se liquida la comision del agente.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_arriendo_ai
AFTER INSERT ON contrato_arriendo
FOR EACH ROW
BEGIN
    DECLARE v_id_agente  INT UNSIGNED;
    DECLARE v_porcentaje DECIMAL(5,2);

    CALL sp_generar_plan_arriendo(NEW.id_contrato, NEW.canon_mensual, NEW.valor_administracion,
                                  NEW.valor_deposito, NEW.fecha_inicio, NEW.fecha_fin,
                                  NEW.dia_pago, NEW.incremento_anual_pct);

    SELECT id_agente, porcentaje_comision
      INTO v_id_agente, v_porcentaje
      FROM contrato WHERE id_contrato = NEW.id_contrato;

    INSERT INTO comision (id_contrato, id_agente, base_calculo, porcentaje, valor_comision)
    VALUES (NEW.id_contrato, v_id_agente, NEW.canon_mensual, v_porcentaje,
            ROUND(NEW.canon_mensual * v_porcentaje / 100, 2))
    ON DUPLICATE KEY UPDATE
        base_calculo   = VALUES(base_calculo),
        porcentaje     = VALUES(porcentaje),
        valor_comision = VALUES(valor_comision);
END$$

-- ---------------------------------------------------------------------
-- C2. Equivalente para la compraventa: plan de pagos y comision sobre
--     el precio de venta.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_venta_ai
AFTER INSERT ON contrato_venta
FOR EACH ROW
BEGIN
    DECLARE v_id_agente  INT UNSIGNED;
    DECLARE v_porcentaje DECIMAL(5,2);

    CALL sp_generar_plan_venta(NEW.id_contrato, NEW.precio_venta, NEW.cuota_inicial, NEW.fecha_escritura);

    SELECT id_agente, porcentaje_comision
      INTO v_id_agente, v_porcentaje
      FROM contrato WHERE id_contrato = NEW.id_contrato;

    INSERT INTO comision (id_contrato, id_agente, base_calculo, porcentaje, valor_comision)
    VALUES (NEW.id_contrato, v_id_agente, NEW.precio_venta, v_porcentaje,
            ROUND(NEW.precio_venta * v_porcentaje / 100, 2))
    ON DUPLICATE KEY UPDATE
        base_calculo   = VALUES(base_calculo),
        porcentaje     = VALUES(porcentaje),
        valor_comision = VALUES(valor_comision);
END$$

-- =====================================================================
-- D. CARTERA: CUOTAS Y PAGOS
-- =====================================================================

-- ---------------------------------------------------------------------
-- D1. Ningun abono puede superar el saldo de la cuota ni registrarse
--     con fecha futura.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_pago_bi
BEFORE INSERT ON pago
FOR EACH ROW
BEGIN
    DECLARE v_valor  DECIMAL(14,2);
    DECLARE v_pagado DECIMAL(14,2) DEFAULT 0.00;

    SELECT valor_cuota INTO v_valor FROM cuota WHERE id_cuota = NEW.id_cuota;

    IF v_valor IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El pago referencia una cuota inexistente';
    END IF;

    SELECT COALESCE(SUM(valor_pagado), 0.00) INTO v_pagado
      FROM pago WHERE id_cuota = NEW.id_cuota;

    IF NEW.valor_pagado > (v_valor - v_pagado) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El abono excede el saldo pendiente de la cuota';
    END IF;

    IF NEW.fecha_pago > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se admiten pagos con fecha futura';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- D2. Traza contable de cada abono registrado.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_pago_ai
AFTER INSERT ON pago
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_pago (id_pago, id_cuota, accion, valor_anterior, valor_nuevo, usuario_bd)
    VALUES (NEW.id_pago, NEW.id_cuota, 'INSERT', NULL, NEW.valor_pagado, CURRENT_USER());
END$$

-- ---------------------------------------------------------------------
-- D3. Traza contable de la anulacion de un abono.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_pago_ad
AFTER DELETE ON pago
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_pago (id_pago, id_cuota, accion, valor_anterior, valor_nuevo, usuario_bd)
    VALUES (OLD.id_pago, OLD.id_cuota, 'DELETE', OLD.valor_pagado, NULL, CURRENT_USER());
END$$

-- ---------------------------------------------------------------------
-- D4. Una cuota con abonos no puede eliminarse.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_cuota_bd
BEFORE DELETE ON cuota
FOR EACH ROW
BEGIN
    DECLARE v_pagos INT DEFAULT 0;

    SELECT COUNT(*) INTO v_pagos FROM pago WHERE id_cuota = OLD.id_cuota;

    IF v_pagos > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La cuota tiene abonos registrados y no puede eliminarse';
    END IF;
END$$

DELIMITER ;

SELECT CONCAT('Triggers creados: ', COUNT(*)) AS resultado
FROM information_schema.triggers
WHERE trigger_schema = 'inmobiliaria';
