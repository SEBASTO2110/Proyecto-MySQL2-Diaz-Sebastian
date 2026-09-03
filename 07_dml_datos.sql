-- =====================================================================
-- PROYECTO : SISTEMA DE GESTION INMOBILIARIA
-- ARCHIVO  : 07_dml_datos.sql
-- OBJETIVO : Carga de datos de prueba.
-- IMPORTANTE: se ejecuta DESPUES de los triggers para que la insercion
--            de contratos dispare automaticamente:
--              - la auditoria,
--              - el cambio de estado de la propiedad,
--              - la generacion del plan de cuotas,
--              - la liquidacion de la comision del agente.
--            Las fechas son RELATIVAS a CURRENT_DATE para que el escenario
--            de mora siga siendo valido cualquier dia que se ejecute.
-- ====================================================================


USE inmobiliaria;

-- =====================================================================
-- 1. CATALOGOS
-- =====================================================================

INSERT INTO tipo_documento (id_tipo_documento, codigo, descripcion) VALUES
(1,'CC','Cedula de ciudadania'),
(2,'CE','Cedula de extranjeria'),
(3,'NIT','Numero de identificacion tributaria'),
(4,'PAS','Pasaporte');

INSERT INTO tipo_propiedad (id_tipo_propiedad, nombre, descripcion) VALUES
(1,'Casa','Vivienda unifamiliar independiente'),
(2,'Apartamento','Unidad residencial en propiedad horizontal'),
(3,'Local comercial','Inmueble destinado a comercio'),
(4,'Oficina','Espacio destinado a actividad empresarial'),
(5,'Bodega','Inmueble para almacenamiento o industria'),
(6,'Lote','Terreno sin construccion');

INSERT INTO estado_propiedad (id_estado_propiedad, nombre, descripcion) VALUES
(1,'Disponible','Publicada y lista para arrendar o vender'),
(2,'Reservada','Con promesa o separacion vigente'),
(3,'Arrendada','Con contrato de arrendamiento vigente'),
(4,'Vendida','Transferida a un nuevo propietario'),
(5,'En mantenimiento','Temporalmente fuera del mercado'),
(6,'Retirada','El propietario la retiro del portafolio');

INSERT INTO tipo_contrato (id_tipo_contrato, nombre, descripcion) VALUES
(1,'Arriendo','Contrato de arrendamiento con canon mensual'),
(2,'Venta','Contrato de compraventa');

INSERT INTO estado_contrato (id_estado_contrato, nombre, descripcion) VALUES
(1,'Activo','Contrato vigente y al dia'),
(2,'Finalizado','Contrato terminado normalmente'),
(3,'Cancelado','Contrato terminado anticipadamente'),
(4,'En mora','Contrato vigente con cartera vencida');

INSERT INTO metodo_pago (id_metodo_pago, nombre) VALUES
(1,'Efectivo'),
(2,'Transferencia bancaria'),
(3,'PSE'),
(4,'Tarjeta de credito'),
(5,'Cheque'),
(6,'Consignacion');

INSERT INTO concepto_pago (id_concepto_pago, nombre, descripcion) VALUES
(1,'Canon de arrendamiento','Valor mensual del arriendo'),
(2,'Administracion','Cuota de administracion de la copropiedad'),
(3,'Deposito','Deposito o garantia del contrato'),
(4,'Cuota inicial','Pago inicial de la compraventa'),
(5,'Saldo de venta','Saldo pagado contra escritura o credito'),
(6,'Multa por mora','Sancion por pago extemporaneo');

INSERT INTO caracteristica (id_caracteristica, nombre) VALUES
(1,'Piscina'),(2,'Ascensor'),(3,'Gimnasio'),(4,'Balcon'),
(5,'Zona BBQ'),(6,'Vigilancia 24 horas'),(7,'Deposito privado'),
(8,'Chimenea'),(9,'Jardin privado'),(10,'Salon comunal'),
(11,'Aire acondicionado'),(12,'Amoblado');

INSERT INTO ciudad (id_ciudad, nombre, departamento, pais) VALUES
(1,'Bogota D.C.','Cundinamarca','Colombia'),
(2,'Medellin','Antioquia','Colombia'),
(3,'Cali','Valle del Cauca','Colombia'),
(4,'Barranquilla','Atlantico','Colombia');

INSERT INTO barrio (id_barrio, nombre, id_ciudad) VALUES
(1,'Chapinero',1),(2,'Usaquen',1),(3,'Cedritos',1),(4,'Teusaquillo',1),(5,'Salitre',1),
(6,'El Poblado',2),(7,'Laureles',2),(8,'Envigado',2),
(9,'Granada',3),(10,'Ciudad Jardin',3),
(11,'Alto Prado',4),(12,'Riomar',4);

