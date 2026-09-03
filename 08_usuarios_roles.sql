-- =====================================================================
-- PROYECTO : SISTEMA DE GESTION INMOBILIARIA
-- ARCHIVO  : 08_usuarios_roles.sql
-- OBJETIVO : Seguridad. Creacion de roles, usuarios y privilegios
--            diferenciados segun el principio de minimo privilegio.
--
-- MODELO DE SEGURIDAD
--   rol_admin_inmobiliaria : control total del esquema (DDL + DML).
--   rol_agente_inmobiliario: gestiona portafolio, clientes y contratos.
--                            NO puede tocar dinero ni borrar registros.
--   rol_contador           : ve toda la informacion financiera y registra
--                            recaudo unicamente a traves de procedimientos.
--   rol_auditor            : solo lectura sobre auditoria y reportes.
--
-- NOTA CLAVE: las tablas auditoria_* NO reciben privilegios de escritura
-- para NINGUN rol. Solo los triggers escriben en ellas, y lo hacen con
-- los privilegios de su DEFINER, de modo que el historico no se puede
-- alterar ni siquiera por quien origina el cambio.
-- =====================================================================

USE inmobiliaria;

-- ---------------------------------------------------------------------
-- 1. LIMPIEZA PREVIA (permite re-ejecutar el script)
-- ---------------------------------------------------------------------
DROP USER IF EXISTS 'admin_inmo'@'localhost';
DROP USER IF EXISTS 'agente_demo'@'localhost';
DROP USER IF EXISTS 'contador_demo'@'localhost';
DROP USER IF EXISTS 'auditor_demo'@'localhost';

DROP ROLE IF EXISTS 'rol_admin_inmobiliaria';
DROP ROLE IF EXISTS 'rol_agente_inmobiliario';
DROP ROLE IF EXISTS 'rol_contador';
DROP ROLE IF EXISTS 'rol_auditor';

-- ---------------------------------------------------------------------
-- 2. CREACION DE ROLES
-- ---------------------------------------------------------------------
CREATE ROLE 'rol_admin_inmobiliaria',
            'rol_agente_inmobiliario',
            'rol_contador',
            'rol_auditor';

-- ---------------------------------------------------------------------
-- 3. PRIVILEGIOS DEL ADMINISTRADOR
--    Control total sobre el esquema, incluidos triggers, rutinas y
--    eventos programados.
-- ---------------------------------------------------------------------
GRANT ALL PRIVILEGES ON inmobiliaria.* TO 'rol_admin_inmobiliaria';

-- ---------------------------------------------------------------------
-- 4. PRIVILEGIOS DEL AGENTE INMOBILIARIO
--    Opera el negocio comercial: publica inmuebles, registra clientes,
--    agenda visitas y firma contratos. No accede al recaudo ni borra.
-- ---------------------------------------------------------------------
GRANT SELECT ON inmobiliaria.ciudad             TO 'rol_agente_inmobiliario';
GRANT SELECT ON inmobiliaria.barrio             TO 'rol_agente_inmobiliario';
GRANT SELECT ON inmobiliaria.tipo_documento     TO 'rol_agente_inmobiliario';
GRANT SELECT ON inmobiliaria.tipo_propiedad     TO 'rol_agente_inmobiliario';
GRANT SELECT ON inmobiliaria.estado_propiedad   TO 'rol_agente_inmobiliario';
GRANT SELECT ON inmobiliaria.tipo_contrato      TO 'rol_agente_inmobiliario';
GRANT SELECT ON inmobiliaria.estado_contrato    TO 'rol_agente_inmobiliario';
GRANT SELECT ON inmobiliaria.caracteristica     TO 'rol_agente_inmobiliario';
GRANT SELECT ON inmobiliaria.sucursal           TO 'rol_agente_inmobiliario';
GRANT SELECT ON inmobiliaria.agente             TO 'rol_agente_inmobiliario';
GRANT SELECT ON inmobiliaria.propietario        TO 'rol_agente_inmobiliario';
GRANT SELECT ON inmobiliaria.comision           TO 'rol_agente_inmobiliario';
GRANT SELECT ON inmobiliaria.cuota              TO 'rol_agente_inmobiliario';

GRANT SELECT, INSERT, UPDATE ON inmobiliaria.persona                  TO 'rol_agente_inmobiliario';
GRANT SELECT, INSERT, UPDATE ON inmobiliaria.cliente                  TO 'rol_agente_inmobiliario';
GRANT SELECT, INSERT, UPDATE ON inmobiliaria.propiedad                TO 'rol_agente_inmobiliario';
GRANT SELECT, INSERT, DELETE ON inmobiliaria.propiedad_caracteristica TO 'rol_agente_inmobiliario';
GRANT SELECT, INSERT, UPDATE ON inmobiliaria.visita                   TO 'rol_agente_inmobiliario';
GRANT SELECT, INSERT, UPDATE ON inmobiliaria.contrato                 TO 'rol_agente_inmobiliario';
GRANT SELECT, INSERT           ON inmobiliaria.contrato_arriendo      TO 'rol_agente_inmobiliario';
GRANT SELECT, INSERT           ON inmobiliaria.contrato_venta         TO 'rol_agente_inmobiliario';

