USE municipalidad_la_florida;

SELECT DATABASE() AS active_database,
       @@character_set_database AS database_character_set,
       @@collation_database AS database_collation;

SHOW CREATE TABLE users;
DESCRIBE users;

SELECT COUNT(*) AS user_count FROM users;
SELECT id, firstName, lastName, email FROM users ORDER BY id;

SELECT table_schema, table_name, engine, table_collation
FROM information_schema.tables
WHERE table_schema = 'municipalidad_la_florida'
  AND table_name = 'users';