INSERT INTO sucursal (id_sucursal, nombre, direccion, id_ciudad, telefono) VALUES
(1,'Sede Norte','Carrera 15 # 93-60 Oficina 401',1,'6013456789'),
(2,'Sede Poblado','Carrera 43A # 1-50 Oficina 902',2,'6042345678'),
(3,'Sede Sur','Avenida 6 Norte # 23-40 Local 5',3,'6023456712');

-- =====================================================================
-- 2. PERSONAS  (supertipo)
--    Nota: la persona 5 es propietaria Y cliente a la vez; gracias al
--    patron supertipo/subtipo sus datos NO se duplican.
-- =====================================================================

INSERT INTO persona (id_persona, id_tipo_documento, numero_documento, primer_nombre, segundo_nombre,
                     primer_apellido, segundo_apellido, fecha_nacimiento, email, telefono, direccion, id_ciudad) VALUES
-- Propietarios (1-8)
(1,1,'79512340','Carlos','Andres','Ramirez','Lopez','1972-03-14','carlos.ramirez@correo.com','3101234567','Calle 93 # 15-20',1),
(2,1,'52341876','Maria','Fernanda','Gomez','Castro','1980-07-22','maria.gomez@correo.com','3112345678','Carrera 11 # 85-40',1),
(3,1,'71234509','Jorge','Enrique','Velasquez','Ruiz','1968-11-05','jorge.velasquez@correo.com','3123456789','Carrera 43A # 5-15',2),
(4,1,'43876512','Luz','Adriana','Mejia','Ospina','1975-01-30','luz.mejia@correo.com','3134567890','Circular 4 # 70-10',2),
(5,3,'900456789','Inversiones','Del Valle','S A S',NULL,NULL,'contacto@inversionesdelvalle.com','3145678901','Avenida 9 Norte # 15-30',3),
(6,1,'16789023','Andres','Felipe','Palacio','Zapata','1985-09-12','andres.palacio@correo.com','3156789012','Calle 16 # 100-20',3),
(7,1,'32456789','Claudia','Patricia','Barrios','Nieto','1978-05-19','claudia.barrios@correo.com','3167890123','Carrera 51B # 87-30',4),
(8,1,'80123456','Ricardo','Jose','Salazar','Duran','1970-12-01','ricardo.salazar@correo.com','3178901234','Calle 140 # 12-10',1),
-- Agentes (9-13)
(9,1,'1010234567','Diana','Carolina','Rojas','Pineda','1992-04-08','diana.rojas@inmobiliaria.com','3181234567','Carrera 15 # 93-60',1),
(10,1,'1020345678','Julian','Esteban','Cardenas','Moreno','1990-08-25','julian.cardenas@inmobiliaria.com','3182345678','Calle 100 # 19-54',1),
(11,1,'1030456789','Paola','Andrea','Zuluaga','Rincon','1994-02-17','paola.zuluaga@inmobiliaria.com','3183456789','Carrera 43A # 1-50',2),
(12,1,'1040567890','Sebastian','David','Herrera','Quintero','1988-10-03','sebastian.herrera@inmobiliaria.com','3184567890','Avenida 6 Norte # 23-40',3),
(13,1,'1050678901','Natalia','Sofia','Correa','Vargas','1996-06-11','natalia.correa@inmobiliaria.com','3185678901','Carrera 52 # 76-80',4),
-- Clientes (14-27)
(14,1,'1015678901','Andrea','Milena','Torres','Suarez','1993-03-21','andrea.torres@correo.com','3201234567','Calle 63 # 11-25',1),
(15,3,'901234567','Comercializadora','Andina','S A S',NULL,NULL,'gerencia@comercializadoraandina.com','3202345678','Carrera 13 # 60-15',1),
(16,1,'1016789012','Felipe','Antonio','Ochoa','Guzman','1991-11-14','felipe.ochoa@correo.com','3203456789','Avenida El Dorado # 68-45',1),
(17,1,'1017890123','Laura','Cristina','Nino','Beltran','1995-07-09','laura.nino@correo.com','3204567890','Circular 4 # 70-20',2),
(18,3,'830987654','Logistica','Del Norte','S A S',NULL,NULL,'operaciones@logisticadelnorte.com','3205678901','Carrera 68 # 15-30',1),
(19,1,'1018901234','Camilo','Ernesto','Bermudez','Alvarez','1989-01-27','camilo.bermudez@correo.com','3206789012','Carrera 51B # 87-40',4),
(20,1,'1019012345','Valentina','Isabel','Cruz','Marin','1997-09-30','valentina.cruz@correo.com','3207890123','Calle 45 # 20-15',1),
(21,1,'1020123456','Mauricio','Alberto','Pena','Cardona','1986-04-16','mauricio.pena@correo.com','3208901234','Avenida 6 Norte # 25-50',3),
(22,1,'1021234567','Sandra','Liliana','Guerrero','Fonseca','1983-12-05','sandra.guerrero@correo.com','3209012345','Calle 140 # 12-30',1),
(23,1,'1022345678','Oscar','Ivan','Delgado','Rivas','1979-06-23','oscar.delgado@correo.com','3210123456','Calle 37 Sur # 27-15',2),
(24,2,'E1234567','Marco','Antonio','Rossi',NULL,'1982-02-11','marco.rossi@correo.com','3211234567','Calle 10 # 40-30',2),
(25,1,'1024567890','Juliana','Marcela','Acosta','Cifuentes','1998-08-19','juliana.acosta@correo.com','3212345678','Carrera 7 # 116-40',1),
(26,1,'1025678901','Daniel','Ricardo','Forero','Munoz','1990-05-07','daniel.forero@correo.com','3213456789','Carrera 76 # 39-22',2),
(27,1,'1026789012','Catalina','Maria','Restrepo','Jaramillo','1994-10-28','catalina.restrepo@correo.com','3214567890','Carrera 38 # 96-120',4);

