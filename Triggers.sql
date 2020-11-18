/*
Dada la tabla Products de la base de datos stores7 se requiere crear una tabla
Products_historia_precios y crear un trigger que registre los cambios de precios que se hayan
producido en la tabla Products.

Tabla Products_historia_precios
- Stock_historia_Id Identity (PK)
- Stock_num
- Manu_code
- fechaHora (grabar fecha y hora del evento)
- usuario (grabar usuario que realiza el cambio de precios)
- unit_price_old
- unit_price_new
- estado char default �A� check (estado IN (�A�,�I�)

*/
CREATE TABLE productos_historia_precios
(

	stock_historia_id INT PRIMARY KEY IDENTITY(1,1),
	stock_num INT,
	manu_code CHAR(3),
	fechaHora DATE DEFAULT GETDATE(),
	usuario VARCHAR(15) DEFAULT CURRENT_USER,
	unit_price_old DECIMAL(6,2),
	unit_price_new DECIMAL(6,2),
	estado CHAR DEFAULT 'A' CHECK (estado IN ('A','I'))
);
GO

CREATE TRIGGER registrar_cambios_productos ON products AFTER UPDATE AS
BEGIN

	DECLARE @stock_num INT, 
			@manu_code CHAR(3),
			@unit_price_old DECIMAL(6,2),
			@unit_price_new DECIMAL(6,2);

	DECLARE updated_products CURSOR FOR (SELECT @stock_num = stock_num, @manu_code = manu_code, @unit_price_new = unit_price
	FROM inserted)
	OPEN updated_products
	FETCH NEXT FROM updated_products INTO @stock_num, @manu_code,@unit_price_new

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @unit_price_old = unit_price
		FROM deleted
		WHERE stock_num = @stock_num

		INSERT INTO productos_historia_precios
			(stock_num, manu_code, unit_price_old, unit_price_new)
		VALUES
			(@stock_num, @manu_code, @unit_price_old, @unit_price_new)

		FETCH NEXT FROM updated_products INTO @stock_num, @manu_code,@unit_price_new
	END

	CLOSE updated_products
	DEALLOCATE update_products


END
GO

/*
Crear un trigger sobre la tabla Products_historia_precios que ante un delete sobre la misma
realice en su lugar un update del campo estado de �A� a �I� (inactivo).
*/

CREATE TRIGGER delete_product_historia_precios ON productos_historia_precios INSTEAD OF DELETE AS
BEGIN

	UPDATE productos_historia_precios SET estado = 'I' WHERE stock_historia_id IN (SELECT stock_historia_id
	FROM deleted)

END
GO


/*
Validar que s�lo se puedan hacer inserts en la tabla Products en un horario entre las 8:00 AM y
8:00 PM. En caso contrario enviar un error por pantalla.
*/

CREATE TRIGGER horarios_insert_products ON products INSTEAD OF INSERT AS
BEGIN

	IF DATEPART(HOUR, GETDATE()) BETWEEN 8 AND 20
		THROW 50001, 'No puede trabajar a estas horas', 1

	INSERT INTO products
		(stock_num, manu_code, unit_price, unit_code)
	SELECT stock_num, manu_code, unit_price, unit_code
	FROM inserted

END
GO

/*
Crear un trigger que ante un borrado sobre la tabla ORDERS realice un borrado en cascada
sobre la tabla ITEMS, validando que s�lo se borre 1 orden de compra.
Si detecta que est�n queriendo borrar m�s de una orden de compra, informar� un error y
abortar� la operaci�n.
*/

CREATE TRIGGER borrar_orden ON orders INSTEAD OF DELETE AS
BEGIN

	IF (SELECT COUNT(*)
	FROM deleted) > 1
		THROW 50001, 'Est� intentando borrar m�s de una orden de compra', 1;

	DECLARE @order_num INT;

	SELECT @order_num = order_num
	FROM deleted

	DELETE FROM items WHERE order_num = @order_num
	DELETE FROM orders WHERE order_num = @order_num

END
GO

/*
Crear un trigger de insert sobre la tabla �tems que al detectar que el c�digo de fabricante
(manu_code) del producto a comprar no existe en la tabla manufact, inserte una fila en dicha
tabla con el manu_code ingresado, en el campo manu_name la descripci�n �Manu Orden 999�
donde 999 corresponde al nro. de la orden de compra a la que pertenece el �tem y en el campo
lead_time el valor 1.
*/


