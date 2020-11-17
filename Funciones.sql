/*
Escribir una sentencia SELECT que devuelva el número de orden, fecha de orden y el nombre del
día de la semana de la orden de todas las órdenes que no han sido pagadas.


Si el cliente pertenece al estado de California el día de la semana debe devolverse en inglés, caso
contrario en español. 

Cree una función para resolver este tema.
Nota: SET @DIA = datepart(weekday,@fecha)
Devuelve en la variable @DIA el nro. de día de la semana , comenzando con 1 Domingo hasta 7
Sábado.
*/

CREATE FUNCTION dia_de_la_semana (@estado CHAR(2), @fecha DATE) RETURNS VARCHAR(15) AS
BEGIN
	DECLARE @DIA INT;
	DECLARE @RETURNED VARCHAR(15);
	SET @DIA = DATEPART(weekday, @fecha);

	IF @estado = 'CA'
	BEGIN
		SET @RETURNED = 
			CASE @DIA
				WHEN 1 THEN 'Monday'
				WHEN 2 THEN 'Tuesday'
				WHEN 3 THEN 'Wedenesday'
				WHEN 4 THEN 'Thursday'
				WHEN 5 THEN 'Friday'
				WHEN 6 THEN 'Saturday'
				WHEN 7 THEN 'Sunday'
		END
	END
	ELSE
	BEGIN
		SET @RETURNED = 
			CASE @DIA
				WHEN 1 THEN 'Lunes'
				WHEN 2 THEN 'Martes'
				WHEN 3 THEN 'Miércoles'
				WHEN 4 THEN 'Jueves'
				WHEN 5 THEN 'Viernes'
				WHEN 6 THEN 'Sábado'
				WHEN 7 THEN 'Domingo'
		END
	END 

	RETURN @RETURNED
END
GO


SELECT order_num, order_date, dbo.dia_de_la_semana(state, order_date) FROM orders JOIN customer c ON orders.customer_num = c.customer_num WHERE paid_date IS NULL 
GO

/*Escribir una sentencia SELECT para los clientes que han tenido órdenes en al menos 2 meses
diferentes, los dos meses con las órdenes con el mayor ship_charge.
Se debe devolver una fila por cada cliente que cumpla esa condición.*/

DROP FUNCTION dbo.datos_del_mes
GO
CREATE FUNCTION datos_del_mes(@ORDER INT, @CUSTOMER_NUM INT) RETURNS VARCHAR(100) AS
BEGIN
  DECLARE 
    @RETORNO VARCHAR(100),
    @MES VARCHAR(4),
    @ANIO VARCHAR(4),
    @TOTAL VARCHAR(10)

    IF (@ORDER = 1)
    BEGIN
      SELECT TOP 1 @MES = MONTH(ship_date), @ANIO = YEAR(ship_date), @TOTAL = ship_charge
      FROM orders
      WHERE customer_num = @CUSTOMER_NUM
      ORDER BY ship_charge DESC
    END
    ELSE
    BEGIN
      SELECT TOP 1 @MES = mes, @ANIO = anio, @TOTAL = ship_charge 
      FROM (SELECT TOP 2 MONTH(order_date) mes, YEAR(order_date) anio, ship_charge
        FROM orders
        WHERE customer_num = @CUSTOMER_NUM
        ORDER BY ship_charge DESC) t1
      ORDER BY ship_charge ASC
    END

    SET @RETORNO = @ANIO + '-' + @MES + ' - TOTAL: ' + @TOTAL

  RETURN @RETORNO
END
GO

SELECT DISTINCT customer_num, dbo.datos_del_mes(1, customer_num) mesMaximo, dbo.datos_del_mes(2, customer_num) segundoMes
FROM orders o1
WHERE EXISTS (SELECT 1 FROM orders o2 WHERE o2.customer_num = o1.customer_num AND MONTH(o1.order_date) > MONTH(o2.order_date))

/*
Escribir un Select que devuelva para cada producto de la tabla Products que exista en la tabla
Catalog todos sus fabricantes separados entre sí por el caracter pipe (|). Utilizar una función para
resolver parte de la consulta. Ejemplo de la salida
*/

DROP FUNCTION dbo.fabricantes_por_producto
GO
CREATE FUNCTION fabricantes_por_producto (@stock_num SMALLINT) RETURNS VARCHAR(20) AS
BEGIN

	DECLARE @RETORNO VARCHAR(20);
	DECLARE @manu_code CHAR(3);

	DECLARE fabricantes CURSOR FOR SELECT manu_code FROM products WHERE stock_num = @stock_num
	OPEN fabricantes;
	FETCH NEXT FROM fabricantes INTO @manu_code
	SET @RETORNO = @manu_code
	FETCH NEXT FROM fabricantes INTO @manu_code
	WHILE @@FETCH_STATUS = 0
	BEGIN
		
		SET @RETORNO = @RETORNO + ' | ' + @manu_code


		FETCH NEXT FROM fabricantes INTO @manu_code
	END
	CLOSE fabricantes;
	DEALLOCATE fabricantes;

	RETURN @RETORNO;
END
GO 

SELECT DISTINCT stock_num, dbo.fabricantes_por_producto(stock_num) FROM products WHERE stock_num IN (SELECT stock_num FROM catalog)

