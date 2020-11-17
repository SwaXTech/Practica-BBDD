/*
Crear la siguiente tabla CustomerStatistics con los siguientes campos
customer_num (entero y pk), ordersqty (entero), maxdate (date), uniqueProducts
(entero)

Crear un procedimiento ‘actualizaEstadisticas’ que reciba dos parámetros
customer_numDES y customer_numHAS y que en base a los datos de la tabla
customer cuyo customer_num estén en en rango pasado por parámetro, inserte (si
no existe) o modifique el registro de la tabla CustomerStatistics con la siguiente
información:

Ordersqty contedrá la cantidad de órdenes para cada cliente.
Maxdate contedrá la fecha máxima de la última órde puesta por cada cliente.
uniqueProducts contendrá la cantidad única de tipos de productos adquiridos
por cada cliente.
*/

CREATE TABLE customer_statistics(
	customer_num INT PRIMARY KEY,
	orderqty INT,
	maxdate DATETIME,
	products_qty INT
);
GO


CREATE PROCEDURE actualiza_estadisticas(@customer_num_desde INT, @customer_num_hasta INT) AS
BEGIN

	MERGE customer_statistics cs
		USING(
		
			SELECT o.customer_num, COUNT(DISTINCT o.order_num) AS orderqty, MAX(order_date) AS maxdate, COUNT(DISTINCT stock_num) AS products_qty
			FROM orders o JOIN items i ON o.order_num = i.order_num
			WHERE (o.customer_num BETWEEN @customer_num_desde AND @customer_num_hasta)
			GROUP BY o.customer_num
		
		) o
			ON o.customer_num = cs.customer_num
			WHEN MATCHED THEN
				UPDATE
					SET cs.orderqty = o.orderqty, cs.maxdate = o.maxdate, cs.products_qty = o.products_qty
			WHEN NOT MATCHED BY TARGET THEN
				INSERT (customer_num, orderqty, maxdate, products_qty)
					VALUES (o.customer_num, o.orderqty, o.maxdate, o.products_qty);


END
GO

EXEC actualiza_estadisticas 0, 1000

SELECT * FROM customer_statistics
GO
/*
Crear un procedimiento ‘migraClientes’ que reciba dos parámetros
customer_numDES y customer_numHAS y que dependiendo el tipo de cliente y la
cantidad de órdenes los inserte en las tablas clientesCalifornia, clientesNoCaBaja,
clienteNoCAAlta.

	• El procedimiento deberá migrar de la tabla customer todos los
	  clientes de California a la tabla clientesCalifornia, los clientes que no
	  son de California pero tienen más de 999u$ en OC en
	  clientesNoCaAlta y los clientes que tiene menos de 1000u$ en OC en
	  la tablas clientesNoCaBaja.

	• Se deberá actualizar un campo status en la tabla customer con valor
	  ‘P’ Procesado, para todos aquellos clientes migrados.
	
	• El procedimiento deberá contemplar toda la migración como un lote,
	  en el caso que ocurra un error, se deberá informar el error ocurrido y
	  abortar y deshacer la operación.
*/
CREATE TABLE clientes_california(

	customer_num INT PRIMARY KEY,
	fname VARCHAR(15),
	lname VARCHAR(15),
	company VARCHAR(20),
	address1 VARCHAR(20),
	address2 VARCHAR(20),
	city VARCHAR(15),
	state CHAR(2),
	zipcode CHAR(5),
	phone VARCHAR(18),
	customer_num_referedBy INT,
);
GO
CREATE TABLE clientes_no_ca_baja(

	customer_num INT PRIMARY KEY,
	fname VARCHAR(15),
	lname VARCHAR(15),
	company VARCHAR(20),
	address1 VARCHAR(20),
	address2 VARCHAR(20),
	city VARCHAR(15),
	state CHAR(2),
	zipcode CHAR(5),
	phone VARCHAR(18),
	customer_num_referedBy INT,
);

