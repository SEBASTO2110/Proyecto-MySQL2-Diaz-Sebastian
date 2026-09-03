-- ===================================================================
-- PROYECTO : SISTEMA DE GESTION INMOBILIARIA
-- ARCHIVO  : 06_eventos.sql
-- OBJETIVO : Eventos programados (planificador de MySQL).
-- REQUISITO: el planificador debe estar encendido. Requiere privilegio
--            SUPER o SYSTEM_VARIABLES_ADMIN:
--                SET GLOBAL event_scheduler = ON;
--            Para dejarlo permanente, en my.ini / my.cnf:
--                [mysqld]
--                event_scheduler = ON
-- ====================================================================

USE inmobiliaria;

SET GLOBAL event_scheduler = ON;

DROP EVENT IF EXISTS ev_reporte_mensual_cartera;
DROP EVENT IF EXISTS ev_marcar_contratos_en_mora;
DROP EVENT IF EXISTS ev_cierre_contratos_vencidos;
DROP EVENT IF EXISTS ev_purgar_auditoria;

DELIMITER $$

-- ---------------------------------------------------------------------
-- 1. EVENTO MENSUAL DE CARTERA  (requisito del enunciado)
--    El primer dia de cada mes a la 01:00 inserta en la tabla
--    reporte_pagos_pendientes el estado de los pagos vencidos de todos
--    los contratos vigentes.
-- ---------------------------------------------------------------------
CREATE EVENT ev_reporte_mensual_cartera
ON SCHEDULE EVERY 1 MONTH
    STARTS (TIMESTAMP(DATE_ADD(DATE_FORMAT(CURRENT_DATE, '%Y-%m-01'), INTERVAL 1 MONTH)) + INTERVAL 1 HOUR)
ON COMPLETION PRESERVE
ENABLE
COMMENT 'Genera el reporte mensual de propiedades arrendadas con pagos pendientes'
DO
BEGIN
    CALL sp_generar_reporte_pagos_pendientes(DATE_FORMAT(CURRENT_DATE, '%Y-%m'));
END$$

-- ---------------------------------------------------------------------
-- 2. Reclasificacion diaria de la cartera: contratos activos que
--    presentan cuotas vencidas pasan a estado 'En mora'.
-- ---------------------------------------------------------------------
CREATE EVENT ev_marcar_contratos_en_mora
ON SCHEDULE EVERY 1 DAY
    STARTS (TIMESTAMP(CURRENT_DATE + INTERVAL 1 DAY) + INTERVAL 2 HOUR)
ON COMPLETION PRESERVE
ENABLE
COMMENT 'Marca en mora los contratos con cartera vencida'
DO
BEGIN
    CALL sp_marcar_contratos_en_mora();
END$$

-- ---------------------------------------------------------------------
-- 3. Cierre automatico de los arriendos cuya vigencia expiro; el trigger
--    del contrato devuelve la propiedad al estado 'Disponible'.
-- ---------------------------------------------------------------------
CREATE EVENT ev_cierre_contratos_vencidos
ON SCHEDULE EVERY 1 DAY
    STARTS (TIMESTAMP(CURRENT_DATE + INTERVAL 1 DAY) + INTERVAL 3 HOUR)
ON COMPLETION PRESERVE
ENABLE
COMMENT 'Finaliza contratos de arriendo vencidos y libera el inmueble'
DO
BEGIN
    CALL sp_actualizar_contratos_vencidos();
END$$

-- ---------------------------------------------------------------------
-- 4. Depuracion anual de auditoria con mas de 5 anios de antiguedad,
--    conservando siempre la historia contractual.
-- ---------------------------------------------------------------------
CREATE EVENT ev_purgar_auditoria
ON SCHEDULE EVERY 1 YEAR
    STARTS (TIMESTAMP(DATE_ADD(DATE_FORMAT(CURRENT_DATE, '%Y-01-01'), INTERVAL 1 YEAR)) + INTERVAL 4 HOUR)
ON COMPLETION PRESERVE
ENABLE
COMMENT 'Depura registros de auditoria de propiedades con mas de 5 anios'
DO
BEGIN
    DECLARE v_filas INT DEFAULT 0;

    DELETE FROM auditoria_propiedad
     WHERE fecha_hora < DATE_SUB(CURRENT_DATE, INTERVAL 5 YEAR);

    SET v_filas = ROW_COUNT();

    INSERT INTO bitacora_evento (nombre_evento, filas_afectadas, mensaje)
    VALUES ('ev_purgar_auditoria', v_filas, 'Depuracion anual de auditoria de propiedades');
END$$

DELIMITER ;

SELECT event_name, status, interval_value, interval_field, starts
FROM information_schema.events
WHERE event_schema = 'inmobiliaria';