-- Subtipos
INSERT INTO propietario (id_propietario, id_persona, banco, numero_cuenta, tipo_cuenta, fecha_vinculacion) VALUES
(1,1,'Bancolombia','12345678901','Ahorros','2019-02-10'),
(2,2,'Davivienda','98765432101','Corriente','2020-06-15'),
(3,3,'BBVA','45678912301','Ahorros','2018-09-01'),
(4,4,'Banco de Bogota','32165498701','Ahorros','2021-03-22'),
(5,5,'Bancolombia','78912345601','Corriente','2017-11-30'),
(6,6,'Scotiabank Colpatria','65432198701','Ahorros','2022-01-18'),
(7,7,'Banco de Occidente','14725836901','Corriente','2020-08-05'),
(8,8,'Bancolombia','36925814701','Ahorros','2016-04-12');

INSERT INTO agente (id_agente, id_persona, codigo_agente, id_sucursal, fecha_ingreso, porcentaje_comision, activo) VALUES
(1,9 ,'AGE-001',1,'2019-03-01',3.00,TRUE),
(2,10,'AGE-002',1,'2020-07-15',3.50,TRUE),
(3,11,'AGE-003',2,'2021-01-11',3.00,TRUE),
(4,12,'AGE-004',3,'2018-05-20',4.00,TRUE),
(5,13,'AGE-005',1,'2022-09-05',3.00,TRUE);

INSERT INTO cliente (id_cliente, id_persona, ocupacion, ingresos_mensuales, fecha_registro) VALUES
(1 ,14,'Ingeniera de sistemas',       9500000.00,'2024-01-15'),
(2 ,15,'Persona juridica - comercio',85000000.00,'2023-08-22'),
(3 ,16,'Contador publico',            7800000.00,'2024-03-10'),
(4 ,17,'Disenadora grafica',          5200000.00,'2024-05-30'),
(5 ,18,'Persona juridica - logistica',120000000.00,'2023-02-14'),
(6 ,19,'Medico especialista',        18000000.00,'2024-07-01'),
(7 ,20,'Docente universitaria',       4800000.00,'2024-09-12'),
(8 ,21,'Comerciante independiente',   9200000.00,'2024-11-20'),
(9 ,22,'Abogada',                    15000000.00,'2025-01-08'),
(10,23,'Gerente comercial',          22000000.00,'2025-02-19'),
(11,24,'Inversionista extranjero',   60000000.00,'2025-03-27'),
(12,25,'Analista financiera',         6500000.00,'2025-04-15'),
(13,26,'Arquitecto',                 11000000.00,'2025-05-23'),
(14,5 ,'Persona juridica - inversion',95000000.00,'2025-06-10');

-- =====================================================================
-- 3. PORTAFOLIO DE PROPIEDADES  (todas ingresan como 'Disponible';
--    los triggers cambiaran el estado al firmarse cada contrato)
-- =====================================================================

INSERT INTO propiedad (id_propiedad, codigo_interno, id_tipo_propiedad, id_estado_propiedad, id_propietario,
                       id_agente_captador, id_barrio, direccion, matricula_inmobiliaria, area_construida, area_lote,
                       habitaciones, banos, parqueaderos, estrato, anio_construccion,
                       se_vende, se_arrienda, precio_venta, precio_arriendo, valor_administracion, descripcion) VALUES