CREATE TABLE clientes_no_ca_alta(

	customer_num INT PRIMARY KEY,
	fname VARCHAR(15),
	lname VARCHAR(15),
	company VARCHAR(20),
	address1 VARCHAR(20),
	address2 VARCHAR(20),
	city VARCHAR(15),
	state CHAR(2),
	zipcode CHAR(5),
	phone VARCHAR(18),
	customer_num_referedBy INT,
);
GO


CREATE PROCEDURE migra_clientes (@customer_num_desde INT, @customer_num_hasta INT) AS 
BEGIN

BEGIN TRANSACTION

	BEGIN TRY
		INSERT INTO clientes_california (customer_num, fname, lname, company,
										address1, address2, city, state, zipcode, 
										phone, customer_num_referedBy) 
		SELECT
			customer_num, fname, lname, company, address1, address2, city, state,
			zipcode, phone, customer_num_referedBy FROM customer WHERE state = 'CA' AND (customer_num BETWEEN @customer_num_desde AND @customer_num_hasta)


		INSERT INTO clientes_no_ca_baja (customer_num, fname, lname, company,
										address1, address2, city, state, zipcode, 
										phone, customer_num_referedBy) 
		SELECT
			c.customer_num, fname, lname, company, address1, address2, city, state,
			zipcode, phone, customer_num_referedBy FROM customer c JOIN orders o ON o.customer_num = c.customer_num
																   JOIN items i ON o.order_num = i.order_num
			WHERE state != 'CA' AND (o.customer_num BETWEEN @customer_num_desde AND @customer_num_hasta)
			GROUP BY c.customer_num, fname, lname, company, address1, address2, city, state,
			zipcode, phone, customer_num_referedBy
			HAVING SUM(i.quantity * i.unit_price) < 1000

		INSERT INTO clientes_no_ca_alta (customer_num, fname, lname, company,
										address1, address2, city, state, zipcode, 
										phone, customer_num_referedBy) 
		SELECT
			c.customer_num, fname, lname, company, address1, address2, city, state,
			zipcode, phone, customer_num_referedBy FROM customer c JOIN orders o ON o.customer_num = c.customer_num
																   JOIN items i ON o.order_num = i.order_num
			WHERE state != 'CA' AND (o.customer_num BETWEEN @customer_num_desde AND @customer_num_hasta)
			GROUP BY c.customer_num, fname, lname, company, address1, address2, city, state,
			zipcode, phone, customer_num_referedBy
			HAVING SUM(i.quantity * i.unit_price) > 999
	
		UPDATE customer SET status = 'P' WHERE customer_num BETWEEN @customer_num_desde AND @customer_num_hasta

	END TRY
	BEGIN CATCH

		ROLLBACK TRANSACTION
		DECLARE @errorDescripcion VARCHAR(100)
		RAISERROR(@errorDescripcion,14,1)

	END CATCH


COMMIT TRANSACTION

END
GO

/*
Crear un procedimiento ‘actualizaPrecios’ que reciba como parámetros
manu_codeDES, manu_codeHAS y por cada Actualizacion que dependiendo y la cantidad de órdenes genere las siguientes
tablas listaPrecioMayor y listaPreciosMenor. 
Ambas tienen las misma estructura que la tabla Productos.

	• El procedimiento deberá tomar de la tabla products todos los productos que
	  correspondan al rango de fabricantes asignados por parámetro.

	  Por cada producto del fabricante se evaluará la cantidad (quantity) comprada.
	  Si la misma es mayor o igual a 500 se grabará el producto en la tabla
	  listaPrecioMayor y el unit_price deberá ser actualizado con (unit_price *
	  (porcActualización *0,80)),
	  Si la cantidad comprada del producto es menor a 500 se actualizará (o insertará)
	  en la tabla listaPrecioMenor y el unit_price se actualizará con (unit_price *
	  porcActualizacion)

	• Asimismo, se deberá actualizar un campo status de la tabla stock con valor ‘A’
	  Actualizado, para todos aquellos productos con cambio de precio actualizado.

	• El procedimiento deberá contemplar todas las operaciones de cada fabricante
	  como un lote, en el caso que ocurra un error, se deberá informar el error ocurrido
	  y deshacer la operación de ese fabricante.
*/

