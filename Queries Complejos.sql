/* Pr�ctica de Complejos */

/*
1) Crear una vista que devuelva:

a) C�digo y Nombre (manu_code,manu_name) de los fabricante, posean o no productos
(en tabla Products), cantidad de productos que fabrican (cant_producto) y la fecha de
la �ltima OC que contenga un producto suyo (ult_fecha_orden).

- De los fabricantes que fabriquen productos s�lo se podr�n mostrar los que
fabriquen m�s de 2 productos.

- No se permite utilizar funciones definidas por usuario, ni tablas temporales, ni
UNION.

b) Realizar una consulta sobre la vista que devuelva manu_code, manu_name,
cant_producto y si el campo ult_fecha_orden posee un NULL informar �No Posee
�rdenes� si no posee NULL informar el valor de dicho campo.

- No se puede utilizar UNION para el SELECT.

*/

DROP VIEW vista_fabricantes
GO
CREATE VIEW vista_fabricantes AS
	SELECT m.manu_code, m.manu_name, COUNT(DISTINCT p.stock_num) AS cant_productos, MAX(o1.order_date) AS ultima_orden
	FROM manufact m LEFT JOIN products p ON p.manu_code = m.manu_code
					LEFT JOIN items i1 ON i1.manu_code = m.manu_code AND i1.stock_num = p.stock_num
					LEFT JOIN orders o1 ON o1.order_num = i1.order_num
	GROUP BY m.manu_code, m.manu_name
	HAVING COUNT(DISTINCT p.stock_num) > 2 OR COUNT(DISTINCT p.stock_num) = 0
GO

SELECT manu_code, manu_name, cant_productos, COALESCE(CAST(ultima_orden AS VARCHAR) , 'No posee �rdenes') FROM vista_fabricantes


/*
Desarrollar una consulta ABC de fabricantes que:

Liste el c�digo y nombre del fabricante, la cantidad de �rdenes de compra que contengan
sus productos y el monto total de los productos vendidos.

Mostrar s�lo los fabricantes cuyo c�digo comience con A � con N y posea 3 letras, y los
productos cuya descripci�n posean el string �tennis� � el string �ball� en cualquier parte del
nombre y cuyo monto total vendido sea mayor que el total de ventas promedio de todos
los fabricantes (Cantidad * precio unitario / Cantidad de fabricantes que vendieron sus
productos).

Mostrar los registros ordenados por monto total vendido de mayor a menor.
*/

SELECT m.manu_code, m.manu_name, COUNT(DISTINCT i1.order_num) AS cantidad_ventas, SUM(i1.quantity * i1.unit_price) as monto_total
	FROM manufact m LEFT JOIN items i1 ON i1.manu_code = m.manu_code
						 JOIN product_types pt ON pt.stock_num = i1.stock_num
	WHERE m.manu_code LIKE '[AN]__' AND (pt.description LIKE '%tennis%' OR pt.description LIKE '%ball%')
	GROUP BY m.manu_code, m.manu_name
	HAVING SUM(i1.quantity * i1.unit_price) > 
		(SELECT SUM(i2.quantity * i2.unit_price)/COUNT(DISTINCT i2.manu_code) FROM items i2) 
	ORDER BY SUM(i1.quantity * i1.unit_price) DESC


/*
Crear una vista que devuelva

Para cada cliente mostrar (customer_num, lname, company), cantidad de �rdenes
de compra, fecha de su �ltima OC, monto total comprado y el total general
comprado por todos los clientes.

De los clientes que posean �rdenes s�lo se podr�n mostrar los clientes que tengan
alguna orden que posea productos que son fabricados por m�s de dos fabricantes y
que tengan al menos 3 �rdenes de compra.
Ordenar el reporte de tal forma que primero aparezcan los clientes que tengan
�rdenes por cantidad de �rdenes descendente y luego los clientes que no tengan
�rdenes.

No se permite utilizar funciones, ni tablas temporales.
*/

