--	Table for holding image ids and image urls
--
CREATE TABLE IF NOT EXISTS image(
	id integer PRIMARY KEY,
	url varchar(512) NOT NULL
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