CREATE TABLE lista_precio_mayor(
	stock_num INT,
	manu_code CHAR(3),
	unit_price DECIMAL(6,2),
	unit_code INT,
	PRIMARY KEY(stock_num, manu_code)
);
CREATE TABLE lista_precio_menor(
	stock_num INT,
	manu_code CHAR(3),
	unit_price DECIMAL(6,2),
	unit_code INT,
	PRIMARY KEY(stock_num, manu_code)
);
GO

CREATE PROCEDURE actualizar_precios @manu_code_desde CHAR(3), @manu_code_hasta CHAR(3), @porc_actualizacion DECIMAL(6,2) AS
BEGIN

	DECLARE @manu_code CHAR(3);

	DECLARE fabricantes CURSOR FOR SELECT manu_code FROM manufact WHERE manu_code BETWEEN @manu_code_desde AND @manu_code_hasta
	OPEN fabricantes;
	FETCH NEXT FROM fabricantes INTO @manu_code
	WHILE @@FETCH_STATUS = 0
	BEGIN


		BEGIN TRY
			BEGIN TRANSACTION

				DECLARE @stock_num INT;
				DECLARE @cantidad_vendida INT;

				DECLARE productos CURSOR FOR SELECT stock_num FROM products WHERE manu_code = @manu_code;
				OPEN productos;
				FETCH NEXT FROM productos INTO @stock_num;
				WHILE @@FETCH_STATUS = 0
				BEGIN

					SELECT @cantidad_vendida = SUM(i.quantity) FROM items i WHERE stock_num = @stock_num AND manu_code = @manu_code

					IF @cantidad_vendida > 500
						INSERT INTO lista_precio_mayor (stock_num, manu_code, unit_price, unit_code)
							SELECT stock_num, manu_code, unit_price * @porc_actualizacion * 0.8 , unit_code FROM products WHERE stock_num = @stock_num AND manu_code = @manu_code
			
					ELSE
						IF NOT EXISTS (SELECT 1 FROM lista_precio_menor WHERE stock_num = @stock_num AND manu_code = @manu_code)
							INSERT INTO lista_precio_menor (stock_num, manu_code, unit_price, unit_code)
								SELECT stock_num, manu_code, unit_price * @porc_actualizacion , unit_code FROM products WHERE stock_num = @stock_num AND manu_code = @manu_code
						ELSE 
							UPDATE lista_precio_menor SET unit_price = unit_price * @porc_actualizacion
								WHERE stock_num = @stock_num AND manu_code = @manu_code
				
					FETCH NEXT FROM productos INTO @stock_num;
				END

				CLOSE productos;
				DEALLOCATE productos;

			COMMIT TRANSACTION
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION
			DECLARE @errorDescripcion VARCHAR(100)
			SELECT @errorDescripcion = 'Error en Fabricante '+CAST(@manu_code AS CHAR(3))
			RAISERROR(@errorDescripcion,14,1)
		END CATCH
	
		FETCH NEXT FROM fabricantes INTO @manu_code
	END
	CLOSE fabricantes;
	DEALLOCATE fabricantes;

END
GO

/*
Stored Procedures
1. Crear la tabla informeStock con los siguientes campos: fechaInforme (date),
	stock_num (entero), manu_code (char(3)), cantOrdenes (entero), UltCompra
	(date), cantClientes (entero), totalVentas (decimal). PK (fechaInforme,
	stock_num, manu_code)

2. Crear un procedimiento ‘generarInformeGerencial’ que reciba un parámetro
	fechaInforme y que en base a los datos de la tabla PRODUCTS de todos los
	productos existentes, inserte un registro de la tabla informeStock con la
	siguiente información:

		fechaInforme: fecha pasada por parámetro
		stock_num: número de stock del producto
		manu_code: código del fabricante
		cantOrdenes: cantidad de órdenes que contengan el producto.
		UltCompra: fecha de última orden para el producto evaluado.
		cantClientes: cantidad de clientes únicos que hayan comprado el producto.
		totalVentas: Sumatoria de las ventas de ese producto (p x q)


		Validar que no exista en la tabla informeStock un informe con la misma
		fechaInforme recibida por parámetro.

*/