CREATE TRIGGER insert_item ON items INSTEAD OF INSERT AS
BEGIN

	DECLARE @manu_code CHAR(3);
	DECLARE @order_num INT;

	DECLARE inserted_items CURSOR FOR SELECT manu_code, order_num
	FROM inserted;
	OPEN inserted_items;

	FETCH NEXT FROM inserted_items INTO @manu_code, @order_num
	WHILE @@FETCH_STATUS = 0
	BEGIN

		IF NOT EXISTS (SELECT 1
		FROM manufact
		WHERE manu_code = @manu_code)
			INSERT INTO manufact
			(manu_code, manu_name, lead_time)
		VALUES
			(@manu_code, 'Manu Orden ' + CAST(@order_num AS VARCHAR), 1)

		FETCH NEXT FROM inserted_items INTO @manu_code, @order_num
	END

	CLOSE inserted_items
	DEALLOCATE inserted_items

	INSERT INTO items
		(item_num, order_num, stock_num, manu_code, quantity, unit_price)
	SELECT item_num, order_num, stock_num, manu_code, quantity, unit_price
	FROM inserted

END
GO


/*
Crear tres triggers (Insert, Update y Delete) sobre la tabla Products para replicar todas las
operaciones en la tabla Products _replica, la misma deber� tener la misma estructura de la tabla
Products.
*/


CREATE TABLE products_replica
(
	stock_num INT,
	manu_code CHAR(3),
	unit_price DECIMAL(6,2),
	unit_code INT
);
GO

CREATE TRIGGER insert_product ON products AFTER INSERT AS
BEGIN

	INSERT INTO products_replica
	SELECT *
	FROM inserted

END
GO

CREATE TRIGGER delete_product ON products AFTER DELETE AS
BEGIN

	DECLARE @stock_num INT;
	DECLARE @manu_code CHAR(3);

	DECLARE deleted_products CURSOR FOR SELECT stock_num, manu_code
	FROM deleted;
	OPEN deleted_products;
	FETCH NEXT FROM deleted_products INTO @stock_num, @manu_code;
	WHILE @@FETCH_STATUS = 0
	BEGIN
		DELETE FROM products_replica WHERE stock_num = @stock_num AND manu_code = @manu_code;
		FETCH NEXT FROM deleted_products INTO @stock_num, @manu_code;
	END

	CLOSE deleted_products;
	DEALLOCATE deleted_products;
END
GO


CREATE TRIGGER delete_product ON products AFTER DELETE AS
BEGIN
	DELETE pr FROM products_replica pr JOIN deleted d ON pr.stock_num = d.stock_num AND pr.manu_code = d.manu_code;
END
GO

CREATE TRIGGER update_product ON products AFTER UPDATE AS
BEGIN

	DECLARE @stock_num INT;
	DECLARE @manu_code CHAR(3);
	DECLARE @unit_price DECIMAL(6,2);
	DECLARE @unit_code INT;

	DECLARE inserted_products CURSOR FOR SELECT stock_num, manu_code, unit_price, unit_code
	FROM inserted;
	OPEN inserted_products;
	FETCH NEXT FROM inserted_products INTO @stock_num, @manu_code, @unit_price, @unit_code;
	WHILE @@FETCH_STATUS = 0
	BEGIN
		UPDATE products_replica SET unit_price = @unit_price, unit_code = @unit_code WHERE stock_num = @stock_num AND @manu_code = manu_code;
		FETCH NEXT FROM inserted_products INTO @stock_num, @manu_code, @unit_price, @unit_code;
	END

	CLOSE inserted_products;
	DEALLOCATE inserted_products;

END
GO

CREATE TRIGGER update_product ON products AFTER UPDATE AS
BEGIN

	UPDATE pr SET pr.unit_price = i.unit_price, pr.unit_code = i.unit_code
		FROM Products_replica pr JOIN inserted i ON (pr.stock_num = i.stock_num AND pr.manu_code = i.manu_code)

END
GO

/*
Crear la vista Productos_x_fabricante que tenga los siguientes atributos:
Stock_num, description, manu_code, manu_name, unit_price
Crear un trigger de Insert sobre la vista anterior que ante un insert, inserte una fila en la tabla
Products, pero si el manu_code no existe en la tabla manufact, inserte adem�s una fila en dicha
tabla con el campo lead_time en 1.
*/

CREATE VIEW pxf
AS
	SELECT p.stock_num, pt.description, p.manu_code, m.manu_name, unit_price
	FROM products p
		JOIN product_types pt ON pt.stock_num = p.stock_num
		JOIN manufact m ON m.manu_code = p.manu_code;
GO