(1 ,'INM-001',2,1,1,1,1 ,'Calle 63 # 11-25 Apto 502'      ,'50C-1234567', 78.00,NULL,2,2,1,4,2015,FALSE,TRUE ,NULL         ,  2800000.00, 320000.00,'Apartamento remodelado cerca al parque'),
(2 ,'INM-002',2,1,1,1,2 ,'Carrera 7 # 116-40 Apto 1203'   ,'50C-2345678',110.00,NULL,3,3,2,6,2018,TRUE ,TRUE , 780000000.00,  4200000.00, 480000.00,'Apartamento con vista panoramica'),
(3 ,'INM-003',1,1,2,2,3 ,'Calle 140 # 12-30'              ,'50C-3456789',220.00,320.00,4,3,2,5,2010,TRUE ,FALSE, 950000000.00,        NULL,      0.00,'Casa familiar con jardin y estudio'),
(4 ,'INM-004',3,1,2,2,1 ,'Carrera 13 # 60-15 Local 3'     ,'50C-4567890', 65.00,NULL,0,1,0,4,2008,FALSE,TRUE ,NULL         ,  5500000.00, 400000.00,'Local sobre via principal con vitrina'),
(5 ,'INM-005',4,1,3,3,5 ,'Avenida El Dorado # 68-45 Of 802','50C-5678901', 95.00,NULL,0,2,2,NULL,2019,FALSE,TRUE,NULL       ,  6200000.00, 750000.00,'Oficina en centro empresarial'),
(6 ,'INM-006',2,1,3,1,6 ,'Carrera 43A # 7-50 Apto 901'    ,'01N-6789012',130.00,NULL,3,3,2,6,2020,TRUE ,TRUE ,1150000000.00,  5800000.00, 690000.00,'Apartamento de lujo en El Poblado'),
(7 ,'INM-007',2,1,4,4,7 ,'Circular 4 # 70-20 Apto 302'    ,'01N-7890123', 72.00,NULL,2,2,1,5,2012,FALSE,TRUE ,NULL         ,  2400000.00, 260000.00,'Apartamento cerca a la Primero de Mayo'),
(8 ,'INM-008',1,1,4,4,8 ,'Calle 37 Sur # 27-15'           ,'01N-8901234',180.00,240.00,4,4,2,5,2005,TRUE ,FALSE, 620000000.00,       NULL,      0.00,'Casa en conjunto cerrado con zonas verdes'),
(9 ,'INM-009',5,1,5,2,5 ,'Zona Industrial Carrera 68 # 15-30','50C-9012345',450.00,600.00,0,2,4,NULL,2016,FALSE,TRUE,NULL   , 12000000.00,      0.00,'Bodega con muelle de cargue'),
(10,'INM-010',2,1,5,3,9 ,'Avenida 9 Norte # 15-40 Apto 604','37U-0123456', 85.00,NULL,3,2,1,5,2014,TRUE ,TRUE , 420000000.00,  2100000.00, 240000.00,'Apartamento en el norte de Cali'),
(11,'INM-011',1,1,6,5,10,'Calle 16 # 100-25'              ,'37U-1234567',260.00,450.00,5,4,3,6,2011,TRUE ,FALSE,1250000000.00,       NULL,      0.00,'Casa campestre en Ciudad Jardin'),
(12,'INM-012',3,1,6,5,11,'Carrera 52 # 76-80 Local 12'    ,'04N-2345678', 90.00,NULL,0,2,1,5,2013,TRUE ,TRUE , 680000000.00,  7200000.00, 550000.00,'Local en centro comercial consolidado'),
(13,'INM-013',2,1,7,3,12,'Carrera 51B # 87-40 Apto 1502'  ,'04N-3456789',140.00,NULL,3,3,2,6,2021,FALSE,TRUE ,NULL         ,  4800000.00, 520000.00,'Apartamento nuevo frente al mar'),
(14,'INM-014',4,1,7,1,2 ,'Calle 100 # 19-54 Oficina 405'  ,'50C-4567891', 60.00,NULL,0,1,1,NULL,2017,TRUE ,TRUE , 480000000.00,  3600000.00, 420000.00,'Oficina en zona financiera'),
(15,'INM-015',6,1,8,2,3 ,'Kilometro 3 via La Calera'      ,'50C-5678912',  0.00,1200.00,0,0,0,NULL,NULL,TRUE ,FALSE, 850000000.00,       NULL,      0.00,'Lote con licencia de construccion'),
(16,'INM-016',2,1,8,4,4 ,'Calle 45 # 20-15 Apto 201'      ,'50C-6789123', 65.00,NULL,2,1,1,4,2009,FALSE,TRUE ,NULL         ,  1900000.00, 180000.00,'Apartamento economico cerca a universidades'),
(17,'INM-017',1,1,1,5,7 ,'Carrera 76 # 39-22'             ,'01N-7891234',195.00,260.00,4,3,2,5,2007,FALSE,TRUE ,NULL         ,  5200000.00,      0.00,'Casa amplia en Laureles'),
(18,'INM-018',2,1,2,1,6 ,'Calle 10 # 40-30 Apto 1801'     ,'01N-8912345',160.00,NULL,3,4,3,6,2022,TRUE ,FALSE,1680000000.00,       NULL,      0.00,'Penthouse con terraza privada'),
(19,'INM-019',3,1,3,5,9 ,'Avenida 6 Norte # 25-50 Local 2','37U-9123456', 55.00,NULL,0,1,0,4,2010,FALSE,TRUE ,NULL         ,  3200000.00, 300000.00,'Local para restaurante o cafeteria'),
(20,'INM-020',5,1,6,2,12,'Carrera 38 # 96-120'            ,'04N-0234567',800.00,1100.00,0,3,6,NULL,2018,TRUE,TRUE ,1900000000.00, 18000000.00,     0.00,'Bodega logistica con oficinas');