DROP VIEW vista_clientes
CREATE VIEW vista_clientes AS
	SELECT 1 AS ord, c1.customer_num, c1.lname, c1.company, COUNT(DISTINCT o1.order_num) AS cant_ordenes, SUM(i1.unit_price * i1.quantity) as monto_total,
		(SELECT SUM(i2.unit_price * i2.quantity) FROM items i2) AS total_general,
		MAX(o1.order_date) as ultima_orden
	FROM customer c1 JOIN orders o1 ON o1.customer_num = c1.customer_num JOIN items i1 ON i1.order_num = o1.order_num
	WHERE EXISTS (SELECT 1 FROM orders o3 JOIN items i3 ON o3.order_num = i3.order_num WHERE o3.customer_num = c1.customer_num HAVING COUNT(DISTINCT i3.manu_code) > 2)
	GROUP BY c1.customer_num, c1.lname, c1.company
	HAVING COUNT(DISTINCT o1.order_num) >= 3
	UNION 
	SELECT 2 AS ord, c1.customer_num, c1.lname, c1.company, 0 AS cant_ordenes, (SELECT SUM(unit_price*quantity) FROM items) AS monto_total,
		(SELECT SUM(i2.unit_price * i2.quantity) FROM items i2) as total_general,
		null AS ultima_orden
	FROM customer c1 
	WHERE c1.customer_num NOT IN (SELECT customer_num FROM orders)
	GROUP BY c1.customer_num, c1.lname, c1.company
	

SELECT * FROM vista_clientes ORDER BY 1, 5

/*
Crear una consulta que devuelva los 5 primeros estados y el tipo de producto
(description) m�s comprado en ese estado (state) seg�n la cantidad vendida del tipo
de producto.

Ordenarlo por la cantidad vendida en forma descendente.
Nota: No se permite utilizar funciones, ni tablas temporales.
*/

SELECT DISTINCT TOP 5 c1.state, 
	(SELECT TOP 1 pt2.description FROM orders o2 JOIN items i2 ON o2.order_num = i2.order_num
											   JOIN product_types pt2 ON i2.stock_num = pt2.stock_num
											   JOIN customer c2 ON c2.customer_num = o2.customer_num
											   WHERE c1.state = c2.state
											   GROUP BY pt2.description
											   ORDER BY SUM(i2.quantity) DESC)
FROM customer c1


/*
Listar los customers que no posean �rdenes de compra y aquellos cuyas �ltimas
�rdenes de compra superen el promedio de todas las anteriores.
Mostrar customer_num, fname, lname, paid_date y el monto total de la orden que
supere el promedio de las anteriores. Ordenar el resultado por monto total en forma
descendiente.
*/

SELECT 2, c1.customer_num, c1.fname, c1.lname, null AS paid_date, 0 AS monto_total FROM customer c1 WHERE NOT EXISTS (SELECT o1.customer_num FROM orders o1 WHERE c1.customer_num = o1.customer_num)
UNION
SELECT 1, c1.customer_num, c1.fname, c1.lname, COALESCE(CAST(o1.paid_date AS VARCHAR), 'No pagado'), SUM(i1.quantity * i1.unit_price)
FROM customer c1 JOIN orders o1 ON c1.customer_num = o1.customer_num JOIN items i1 ON i1.order_num = o1.order_num
GROUP BY c1.customer_num, c1.fname, c1.lname, o1.paid_date, o1.order_date, o1.order_num
HAVING o1.order_date = MAX(o1.order_date) AND 
	SUM(i1.quantity * i1.unit_price) > (SELECT SUM(i2.quantity * i2.unit_price) / COUNT(DISTINCT o2.order_num) FROM items i2 JOIN orders o2 ON o2.order_num = i2.order_num 
	WHERE o2.customer_num = c1.customer_num AND o2.order_num != o1.order_num)
ORDER BY 1, 6 DESC

/*
Se desean saber los fabricantes que vendieron mayor cantidad de un mismo
producto que la competencia seg�n la cantidad vendida. Tener en cuenta que puede
existir un producto que no sea fabricado por ning�n otro fabricante y que puede
haber varios fabricantes que tengan la misma cantidad m�xima vendida.

Mostrar el c�digo del producto, descripci�n del producto, c�digo de fabricante,
cantidad vendida, monto total vendido. Ordenar el resultado c�digo de producto, por
cantidad total vendida y por monto total, ambos en forma decreciente.
Nota: No se permiten utilizar funciones, ni tablas temporales.*/

SELECT pt.stock_num, pt.description, p.manu_code, (
	SELECT SUM(i2.quantity) FROM items i2 WHERE i2.stock_num = pt.stock_num AND i2.manu_code = p.manu_code
) AS cantidad_vendida, (
	SELECT SUM(i2.quantity * i2.unit_price) FROM items i2 WHERE i2.stock_num = pt.stock_num AND i2.manu_code = p.manu_code 
) AS monto_total 
FROM product_types pt JOIN products p ON p.stock_num = pt.stock_num
WHERE (SELECT SUM(i2.quantity) FROM items i2 WHERE i2.stock_num = pt.stock_num AND i2.manu_code = p.manu_code) >= 
	COALESCE((SELECT TOP 1 SUM(i2.quantity) FROM items i2 WHERE i2.stock_num = pt.stock_num AND i2.manu_code != p.manu_code ORDER BY SUM(i2.quantity) DESC), 0)