CREATE TRIGGER insert_pxf ON pxf INSTEAD OF INSERT AS
BEGIN

	DECLARE @stock_num INT, @desc VARCHAR(50), @manu_code CHAR(3), @manu_name VARCHAR(15), @unit_price DECIMAL(6,2);
	DECLARE inserted_on_view CURSOR FOR SELECT stock_num, description, manu_code, manu_name, unit_price
	FROM inserted
	OPEN inserted_on_view;
	FETCH NEXT FROM inserted_on_view INTO @stock_num, @desc, @manu_code, @manu_name, @unit_price;
	WHILE @@FETCH_STATUS = 0
	BEGIN

		IF NOT EXISTS (SELECT 1
		FROM manufact
		WHERE manu_code = @manu_code)
			INSERT INTO manufact
			(manu_code, manu_name, lead_time)
		VALUES
			(@manu_code, @manu_name, 1)

		INSERT INTO products
			(stock_num, manu_code, unit_price)
		VALUES
			(@stock_num, @manu_code, @unit_price)

		FETCH NEXT FROM inserted_on_view INTO @stock_num, @desc, @manu_code, @manu_name, @unit_price;
	END

	CLOSE inserted_on_view;
	DEALLOCATE inserted_on_view;

END
GO
/*
1. Se pide: Crear un trigger que valide que ante un insert de una o m�s filas en la tabla
�tems, realice la siguiente validaci�n:

- Si la orden de compra a la que pertenecen los �tems ingresados corresponde a
clientes del estado de California, se deber� validar que estas �rdenes puedan tener
como m�ximo 5 registros en la tabla �tem.

- Si se insertan m�s �tems de los definidos, el resto de los �tems se deber�n insertar
en la tabla items_error la cual contiene la misma estructura que la tabla �tems m�s
un atributo fecha que deber� contener la fecha del d�a en que se trat� de insertar.

Ej. Si la Orden de Compra tiene 3 items y se realiza un insert masivo de 3 �tems m�s, el
trigger deber� insertar los 2 primeros en la tabla �tems y el restante en la tabla �tems_error.
Supuesto: En el caso de un insert masivo los items son de la misma orden.*/

CREATE TABLE items_error
(

	item_num INT,
	order_num INT,
	stock_num INT,
	manu_code CHAR(3),
	quantity INT,
	unit_price DECIMAL(6,2),
	fecha DATE DEFAULT GETDATE(),

);
GO

CREATE TRIGGER insert_on_items ON items INSTEAD OF INSERT AS
BEGIN

	DECLARE @item_num INT;
	DECLARE @order_num INT;
	DECLARE @stock_num INT;
	DECLARE @manu_code CHAR(3);
	DECLARE @quantity INT;
	DECLARE @unit_price DECIMAL(6,2);

	DECLARE inserted_items CURSOR FOR SELECT item_num, order_num, stock_num, manu_code, quantity, unit_price
	FROM inserted;
	FETCH NEXT FROM inserted_items INTO @item_num, @order_num, @stock_num, @manu_code, @quantity, @unit_price;
	WHILE @@FETCH_STATUS = 0
	BEGIN

		IF (SELECT state
		FROM orders o JOIN customer c ON c.customer_num = o.customer_num
		WHERE o.order_num = @order_num) = 'CA'
			IF(SELECT COUNT(DISTINCT item_num)
		FROM items
		WHERE order_num = @order_num) > 5
				INSERT INTO items_error
			(item_num, order_num, stock_num, manu_code, quantity, unit_price)
		VALUES(@item_num, @order_num, @stock_num, @manu_code, @quantity, @unit_price)
			ELSE
				INSERT INTO items
			(item_num, order_num, stock_num, manu_code, quantity, unit_price)
		VALUES(@item_num, @order_num, @stock_num, @manu_code, @quantity, @unit_price)
		ELSE
			INSERT INTO items
			(item_num, order_num, stock_num, manu_code, quantity, unit_price)
		VALUES(@item_num, @order_num, @stock_num, @manu_code, @quantity, @unit_price)

		FETCH NEXT FROM inserted_items INTO @item_num, @order_num, @stock_num, @manu_code, @quantity, @unit_price;
	END
	CLOSE inserted_items;
	DEALLOCATE inserted_items;

END
GO


/*
Triggers Dada la siguiente vista

CREATE VIEW ProdPorFabricante AS
SELECT m.manu_code, m.manu_name, COUNT(*)
FROM manufact m INNER JOIN products p
ON (m.manu_code = p.manu_code)
GROUP BY manu_code, manu_name;

Crear un trigger que permita ante un insert en la vista ProdPorFabricante insertar una fila
en la tabla manufact.

Observaciones: el atributo leadtime deber� insertarse con un valor default 10
El trigger deber� contemplar inserts de varias filas, por ej. ante un
INSERT / SELECT.
*/

