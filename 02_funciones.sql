-- ===================================================================
-- PROYECTO : SISTEMA DE GESTION INMOBILIARIA
-- ARCHIVO  : 02_funciones.sql
-- OBJETIVO : Funciones definidas por el usuario (UDF) para las
--            operaciones clave del negocio.
-- NOTA     : Todas las funciones que leen tablas se declaran
--            READS SQL DATA; las puramente aritmeticas, DETERMINISTIC.
-- ===================================================================


USE inmobiliaria;

DROP FUNCTION IF EXISTS fn_nombre_completo;
DROP FUNCTION IF EXISTS fn_saldo_cuota;
DROP FUNCTION IF EXISTS fn_deuda_pendiente;
DROP FUNCTION IF EXISTS fn_deuda_total_contrato;
DROP FUNCTION IF EXISTS fn_calcular_comision;
DROP FUNCTION IF EXISTS fn_propiedades_disponibles_por_tipo;
DROP FUNCTION IF EXISTS fn_dias_mora;
DROP FUNCTION IF EXISTS fn_estado_cartera;
DROP FUNCTION IF EXISTS fn_canon_con_incremento;
DROP FUNCTION IF EXISTS fn_ocupacion_portafolio;

DELIMITER $$

-- ---------------------------------------------------------------------
-- 1. fn_nombre_completo
--    Arma el nombre completo de una persona ignorando los nombres nulos.
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_nombre_completo(p_id_persona INT UNSIGNED)
RETURNS VARCHAR(160)
READS SQL DATA
COMMENT 'Devuelve el nombre completo normalizado de una persona'
BEGIN
    DECLARE v_nombre VARCHAR(160);

    SELECT CONCAT_WS(' ', primer_nombre, segundo_nombre, primer_apellido, segundo_apellido)
      INTO v_nombre
      FROM persona
     WHERE id_persona = p_id_persona;

    RETURN COALESCE(v_nombre, 'DESCONOCIDO');
END$$

-- ---------------------------------------------------------------------
-- 2. fn_saldo_cuota
--    Saldo insoluto de una cuota = valor facturado - abonos aplicados.
--    El saldo es un dato DERIVADO: no se almacena, se calcula.
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_saldo_cuota(p_id_cuota BIGINT UNSIGNED)
RETURNS DECIMAL(14,2)
READS SQL DATA
COMMENT 'Valor pendiente de una cuota especifica'
BEGIN
    DECLARE v_valor  DECIMAL(14,2) DEFAULT 0.00;
    DECLARE v_pagado DECIMAL(14,2) DEFAULT 0.00;

    SELECT valor_cuota INTO v_valor
      FROM cuota
     WHERE id_cuota = p_id_cuota;

    IF v_valor IS NULL THEN
        RETURN 0.00;
    END IF;

    SELECT COALESCE(SUM(valor_pagado), 0.00) INTO v_pagado
      FROM pago
     WHERE id_cuota = p_id_cuota;

    RETURN ROUND(v_valor - v_pagado, 2);
END$$

-- ---------------------------------------------------------------------
-- 3. fn_deuda_pendiente  (REQUISITO DEL ENUNCIADO)
--    Deuda EXIGIBLE de un contrato de arriendo (o de venta financiada):
--    suma de las cuotas ya vencidas menos todo lo abonado a ellas.
--    Las cuotas futuras no se consideran mora.
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_deuda_pendiente(p_id_contrato INT UNSIGNED)
RETURNS DECIMAL(14,2)
READS SQL DATA
COMMENT 'Deuda vencida y exigible de un contrato a la fecha actual'
BEGIN
    DECLARE v_facturado DECIMAL(14,2) DEFAULT 0.00;
    DECLARE v_pagado    DECIMAL(14,2) DEFAULT 0.00;

    SELECT COALESCE(SUM(c.valor_cuota), 0.00)
      INTO v_facturado
      FROM cuota c
     WHERE c.id_contrato = p_id_contrato
       AND c.fecha_vencimiento <= CURRENT_DATE;

    SELECT COALESCE(SUM(p.valor_pagado), 0.00)
      INTO v_pagado
      FROM pago p
      JOIN cuota c ON c.id_cuota = p.id_cuota
     WHERE c.id_contrato = p_id_contrato
       AND c.fecha_vencimiento <= CURRENT_DATE;

    RETURN GREATEST(ROUND(v_facturado - v_pagado, 2), 0.00);