-- Vistas de consulta autorizadas
GRANT SELECT ON inmobiliaria.v_propiedades_disponibles TO 'rol_agente_inmobiliario';
GRANT SELECT ON inmobiliaria.v_contratos_activos       TO 'rol_agente_inmobiliario';
GRANT SELECT ON inmobiliaria.v_resumen_portafolio      TO 'rol_agente_inmobiliario';
GRANT SELECT ON inmobiliaria.v_comisiones_agente       TO 'rol_agente_inmobiliario';

-- Rutinas autorizadas
GRANT EXECUTE ON PROCEDURE inmobiliaria.sp_buscar_propiedades          TO 'rol_agente_inmobiliario';
GRANT EXECUTE ON FUNCTION  inmobiliaria.fn_propiedades_disponibles_por_tipo TO 'rol_agente_inmobiliario';
GRANT EXECUTE ON FUNCTION  inmobiliaria.fn_calcular_comision           TO 'rol_agente_inmobiliario';
GRANT EXECUTE ON FUNCTION  inmobiliaria.fn_nombre_completo             TO 'rol_agente_inmobiliario';
GRANT EXECUTE ON FUNCTION  inmobiliaria.fn_deuda_pendiente             TO 'rol_agente_inmobiliario';
GRANT EXECUTE ON FUNCTION  inmobiliaria.fn_dias_mora                   TO 'rol_agente_inmobiliario';
GRANT EXECUTE ON FUNCTION  inmobiliaria.fn_estado_cartera              TO 'rol_agente_inmobiliario';
GRANT EXECUTE ON FUNCTION  inmobiliaria.fn_saldo_cuota                 TO 'rol_agente_inmobiliario';
GRANT EXECUTE ON FUNCTION  inmobiliaria.fn_ocupacion_portafolio        TO 'rol_agente_inmobiliario';

-- ---------------------------------------------------------------------
-- 5. PRIVILEGIOS DEL CONTADOR
--    Lectura completa de la informacion financiera. El recaudo se
--    registra SOLO mediante sp_registrar_pago (no tiene INSERT directo
--    sobre pago), lo que garantiza que siempre pasen las validaciones.
-- ---------------------------------------------------------------------
GRANT SELECT ON inmobiliaria.contrato          TO 'rol_contador';
GRANT SELECT ON inmobiliaria.contrato_arriendo TO 'rol_contador';
GRANT SELECT ON inmobiliaria.contrato_venta    TO 'rol_contador';
GRANT SELECT ON inmobiliaria.propiedad         TO 'rol_contador';
GRANT SELECT ON inmobiliaria.cliente           TO 'rol_contador';
GRANT SELECT ON inmobiliaria.persona           TO 'rol_contador';
GRANT SELECT ON inmobiliaria.propietario       TO 'rol_contador';
GRANT SELECT ON inmobiliaria.agente            TO 'rol_contador';
GRANT SELECT ON inmobiliaria.metodo_pago       TO 'rol_contador';
GRANT SELECT ON inmobiliaria.concepto_pago     TO 'rol_contador';
GRANT SELECT ON inmobiliaria.tipo_contrato     TO 'rol_contador';
GRANT SELECT ON inmobiliaria.estado_contrato   TO 'rol_contador';
GRANT SELECT ON inmobiliaria.tipo_propiedad    TO 'rol_contador';
GRANT SELECT ON inmobiliaria.estado_propiedad  TO 'rol_contador';
GRANT SELECT ON inmobiliaria.pago              TO 'rol_contador';
GRANT SELECT ON inmobiliaria.auditoria_pago    TO 'rol_contador';

GRANT SELECT, INSERT, UPDATE ON inmobiliaria.cuota    TO 'rol_contador';
GRANT SELECT, UPDATE         ON inmobiliaria.comision TO 'rol_contador';
GRANT SELECT, INSERT         ON inmobiliaria.reporte_pagos_pendientes TO 'rol_contador';

GRANT SELECT ON inmobiliaria.v_cartera_vencida    TO 'rol_contador';
GRANT SELECT ON inmobiliaria.v_estado_cuenta      TO 'rol_contador';
GRANT SELECT ON inmobiliaria.v_contratos_activos  TO 'rol_contador';
GRANT SELECT ON inmobiliaria.v_comisiones_agente  TO 'rol_contador';

