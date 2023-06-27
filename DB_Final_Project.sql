USE restaurant;

CREATE TABLE employees (
    employee_ID INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(255) NOT NULL,
    last_name VARCHAR(255) NOT NULL,
    DOB DATE NOT NULL,
    gender ENUM('FEMALE', 'MALE'),
    email VARCHAR(255) NOT NULL UNIQUE,
    city VARCHAR(255),
    street VARCHAR(255),
    building_number INT,
    zip_code INT,
    job_title VARCHAR(255) NOT NULL,
    schedule ENUM('part-time', 'full-time'),
    salary INT NOT NULL,
    employement_date DATE NOT NULL,
    leaving_date DATE
);

CREATE TABLE employee_phones (
    employee_ID INT,
    phone VARCHAR(255),
    CONSTRAINT PK_employee_phones PRIMARY KEY (employee_ID , phone),
    FOREIGN KEY (employee_id)
        REFERENCES employees (employee_ID)
);

CREATE TABLE menu_item_categories (
    category_ID INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE menu_items (
    item_ID INT AUTO_INCREMENT PRIMARY KEY,
    item_name VARCHAR(255) NOT NULL UNIQUE,
    item_price INT NOT NULL,
    status ENUM('available', 'not available'),
    category_ID INT NOT NULL,
    employee_ID INT,
    FOREIGN KEY (category_ID)
        REFERENCES menu_item_categories (category_ID),
    FOREIGN KEY (employee_id)
        REFERENCES employees (employee_ID),
    CHECK (item_price > 0)
);

CREATE TABLE customers (
    customer_ID INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(255) NOT NULL,
    last_name VARCHAR(255) NOT NULL,
    DOB DATE NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    city VARCHAR(255),
    street VARCHAR(255),
    building_number INT,
    zip_code INT,
    registration_date DATE NOT NULL,
    isBlocked ENUM('yes', 'no')
);

CREATE TABLE customer_phones (
    customer_ID INT,
    phone VARCHAR(255),
    CONSTRAINT PK_customer_phones PRIMARY KEY (customer_ID , phone),
    FOREIGN KEY (customer_ID)
        REFERENCES customers (customer_ID)
);

CREATE TABLE payments (
    payment_ID INT AUTO_INCREMENT PRIMARY KEY,
    date DATETIME NOT NULL,
    amount INT NOT NULL,
    status ENUM('payment created','successfull', 'unsuccessfull') NOT NULL,
    customer_ID INT,
    FOREIGN KEY (customer_ID)
        REFERENCES customers (customer_ID),
    CHECK (amount > 0)
);

CREATE TABLE in_place_orders (
    ipo_ID INT AUTO_INCREMENT PRIMARY KEY,
    date DATETIME NOT NULL,
    status ENUM('in progress', 'finished') NOT NULL,
    customer_ID INT,
    waiter_ID INT NOT NULL,
    payment_ID INT,
    FOREIGN KEY (customer_ID)
        REFERENCES customers (customer_ID),
    FOREIGN KEY (waiter_ID)
        REFERENCES employees (employee_ID),
    FOREIGN KEY (payment_ID)
        REFERENCES payments (payment_ID)
);

CREATE TABLE inplace_order_details (
    ipo_ID INT,
    menu_item_ID INT,
    quantity INT NOT NULL,
    CONSTRAINT PK_iod PRIMARY KEY (ipo_ID , menu_item_ID),
    FOREIGN KEY (ipo_ID)
        REFERENCES in_place_orders (ipo_ID),
    FOREIGN KEY (menu_item_ID)
        REFERENCES menu_items (item_ID)
);

CREATE TABLE delivery_orders (
    do_ID INT AUTO_INCREMENT PRIMARY KEY,
    date DATETIME NOT NULL,
    status VARCHAR(255) NOT NULL,
    customer_ID INT NOT NULL,
    delivery_person_ID INT NOT NULL,
    payment_ID INT,
    FOREIGN KEY (delivery_person_ID)
        REFERENCES employees (employee_ID),
    FOREIGN KEY (customer_ID)
        REFERENCES customers (customer_ID),
    FOREIGN KEY (payment_ID)
        REFERENCES payments (payment_ID)
);

CREATE TABLE delivery_order_details (
    do_id INT,
    menu_item_ID INT,
    quantity INT NOT NULL,
    CONSTRAINT PK_dod PRIMARY KEY (do_ID , menu_item_ID),
    FOREIGN KEY (do_id)
        REFERENCES delivery_orders (do_ID),
    FOREIGN KEY (menu_item_ID)
        REFERENCES menu_items (item_ID)
);

CREATE TABLE ingredient_types (
    type_ID INT AUTO_INCREMENT PRIMARY KEY,
    type_name VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE ingredients (
    ID INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255),
    description VARCHAR(255),
    type_ID INT NOT NULL,
    FOREIGN KEY (type_ID)
        REFERENCES ingredient_types (type_ID)
);

CREATE TABLE recipe (
    menu_item_id INT,
    ingredient_id INT,
    CONSTRAINT PK_recipe PRIMARY KEY (menu_item_id , ingredient_id),
    FOREIGN KEY (menu_item_id)
        REFERENCES menu_items (item_ID),
    FOREIGN KEY (ingredient_id)
        REFERENCES ingredients (ID)
);

CREATE TABLE tables (
    table_ID INT AUTO_INCREMENT PRIMARY KEY,
    capacity INT NOT NULL,
    status VARCHAR(255) NOT NULL,
    CHECK (capacity >= 0)
);

CREATE TABLE reservations (
    table_ID INT,
    customer_ID INT,
    date DATETIME NOT NULL,
    CONSTRAINT PK_reservations PRIMARY KEY (table_ID , customer_ID),
    FOREIGN KEY (table_id)
        REFERENCES tables (table_ID),
    FOREIGN KEY (customer_ID)
        REFERENCES customers (customer_ID)
);

CREATE INDEX emp_fname_lname ON employees(first_name, last_name);

CREATE INDEX cust_fname_lname ON customers(first_name, last_name);

CREATE INDEX table_status ON tables(status);

DELIMITER $$
CREATE TRIGGER customer_status 
BEFORE INSERT ON in_place_orders
FOR EACH ROW 
BEGIN 
	DECLARE Status ENUM('yes','no');
    DECLARE iop_customer_ID INT;
    SET iop_customer_ID = NEW.customer_ID;
    SET Status = (SELECT c.isBlocked FROM customers c WHERE c.customer_ID = iop_customer_ID);
	IF (Status = 'yes')
    THEN
    SIGNAL SQLSTATE '23000' SET MYSQL_ERRNO = 1242, MESSAGE_TEXT = 'Customer is blocked, cannot create order for this customer';
    END IF;
END $$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER customer_status_delivery 
BEFORE INSERT ON delivery_orders
FOR EACH ROW 
BEGIN 
	DECLARE Status ENUM('yes','no');
    DECLARE do_customer_ID INT;
    SET do_customer_ID = NEW.customer_ID;
    SET Status = (SELECT c.isBlocked FROM customers c WHERE c.customer_ID = do_customer_ID);
	IF (Status = 'yes')
    THEN
    SIGNAL SQLSTATE '23000' SET MYSQL_ERRNO = 1242, MESSAGE_TEXT = 'Customer is blocked, cannot create order for this customer';
    END IF;
END $$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER customer_reservations 
BEFORE INSERT ON reservations
FOR EACH ROW 
BEGIN 
	DECLARE Status ENUM('yes','no');
    DECLARE reservation_customer_ID INT;
    SET reservation_customer_ID = NEW.customer_ID;
    SET Status = (SELECT c.isBlocked FROM customers c WHERE c.customer_ID = reservation_customer_ID);
	IF (Status = 'yes')
    THEN
    SIGNAL SQLSTATE '23000' SET MYSQL_ERRNO = 1242, MESSAGE_TEXT = 'Customer is blocked, cannot create order for this customer';
    END IF;
END $$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER table_available 
BEFORE INSERT ON reservations
FOR EACH ROW 
BEGIN 
	DECLARE Status VARCHAR(255);
    DECLARE reservation_table_ID INT;
    SET reservation_table_ID = NEW.table_ID;
    SET Status = (SELECT t.status FROM tables t WHERE t.table_ID = reservation_table_ID);
	IF (Status <> 'available')
    THEN
    SIGNAL SQLSTATE '23000' SET MYSQL_ERRNO = 1242, MESSAGE_TEXT = 'Table is not available for reservation';
    END IF;
END $$
DELIMITER ;

DELIMITER //
CREATE TRIGGER sync_reservation_status 
AFTER INSERT ON reservations
FOR EACH ROW
BEGIN
	DECLARE table_ID INT;
    SET table_ID = NEW.table_ID;
	UPDATE tables t SET status = 'reserved' WHERE t.table_ID = table_ID;
END //
DELIMITER ;

INSERT INTO employees(first_name, last_name, DOB, gender, email, city, street, building_number, zip_code,  job_title, schedule, salary, employement_date, leaving_date) 
VALUES
('Megaira', 'Poirot', '1988-11-07', 'female', 'yanarushsnec@filesn.site', 'South Hadley', 'Allerton Birches', 15, 62426, 'chef', 'full-time', 250000, '2018-05-02', null),
('Pluto', 'Weasley', '2002-09-12', 'male', 'fakapazepri-4954@yopmail.com', 'Tawe', 'Tennyson Trees', 21, 26410, 'waiter', 'part-time', 80000, '2018-11-25', '2020-02-03'),
('Rhea', 'Poppins', '1986-09-01', 'female', 'Rhea_Poppins@gmail..com', 'Vikeu', 'Quarry Lane', 59, 23409, 'chef', 'full-time', 230000, '2018-12-03', '2021-03-23'),
('Evander', 'Gynt',  '1999-07-26', 'male', 'Evander_Gynt@gmail.com', 'Matbert', ' Leeds Royd', 62, 38091, 'barista', 'full-time', 120000, '2019-01-23', null),
('Walganus', 'Quijote', '1982-03-16', 'male', 'alganus_Quijote.com', 'Jonst', 'Narrow Dale', 61, 57947, 'chef', 'full-time', 200000, '2019-05-22', null),
('Hyacintha', 'Targaryen', '1995-09-12', 'female', 'peipaugrequojou-7232@yopmail.com', 'Bulin-On-Sea', 'Stoney Wharf', 31, 16229, 'waiter', 'part-time', 80000, '2019-07-08', '2020-09-04'),
('Macbeth', 'Dumbledore', '1995-12-26', 'male', 'Macbeth_Dumbledore@gmail.com', 'Rouynalpiss', 'Markham Parade', 8, 26962, 'barista', 'full-time', 125000, '2019-09-10', '2021-09-12'),
('Aminta', 'Copperfield', '1990-03-02', 'female', 'fingersnthumbs@gamakang.com', 'Vikeu', 'Solway Point', 42, 15743, 'delivery person', 'part-time', 80000, '2019-11-17', '2021-05-05'),
('Cassiopea', 'Targaryen', '1998-03-16', 'female', 'kawave5757@mediafate.com', 'Grand Chanmcwhite', 'Broadway', 34, 64760, 'waiter', 'part-time', 85000, '2019-12-02', null),
('Afrodita', 'Valjean', '2000-06-11', 'male', 'crock723@hoangtaote.com', 'Tiperthster-By-The-Sea', 'Blackbird Springs', 4, 83326, 'delivery person', 'part-time', 80000, '2020-01-06', null),
('Alexandros', 'Finch', '1983-03-19', 'male', 'shufflenerine@teeenye.com', 'South Hadley', 'Allerton Birches', 63, 62426, 'delivery person', 'full-time', 90000, '2020-04-12', null),
('Paris', 'Poirot', '1985-01-07', 'female', '3t2pjj@mobilp.site', 'El Lande', 'Quarry Fairway', 24, 50526, 'chef', 'full-time', 230000, '2020-04-14', null),
('Eris', 'Gatsby', '1992-04-09', 'female', 'elpabloxxl@816qs.com', 'Matbert', 'Webster Manor', 15, 46115, 'barista', 'part-time', 130000, '2020-05-06', '2021-11-02'),
('Kastor', 'Poirot', '1993-09-15', 'male', 'viknu@gltrrf.com', 'Las Stingbraun', 'Pitt Spinney', 60, 68192, 'barista', 'full-time', 160000, '2020-06-18', null),
('Morgaine', 'Quixote', '1991-09-06', 'female', 'sscottsowards@soccerfit.com', 'El Lande', 'Quarry Fairway', 49, 68286, 'waiter', 'part-time', 83000, '2020-07-20', null),
('Laocoön', 'Panza', '1999-01-04', 'male', 'svaran@hackertrap.info', 'Tiperthster-By-The-Sea', 'Blackbird Springs', 9, 76104, 'delivery person', 'part-time', 80000, '2020-07-22', null),
('Percival', 'Gynt', '1986-06-08', 'male', 'beummepraprette-8614@yopmail.com', 'Sconecarhill', 'Delph Acre', 57, 16829, 'waiter', 'full-time', 210000, '2020-08-05', null),
('Jocasta', 'Weasley', '1998-07-06', 'female', 'yoimauffouffofou-4941@yopmail.com', 'East Dsey', 'Paxton Point', 24, 76249, 'waiter', 'part-time', 82000, '2020-09-13', null),
('Alexander', 'Copperfield', '1997-10-20', 'male', 'liyijaullawou-4245@yopmail.com', 'El Lande', 'Cypress Yard', 20, 26320, 'waiter', 'part-time', 80000, '2020-10-01', '2021-07-18'),
('Morgan', 'Gatsby', '1996-12-19', 'female', 'gaffeppebefri-9650@yopmail.com', 'La Anpor', 'Paterson Copse', 7, 15228, 'waiter', 'part-time', 80000, '2021-02-27', null);

INSERT INTO employee_phones(employee_ID, phone) 
VALUES
(1, '+374 95 149032'), (2, '+374 33 567489'), (3, '+374 43 952768'), (4, '+374 33 953328'), (5, '+374 33 337086'),
(6, '+374 33 722871'), (7, '+374 97 848125'), (8, '+374 55 412191'), (9, '+374 33 805461'), (10, '+374 95 767484'),
(11, '+374 55 083578'), (12, '+374 49 859428'), (13, '+374 55 302121'), (14, '+374 33 589876'), (15, '+374 33 598627'),
(16, '+374 33 948132'), (17, '+374 55 887035'), (18, '+374 55 181973'), (19, '+374 41 327548'), (20, '+374 33 566095');

SELECT e.first_name, e.last_name, ep.phone FROM employees e, employee_phones ep WHERE e.employee_ID = ep.employee_ID;

INSERT INTO menu_item_categories(category_name) 
VALUES
('salad'), ('sandwich'), ('pizza'), ('pasta'), ('pancake'), ('cake'), ('waffle'),
('coffee'), ('iced coffee'), ('tea'), ('iced tea'), ('other drinks');

INSERT INTO menu_items(item_name, item_price, status, category_id, employee_id)
VALUES
('ceaser salad', 2500, null, 1, 5), ('Greek salad', 2200, null, 1, 5), ('Tabbouleh', 2300, null, 1, 1), ('Olivier salad', 2600, null, 1, 1),
('Avocado toast', 1500, null, 2, 5), ('Club sandwich', 2400, null, 2, 5), ('BLT sandwich', 2400, null, 2, 1), ('Veggie pizza', 2500, null, 3, 1),
('Pepperoni pizza', 2700, null, 3, 5), ('Margherita', 2100, null, 3, 5), ('BBQ chicken pizza', 2800, null, 3, 1), ('Spaghetti bolognese', 2400, null, 4, 1),
('Spaghetti aglio e olio', 1800, null, 4, 5), ('Chicken fettucine', 2500, null, 4, 5), ('Pancake with banana and Nutella', 2400, null, 5, 12),
('Pancake with strawberries and Nutella', 2300, null, 5, 12), ('Pancake with jam', 2000, null, 5, 12), ('Carrot cake', 1400, 'available', 6, 12),
('Red velvet', 1800, 'available', 6, 12), ('Chocolate cake', 1500, 'available', 6, 12), ('Eskimo', 1400, 'available', 6, 12),
('Waffle with a vanilla ice-cream', 1300, null, 7, 12), ('Waffle with a chocolate ice-cream', 1300, null, 7, 12), 
('Waffle with a vanilla ice-cream and berries', 2000, null, 7, 12), ('Espresso', 800, null, 8, 7), ('Americano', 900, null, 8, 7),
('Cappuccino', 1300, null, 8, 7), ('Latte', 1400, null, 8, 7), ('Mocha', 1600, null, 8, 7), ('Iced caramel macchiato', 1700, null, 9, 13),
('Iced vanilla latte', 1800, null, 9, 7), ('Iced Americano', 1400, null, 9, 13), ('Iced Espresso', 1400, null, 9, 7),
('Black tea', 1100, null, 10, 13), ('Green tea', 1100, null, 10, 13), ('Fruit tea', 1100, null, 10, 13),
('icec black tea', 900, null, 11, 13), ('Iced green tea', 900, null, 11, 13), ('Iced fruit tea', 1000, null, 11, 7),
('Coca-cola 250ml', 250, 'available', 12, null), ('Sparkling water 250ml', 250, 'available', 12, null), 
('Fresh apple juice 250ml', 250, 'available', 12, null),
('Fresh orange juice 250ml', 250, 'available', 12, null), ('Water', 150, 'available', 12, null);

INSERT INTO ingredient_types(type_name) VALUES
('leaf vegetable'), ('dairy'), ('fruit'), ('vegetable'), ('oil'), ('spice'), ('grain'),
('condiment'), ('meat'), ('animal product'), ('dessert topping'), ('ice-cream'),
('tea'), ('coffee'), ('baked product'), ('salt'), ('sugar'), ('pizza_dough'),
('sauce'), ('nuts'), ('sweets'), ('chocolate');

INSERT INTO ingredients(name, type_ID) VALUES
('lettuce', 1), ('lemon', 3), ('salt', 16), ('eggs', 10), ('Parmigiano-Reggiano', 2), ('croutons', 15), ('olive oil', 5),
('garlic', 4), ('black pepper', 6), ('feta', 2), ('onion', 4), ('cucumber', 4), ('tomato', 4), ('oregano', 6), ('bulgur', 7),
('mint', 1), ('parsley', 1), ('potatoes', 4), ('mayonnaise', 8), ('peas', 4), ('dill', 1), ('scallions', 1), ('ham', 9),
('carrot', 4), ('pickles', 4), ('bread', 7), ('avocado', 3), ('bacon', 9), ('chicken', 9), ('spinach', 1), ('mozzarella', 2),
('bell pepper', 4), ('olives', 3), ('pizza dough', 18), ('pepperoni', 9), ('flour', 7), ('tomato sauce', 19),
('bazil', 1), ('BBQ sauce', 8), ('spaghetti', 7), ('beef', 9), ('chili pepper', 4), ('red pepper', 6),
('fettuccine', 7), ('butter', 2), ('heavy cream', 2), ('milk', 2), ('baking powder', 7), ('sugar', 17),
('Nutella', 11), ('banana', 3), ('strawberries', 3), ('jam', 21), ('cream cheese', 2), ('walnuts', 20),
('pineapple', 3), ('vanilla', 6), ('cinnamon', 6), ('cocoa', 7), ('vinegar', 8), ('chocolate', 22),
('corn starch', 7), ('vanilla ice-cream', 12), ('chocolate ice-cream', 12), ('blueberry', 3),
('raspberry', 3), ('ground coffee', 14), ('vanilla syrup', 11), ('chockolate syrup', 11),
('black tea', 13), ('green tea', 13), ('fruit tea', 13);

INSERT INTO tables(capacity, status) VALUES
(2, 'available'), (2, 'available'), (2, 'not available'), (4, 'reserved'), (4, 'available'),
(4, 'available'), (4, 'available'), (6, 'available'), (6, 'available'), (6, 'available');

INSERT INTO customers(first_name, last_name, DOB, email, city, street, building_number, zip_code, registration_date, isBlocked)
VALUES
('Anush', 'Ghazaryan', '2001-06-02', 'anush_ghazaryan@edu.aua.am', 'Yerevan', 'Azatutyan 2A', 3, 1234, '2019-05-16', 'no'),
('Ani', 'Petrosyan', '1999-05-03', 'ani_p@edu.aua.am', 'Yerevan', 'Komitas', 12, 2341, '2018-04-16', 'no'),
('Karen', 'Bagratyan', '1994-01-01', 'kar.bag@gmail.com', 'Yerevan', 'Hovhannes Kajaznunu St', 11, 1070, '2020-09-20', 'yes'),
('Armen', 'Tigranyan', '1996-01-01', 'arm@gmail.com', 'Yerevan', 'Nalbandyan St', 37, 1000, '2019-09-20', 'no'),
('Linda', 'Sargsyan', '2001-02-17', 'linda_sargsyan@edu.aua.am', 'Yerevan', 'Komitas', 37, 1000, '2019-05-06', 'no'),
('Hayk', 'Mantashyan', '1986-03-14', 'hmantashyan@gmail.com', 'Yerevan', 'Koryuni St', 6, 9854, '2019-05-06', 'yes'),
('Narek', 'Karapetyan', '2000-12-15', 'nar_k@gmail.com', 'Gyumri', 'Shirak Marz', 1, 3104, '2021-08-11', 'no'),
('Hrach', 'Alexanyan', '2001-05-31', 'h_alex@gmail.com', 'Yerevan', 'Artashisyan St', 4, 543, '2019-07-07', 'yes'),
('Levon', 'Gasparyan', '1993-03-18', 'lgasparyan@gmail.com', 'Yerevan', 'Hrachya Kochari St', 13, 1200, '2019-06-07', 'no'),
('Lilit', 'Arakelyan', '1984-06-23', 'larakelyan@gmail.com', 'Yerevan', 'Tigran Metsi Ave', 67, 5000, '2020-01-30', 'no');

INSERT INTO customer_phones(customer_ID, phone) VALUES
(1, '+374 93396699'), (2, '+374 77256212'), (3, '+374 93301006'), (4, '+374 99123456'), (5, '+374 77875637'),
(6, '+374 77909090'), (7, '+374 93111122'), (8, '+374 93467389'), (9, '+374 99627189'), (10, '+374 77902030');

SELECT * FROM customers c, customer_phones cp WHERE c.customer_ID = cp.customer_ID;

INSERT INTO in_place_orders(date, status, customer_ID, waiter_ID) VALUES
('2021-12-11', 'in progress', 1, 3),
('2021-12-11', 'in progress', null, 7),
('2021-12-11', 'in progress', 5, 3);

-- to illustrate trigger for blocked customers
INSERT INTO in_place_orders(date, status, customer_ID, waiter_ID) VALUES
('2021-12-11', 'in progress', 3, 3);

SELECT * FROM in_place_orders;

SELECT c.first_name as `Customer Name`, c.last_name as `Customer Surname`, e.first_name as `Employee Name`, ipo.date as `Date`
FROM in_place_orders ipo LEFT JOIN customers c 
ON ipo.customer_ID = c.customer_ID JOIN employees e ON ipo.waiter_ID = e.employee_ID;

SELECT * FROM menu_items;

INSERT INTO inplace_order_details (ipod_ID, menu_item_ID, quantity) VALUES
(1, 28, 2),
(2, 6, 3),
(3, 35, 2);

SELECT ipo.ipo_ID `Order ID`, concat(c.first_Name, " ", c.last_Name) as `Customer Name`, mi.item_name `Menu Item Name`, mi.item_price `Price`, iod.quantity `Quantity`
FROM in_place_orders ipo JOIN inplace_order_details iod ON ipo.ipo_ID = iod.ipo_ID 
JOIN menu_items mi ON iod.menu_item_ID = mi.item_ID LEFT JOIN customers c 
ON ipo.customer_ID = c.customer_ID;

SELECT concat(c.first_Name, " ", c.last_Name) as `Customer Name`, sum(mi.item_price * iod.quantity) as `Order Payment Amount`
FROM in_place_orders ipo JOIN inplace_order_details iod ON ipo.ipo_ID = iod.ipo_ID 
JOIN menu_items mi ON iod.menu_item_ID = mi.item_ID LEFT JOIN customers c 
ON ipo.customer_ID = c.customer_ID GROUP BY iod.ipo_ID;

INSERT INTO payments (date, amount, status, customer_ID)
VALUES 
('2021-12-11', 7200, 'successfull', null),
('2021-12-11', 4600, 'successfull', 1),
('2021-12-11', 2200, 'successfull', 5);

UPDATE in_place_orders ipo SET payment_ID = 2, status = 'finished' WHERE ipo.ipo_ID = 1;
-- table status changes to reserved after reservation insert
SELECT * FROM tables;
SELECT * FROM reservations;

INSERT INTO reservations(table_ID, customer_ID, date) VALUES
(1, 2, '2021-12-12');
-- does not allow to reserve not avaulable tables
INSERT INTO reservations(table_ID, customer_ID, date) VALUES
(1, 2, '2021-12-12');
-- customer is blocked trigger is working fine 
INSERT INTO reservations(table_ID, customer_ID, date) VALUES
(2, 3, '2021-12-12');

SELECT * FROM menu_items;

SELECT i.name `Ingredient Name`, it.type_name `Type Name` 
FROM ingredients i, ingredient_types it 
WHERE i.type_ID = it.type_ID;

SELECT  it.type_name `Type Name`, count(i.ID) `Quantity` 
FROM ingredients i, ingredient_types it 
WHERE i.type_ID = it.type_ID
GROUP BY it.type_name;

INSERT INTO recipe(menu_item_ID, ingredient_ID) VALUES
(39, 72), (39, 49),(38, 71),(38, 49),(37, 70),(37, 49),(36, 72),(36, 49),(35, 71),(35, 49),(34, 70),(34, 49),(33, 67),
(33, 46),(33, 49),(32, 67),(32, 49),(31, 67),(31, 47),(31, 68),(30, 68),(30, 47),(30, 67),(29, 67),(29, 47),(29, 61),
(29, 59),(29, 69),(28, 67),(28, 47),(27, 67),(27, 47),(26, 67),(25, 67),(24, 63),(24, 52),(24, 65),(24, 66),(24, 4),(24, 36),
(24, 45),(24, 47),(24, 48),(24, 49),(23, 64),(21, 4),(21, 59),(21, 36),(21, 47),(21, 45),(21, 62),(21, 49),(20, 61),(20, 4),
(20, 45),(20, 36),(20, 59),(20, 57),(20, 48),(20, 49),(19, 36),(19, 49),(19, 3),(19, 59),(19, 4),(19, 60),(18, 24),
(18, 36),(18, 4),(18, 45),(18, 55),(18, 49),(18, 56),(18, 48),(18, 57),(18, 58),(17, 4),(17, 36),(17, 47),(17, 45),(17, 49),
(17, 48),(17, 53),(16, 52),(16, 50),(16, 4),(16, 36),(16, 47),(16, 48),(16, 49),(15, 50),(15, 4),(15, 36),(15, 47),(15, 48),(15, 49),
(15, 51),(14, 44),(14, 45),(14, 29),(14, 3),(14, 9),(14, 46),(14, 5),(13, 8),(13, 40),(13, 42),(13, 7),(13, 5),(13, 3),(13, 17),(13, 9),
(12, 40),(12, 13),(12, 5),(12, 11),(12, 37),(11, 39),(11, 29),(11, 11),(11, 31),(10, 31),(10, 13),(10, 37),(10, 38),(10, 34),(10, 3),(9, 34),
(9, 35),(9, 31),(9, 9),(9, 37),(9, 8),(9, 11),(9, 7),(8, 31),(8, 30),(8, 32),(8, 11),(8, 13),(8, 34),(7, 28),(7, 26),(7, 13),(7, 1),
(7, 19),(6, 28),(6, 26),(6, 5),(6, 13),(6, 19),(6, 1),(5, 26),(5, 27);

SELECT mi.item_name `Menu Item Name`, mic.category_name `Category Name`, i.name `Ingredient Name`
FROM recipe r, menu_items mi, menu_item_categories mic, ingredients i 
WHERE r.menu_item_ID = mi.item_ID AND mi.category_ID = mic.category_ID AND r.ingredient_ID = i.ID;