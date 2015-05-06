--	Table for holding image ids and image urls
--  @min_price: starting price for hits
--  @max_price: maximum price for hits
--  @step_price: The amount the price per hit will increase per tier in the question tree
--  @..._assign: same as price, but for number of assignments

CREATE TABLE IF NOT EXISTS image(
	id integer PRIMARY KEY,
	url varchar(512) NOT NULL,
	min_price float DEFAULT 0,
	max_price float DEFAULT 0,
	step_price float DEFAULT 0,
	min_assign int DEFAULT 0,
	max_assign int DEFAULT 0,
	step_assign int DEFEAULT 0
);

CREATE TABLE IF NOT EXISTS hit(
	image_id int NOT NULL,
	task_tier varchar(10) NOT NULL,
	hit_id varchar(128) NOT NULL,
	complete boolean DEFAULT 0,
	PRIMARY KEY(image_id, hit_id)
	FOREIGN KEY(image_id)
	REFERENCES image(id)
);

CREATE TABLE IF NOT EXISTS food(
	image_id int NOT NULL,
	task_tier varchar(10) NOT NULL,
	quantity float NOT NULL,
	PRIMARY KEY(image_id, task_tier),
	FOREIGN KEY(image_id)
	REFERENCES image(id)
);