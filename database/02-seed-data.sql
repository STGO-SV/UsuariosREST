-- The ten official EFT records. UNIQUE(email) makes repeated execution safe.
USE municipalidad_la_florida;

INSERT INTO users (firstName, lastName, email) VALUES
    ('Lissette', 'León', 'lissette.leon@gmail.com'),
    ('Emilia', 'Gómez', 'emilia.gomez@hotmail.com'),
    ('Carlos', 'López', 'carlos.lopez@outlook.com'),
    ('Tomas', 'Martínez', 'tomas.martinez@gmail.com'),
    ('Sofia', 'Sánchez', 'sofia.sanchez@hotmail.com'),
    ('Laura', 'Fernández', 'laura.fernandez@outlook.com'),
    ('Diego', 'Torres', 'diego.torres@gmail.com'),
    ('Sofía', 'Ramírez', 'sofia.ramirez@hotmail.com'),
    ('Luis', 'Castro', 'luis.castro@outlook.com'),
    ('Elena', 'Mendoza', 'elena.mendoza@gmail.com')
ON DUPLICATE KEY UPDATE
    firstName = VALUES(firstName),
    lastName = VALUES(lastName);