GRANT EXECUTE ON PROCEDURE inmobiliaria.sp_registrar_pago                    TO 'rol_contador';
GRANT EXECUTE ON PROCEDURE inmobiliaria.sp_liquidar_comision                 TO 'rol_contador';
GRANT EXECUTE ON PROCEDURE inmobiliaria.sp_generar_reporte_pagos_pendientes  TO 'rol_contador';
GRANT EXECUTE ON PROCEDURE inmobiliaria.sp_generar_cuotas_arriendo           TO 'rol_contador';
GRANT EXECUTE ON PROCEDURE inmobiliaria.sp_generar_cuotas_venta              TO 'rol_contador';
GRANT EXECUTE ON FUNCTION  inmobiliaria.fn_deuda_pendiente                   TO 'rol_contador';
GRANT EXECUTE ON FUNCTION  inmobiliaria.fn_deuda_total_contrato              TO 'rol_contador';
GRANT EXECUTE ON FUNCTION  inmobiliaria.fn_saldo_cuota                       TO 'rol_contador';
GRANT EXECUTE ON FUNCTION  inmobiliaria.fn_dias_mora                         TO 'rol_contador';
GRANT EXECUTE ON FUNCTION  inmobiliaria.fn_estado_cartera                    TO 'rol_contador';
GRANT EXECUTE ON FUNCTION  inmobiliaria.fn_calcular_comision                 TO 'rol_contador';
GRANT EXECUTE ON FUNCTION  inmobiliaria.fn_nombre_completo                   TO 'rol_contador';

-- ---------------------------------------------------------------------
-- 6. PRIVILEGIOS DEL AUDITOR
--    Solo lectura del historico y de los reportes: no ve datos de
--    contacto ni puede modificar nada.
-- ---------------------------------------------------------------------
GRANT SELECT ON inmobiliaria.auditoria_propiedad        TO 'rol_auditor';
GRANT SELECT ON inmobiliaria.auditoria_contrato         TO 'rol_auditor';
GRANT SELECT ON inmobiliaria.auditoria_pago             TO 'rol_auditor';
GRANT SELECT ON inmobiliaria.bitacora_evento            TO 'rol_auditor';
GRANT SELECT ON inmobiliaria.reporte_pagos_pendientes   TO 'rol_auditor';
GRANT SELECT ON inmobiliaria.v_historico_propiedad      TO 'rol_auditor';
GRANT SELECT ON inmobiliaria.v_resumen_portafolio       TO 'rol_auditor';

-- ---------------------------------------------------------------------
-- 7. USUARIOS DE PRUEBA
--    Cambie las contrasenas antes de cualquier uso real.
--    PASSWORD EXPIRE NEVER evita el bloqueo durante la demostracion.
-- ---------------------------------------------------------------------
CREATE USER 'admin_inmo'@'localhost'
    IDENTIFIED BY 'Admin#2026'    PASSWORD EXPIRE NEVER;
CREATE USER 'agente_demo'@'localhost'
    IDENTIFIED BY 'Agente#2026'   PASSWORD EXPIRE NEVER;
CREATE USER 'contador_demo'@'localhost'
    IDENTIFIED BY 'Contador#2026' PASSWORD EXPIRE NEVER;
CREATE USER 'auditor_demo'@'localhost'
    IDENTIFIED BY 'Auditor#2026'  PASSWORD EXPIRE NEVER;

-- ---------------------------------------------------------------------
-- 8. ASIGNACION DE ROLES
-- ---------------------------------------------------------------------
GRANT 'rol_admin_inmobiliaria'  TO 'admin_inmo'@'localhost';
GRANT 'rol_agente_inmobiliario' TO 'agente_demo'@'localhost';
GRANT 'rol_contador'            TO 'contador_demo'@'localhost';
GRANT 'rol_auditor'             TO 'auditor_demo'@'localhost';

-- El administrador ademas necesita gestionar el planificador de eventos.
GRANT EVENT ON inmobiliaria.* TO 'admin_inmo'@'localhost';

-- Los roles se activan automaticamente al iniciar sesion; de lo
-- contrario cada usuario tendria que ejecutar SET ROLE manualmente.
SET DEFAULT ROLE ALL TO
    'admin_inmo'@'localhost',
    'agente_demo'@'localhost',
    'contador_demo'@'localhost',
    'auditor_demo'@'localhost';

FLUSH PRIVILEGES;

-- ---------------------------------------------------------------------
-- 9. VERIFICACION
-- ---------------------------------------------------------------------
SELECT user, host, account_locked
FROM mysql.user
WHERE user IN ('admin_inmo','agente_demo','contador_demo','auditor_demo',
               'rol_admin_inmobiliaria','rol_agente_inmobiliario','rol_contador','rol_auditor');

SHOW GRANTS FOR 'rol_agente_inmobiliario';
SHOW GRANTS FOR 'rol_contador';
SHOW GRANTS FOR 'rol_auditor';