INSERT INTO propiedad_caracteristica (id_propiedad, id_caracteristica) VALUES
(1,2),(1,4),(1,6),
(2,2),(2,3),(2,4),(2,6),(2,10),
(3,5),(3,8),(3,9),
(4,6),(4,11),
(5,2),(5,6),(5,11),
(6,1),(6,2),(6,3),(6,4),(6,6),(6,10),(6,11),
(7,2),(7,4),
(8,5),(8,6),(8,9),(8,10),
(9,6),(9,7),
(10,2),(10,4),(10,6),(10,11),
(11,1),(11,5),(11,8),(11,9),(11,6),
(12,6),(12,11),
(13,1),(13,2),(13,3),(13,4),(13,6),(13,11),(13,12),
(14,2),(14,6),(14,11),
(16,2),(16,6),
(17,5),(17,9),
(18,1),(18,2),(18,3),(18,4),(18,6),(18,10),(18,11),(18,12),
(19,6),(19,11),
(20,6),(20,7),(20,11);

-- =====================================================================
-- 4. VISITAS COMERCIALES
-- =====================================================================

INSERT INTO visita (id_propiedad, id_cliente, id_agente, fecha_hora, calificacion, observaciones) VALUES
(1 ,1 ,1,DATE_SUB(CURRENT_DATE, INTERVAL 320 DAY) + INTERVAL 10 HOUR,5,'Le gusto la iluminacion y la ubicacion'),
(2 ,12,1,DATE_SUB(CURRENT_DATE, INTERVAL 200 DAY) + INTERVAL 15 HOUR,4,'Interesada, pide negociar el precio'),
(3 ,9 ,2,DATE_SUB(CURRENT_DATE, INTERVAL 150 DAY) + INTERVAL  9 HOUR,5,'Cierra compra despues de la segunda visita'),
(4 ,2 ,2,DATE_SUB(CURRENT_DATE, INTERVAL 430 DAY) + INTERVAL 11 HOUR,4,'Requiere adecuacion electrica'),
(6 ,11,3,DATE_SUB(CURRENT_DATE, INTERVAL 100 DAY) + INTERVAL 16 HOUR,3,'Considera el precio alto para el sector'),
(8 ,10,4,DATE_SUB(CURRENT_DATE, INTERVAL  45 DAY) + INTERVAL 10 HOUR,5,'Solicita estudio de credito hipotecario'),
(11,13,5,DATE_SUB(CURRENT_DATE, INTERVAL  30 DAY) + INTERVAL 14 HOUR,4,'Pregunta por la reforma de la cocina'),
(13,6 ,3,DATE_SUB(CURRENT_DATE, INTERVAL  95 DAY) + INTERVAL 17 HOUR,5,'Firma contrato de arriendo'),
(18,11,1,DATE_SUB(CURRENT_DATE, INTERVAL  70 DAY) + INTERVAL 12 HOUR,5,'Compra para inversion'),
(20,14,2,DATE_SUB(CURRENT_DATE, INTERVAL  20 DAY) + INTERVAL  8 HOUR,3,'Evalua la altura libre de la bodega');

-- =====================================================================
-- 5. CONTRATOS DE ARRIENDO
--    Cada INSERT en contrato dispara la auditoria y cambia el estado de
--    la propiedad; cada INSERT en contrato_arriendo genera el plan de
--    cuotas y la comision del agente.
-- =====================================================================

INSERT INTO contrato (id_contrato, numero_contrato, id_tipo_contrato, id_propiedad, id_cliente, id_agente,
                      id_estado_contrato, fecha_firma, valor_total, porcentaje_comision, observaciones) VALUES