END$$

-- ---------------------------------------------------------------------
-- 4. fn_deuda_total_contrato
--    Saldo total del contrato incluyendo cuotas aun no vencidas.
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_deuda_total_contrato(p_id_contrato INT UNSIGNED)
RETURNS DECIMAL(14,2)
READS SQL DATA
COMMENT 'Saldo total del contrato (vencido + por vencer)'
BEGIN
    DECLARE v_facturado DECIMAL(14,2) DEFAULT 0.00;
    DECLARE v_pagado    DECIMAL(14,2) DEFAULT 0.00;

    SELECT COALESCE(SUM(valor_cuota), 0.00) INTO v_facturado
      FROM cuota WHERE id_contrato = p_id_contrato;

    SELECT COALESCE(SUM(p.valor_pagado), 0.00) INTO v_pagado
      FROM pago p JOIN cuota c ON c.id_cuota = p.id_cuota
     WHERE c.id_contrato = p_id_contrato;

    RETURN GREATEST(ROUND(v_facturado - v_pagado, 2), 0.00);
END$$

-- ---------------------------------------------------------------------
-- 5. fn_calcular_comision  (REQUISITO DEL ENUNCIADO)
--    Regla de negocio:
--      * VENTA   -> comision = precio de venta * % pactado en el contrato.
--      * ARRIENDO-> comision = canon mensual   * % pactado (comision de
--                   consignacion, equivalente a un porcentaje del canon).
--    Si el contrato no existe se levanta un error controlado.
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_calcular_comision(p_id_contrato INT UNSIGNED)
RETURNS DECIMAL(14,2)
READS SQL DATA
COMMENT 'Comision del agente segun el tipo de contrato'
BEGIN
    DECLARE v_tipo       VARCHAR(30);
    DECLARE v_porcentaje DECIMAL(5,2);
    DECLARE v_base       DECIMAL(14,2) DEFAULT 0.00;

    SELECT tc.nombre, c.porcentaje_comision
      INTO v_tipo, v_porcentaje
      FROM contrato c
      JOIN tipo_contrato tc ON tc.id_tipo_contrato = c.id_tipo_contrato
     WHERE c.id_contrato = p_id_contrato;

    IF v_tipo IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'fn_calcular_comision: el contrato indicado no existe';
    END IF;

    IF v_tipo = 'Venta' THEN
        SELECT cv.precio_venta INTO v_base
          FROM contrato_venta cv
         WHERE cv.id_contrato = p_id_contrato;
    ELSE
        SELECT ca.canon_mensual INTO v_base
          FROM contrato_arriendo ca
         WHERE ca.id_contrato = p_id_contrato;
    END IF;

    RETURN ROUND(COALESCE(v_base, 0.00) * v_porcentaje / 100, 2);
END$$

-- ---------------------------------------------------------------------
-- 6. fn_propiedades_disponibles_por_tipo  (REQUISITO DEL ENUNCIADO)
--    Total de inmuebles en estado 'Disponible' para un tipo dado.
--    Si se envia NULL devuelve el total de disponibles del portafolio.
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_propiedades_disponibles_por_tipo(p_id_tipo TINYINT UNSIGNED)
RETURNS INT
READS SQL DATA
COMMENT 'Cantidad de propiedades disponibles por tipo de inmueble'
BEGIN
    DECLARE v_total INT DEFAULT 0;

    SELECT COUNT(*)
      INTO v_total
      FROM propiedad p
      JOIN estado_propiedad ep ON ep.id_estado_propiedad = p.id_estado_propiedad
     WHERE ep.nombre = 'Disponible'
       AND (p_id_tipo IS NULL OR p.id_tipo_propiedad = p_id_tipo);

    RETURN v_total;
