-- ==================================================================
-- PROYECTO : SISTEMA DE GESTION INMOBILIARIA
-- ARCHIVO  : 00_instalar.sql
-- OBJETIVO : Instalador maestro. Ejecuta todos los scripts en el orden
--            correcto de dependencias.
--
-- USO (desde la carpeta raiz del proyecto):
--     mysql -u root -p < sql/00_instalar.sql
--
--   o bien, dentro del cliente de MySQL:
--     mysql> SOURCE sql/00_instalar.sql;
--
-- ORDEN DE DEPENDENCIAS
--   1. DDL          -> estructura
--   2. Funciones    -> las usan procedimientos, triggers y vistas
--   3. Procedimientos -> los invocan los triggers y los eventos
--   4. Triggers     -> deben existir ANTES de cargar los datos
--   5. Vistas/indices
--   6. Eventos
--   7. DML          -> al insertarse dispara toda la automatizacion
--   8. Usuarios y roles (requiere privilegios de administrador)
-- =====================================================================

SELECT '>>> 1/8 Creando estructura (DDL)...' AS paso;
SOURCE sql/01_ddl.sql;

SELECT '>>> 2/8 Creando funciones...' AS paso;
SOURCE sql/02_funciones.sql;

SELECT '>>> 3/8 Creando procedimientos...' AS paso;
SOURCE sql/03_procedimientos.sql;

SELECT '>>> 4/8 Creando triggers...' AS paso;
SOURCE sql/04_triggers.sql;

SELECT '>>> 5/8 Creando indices y vistas...' AS paso;
SOURCE sql/05_vistas_indices.sql;

SELECT '>>> 6/8 Creando eventos programados...' AS paso;
SOURCE sql/06_eventos.sql;

SELECT '>>> 7/8 Cargando datos de prueba (DML)...' AS paso;
SOURCE sql/07_dml_datos.sql;

SELECT '>>> 8/8 Creando roles y usuarios...' AS paso;
SOURCE sql/08_usuarios_roles.sql;

SELECT 'INSTALACION COMPLETADA' AS resultado;

USE inmobiliaria;

SELECT
    (SELECT COUNT(*) FROM information_schema.tables
      WHERE table_schema='inmobiliaria' AND table_type='BASE TABLE') AS tablas,
    (SELECT COUNT(*) FROM information_schema.views
      WHERE table_schema='inmobiliaria')                             AS vistas,
    (SELECT COUNT(*) FROM information_schema.routines
      WHERE routine_schema='inmobiliaria' AND routine_type='FUNCTION')  AS funciones,
    (SELECT COUNT(*) FROM information_schema.routines
      WHERE routine_schema='inmobiliaria' AND routine_type='PROCEDURE') AS procedimientos,
    (SELECT COUNT(*) FROM information_schema.triggers
      WHERE trigger_schema='inmobiliaria')                           AS triggers,
    (SELECT COUNT(*) FROM information_schema.events
      WHERE event_schema='inmobiliaria')                             AS eventos;