(1,'CTO-0001',1,1 ,1,1,1,DATE_SUB(CURRENT_DATE, INTERVAL 305 DAY), 33600000.00,10.00,'Arriendo de vivienda por 12 meses'),
(2,'CTO-0002',1,4 ,2,2,1,DATE_SUB(CURRENT_DATE, INTERVAL 430 DAY),132000000.00,10.00,'Arriendo comercial por 24 meses'),
(3,'CTO-0003',1,5 ,3,3,1,DATE_SUB(CURRENT_DATE, INTERVAL 185 DAY), 74400000.00,10.00,'Arriendo de oficina por 12 meses'),
(4,'CTO-0004',1,7 ,4,4,1,DATE_SUB(CURRENT_DATE, INTERVAL 245 DAY), 28800000.00,10.00,'Arriendo de vivienda por 12 meses'),
(5,'CTO-0005',1,9 ,5,2,1,DATE_SUB(CURRENT_DATE, INTERVAL 610 DAY),432000000.00,10.00,'Arriendo de bodega por 36 meses'),
(6,'CTO-0006',1,13,6,3,1,DATE_SUB(CURRENT_DATE, INTERVAL  95 DAY), 57600000.00,10.00,'Arriendo de vivienda por 12 meses'),
(7,'CTO-0007',1,16,7,4,1,DATE_SUB(CURRENT_DATE, INTERVAL 460 DAY), 22800000.00,10.00,'Arriendo por 12 meses (vigencia expirada)'),
(8,'CTO-0008',1,19,8,5,1,DATE_SUB(CURRENT_DATE, INTERVAL 155 DAY), 38400000.00,10.00,'Arriendo comercial por 12 meses');

INSERT INTO contrato_arriendo (id_contrato, canon_mensual, valor_administracion, valor_deposito,
                               fecha_inicio, fecha_fin, dia_pago, incremento_anual_pct) VALUES
(1, 2800000.00,320000.00, 2800000.00,
   DATE_ADD(DATE_FORMAT(CURRENT_DATE,'%Y-%m-01'), INTERVAL -10 MONTH),
   DATE_ADD(DATE_FORMAT(CURRENT_DATE,'%Y-%m-01'), INTERVAL   2 MONTH), 5, 8.00),
(2, 5500000.00,400000.00,11000000.00,
   DATE_ADD(DATE_FORMAT(CURRENT_DATE,'%Y-%m-01'), INTERVAL -14 MONTH),
   DATE_ADD(DATE_FORMAT(CURRENT_DATE,'%Y-%m-01'), INTERVAL  10 MONTH),10, 9.00),
(3, 6200000.00,750000.00, 6200000.00,
   DATE_ADD(DATE_FORMAT(CURRENT_DATE,'%Y-%m-01'), INTERVAL  -6 MONTH),
   DATE_ADD(DATE_FORMAT(CURRENT_DATE,'%Y-%m-01'), INTERVAL   6 MONTH), 5, 7.50),
(4, 2400000.00,260000.00, 2400000.00,
   DATE_ADD(DATE_FORMAT(CURRENT_DATE,'%Y-%m-01'), INTERVAL  -8 MONTH),
   DATE_ADD(DATE_FORMAT(CURRENT_DATE,'%Y-%m-01'), INTERVAL   4 MONTH),15, 8.00),
(5,12000000.00,     0.00,24000000.00,
   DATE_ADD(DATE_FORMAT(CURRENT_DATE,'%Y-%m-01'), INTERVAL -20 MONTH),
   DATE_ADD(DATE_FORMAT(CURRENT_DATE,'%Y-%m-01'), INTERVAL  16 MONTH), 5,10.00),
(6, 4800000.00,520000.00, 4800000.00,
   DATE_ADD(DATE_FORMAT(CURRENT_DATE,'%Y-%m-01'), INTERVAL  -3 MONTH),
   DATE_ADD(DATE_FORMAT(CURRENT_DATE,'%Y-%m-01'), INTERVAL   9 MONTH), 5, 8.00),
(7, 1900000.00,180000.00, 1900000.00,
   DATE_ADD(DATE_FORMAT(CURRENT_DATE,'%Y-%m-01'), INTERVAL -15 MONTH),
   DATE_ADD(DATE_FORMAT(CURRENT_DATE,'%Y-%m-01'), INTERVAL  -3 MONTH), 5, 0.00),
(8, 3200000.00,300000.00, 3200000.00,
   DATE_ADD(DATE_FORMAT(CURRENT_DATE,'%Y-%m-01'), INTERVAL  -5 MONTH),
   DATE_ADD(DATE_FORMAT(CURRENT_DATE,'%Y-%m-01'), INTERVAL   7 MONTH), 5, 8.00);