CREATE VIEW prod_por_fabricante
AS
	SELECT m.manu_code, m.manu_name, COUNT(*) AS cantidad
	FROM manufact m INNER JOIN products p ON (m.manu_code = p.manu_code)
	GROUP BY m.manu_code, manu_name;

CREATE TRIGGER insert_on_ppf ON prod_por_fabricante INSTEAD OF INSERT AS
BEGIN

	DECLARE @manu_code CHAR(3), @manu_name VARCHAR(15);
	DECLARE inserted_manufact CURSOR FOR SELECT manu_code, manu_name
	FROM inserted;
	OPEN inserted_manufact;
	FETCH NEXT FROM inserted_manufact INTO @manu_code, @manu_name;
	WHILE @@FETCH_STATUS = 0
	BEGIN

		INSERT INTO manufact
			(manu_code, manu_name, lead_time)
		VALUES
			(@manu_code, @manu_name, 10)

		FETCH NEXT FROM inserted_manufact INTO @manu_code, @manu_name;
	END


	CLOSE inserted_manufact;
	DEALLOCATE inserted_manufact;


END
GO

-- Usar esta!
CREATE TRIGGER insert_on_ppf ON prod_por_fabricante INSTEAD OF INSERT AS
BEGIN
	INSERT INTO manufact
		(manu_code, manu_name, lead_time)
	SELECT manu_code, manu_name, 10
	FROM inserted
END
GO

/*
Crear un trigger que ante un INSERT o UPDATE de una o m�s filas de la tabla Customer, realice
la siguiente validaci�n.
- La cuota de clientes correspondientes al estado de California es de 20, si se supera dicha
cuota se deber�n grabar el resto de los clientes en la tabla customer_pend.

- Validar que si de los clientes a modificar se modifica el Estado, no se puede superar dicha
cuota.

Si por ejemplo el estado de CA cuenta con 18 clientes y se realiza un update o insert masivo de 5
clientes con estado de CA, el trigger deber� modificar los 2 primeros en la tabla customer y los
restantes grabarlos en la tabla customer_pend.
La tabla customer_pend tendr� la misma estructura que la tabla customer con un atributo adicional
fechaHora que deber� actualizarse con la fecha y hora del d�a.
*/

CREATE TABLE customer_pend
(

	customer_num INT,
	fname VARCHAR(15),
	lname VARCHAR(15),
	company VARCHAR(20),
	address1 VARCHAR(20),
	city VARCHAR(18),
	state CHAR(2),
	zipcode CHAR(5),
	phone VARCHAR(18),
	customer_num_referedBy INT,
	status char(1),
	fecha DATETIME DEFAULT GETDATE()
);
GO

CREATE TRIGGER customer_cuota ON customer INSTEAD OF UPDATE, INSERT AS
BEGIN

	DECLARE @customer_num INT;

	INSERT INTO customer
	SELECT *
	FROM inserted
	WHERE state != 'CA';

	DECLARE inserted_customer CURSOR FOR SELECT customer_num, state
	FROM inserted
	WHERE state = 'CA';
	OPEN inserted_customer;
	FETCH NEXT FROM inserted_customer INTO @customer_num;
	WHILE @@FETCH_STATUS = 0
	BEGIN

		IF (SELECT COUNT(customer_num)
		FROM customer
		WHERE state = 'CA') > 20
			INSERT INTO customer_pend
		SELECT *
		FROM inserted
		WHERE customer_num = @customer_num

		IF @customer_num IN (SELECT customer_num
		FROM deleted)
			DELETE FROM customer WHERE @customer_num = customer_num
		INSERT INTO customer
		SELECT *
		FROM inserted
		WHERE customer_num = @customer_num


		FETCH NEXT FROM inserted_customer INTO @customer_num;
	END

	CLOSE inserted_customer;
	DEALLOCATE inserted_customer;


END
GO