/*
Listar N�mero de Cliente, apellido y nombre, Total Comprado por el cliente �Total del Cliente�,
Cantidad de �rdenes de Compra del cliente �OCs del Cliente� y la Cant. de �rdenes de Compra
solicitadas por todos los clientes �Cant. Total OC�, 
de todos aquellos clientes cuyo promedio de compra
por Orden supere al promedio de �rdenes de compra general, tengan al menos 2 �rdenes y cuyo
zipcode comience con 94.
*/

SELECT c1.customer_num, lname, fname, (
	SELECT SUM(i1.quantity * i1.unit_price) FROM items i1 JOIN orders o1 ON o1.order_num = i1.order_num WHERE o1.customer_num = c1.customer_num
) AS 'Total comprado por el cliente',
COUNT(DISTINCT o1.order_num) AS 'Cantidad OC',
(SELECT COUNT(order_num) FROM orders) AS 'Total OC'
FROM customer c1 JOIN orders o1 ON o1.customer_num = c1.customer_num
WHERE c1.zipcode LIKE '94%'
GROUP BY c1.customer_num, lname, fname
HAVING COUNT(DISTINCT o1.order_num) >= 2 AND 
(SELECT SUM(i2.quantity * i2.unit_price) / COUNT(DISTINCT o2.order_num) FROM items i2 JOIN orders o2 ON o2.order_num = i2.order_num WHERE o2.customer_num = c1.customer_num) >
(SELECT SUM(i2.quantity * i2.unit_price) / COUNT(DISTINCT i2.order_num) FROM items i2)

/*
Se requiere crear una tabla temporal #ABC_Productos un ABC de Productos ordenado por cantidad
de venta en u$, los datos solicitados son:
Nro. de Stock, C�digo de fabricante, descripci�n del producto, Nombre de Fabricante, Total del producto
pedido 'u$ por Producto', Cant. de producto pedido 'Unid. por Producto', para los productos que
pertenezcan a fabricantes que fabriquen al menos 10 productos diferentes.
*/

DROP TABLE #ABC_Productos
SELECT i1.stock_num, i1.manu_code, pt.description, m.manu_name, SUM(i1.quantity * i1.unit_price) AS 'u$ por Producto', SUM(i1.quantity) AS 'Unid. por Producto'
INTO #ABC_Productos FROM items i1 JOIN product_types pt ON i1.stock_num = pt.stock_num
								  JOIN manufact m ON m.manu_code = i1.manu_code
WHERE i1.manu_code IN (SELECT manu_code FROM products GROUP BY manu_code HAVING COUNT(DISTINCT stock_num) >= 10)
GROUP BY i1.stock_num, i1.manu_code, pt.description, m.manu_name


SELECT * FROM #ABC_Productos ORDER BY 5 


/*
En funci�n a la tabla temporal generada en el punto 2, obtener un listado que detalle para cada tipo
de producto existente en #ABC_Producto, la descripci�n del producto, el mes en el que fue solicitado, el
cliente que lo solicit� (en formato 'Apellido, Nombre'), la cantidad de �rdenes de compra 'Cant OC', 
la cantidad del producto solicitado 'Unid Producto' y el total en u$ solicitado 'u$ Producto'.

Mostrar s�lo aquellos clientes que vivan en el estado con mayor cantidad de clientes, ordenado por
mes y descripci�n del tipo de producto en forma ascendente y por cantidad de productos en
forma descendente.
*/

SELECT description, MONTH(o.order_date) AS mes_solicitado, c1.lname + ', ' + c1.fname AS cliente_que_lo_solicito, COUNT(DISTINCT o.order_num) AS 'Cant OC', 
	SUM(i1.quantity) AS 'Unid Producto', SUM(i1.quantity * i1.unit_price) AS 'u$ Producto' 
FROM #ABC_Productos abc JOIN items i1 ON i1.stock_num = abc.stock_num AND i1.manu_code = abc.manu_code
						JOIN orders o ON o.order_num = i1.order_num
						JOIN customer c1 ON c1.customer_num = o.customer_num
WHERE c1.state = (SELECT TOP 1 state FROM customer GROUP BY state ORDER BY COUNT(customer_num) DESC)
GROUP BY description, MONTH(o.order_date), c1.lname + ', ' + c1.fname
ORDER BY MONTH(o.order_date), description ASC, SUM(i1.quantity) DESC

