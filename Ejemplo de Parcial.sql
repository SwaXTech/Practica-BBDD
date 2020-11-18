/*
Obtener los Tipos de Productos, monto total comprado por cliente y por sus referidos. 

Mostrar: descripción del Tipo de Producto, Nombre y apellido del cliente, monto total comprado de ese
tipo de producto, Nombre y apellido de su cliente referido y el monto total comprado de su
referido. Ordenado por Descripción, Apellido y Nombre del cliente (Referente).
Nota: Si el Cliente no tiene referidos o sus referidos no compraron el mismo producto, mostrar
 ́-- ́ como nombre y apellido del referido y 0 (cero) en la cantidad vendida.
*/

SELECT pt.description, c1.lname + ', ' +  c1.fname, SUM(i1.quantity *  i1.unit_price), COALESCE(ref.lname + ', ' +  ref.fname, '--'), COALESCE(ref.total, 0)
FROM customer c1 JOIN orders o1 ON o1.customer_num = c1.customer_num
	JOIN items  i1 ON i1.order_num = o1.order_num
	JOIN product_types pt ON pt.stock_num = i1.stock_num
	LEFT JOIN (
					SELECT i2.stock_num, c2.customer_num_referedBy, c2.fname, c2.lname, SUM(i2.quantity * i2.unit_price) as 'Total'
	FROM customer c2 LEFT JOIN orders o2 ON o2.customer_num = c2.customer_num
		LEFT JOIN items i2 ON i2.order_num = o2.order_num
	GROUP BY c2.customer_num_referedBy, c2.fname, c2.lname, i2.stock_num
				 ) ref ON ref.customer_num_referedBy = c1.customer_num AND ref.stock_num = i1.stock_num
GROUP BY pt.description, c1.lname + ', ' +  c1.fname, ref.lname + ', ' +  ref.fname, ref.total
ORDER BY pt.description, c1.lname + ', ' +  c1.fname


/*
Crear un procedimiento actualizaPrecios que reciba como parámetro una fecha a partir de la cual
procesar los registros de una tabla Novedades que contiene los nuevos precios de Productos con
la siguiente estructura/información.

FechaAlta, Manu_code, Stock_num, descTipoProducto, Unit_price

Por cada fila de la tabla Novedades

Si no existe el Fabricante, devolver un error de Fabricante inexistente y descartar la
novedad.

Si no existe el stock_num (pero existe el Manu_code) darlo de alta en la tabla
Product_types
Si ya existe el Producto actualizar su precio
Si no existe, Insertarlo en la tabla de productos.

Nota: Manejar una transacción por novedad y errores no contemplados.
*/

CREATE TABLE ##novedades
(

	fecha_alta DATE,
	manu_code CHAR(3),
	stock_num INT,
	descr VARCHAR(15),
	unit_price DECIMAL(6,2)
);
GO

CREATE PROCEDURE actualiza_precios
	@fecha DATE
AS
BEGIN

	DECLARE @fecha_alta DATE, @manu_code CHAR(3), @stock_num INT, @descr VARCHAR(15), @unit_price DECIMAL(6,2);

	DECLARE novedades CURSOR FOR SELECT fecha_alta, manu_code, descr, unit_price
	FROM ##novedades;
	OPEN novedades;
	FETCH NEXT FROM novedades INTO @fecha_alta, @manu_code, @descr, @unit_price;
	WHILE @@FETCH_STATUS = 0
	BEGIN

		BEGIN TRY
			BEGIN TRANSACTION

				IF NOT EXISTS (SELECT manu_code
		FROM manufact
		WHERE manu_code = @manu_code)
					THROW 50001, 'No existe el fabricante', 1

				IF NOT EXISTS (SELECT stock_num
		FROM product_types
		WHERE stock_num = @stock_num)
					INSERT INTO product_types
			(stock_num, description)
		VALUES
			(@stock_num, @descr)

				IF NOT EXISTS (SELECT stock_num
		FROM products
		WHERE stock_num = @stock_num)
					INSERT INTO products
			(stock_num, manu_code, unit_price)
		VALUES(@stock_num, @manu_code, @unit_price)
				ELSE
					UPDATE products SET unit_price = @unit_price WHERE stock_num = @stock_num AND manu_code = @manu_code
			COMMIT TRANSACTION
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION
		END CATCH

		FETCH NEXT FROM novedades INTO @fecha_alta, @manu_code, @descr, @unit_price;
	END
	CLOSE novedades;
	DEALLOCATE novedades;
END
GO


/*
Se desea llevar en tiempo real la cantidad de llamadas/reclamos (Cust_calls) de los Clientes
(Customers) que se producen por cada mes del año y por cada tipo (Call_code).

Ante este requerimiento, se solicita realizar un trigger que cada vez que se produzca un Alta o
Modificación en la tabla Cust_calls, se actualice una tabla ResumenLLamadas donde se lleve en
tiempo real la cantidad de llamadas por Año, Mes y Tipo de llamada.

Ejemplo. Si se da de alta una llamada, se debe sumar 1 a la cantidad de ese Año, Mes y Tipo de
llamada. En caso de ser una modificación y se modifica el tipo de llamada (por ejemplo por una
mala clasificación del operador), se deberá restar 1 al tipo anterior y sumarle 1 al tipo nuevo. Si
no se modifica el tipo de llamada no se deberá hacer nada.

Tabla ResumenLLamadas:
	Anio decimal(4) PK,
	Mes decimal(2) PK,
	Call_code char(1) PK,
	Cantidad int

Nota: No se modifica la PK de la tabla de llamadas. Tener en cuenta altas y modificaciones
múltiples.

*/

CREATE TABLE resumen_llamadas
(

	anio DECIMAL(4),
	mes DECIMAL (2),
	call_code CHAR(1),
	cantidad INT,
	PRIMARY KEY (anio, mes, call_code)
);
GO

CREATE TRIGGER llamadas ON cust_calls AFTER INSERT, UPDATE AS
BEGIN


	DECLARE @date DATE;
	DECLARE @call_code CHAR(1);
	DECLARE @last_call_code CHAR(1);

	DECLARE llamadas CURSOR FOR SELECT i.call_dtime, i.call_code, d.call_code
	FROM inserted i LEFT JOIN deleted d ON i.customer_num = d.customer_num AND i.call_dtime = d.call_dtime;
	OPEN llamadas;
	FETCH NEXT FROM llamadas INTO @date, @call_code, @last_call_code;
	WHILE @@FETCH_STATUS = 0
	BEGIN

		IF @last_call_code = NULL
			IF NOT EXISTS (SELECT 1
		FROM resumen_llamadas
		WHERE anio = YEAR(@date) AND mes = MONTH(@date))
				INSERT INTO resumen_llamadas
			(anio, mes, call_code, cantidad)
		VALUES
			(YEAR(@date), MONTH(@date), @call_code, 1)
			ELSE
				UPDATE resumen_llamadas SET cantidad = cantidad + 1 WHERE anio = YEAR(@date) AND mes = MONTH(@date) AND call_code = @call_code
		ELSE IF @call_code != @last_call_code
		BEGIN
			UPDATE resumen_llamadas SET cantidad = cantidad - 1 WHERE anio = YEAR(@date) AND mes = MONTH(@date) AND call_code = @last_call_code
			UPDATE resumen_llamadas SET cantidad = cantidad + 1 WHERE anio = YEAR(@date) AND mes = MONTH(@date) AND call_code = @call_code
		END

		FETCH NEXT FROM llamadas INTO @date, @call_code, @last_call_code;
	END

	CLOSE llamadas;
	DEALLOCATE llamadas;
END
GO