-- Usar esta!
CREATE TRIGGER customer_cuota ON customer INSTEAD OF INSERT, UPDATE AS
BEGIN

	DECLARE @customer_num SMALLINT
	DECLARE @fname VARCHAR(15), @lname VARCHAR(15),@city VARCHAR(15)
	DECLARE @company VARCHAR(20),@address1 VARCHAR(20),@address2 VARCHAR(20)
	DECLARE @state CHAR(2), @state_old CHAR(2)
	DECLARE @zipcode CHAR(5)
	DECLARE @phone VARCHAR(18)
	DECLARE c_call cursor FOR SELECT i.*, d.state
	FROM inserted i LEFT JOIN deleted d ON (i.customer_num = d.customer_num)
	OPEN c_call
	FETCH FROM c_call into @customer_num, @fname, @lname, @company, @address1, @address2, @city, @state, @zipcode, @phone, @state_old
	WHILE @@fetch_status = 0
	BEGIN
		IF @state = 'CA' and @state ! =  COALESCE(@state_old, 'ZZ')
		BEGIN
			IF (SELECT COUNT(*)
			FROM customer
			WHERE STATE = 'CA') < 20
			BEGIN
				UPDATE customer SET fname = @fname, lname = @lname, company = @company,
				address1 = @address1, address2 = @address2,
				city = @city, STATE = @state, zipcode = @zipcode,
				phone = @phone
				WHERE customer_num = @customer_num;
			END
		ELSE
		BEGIN
				INSERT INTO customer_pend
				VALUES
					(@customer_num, @fname,
						@lname, @company, @address1, @address2,
						@city, @state, @zipcode, @phone, GETDATE())
			END
		END
		ELSE
		BEGIN
			UPDATE customer
			SET fname = @fname, lname = @lname, company = @company,
			address1 = @address1, address2 = @address2, city = @city,
			state = @state, zipcode = @zipcode, phone = @phone
			WHERE customer_num = @customer_num
		END
		FETCH NEXT FROM c_call INTO @customer_num, @fname, @lname,
									@company, @address1 ,@address2, @city, @state,
									@zipcode, @phone, @state_old
	END
	CLOSE c_call
	DEALLOCATE c_call
END
GO


/*
CREATE VIEW ProdPorFabricanteDet AS
SELECT m.manu_code, m.manu_name, pt.stock_num, pt.description
FROM manufact m LEFT OUTER JOIN products p ON m.manu_code = p.manu_code
LEFT OUTER JOIN product_types pt ON p.stock_num = pt.stock_num;

Se pide: Crear un trigger que permita ante un DELETE en la vista ProdPorFabricante
borrar los datos en la tabla manufact pero s�lo de los fabricantes cuyo campo description
sea NULO (o sea que no tienen stock).

Observaciones: El trigger deber� contemplar borrado de varias filas mediante un DELETE
masivo. En ese caso s�lo borrar� de la tabla los fabricantes que no tengan productos en
stock, borrando los dem�s.
*/


CREATE VIEW ProdPorFabricanteDet
AS
	SELECT m.manu_code, m.manu_name, pt.stock_num, pt.description
	FROM manufact m LEFT OUTER JOIN products p ON m.manu_code = p.manu_code
		LEFT OUTER JOIN product_types pt ON p.stock_num = pt.stock_num;
GO

CREATE TRIGGER delete_in_manufact ON ProdPorFabricante INSTEAD OF DELETE AS
BEGIN
	DELETE FROM manufact WHERE manu_code IN (SELECT manu_code
	FROM deleted
	WHERE description IS NULL)
END
GO

/*
Se pide crear un trigger que permita ante un delete de una sola fila en la vista
ordenesPendientes valide:

	- Si el cliente asociado a la orden tiene s�lo esa orden pendiente de pago (paid_date IS
		NULL), no permita realizar la Baja, informando el error.

	- Si la Orden tiene m�s de un �tem asociado, no permitir realizar la Baja, informando el
		error
.
	- Ante cualquier otra condici�n borrar la Orden con sus �tems asociados, respetando la
		integridad referencial.
		Estructura de la vista: customer_num, fname, lname, Company, order_num, order_date
		WHERE paid_date IS NULL.
*/


CREATE TRIGGER deleting_orden_pendiente ON ordenes_pendientes INSTEAD OF DELETE AS
BEGIN

	DECLARE @customer_num INT;
	DECLARE @order_num INT;
	SELECT @customer_num = customer_num, @order_num = order_num
	FROM deleted

	IF (SELECT COUNT(*)
	FROM orders
	WHERE customer_num = @customer_num AND paid_date IS NULL) > 1
		THROW 50001, 'El cliente tiene varias �rdenes sin pagar', 1

	IF (SELECT COUNT(*)
	FROM items
	WHERE order_num = @order_num) > 1
		THROW 50001, 'La orden tiene varios �tems asociados', 1

	DELETE FROM items WHERE order_num = @order_num
	DELETE FROM orders WHERE order_num = @order_num


END
GO