-- =====================================================================
-- 6. CONTRATOS DE VENTA
-- =====================================================================

INSERT INTO contrato (id_contrato, numero_contrato, id_tipo_contrato, id_propiedad, id_cliente, id_agente,
                      id_estado_contrato, fecha_firma, valor_total, porcentaje_comision, observaciones) VALUES
(9 ,'CTO-0009',2,3 , 9,2,1,DATE_SUB(CURRENT_DATE, INTERVAL 120 DAY), 950000000.00,3.00,'Compraventa con credito hipotecario'),
(10,'CTO-0010',2,8 ,10,4,1,DATE_SUB(CURRENT_DATE, INTERVAL  30 DAY), 620000000.00,3.00,'Compraventa en tramite de escrituracion'),
(11,'CTO-0011',2,18,11,1,1,DATE_SUB(CURRENT_DATE, INTERVAL  60 DAY),1680000000.00,3.50,'Compraventa de inversion');

INSERT INTO contrato_venta (id_contrato, precio_venta, cuota_inicial, entidad_financiera, fecha_escritura, numero_escritura) VALUES
(9 , 950000000.00,285000000.00,'Bancolombia',    DATE_SUB(CURRENT_DATE, INTERVAL 90 DAY),'ESC-4521-2025'),
(10, 620000000.00,124000000.00,'Davivienda',     DATE_ADD(CURRENT_DATE, INTERVAL 30 DAY),'ESC-4680-2025'),
(11,1680000000.00,500000000.00,'Recursos propios',DATE_SUB(CURRENT_DATE, INTERVAL 30 DAY),'ESC-4712-2025');

-- =====================================================================
-- 7. RECAUDO
--    Se simulan cuatro escenarios de cartera:
--      a) contratos al dia,
--      b) mora de 2 meses,
--      c) mora con abono parcial,
--      d) mora superior a 90 dias (cobro juridico).
-- =====================================================================

-- a) Contratos al dia (se paga todo lo vencido)
INSERT INTO pago (id_cuota, fecha_pago, valor_pagado, id_metodo_pago, referencia, observacion)
SELECT cu.id_cuota,
       LEAST(DATE_ADD(cu.fecha_vencimiento, INTERVAL 2 DAY), CURRENT_DATE),
       cu.valor_cuota, 2,
       CONCAT('TRF-', LPAD(cu.id_cuota, 6, '0')),
       'Pago normal dentro del plazo'
  FROM cuota cu
  JOIN contrato c ON c.id_contrato = cu.id_contrato
 WHERE c.numero_contrato IN ('CTO-0001','CTO-0003','CTO-0005','CTO-0006','CTO-0007')
   AND cu.fecha_vencimiento <= CURRENT_DATE;

-- b) CTO-0002: dejo de pagar hace 2 meses
INSERT INTO pago (id_cuota, fecha_pago, valor_pagado, id_metodo_pago, referencia, observacion)
SELECT cu.id_cuota,
       LEAST(DATE_ADD(cu.fecha_vencimiento, INTERVAL 3 DAY), CURRENT_DATE),
       cu.valor_cuota, 3,
       CONCAT('PSE-', LPAD(cu.id_cuota, 6, '0')),
       'Pago normal dentro del plazo'
  FROM cuota cu
  JOIN contrato c ON c.id_contrato = cu.id_contrato
 WHERE c.numero_contrato = 'CTO-0002'
   AND cu.fecha_vencimiento < DATE_SUB(CURRENT_DATE, INTERVAL 2 MONTH);

-- c) CTO-0004: mora de 1 mes con abono parcial sobre el canon mas antiguo
INSERT INTO pago (id_cuota, fecha_pago, valor_pagado, id_metodo_pago, referencia, observacion)
SELECT cu.id_cuota,
       LEAST(DATE_ADD(cu.fecha_vencimiento, INTERVAL 1 DAY), CURRENT_DATE),
       cu.valor_cuota, 2,
       CONCAT('TRF-', LPAD(cu.id_cuota, 6, '0')),
       'Pago normal dentro del plazo'
  FROM cuota cu
  JOIN contrato c ON c.id_contrato = cu.id_contrato
 WHERE c.numero_contrato = 'CTO-0004'
   AND cu.fecha_vencimiento < DATE_SUB(CURRENT_DATE, INTERVAL 1 MONTH);

