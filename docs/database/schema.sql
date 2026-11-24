-- Таулы аймақтарға арналған офлайн навигация және SOS көмек жүйесінің ДҚ схемасы (PostgreSQL)

DROP TABLE IF EXISTS rescue_responses CASCADE;
DROP TABLE IF EXISTS sos_alerts CASCADE;
DROP TABLE IF EXISTS user_routes CASCADE;
DROP TABLE IF EXISTS waypoints CASCADE;
DROP TABLE IF EXISTS routes CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- D1: Пайдаланушылар кестесі
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    full_name VARCHAR(120) NOT NULL,
    phone VARCHAR(20) NOT NULL UNIQUE,
    role VARCHAR(30) NOT NULL CHECK (role IN ('tourist', 'guide', 'operator', 'admin')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- D2: Таулы маршруттар кестесі
CREATE TABLE routes (
    route_id SERIAL PRIMARY KEY,
    guide_id INT NOT NULL REFERENCES users(user_id),
    route_name VARCHAR(150) NOT NULL,
    difficulty VARCHAR(20) NOT NULL CHECK (difficulty IN ('easy', 'medium', 'hard')),
    distance_km NUMERIC(5,2) NOT NULL CHECK (distance_km > 0)
);

-- Маршруттағы бақылау нүктелері (1:N routes -> waypoints)
CREATE TABLE waypoints (
    waypoint_id SERIAL PRIMARY KEY,
    route_id INT NOT NULL REFERENCES routes(route_id) ON DELETE CASCADE,
    point_name VARCHAR(120) NOT NULL,
    latitude NUMERIC(9,6) NOT NULL,
    longitude NUMERIC(9,6) NOT NULL,
    elevation_m INT NOT NULL
);

-- Пайдаланушылар мен маршруттар арасындағы M:N байланыс кестесі
CREATE TABLE user_routes (
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    route_id INT NOT NULL REFERENCES routes(route_id) ON DELETE CASCADE,
    downloaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (user_id, route_id)
);

-- D3: SOS дабыл сигналдары кестесі
CREATE TABLE sos_alerts (
    alert_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id),
    latitude NUMERIC(9,6) NOT NULL,
    longitude NUMERIC(9,6) NOT NULL,
    battery_level INT NOT NULL CHECK (battery_level BETWEEN 0 AND 100),
    channel VARCHAR(20) NOT NULL CHECK (channel IN ('internet', 'sms', 'satellite')),
    status VARCHAR(25) NOT NULL CHECK (status IN ('sent', 'queued_sms', 'acknowledged', 'resolved')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Құтқару операторының әрекеттері (1:N sos_alerts -> rescue_responses)
CREATE TABLE rescue_responses (
    response_id SERIAL PRIMARY KEY,
    alert_id INT NOT NULL REFERENCES sos_alerts(alert_id) ON DELETE CASCADE,
    operator_id INT NOT NULL REFERENCES users(user_id),
    action_note VARCHAR(255) NOT NULL,
    responded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Тестілік жазбалар (INSERT)
INSERT INTO users (full_name, phone, role) VALUES
('Адель Болатбек', '+77011112233', 'tourist'),
('Ерлан Сейітов', '+77023334455', 'tourist'),
('Нұрлан Қасымов', '+77055556677', 'guide'),
('Айгүл Төлегенова', '+77077778899', 'operator'),
('Дәурен Әлімов', '+77089990011', 'admin');

INSERT INTO routes (guide_id, route_name, difficulty, distance_km) VALUES
(3, 'Көк-Жайлау — Үш Қоңыр', 'medium', 12.50),
(3, 'Үлкен Алматы шыңы', 'hard', 18.20),
(3, 'Бутаковка сарқырамасы', 'easy', 6.40);

INSERT INTO waypoints (route_id, point_name, latitude, longitude, elevation_m) VALUES
(1, 'Көк-Жайлау үстірті', 43.139400, 76.973100, 2240),
(1, 'Құмбел шыңы етегі', 43.128900, 76.991200, 2850),
(2, 'Үлкен Алматы көлі', 43.050600, 76.985000, 2511),
(3, 'Төменгі Бутаковка сарқырамасы', 43.178200, 77.081500, 1790);

INSERT INTO user_routes (user_id, route_id, is_completed) VALUES
(1, 1, TRUE),
(1, 2, FALSE),
(2, 1, FALSE),
(2, 3, TRUE);

INSERT INTO sos_alerts (user_id, latitude, longitude, battery_level, channel, status) VALUES
(1, 43.132500, 76.984100, 24, 'sms', 'acknowledged'),
(2, 43.054100, 76.989200, 15, 'satellite', 'resolved'),
(1, 43.129000, 76.990500, 41, 'internet', 'sent');

INSERT INTO rescue_responses (alert_id, operator_id, action_note) VALUES
(1, 4, 'Құтқару тобы Көк-Жайлау бағытына жіберілді'),
(2, 4, 'Турист табылды, базаға жеткізілді'),
(1, 4, 'Байланыс орнатылды, жағдайы тұрақты');

-- Сұраныс 1: 3 кестені біріктіретін JOIN (sos_alerts + users + rescue_responses)
SELECT
    sa.alert_id,
    u.full_name AS tourist_name,
    u.phone AS tourist_phone,
    sa.latitude,
    sa.longitude,
    sa.channel,
    sa.status,
    op.full_name AS operator_name,
    rr.action_note
FROM sos_alerts sa
JOIN users u ON sa.user_id = u.user_id
LEFT JOIN rescue_responses rr ON sa.alert_id = rr.alert_id
LEFT JOIN users op ON rr.operator_id = op.user_id
ORDER BY sa.alert_id;

-- Сұраныс 2: GROUP BY қолданатын агрегаттық сұраныс (байланыс арналары бойынша SOS статистикасы)
SELECT
    channel,
    COUNT(*) AS total_alerts,
    ROUND(AVG(battery_level), 1) AS avg_battery_percent
FROM sos_alerts
GROUP BY channel
ORDER BY total_alerts DESC;