END$$

-- ---------------------------------------------------------------------
-- 7. fn_dias_mora
--    Dias transcurridos desde el vencimiento de la cuota impaga mas
--    antigua del contrato. Devuelve 0 si el contrato esta al dia.
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_dias_mora(p_id_contrato INT UNSIGNED)
RETURNS INT
READS SQL DATA
COMMENT 'Dias de mora del contrato'
BEGIN
    DECLARE v_fecha DATE;

    SELECT MIN(c.fecha_vencimiento)
      INTO v_fecha
      FROM cuota c
     WHERE c.id_contrato = p_id_contrato
       AND c.fecha_vencimiento <= CURRENT_DATE
       AND fn_saldo_cuota(c.id_cuota) > 0;

    IF v_fecha IS NULL THEN
        RETURN 0;
    END IF;

    RETURN GREATEST(DATEDIFF(CURRENT_DATE, v_fecha), 0);
END$$

-- ---------------------------------------------------------------------
-- 8. fn_estado_cartera
--    Clasificacion de riesgo del contrato segun los dias de mora.
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_estado_cartera(p_id_contrato INT UNSIGNED)
RETURNS VARCHAR(20)
READS SQL DATA
COMMENT 'Clasifica la cartera del contrato: AL DIA / MORA 1-30 / ...'
BEGIN
    DECLARE v_dias INT DEFAULT 0;
    SET v_dias = fn_dias_mora(p_id_contrato);

    RETURN CASE
        WHEN v_dias = 0            THEN 'AL DIA'
        WHEN v_dias BETWEEN 1  AND 30 THEN 'MORA 1-30'
        WHEN v_dias BETWEEN 31 AND 60 THEN 'MORA 31-60'
        WHEN v_dias BETWEEN 61 AND 90 THEN 'MORA 61-90'
        ELSE 'JURIDICO'
    END;
END$$

-- ---------------------------------------------------------------------
-- 9. fn_canon_con_incremento
--    Canon proyectado para el anio n del contrato aplicando el
--    incremento anual pactado (funcion aritmetica pura).
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_canon_con_incremento(
    p_canon DECIMAL(12,2),
    p_incremento_pct DECIMAL(5,2),
    p_anios TINYINT UNSIGNED
)
RETURNS DECIMAL(12,2)
DETERMINISTIC
COMMENT 'Proyecta el canon aplicando el incremento anual compuesto'
BEGIN
    RETURN ROUND(p_canon * POW(1 + p_incremento_pct / 100, p_anios), 2);
END$$

-- ---------------------------------------------------------------------
-- 10. fn_ocupacion_portafolio
--     Porcentaje de inmuebles colocados (arrendados o vendidos).
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_ocupacion_portafolio()
RETURNS DECIMAL(5,2)
READS SQL DATA
COMMENT 'Porcentaje de ocupacion del portafolio'
BEGIN
    DECLARE v_total     INT DEFAULT 0;
    DECLARE v_colocadas INT DEFAULT 0;

    SELECT COUNT(*) INTO v_total FROM propiedad;

    SELECT COUNT(*) INTO v_colocadas
      FROM propiedad p
      JOIN estado_propiedad ep ON ep.id_estado_propiedad = p.id_estado_propiedad
     WHERE ep.nombre IN ('Arrendada','Vendida');

    IF v_total = 0 THEN
        RETURN 0.00;
    END IF;

    RETURN ROUND(v_colocadas * 100 / v_total, 2);
END$$

DELIMITER ;

SELECT CONCAT('Funciones creadas: ', COUNT(*)) AS resultado
FROM information_schema.routines
WHERE routine_schema = 'inmobiliaria' AND routine_type = 'FUNCTION';