/*
Dado los productos con nro de stock 5, 6 y 9 del fabricante 'ANZ' listar de a pares los clientes que
hayan solicitado el mismo producto, siempre y cuando, el primer cliente haya solicitado m�s cantidad
del producto que el 2do cliente.
Se deber� informar nro de stock, c�digo de fabricante, Nro de Cliente y Apellido del primer cliente, Nro
de cliente y apellido del 2do cliente ordenado por stock_num y manu_code
*/


SELECT DISTINCT i1.stock_num, i1.manu_code, c1.lname + ', ' + c1.fname AS cliente1, c2.lname + ', ' + c2.fname AS cliente2
FROM items i1 JOIN orders o1 ON i1.order_num = o1.order_num
			  JOIN customer c1 ON o1.customer_num = c1.customer_num
			  JOIN items i2 ON i2.stock_num = i1.stock_num AND i1.manu_code = i2.manu_code AND i1.order_num <> i2.order_num
			  JOIN orders o2 ON o2.order_num = i2.order_num
			  JOIN customer c2 ON o2.customer_num = c2.customer_num
WHERE c1.customer_num <> c2.customer_num AND i1.stock_num IN (5,6,9) AND i1.manu_code = 'ANZ' AND
(
(SELECT SUM(i3.quantity) FROM items i3 JOIN orders o3 ON i3.order_num = o3.order_num WHERE i3.stock_num = i1.stock_num AND i3.manu_code = i1.manu_code AND o3.customer_num = c1.customer_num) > 
(SELECT SUM(i3.quantity) FROM items i3 JOIN orders o3 ON i3.order_num = o3.order_num WHERE i3.stock_num = i1.stock_num AND i3.manu_code = i1.manu_code AND o3.customer_num = c2.customer_num)
) 
ORDER BY 1,2

/*
Se requiere realizar una consulta que devuelva en una fila la siguiente informaci�n: 
La mayor cantidad de �rdenes de compra de un cliente, 
Mayor total en u$ solicitado por un cliente
la mayor cantidad de productos solicitados por un cliente, 
la menor cantidad de �rdenes de compra de un cliente, 
el menor total en u$ solicitado por un cliente,
la menor cantidad de productos solicitados por un cliente,

Los valores m�ximos y m�nimos solicitados deber�n corresponderse a los datos de clientes seg�n todas
las �rdenes existentes, sin importar a que cliente corresponda el dato.
*/

SELECT MAX(cantOrd) 'Mayor cantidad de OC', 
	   MAX(sumPrecio) 'Mayor total en u$ solicitado por un cliente',
	   MAX(cantItem) 'La mayor cantidad de productos solicitados por un cliente', 
	   MIN(cantOrd) 'Menor cantidad de OC', 
	   MIN(sumPrecio) 'Menor total en u$ solicitado por un cliente', 
	   MIN(cantItem) 'La menor cantidad de productos solicitados por un cliente'
FROM (SELECT o.customer_num, COUNT(DISTINCT o.order_num) cantOrd, 
							 SUM(i.quantity * i.unit_price) sumPrecio, 
							 SUM(i.quantity) cantItem
            FROM orders o JOIN items i ON i.order_num = o.order_num
            GROUP BY o.customer_num) alias

/*
Seleccionar los n�mero de cliente, n�mero de orden y monto total de la orden de aquellos clientes del
estado California(CA) que posean 4 o m�s �rdenes de compra emitidas en el 2015. Adem�s las �rdenes
mostradas deber�n cumplir con la salvedad que la cantidad de l�neas de �tems de esas �rdenes debe ser
mayor a la cantidad de l�neas de �tems de la orden de compra con mayor cantidad de �tems del estado AZ
en el mismo a�o.
*/

SELECT o1.customer_num, o1.order_num, SUM(i1.quantity * i1.unit_price) AS 'Monto Total'
FROM orders o1 JOIN items i1 ON o1.order_num = i1.order_num
			   JOIN customer c1 ON c1.customer_num = o1.customer_num
WHERE c1.state = 'CA' AND o1.customer_num IN (

	SELECT customer_num FROM orders o2
	WHERE YEAR(o2.order_date) = 2015
	GROUP BY o2.customer_num
	HAVING COUNT(*) >= 4
)
GROUP BY o1.customer_num, o1.order_num
HAVING COUNT(i1.item_num) > (SELECT TOP 1 COUNT(i3.item_num) FROM items i3 
																JOIN orders o3 ON i3.order_num = o3.order_num 
																JOIN customer c3 ON c3.customer_num = o3.customer_num
																WHERE c3.state = 'AZ' AND YEAR(o3.order_date) = 2015
																GROUP BY i3.order_num
																ORDER BY COUNT(i3.item_num) DESC)