CREATE TABLE informe_stock(

	fecha_informe DATE,
	stock_num INT,
	manu_code CHAR(3),
	cant_ordenes INT,
	ult_compra DATE,
	cant_clientes INT,
	total_ventas DECIMAL(6,2) 
	PRIMARY KEY(fecha_informe, stock_num, manu_code)
);
GO

CREATE PROCEDURE generar_informe_gerencial @fecha_informe DATETIME AS
BEGIN

	IF EXISTS (SELECT 1 FROM informe_stock WHERE fecha_informe = @fecha_informe)
		THROW 50001, 'Ya existe', 1

	INSERT INTO informe_stock (fecha_informe, stock_num, manu_code, cant_ordenes, ult_compra, cant_clientes, total_ventas)
		SELECT @fecha_informe, p.stock_num, p.manu_code, COUNT(DISTINCT o.order_num), MAX(o.order_date), COUNT(DISTINCT o.customer_num), SUM(i.quantity * i.unit_price)
		FROM products p LEFT JOIN items i ON p.stock_num = i.stock_num AND p.manu_code = i.manu_code
							 JOIN orders o ON o.order_num = i.order_num
		GROUP BY p.stock_num, p.manu_code

END
GO

DECLARE @fecha DATE;
SET @fecha = GETDATE()
EXEC generar_informe_gerencial @fecha

SELECT * FROM informe_stock

/*
Crear un procedimiento ‘generarInformeVentas’ que reciba como parámetros
fechaInforme y codEstado y que en base a los datos de la tabla customer de todos
los clientes que vivan en el estado pasado por parámetro, inserte un registro de la
tabla informeVentas con la siguiente información:

	fechaInforme: fecha pasada por parámetro
	codEstado: código de estado recibido por parámetro
	customer_num: número de cliente
	cantOrdenes: cantidad de órdenes del cliente.
	primerVenta: fecha de la primer orden al cliente.
	UltVenta: fecha de última orden al cliente.
	cantProductos: cantidad de tipos de productos únicos que haya
	comprado el cliente.
	totalVentas: Sumatoria de las ventas de ese producto (p x q)

	Validar que no exista en la tabla informeVentas un informe con la misma
	fechaInforme y estado recibido por parámetro.
*/

CREATE TABLE informe_ventas(

	fecha_informe DATE,
	cod_estado CHAR(2),
	customer_num INT,
	cant_ordenes INT,
	primer_venta DATE,
	ult_venta DATE,
	cant_productos INT,
	total_ventas DECIMAL(6,2)
);
GO

CREATE PROCEDURE generar_informe_ventas @fecha_informe DATE, @state CHAR(2) AS
BEGIN

	IF EXISTS (SELECT 1 FROM informe_ventas WHERE fecha_informe = @fecha_informe AND cod_estado = @state)
		THROW 50001, 'Ya existe', 1

	INSERT INTO informe_ventas (fecha_informe, cod_estado, customer_num, cant_ordenes, primer_venta, ult_venta, cant_productos, total_ventas)
		(
		SELECT @fecha_informe, @state, o.customer_num, COUNT(DISTINCT o.order_num), MIN(o.order_date), MAX(o.order_date), SUM(i.quantity), SUM(i.quantity * i.unit_price)
		FROM orders o JOIN items i ON o.order_num = i.order_num JOIN customer c ON c.customer_num = o.customer_num
		WHERE c.state = @state
		GROUP BY o.customer_num
		)

END
GO


DECLARE @fecha DATE;
SET @fecha = GETDATE()
EXEC generar_informe_ventas @fecha, 'CA'

SELECT * FROM informe_ventas