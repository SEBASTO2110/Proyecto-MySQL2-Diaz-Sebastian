-- ===================================================================
-- PROYECTO : SISTEMA DE GESTION INMOBILIARIA
-- ARCHIVO  : 01_ddl.sql
-- OBJETIVO : Creacion de la base de datos, tablas, claves primarias,
--            claves foraneas y restricciones de integridad.
-- MOTOR    : MySQL 8.0+ / InnoDB / utf8mb4
-- ===================================================================

DROP DATABASE IF EXISTS inmobiliaria;
CREATE DATABASE inmobiliaria
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE inmobiliaria;


-- =====================================================================
-- 1. TABLAS DE CATALOGO (dominios controlados)
--    Se modelan como tablas y no como ENUM para cumplir 3FN, permitir
--    integridad referencial y crecer sin ejecutar ALTER TABLE.
-- =====================================================================

CREATE TABLE ciudad (
    id_ciudad       INT UNSIGNED AUTO_INCREMENT,
    nombre          VARCHAR(80)  NOT NULL,
    departamento    VARCHAR(80)  NOT NULL,
    pais            VARCHAR(60)  NOT NULL DEFAULT 'Colombia',
    CONSTRAINT pk_ciudad PRIMARY KEY (id_ciudad),
    CONSTRAINT uq_ciudad UNIQUE (nombre, departamento, pais)
) ENGINE=InnoDB COMMENT='Catalogo de ciudades donde opera la inmobiliaria';