/*
Se requiere listar para el Estado de California el par de clientes que sean los que suman el mayor
monto en d�lares en �rdenes de compra, con el formato de salida:
'C�digo Estado', 'Descripci�n Estado', 'Apellido, Nombre', 'Apellido, Nombre', 'Total Solicitado' (*)

(*) El total solicitado contendr� la suma de los dos clientes.
*/

SELECT TOP 1 s.state 'C�digo Estado', s.sname 'Descripci�n Estado', c1.lname + ', ' + c1.fname AS cliente1, c2.lname + ', ' + c2.fname AS cliente2, 
(c2.Total + (SELECT SUM(i.quantity * i.unit_price) AS total
			FROM items i JOIN orders o ON o.order_num = i.order_num AND o.customer_num = c1.customer_num GROUP BY o.customer_num)) AS 'Total Solicitado'

FROM state s JOIN customer c1 ON c1.state = s.state
			 JOIN (SELECT o2.customer_num, state, fname, lname, SUM(i3.quantity * i3.unit_price) as 'Total'
					FROM customer c3 JOIN orders o2 ON o2.customer_num = c3.customer_num 
									 JOIN items i3 ON i3.order_num = o2.order_num
									 GROUP BY state, fname, lname, o2.customer_num) c2 ON c2.state = c1.state AND c1.customer_num > c2.customer_num
WHERE s.state = 'CA'
ORDER BY 5 DESC

/*
Se observa que no se cuenta con stock suficiente para las �ltimas 5 �rdenes de compra emitidas que
contengan productos del fabricante 'ANZ'. 

Por lo que se decide asignarle productos en stock a la orden
del cliente que m�s cantidad de productos del fabricante 'ANZ' nos haya comprado.

Se solicita listar el n�mero de orden de compra, n�mero de cliente, fecha de la orden y una fecha de
orden �modificada� a la cual se le suma el lead_time del fabricante m�s 1 d�a por preparaci�n del pedido
a aquellos clientes que no son prioritarios.
 
Para aquellos clientes a los que les entregamos los productos en stock, la �fecha modificada� deber� estar en NULL.
Listar toda la informaci�n ordenada por �fecha modificada�
*/




SELECT DISTINCT TOP 1 order_num, customer_num, order_date, null AS 'Fecha Modificada'
FROM (
	SELECT DISTINCT TOP 5 o1.order_num, i1.manu_code, o1.customer_num, o1.order_date, SUM(i1.quantity) AS 'cantidad_comprada'
	FROM orders o1 JOIN items i1 ON o1.order_num = i1.order_num 
	WHERE i1.manu_code = 'ANZ'
	GROUP BY o1.order_num, i1.manu_code, o1.customer_num, o1.order_date
	ORDER BY SUM(i1.quantity) DESC
) a JOIN manufact m ON m.manu_code = a.manu_code
UNION SELECT order_num, customer_num, order_date, [Fecha Modificada]  FROM 
	(SELECT DISTINCT TOP 4 cantidad_comprada, order_num, customer_num, order_date,order_date + m.lead_time + 1 AS 'Fecha Modificada'
	FROM (
		SELECT DISTINCT TOP 5 o1.order_num, i1.manu_code, o1.customer_num, o1.order_date, SUM(i1.quantity) AS 'cantidad_comprada'
		FROM orders o1 JOIN items i1 ON o1.order_num = i1.order_num 
		WHERE i1.manu_code = 'ANZ'
		GROUP BY o1.order_num, i1.manu_code, o1.customer_num, o1.order_date
		ORDER BY o1.order_date DESC
	) a JOIN manufact m ON m.manu_code = a.manu_code
	ORDER BY cantidad_comprada ASC
) b 

/*
Listar el numero, nombre, apellido, estado, cantidad de ordenes y monto total comprado de los
clientes que no sean del estado de Wisconsin y cuyo monto total comprado sea mayor que el monto
total promedio de �rdenes de compra.
*/


SELECT c1.customer_num, c1.fname, c1.lname, c1.state, COUNT(DISTINCT o1.order_num) AS 'Cantidad de Ordenes' , SUM(i1.quantity * i1.unit_price) AS 'Monto Total'
FROM customer c1 JOIN orders o1 ON o1.customer_num = c1.customer_num
				 JOIN items i1 ON i1.order_num = o1.order_num
WHERE c1.state <> 'WI'
GROUP BY c1.customer_num, c1.fname, c1.lname, c1.state
HAVING SUM(i1.quantity * i1.unit_price) > (SELECT SUM(i2.quantity * i2.unit_price) / COUNT(DISTINCT i2.order_num) FROM items i2)

































													 
	


