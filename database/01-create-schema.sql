-- Normalized from the official EFT database script. No credentials are stored here.
CREATE DATABASE IF NOT EXISTS municipalidad_la_florida
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE municipalidad_la_florida;

CREATE TABLE IF NOT EXISTS users (
    id BIGINT NOT NULL AUTO_INCREMENT,
    firstName VARCHAR(255) NOT NULL,
    lastName VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_users_email (email)
) ENGINE=InnoDB
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