CREATE TABLE barrio (
    id_barrio       INT UNSIGNED AUTO_INCREMENT,
    nombre          VARCHAR(80)  NOT NULL,
    id_ciudad       INT UNSIGNED NOT NULL,
    CONSTRAINT pk_barrio PRIMARY KEY (id_barrio),
    CONSTRAINT uq_barrio UNIQUE (nombre, id_ciudad),
    CONSTRAINT fk_barrio_ciudad FOREIGN KEY (id_ciudad)
        REFERENCES ciudad (id_ciudad) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB COMMENT='Barrio o zona; depende funcionalmente de la ciudad';

CREATE TABLE tipo_documento (
    id_tipo_documento TINYINT UNSIGNED AUTO_INCREMENT,
    codigo            VARCHAR(5)  NOT NULL,
    descripcion       VARCHAR(60) NOT NULL,
    CONSTRAINT pk_tipo_documento PRIMARY KEY (id_tipo_documento),
    CONSTRAINT uq_tipo_documento_codigo UNIQUE (codigo)
) ENGINE=InnoDB COMMENT='CC, CE, NIT, PAS';

CREATE TABLE tipo_propiedad (
    id_tipo_propiedad TINYINT UNSIGNED AUTO_INCREMENT,
    nombre            VARCHAR(40)  NOT NULL,
    descripcion       VARCHAR(150) NULL,
    CONSTRAINT pk_tipo_propiedad PRIMARY KEY (id_tipo_propiedad),
    CONSTRAINT uq_tipo_propiedad UNIQUE (nombre)
) ENGINE=InnoDB COMMENT='Casa, Apartamento, Local comercial, Oficina, Bodega, Lote';

CREATE TABLE estado_propiedad (
    id_estado_propiedad TINYINT UNSIGNED AUTO_INCREMENT,
    nombre              VARCHAR(30)  NOT NULL,
    descripcion         VARCHAR(150) NULL,
    CONSTRAINT pk_estado_propiedad PRIMARY KEY (id_estado_propiedad),
    CONSTRAINT uq_estado_propiedad UNIQUE (nombre)
) ENGINE=InnoDB COMMENT='Disponible, Reservada, Arrendada, Vendida, En mantenimiento, Retirada';

CREATE TABLE tipo_contrato (
    id_tipo_contrato TINYINT UNSIGNED AUTO_INCREMENT,
    nombre           VARCHAR(30)  NOT NULL,
    descripcion      VARCHAR(150) NULL,
    CONSTRAINT pk_tipo_contrato PRIMARY KEY (id_tipo_contrato),
    CONSTRAINT uq_tipo_contrato UNIQUE (nombre)
) ENGINE=InnoDB COMMENT='Arriendo / Venta';

CREATE TABLE estado_contrato (
    id_estado_contrato TINYINT UNSIGNED AUTO_INCREMENT,
    nombre             VARCHAR(30)  NOT NULL,
    descripcion        VARCHAR(150) NULL,
    CONSTRAINT pk_estado_contrato PRIMARY KEY (id_estado_contrato),
    CONSTRAINT uq_estado_contrato UNIQUE (nombre)
) ENGINE=InnoDB COMMENT='Activo, Finalizado, Cancelado, En mora';

CREATE TABLE metodo_pago (
    id_metodo_pago TINYINT UNSIGNED AUTO_INCREMENT,
    nombre         VARCHAR(40) NOT NULL,
    CONSTRAINT pk_metodo_pago PRIMARY KEY (id_metodo_pago),
    CONSTRAINT uq_metodo_pago UNIQUE (nombre)
) ENGINE=InnoDB COMMENT='Efectivo, Transferencia, PSE, Tarjeta, Cheque';

CREATE TABLE concepto_pago (
    id_concepto_pago TINYINT UNSIGNED AUTO_INCREMENT,
    nombre           VARCHAR(40)  NOT NULL,
    descripcion      VARCHAR(150) NULL,
    CONSTRAINT pk_concepto_pago PRIMARY KEY (id_concepto_pago),
    CONSTRAINT uq_concepto_pago UNIQUE (nombre)
) ENGINE=InnoDB COMMENT='Canon, Administracion, Deposito, Cuota inicial, Saldo venta, Multa';

CREATE TABLE caracteristica (
    id_caracteristica TINYINT UNSIGNED AUTO_INCREMENT,
    nombre            VARCHAR(50) NOT NULL,
    CONSTRAINT pk_caracteristica PRIMARY KEY (id_caracteristica),
    CONSTRAINT uq_caracteristica UNIQUE (nombre)
) ENGINE=InnoDB COMMENT='Atributo multivaluado de la propiedad (piscina, ascensor...)';

-- =====================================================================
-- 2. ESTRUCTURA ORGANIZACIONAL Y PERSONAS
--    Patron supertipo/subtipo: una PERSONA puede ser a la vez cliente,
--    propietario y/o agente sin duplicar sus datos basicos.
-- =====================================================================

CREATE TABLE sucursal (
    id_sucursal  INT UNSIGNED AUTO_INCREMENT,
    nombre       VARCHAR(80)  NOT NULL,
    direccion    VARCHAR(150) NOT NULL,
    id_ciudad    INT UNSIGNED NOT NULL,
    telefono     VARCHAR(20)  NULL,
    CONSTRAINT pk_sucursal PRIMARY KEY (id_sucursal),
    CONSTRAINT uq_sucursal_nombre UNIQUE (nombre),
    CONSTRAINT fk_sucursal_ciudad FOREIGN KEY (id_ciudad)
        REFERENCES ciudad (id_ciudad) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB COMMENT='Oficinas de la inmobiliaria';

CREATE TABLE persona (
    id_persona        INT UNSIGNED AUTO_INCREMENT,
    id_tipo_documento TINYINT UNSIGNED NOT NULL,
    numero_documento  VARCHAR(20)  NOT NULL,
    primer_nombre     VARCHAR(40)  NOT NULL,
    segundo_nombre    VARCHAR(40)  NULL,
    primer_apellido   VARCHAR(40)  NOT NULL,
    segundo_apellido  VARCHAR(40)  NULL,
    fecha_nacimiento  DATE         NULL,
    email             VARCHAR(120) NOT NULL,
    telefono          VARCHAR(20)  NOT NULL,
    direccion         VARCHAR(150) NULL,
    id_ciudad         INT UNSIGNED NOT NULL,
    fecha_registro    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_persona PRIMARY KEY (id_persona),
    CONSTRAINT uq_persona_documento UNIQUE (id_tipo_documento, numero_documento),
    CONSTRAINT uq_persona_email UNIQUE (email),
    CONSTRAINT fk_persona_tipo_doc FOREIGN KEY (id_tipo_documento)
        REFERENCES tipo_documento (id_tipo_documento) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_persona_ciudad FOREIGN KEY (id_ciudad)
        REFERENCES ciudad (id_ciudad) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_persona_email CHECK (email LIKE '%_@_%._%')
) ENGINE=InnoDB COMMENT='Supertipo: datos comunes a clientes, propietarios y agentes';

CREATE TABLE propietario (
    id_propietario     INT UNSIGNED AUTO_INCREMENT,
    id_persona         INT UNSIGNED NOT NULL,
    banco              VARCHAR(60)  NULL,
    numero_cuenta      VARCHAR(30)  NULL,
    tipo_cuenta        ENUM('Ahorros','Corriente') NULL,
    fecha_vinculacion  DATE         NOT NULL DEFAULT (CURRENT_DATE),
    activo             BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_propietario PRIMARY KEY (id_propietario),
    CONSTRAINT uq_propietario_persona UNIQUE (id_persona),
    CONSTRAINT fk_propietario_persona FOREIGN KEY (id_persona)
        REFERENCES persona (id_persona) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB COMMENT='Subtipo de persona: dueno de una o mas propiedades';

CREATE TABLE cliente (
    id_cliente         INT UNSIGNED AUTO_INCREMENT,
    id_persona         INT UNSIGNED NOT NULL,
    ocupacion          VARCHAR(80)  NULL,
    ingresos_mensuales DECIMAL(12,2) NULL,
    fecha_registro     DATE         NOT NULL DEFAULT (CURRENT_DATE),
    activo             BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_cliente PRIMARY KEY (id_cliente),
    CONSTRAINT uq_cliente_persona UNIQUE (id_persona),
    CONSTRAINT fk_cliente_persona FOREIGN KEY (id_persona)
        REFERENCES persona (id_persona) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_cliente_ingresos CHECK (ingresos_mensuales IS NULL OR ingresos_mensuales >= 0)
) ENGINE=InnoDB COMMENT='Subtipo de persona: interesado en arrendar o comprar';

CREATE TABLE agente (
    id_agente            INT UNSIGNED AUTO_INCREMENT,
    id_persona           INT UNSIGNED NOT NULL,
    codigo_agente        VARCHAR(15)  NOT NULL,
    id_sucursal          INT UNSIGNED NOT NULL,
    fecha_ingreso        DATE         NOT NULL,
    porcentaje_comision  DECIMAL(5,2) NOT NULL DEFAULT 3.00,
    activo               BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_agente PRIMARY KEY (id_agente),
    CONSTRAINT uq_agente_persona UNIQUE (id_persona),
    CONSTRAINT uq_agente_codigo UNIQUE (codigo_agente),
    CONSTRAINT fk_agente_persona FOREIGN KEY (id_persona)
        REFERENCES persona (id_persona) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_agente_sucursal FOREIGN KEY (id_sucursal)
        REFERENCES sucursal (id_sucursal) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_agente_comision CHECK (porcentaje_comision BETWEEN 0 AND 100)
) ENGINE=InnoDB COMMENT='Subtipo de persona: asesor comercial de la inmobiliaria';

-- =====================================================================
-- 3. PORTAFOLIO DE PROPIEDADES
-- =====================================================================

CREATE TABLE propiedad (
    id_propiedad           INT UNSIGNED AUTO_INCREMENT,
    codigo_interno         VARCHAR(15)  NOT NULL,
    id_tipo_propiedad      TINYINT UNSIGNED NOT NULL,
    id_estado_propiedad    TINYINT UNSIGNED NOT NULL,
    id_propietario         INT UNSIGNED NOT NULL,
    id_agente_captador     INT UNSIGNED NULL,
    id_barrio              INT UNSIGNED NOT NULL,
    direccion              VARCHAR(150) NOT NULL,
    matricula_inmobiliaria VARCHAR(30)  NULL,
    area_construida        DECIMAL(10,2) NOT NULL,
    area_lote              DECIMAL(10,2) NULL,
    habitaciones           TINYINT UNSIGNED NOT NULL DEFAULT 0,
    banos                  TINYINT UNSIGNED NOT NULL DEFAULT 0,
    parqueaderos           TINYINT UNSIGNED NOT NULL DEFAULT 0,
    estrato                TINYINT UNSIGNED NULL,
    anio_construccion      SMALLINT UNSIGNED NULL,
    se_vende               BOOLEAN      NOT NULL DEFAULT FALSE,
    se_arrienda            BOOLEAN      NOT NULL DEFAULT FALSE,
    precio_venta           DECIMAL(14,2) NULL,
    precio_arriendo        DECIMAL(12,2) NULL,
    valor_administracion   DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    descripcion            TEXT         NULL,
    fecha_registro         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_propiedad PRIMARY KEY (id_propiedad),
    CONSTRAINT uq_propiedad_codigo UNIQUE (codigo_interno),
    CONSTRAINT uq_propiedad_matricula UNIQUE (matricula_inmobiliaria),
    CONSTRAINT fk_propiedad_tipo FOREIGN KEY (id_tipo_propiedad)
        REFERENCES tipo_propiedad (id_tipo_propiedad) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_propiedad_estado FOREIGN KEY (id_estado_propiedad)
        REFERENCES estado_propiedad (id_estado_propiedad) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_propiedad_propietario FOREIGN KEY (id_propietario)
        REFERENCES propietario (id_propietario) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_propiedad_agente FOREIGN KEY (id_agente_captador)
        REFERENCES agente (id_agente) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_propiedad_barrio FOREIGN KEY (id_barrio)
        REFERENCES barrio (id_barrio) ON UPDATE CASCADE ON DELETE RESTRICT,
    -- Un lote no tiene area construida, pero toda propiedad debe medir algo.
    CONSTRAINT ck_propiedad_areas CHECK (area_construida >= 0
                                     AND (area_lote IS NULL OR area_lote > 0)
                                     AND (area_construida > 0 OR area_lote > 0)),
    CONSTRAINT ck_propiedad_estrato CHECK (estrato IS NULL OR estrato BETWEEN 1 AND 6),
    CONSTRAINT ck_propiedad_oferta CHECK (se_vende = TRUE OR se_arrienda = TRUE),
    CONSTRAINT ck_propiedad_precio_venta CHECK (se_vende = FALSE OR precio_venta > 0),
    CONSTRAINT ck_propiedad_precio_arriendo CHECK (se_arrienda = FALSE OR precio_arriendo > 0)
) ENGINE=InnoDB COMMENT='Inmuebles administrados por la inmobiliaria';

CREATE TABLE propiedad_caracteristica (
    id_propiedad      INT UNSIGNED NOT NULL,
    id_caracteristica TINYINT UNSIGNED NOT NULL,
    CONSTRAINT pk_propiedad_caracteristica PRIMARY KEY (id_propiedad, id_caracteristica),
    CONSTRAINT fk_pc_propiedad FOREIGN KEY (id_propiedad)
        REFERENCES propiedad (id_propiedad) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_pc_caracteristica FOREIGN KEY (id_caracteristica)
        REFERENCES caracteristica (id_caracteristica) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB COMMENT='Resuelve la relacion N:M propiedad-caracteristica (1FN)';

CREATE TABLE visita (
    id_visita     INT UNSIGNED AUTO_INCREMENT,
    id_propiedad  INT UNSIGNED NOT NULL,
    id_cliente    INT UNSIGNED NOT NULL,
    id_agente     INT UNSIGNED NOT NULL,
    fecha_hora    DATETIME     NOT NULL,
    calificacion  TINYINT UNSIGNED NULL,
    observaciones VARCHAR(255) NULL,
    CONSTRAINT pk_visita PRIMARY KEY (id_visita),
    CONSTRAINT uq_visita UNIQUE (id_propiedad, id_cliente, fecha_hora),
    CONSTRAINT fk_visita_propiedad FOREIGN KEY (id_propiedad)
        REFERENCES propiedad (id_propiedad) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_visita_cliente FOREIGN KEY (id_cliente)
        REFERENCES cliente (id_cliente) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_visita_agente FOREIGN KEY (id_agente)
        REFERENCES agente (id_agente) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_visita_calificacion CHECK (calificacion IS NULL OR calificacion BETWEEN 1 AND 5)
) ENGINE=InnoDB COMMENT='Muestra de inmuebles a clientes potenciales';

-- =====================================================================
-- 4. CONTRATOS (supertipo) Y SUS SUBTIPOS
--    Los atributos exclusivos de arriendo (canon, vigencia, dia de pago)
--    y de venta (escritura, cuota inicial) se separan para no dejar
--    columnas nulas que dependen del tipo de contrato.
-- =====================================================================

CREATE TABLE contrato (
    id_contrato         INT UNSIGNED AUTO_INCREMENT,
    numero_contrato     VARCHAR(20)  NOT NULL,
    id_tipo_contrato    TINYINT UNSIGNED NOT NULL,
    id_propiedad        INT UNSIGNED NOT NULL,
    id_cliente          INT UNSIGNED NOT NULL,
    id_agente           INT UNSIGNED NOT NULL,
    id_estado_contrato  TINYINT UNSIGNED NOT NULL,
    fecha_firma         DATE         NOT NULL,
    valor_total         DECIMAL(14,2) NOT NULL,
    porcentaje_comision DECIMAL(5,2) NOT NULL DEFAULT 3.00,
    observaciones       VARCHAR(255) NULL,
    fecha_registro      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_contrato PRIMARY KEY (id_contrato),
    CONSTRAINT uq_contrato_numero UNIQUE (numero_contrato),
    CONSTRAINT fk_contrato_tipo FOREIGN KEY (id_tipo_contrato)
        REFERENCES tipo_contrato (id_tipo_contrato) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_contrato_propiedad FOREIGN KEY (id_propiedad)
        REFERENCES propiedad (id_propiedad) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_contrato_cliente FOREIGN KEY (id_cliente)
        REFERENCES cliente (id_cliente) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_contrato_agente FOREIGN KEY (id_agente)
        REFERENCES agente (id_agente) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_contrato_estado FOREIGN KEY (id_estado_contrato)
        REFERENCES estado_contrato (id_estado_contrato) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_contrato_valor CHECK (valor_total > 0),
    CONSTRAINT ck_contrato_comision CHECK (porcentaje_comision BETWEEN 0 AND 100)
) ENGINE=InnoDB COMMENT='Supertipo de contrato: datos comunes a arriendo y venta';

CREATE TABLE contrato_arriendo (
    id_contrato          INT UNSIGNED NOT NULL,
    canon_mensual        DECIMAL(12,2) NOT NULL,
    valor_administracion DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    valor_deposito       DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    fecha_inicio         DATE         NOT NULL,
    fecha_fin            DATE         NOT NULL,
    dia_pago             TINYINT UNSIGNED NOT NULL DEFAULT 5,
    incremento_anual_pct DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    CONSTRAINT pk_contrato_arriendo PRIMARY KEY (id_contrato),
    CONSTRAINT fk_arriendo_contrato FOREIGN KEY (id_contrato)
        REFERENCES contrato (id_contrato) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_arriendo_canon CHECK (canon_mensual > 0),
    CONSTRAINT ck_arriendo_fechas CHECK (fecha_fin > fecha_inicio),
    CONSTRAINT ck_arriendo_dia CHECK (dia_pago BETWEEN 1 AND 28)
) ENGINE=InnoDB COMMENT='Subtipo: condiciones especificas del arrendamiento';

CREATE TABLE contrato_venta (
    id_contrato        INT UNSIGNED NOT NULL,
    precio_venta       DECIMAL(14,2) NOT NULL,
    cuota_inicial      DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    entidad_financiera VARCHAR(80)  NULL,
    fecha_escritura    DATE         NULL,
    numero_escritura   VARCHAR(30)  NULL,
    CONSTRAINT pk_contrato_venta PRIMARY KEY (id_contrato),
    CONSTRAINT uq_venta_escritura UNIQUE (numero_escritura),
    CONSTRAINT fk_venta_contrato FOREIGN KEY (id_contrato)
        REFERENCES contrato (id_contrato) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_venta_precio CHECK (precio_venta > 0),
    CONSTRAINT ck_venta_inicial CHECK (cuota_inicial >= 0 AND cuota_inicial <= precio_venta)
) ENGINE=InnoDB COMMENT='Subtipo: condiciones especificas de la compraventa';

-- =====================================================================
-- 5. CARTERA: CUOTAS, PAGOS Y COMISIONES
--    El saldo NO se almacena: es un dato derivado que se calcula con las
--    funciones fn_saldo_cuota / fn_deuda_pendiente (evita anomalias).
-- =====================================================================

CREATE TABLE cuota (
    id_cuota          BIGINT UNSIGNED AUTO_INCREMENT,
    id_contrato       INT UNSIGNED NOT NULL,
    numero_cuota      SMALLINT UNSIGNED NOT NULL,
    id_concepto_pago  TINYINT UNSIGNED NOT NULL,
    periodo           DATE         NULL COMMENT 'Primer dia del mes facturado (arriendos)',
    fecha_vencimiento DATE         NOT NULL,
    valor_cuota       DECIMAL(14,2) NOT NULL,
    CONSTRAINT pk_cuota PRIMARY KEY (id_cuota),
    CONSTRAINT uq_cuota UNIQUE (id_contrato, numero_cuota, id_concepto_pago),
    CONSTRAINT fk_cuota_contrato FOREIGN KEY (id_contrato)
        REFERENCES contrato (id_contrato) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_cuota_concepto FOREIGN KEY (id_concepto_pago)
        REFERENCES concepto_pago (id_concepto_pago) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_cuota_valor CHECK (valor_cuota > 0)
) ENGINE=InnoDB COMMENT='Obligacion facturada al cliente (canon, cuota inicial, saldo...)';

CREATE TABLE pago (
    id_pago        BIGINT UNSIGNED AUTO_INCREMENT,
    id_cuota       BIGINT UNSIGNED NOT NULL,
    fecha_pago     DATE         NOT NULL,
    valor_pagado   DECIMAL(14,2) NOT NULL,
    id_metodo_pago TINYINT UNSIGNED NOT NULL,
    referencia     VARCHAR(60)  NULL,
    observacion    VARCHAR(255) NULL,
    registrado_por VARCHAR(100) NOT NULL DEFAULT (CURRENT_USER()),
    fecha_registro TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_pago PRIMARY KEY (id_pago),
    CONSTRAINT fk_pago_cuota FOREIGN KEY (id_cuota)
        REFERENCES cuota (id_cuota) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_pago_metodo FOREIGN KEY (id_metodo_pago)
        REFERENCES metodo_pago (id_metodo_pago) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_pago_valor CHECK (valor_pagado > 0)
) ENGINE=InnoDB COMMENT='Abonos aplicados a una cuota; admite pagos parciales';

CREATE TABLE comision (
    id_comision      INT UNSIGNED AUTO_INCREMENT,
    id_contrato      INT UNSIGNED NOT NULL,
    id_agente        INT UNSIGNED NOT NULL,
    base_calculo     DECIMAL(14,2) NOT NULL,
    porcentaje       DECIMAL(5,2) NOT NULL,
    valor_comision   DECIMAL(14,2) NOT NULL,
    fecha_generacion DATE         NOT NULL DEFAULT (CURRENT_DATE),
    pagada           BOOLEAN      NOT NULL DEFAULT FALSE,
    fecha_pago       DATE         NULL,
    CONSTRAINT pk_comision PRIMARY KEY (id_comision),
    CONSTRAINT uq_comision_contrato UNIQUE (id_contrato),
    CONSTRAINT fk_comision_contrato FOREIGN KEY (id_contrato)
        REFERENCES contrato (id_contrato) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_comision_agente FOREIGN KEY (id_agente)
        REFERENCES agente (id_agente) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_comision_valor CHECK (valor_comision >= 0)
) ENGINE=InnoDB COMMENT='Comision liquidada al agente por contrato cerrado';

-- =====================================================================
-- 6. TABLAS DE AUDITORIA (alimentadas exclusivamente por TRIGGERS)
-- =====================================================================

CREATE TABLE auditoria_propiedad (
    id_auditoria     BIGINT UNSIGNED AUTO_INCREMENT,
    id_propiedad     INT UNSIGNED NOT NULL,
    accion           ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    campo_modificado VARCHAR(40)  NOT NULL,
    valor_anterior   VARCHAR(255) NULL,
    valor_nuevo      VARCHAR(255) NULL,
    usuario_bd       VARCHAR(100) NOT NULL,
    fecha_hora       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observacion      VARCHAR(255) NULL,
    CONSTRAINT pk_auditoria_propiedad PRIMARY KEY (id_auditoria),
    INDEX idx_aud_prop_propiedad (id_propiedad, fecha_hora),
    INDEX idx_aud_prop_campo (campo_modificado)
) ENGINE=InnoDB COMMENT='Historico de cambios de estado y precio de las propiedades';

CREATE TABLE auditoria_contrato (
    id_auditoria     BIGINT UNSIGNED AUTO_INCREMENT,
    id_contrato      INT UNSIGNED NOT NULL,
    numero_contrato  VARCHAR(20)  NOT NULL,
    accion           ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    datos_anteriores JSON         NULL,
    datos_nuevos     JSON         NULL,
    usuario_bd       VARCHAR(100) NOT NULL,
    fecha_hora       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_auditoria_contrato PRIMARY KEY (id_auditoria),
    INDEX idx_aud_contrato (id_contrato, fecha_hora)
) ENGINE=InnoDB COMMENT='Historico completo del ciclo de vida de cada contrato';

CREATE TABLE auditoria_pago (
    id_auditoria   BIGINT UNSIGNED AUTO_INCREMENT,
    id_pago        BIGINT UNSIGNED NOT NULL,
    id_cuota       BIGINT UNSIGNED NOT NULL,
    accion         ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    valor_anterior DECIMAL(14,2) NULL,
    valor_nuevo    DECIMAL(14,2) NULL,
    usuario_bd     VARCHAR(100) NOT NULL,
    fecha_hora     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_auditoria_pago PRIMARY KEY (id_auditoria),
    INDEX idx_aud_pago (id_pago, fecha_hora)
) ENGINE=InnoDB COMMENT='Trazabilidad contable de los pagos registrados';

-- =====================================================================
-- 7. TABLAS DE REPORTES Y BITACORA (alimentadas por EVENTOS)
-- =====================================================================

CREATE TABLE reporte_pagos_pendientes (
    id_reporte       BIGINT UNSIGNED AUTO_INCREMENT,
    periodo          CHAR(7)      NOT NULL COMMENT 'AAAA-MM del corte',
    fecha_generacion DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_contrato      INT UNSIGNED NOT NULL,
    numero_contrato  VARCHAR(20)  NOT NULL,
    id_propiedad     INT UNSIGNED NOT NULL,
    codigo_propiedad VARCHAR(15)  NOT NULL,
    id_cliente       INT UNSIGNED NOT NULL,
    nombre_cliente   VARCHAR(160) NOT NULL,
    cuotas_vencidas  SMALLINT UNSIGNED NOT NULL,
    valor_adeudado   DECIMAL(14,2) NOT NULL,
    dias_mora        INT          NOT NULL,
    CONSTRAINT pk_reporte_pagos PRIMARY KEY (id_reporte),
    CONSTRAINT uq_reporte_periodo_contrato UNIQUE (periodo, id_contrato),
    INDEX idx_reporte_periodo (periodo)
) ENGINE=InnoDB COMMENT='Snapshot mensual de cartera generado por evento programado';

CREATE TABLE bitacora_evento (
    id_bitacora     BIGINT UNSIGNED AUTO_INCREMENT,
    nombre_evento   VARCHAR(80)  NOT NULL,
    fecha_hora      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    filas_afectadas INT          NOT NULL DEFAULT 0,
    mensaje         VARCHAR(255) NULL,
    CONSTRAINT pk_bitacora_evento PRIMARY KEY (id_bitacora),
    INDEX idx_bitacora_evento (nombre_evento, fecha_hora)
) ENGINE=InnoDB COMMENT='Registro de ejecucion de los eventos programados';

SELECT CONCAT('DDL OK - tablas creadas: ', COUNT(*)) AS resultado
FROM information_schema.tables
WHERE table_schema = 'inmobiliaria' AND table_type = 'BASE TABLE';