INSERT INTO pago (id_cuota, fecha_pago, valor_pagado, id_metodo_pago, referencia, observacion)
SELECT cu.id_cuota, CURRENT_DATE, ROUND(cu.valor_cuota * 0.50, 2), 1,
       'ABONO-PARCIAL', 'Abono parcial acordado con el cliente'
  FROM cuota cu
  JOIN contrato c ON c.id_contrato = cu.id_contrato
 WHERE c.numero_contrato = 'CTO-0004'
   AND cu.id_concepto_pago = 1
   AND cu.fecha_vencimiento <= CURRENT_DATE
   AND cu.fecha_vencimiento >= DATE_SUB(CURRENT_DATE, INTERVAL 1 MONTH)
 ORDER BY cu.fecha_vencimiento
 LIMIT 1;

-- d) CTO-0008: mora superior a 90 dias
INSERT INTO pago (id_cuota, fecha_pago, valor_pagado, id_metodo_pago, referencia, observacion)
SELECT cu.id_cuota,
       LEAST(DATE_ADD(cu.fecha_vencimiento, INTERVAL 2 DAY), CURRENT_DATE),
       cu.valor_cuota, 6,
       CONCAT('CON-', LPAD(cu.id_cuota, 6, '0')),
       'Pago normal dentro del plazo'
  FROM cuota cu
  JOIN contrato c ON c.id_contrato = cu.id_contrato
 WHERE c.numero_contrato = 'CTO-0008'
   AND cu.fecha_vencimiento < DATE_SUB(CURRENT_DATE, INTERVAL 3 MONTH);

-- Ventas: CTO-0009 totalmente pagada, CTO-0010 solo cuota inicial,
--         CTO-0011 sin ningun pago (cartera vencida de alto valor).
INSERT INTO pago (id_cuota, fecha_pago, valor_pagado, id_metodo_pago, referencia, observacion)
SELECT cu.id_cuota, cu.fecha_vencimiento, cu.valor_cuota, 2,
       CONCAT('TRF-', LPAD(cu.id_cuota, 6, '0')), 'Pago de compraventa'
  FROM cuota cu
  JOIN contrato c ON c.id_contrato = cu.id_contrato
 WHERE c.numero_contrato = 'CTO-0009';

INSERT INTO pago (id_cuota, fecha_pago, valor_pagado, id_metodo_pago, referencia, observacion)
SELECT cu.id_cuota, cu.fecha_vencimiento, cu.valor_cuota, 2,
       CONCAT('TRF-', LPAD(cu.id_cuota, 6, '0')), 'Cuota inicial recibida'
  FROM cuota cu
  JOIN contrato c ON c.id_contrato = cu.id_contrato
 WHERE c.numero_contrato = 'CTO-0010'
   AND cu.id_concepto_pago = 4;

-- =====================================================================
-- 8. LIQUIDACION DE COMISIONES YA PAGADAS
-- =====================================================================

CALL sp_liquidar_comision(1);
CALL sp_liquidar_comision(3);
CALL sp_liquidar_comision(9);

-- =====================================================================
-- 9. MOVIMIENTOS QUE ALIMENTAN LA AUDITORIA
--    Ajustes de precio del portafolio disponible.
-- =====================================================================

UPDATE propiedad SET precio_arriendo = 3000000.00 WHERE codigo_interno = 'INM-014';
UPDATE propiedad SET precio_venta    = 1180000000.00 WHERE codigo_interno = 'INM-011';
UPDATE propiedad SET id_estado_propiedad = 5 WHERE codigo_interno = 'INM-017';

-- =====================================================================
-- 10. EJECUCION INICIAL DE LOS PROCESOS AUTOMATICOS
--     (los mismos que ejecutan los eventos programados)
-- =====================================================================

CALL sp_actualizar_contratos_vencidos();   -- cierra CTO-0007 y libera INM-016
CALL sp_marcar_contratos_en_mora();        -- reclasifica la cartera vencida
CALL sp_generar_reporte_pagos_pendientes(NULL);

-- =====================================================================
-- 11. VERIFICACION DE LA CARGA
-- =====================================================================

SELECT 'personas'      AS tabla, COUNT(*) AS registros FROM persona
UNION ALL SELECT 'propiedades', COUNT(*) FROM propiedad
UNION ALL SELECT 'contratos',   COUNT(*) FROM contrato
UNION ALL SELECT 'cuotas',      COUNT(*) FROM cuota
UNION ALL SELECT 'pagos',       COUNT(*) FROM pago
UNION ALL SELECT 'comisiones',  COUNT(*) FROM comision
UNION ALL SELECT 'auditoria_propiedad', COUNT(*) FROM auditoria_propiedad
UNION ALL SELECT 'auditoria_contrato',  COUNT(*) FROM auditoria_contrato
UNION ALL SELECT 'auditoria_pago',      COUNT(*) FROM auditoria_pago
UNION ALL SELECT 'reporte_pagos_pendientes', COUNT(*) FROM reporte_pagos_pendientes;
