--	Table for holding image ids and image urls
--
CREATE TABLE IF NOT EXISTS image(
	id integer AUTOINCREMENT,
	url varchar(512) NOT NULL,
	PRIMARY KEY(id)
);

CREATE TABLE IF NOT EXISTS hit(
	image_id int NOT NULL,
	hit_id varchar(128) NOT NULL,
	PRIMARY KEY(image_id, hit_id)
	FOREIGN KEY(image_id)
		REFERENCES image(id)
);