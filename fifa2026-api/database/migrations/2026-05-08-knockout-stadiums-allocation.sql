-- =====================================================
-- Migration: alocacao oficial FIFA 2026 dos 32 jogos do mata-mata
-- =====================================================
-- Story 0.10 — atualiza stadium_id, date e time de cada jogo conforme
-- alocacao oficial FIFA (32 placeholders criados na Story 0.8 ficaram
-- todos no MetLife como default).
--
-- Source: 2026 FIFA World Cup Knockout Stage (Wikipedia, FIFA oficial)
-- Idempotente: pode ser re-rodada — cada UPDATE casa por match_number
-- (computado via ROW_NUMBER particionado por stage e ordenado por id).
-- =====================================================

SET NOCOUNT ON;

-- 1) Tabela temporaria com a alocacao oficial (match_number, stadium, data, hora local)
DECLARE @alloc TABLE (
  match_number INT PRIMARY KEY,
  stadium_name NVARCHAR(255),
  match_date   DATE,
  match_time   VARCHAR(5)
);

INSERT INTO @alloc (match_number, stadium_name, match_date, match_time) VALUES
  -- Round of 32 (16 jogos) — 28/06 a 03/07
  (73,  N'SoFi Stadium',            '2026-06-28', '12:00'),
  (74,  N'Gillette Stadium',        '2026-06-29', '16:30'),
  (75,  N'Estadio BBVA',            '2026-06-29', '19:00'),
  (76,  N'NRG Stadium',             '2026-06-29', '12:00'),
  (77,  N'MetLife Stadium',         '2026-06-30', '17:00'),
  (78,  N'AT&T Stadium',            '2026-06-30', '12:00'),
  (79,  N'Estadio Azteca',          '2026-06-30', '19:00'),
  (80,  N'Mercedes-Benz Stadium',   '2026-07-01', '12:00'),
  (81,  N'Levi''s Stadium',         '2026-07-01', '17:00'),
  (82,  N'Lumen Field',             '2026-07-01', '13:00'),
  (83,  N'BMO Field',               '2026-07-02', '19:00'),
  (84,  N'SoFi Stadium',            '2026-07-02', '12:00'),
  (85,  N'BC Place',                '2026-07-02', '20:00'),
  (86,  N'Hard Rock Stadium',       '2026-07-03', '18:00'),
  (87,  N'Arrowhead Stadium',       '2026-07-03', '20:30'),
  (88,  N'AT&T Stadium',            '2026-07-03', '13:00'),
  -- Round of 16 (8 jogos) — 04/07 a 07/07
  (89,  N'Lincoln Financial Field', '2026-07-04', '17:00'),
  (90,  N'NRG Stadium',             '2026-07-04', '12:00'),
  (91,  N'MetLife Stadium',         '2026-07-05', '16:00'),
  (92,  N'Estadio Azteca',          '2026-07-05', '18:00'),
  (93,  N'AT&T Stadium',            '2026-07-06', '14:00'),
  (94,  N'Lumen Field',             '2026-07-06', '17:00'),
  (95,  N'Mercedes-Benz Stadium',   '2026-07-07', '12:00'),
  (96,  N'BC Place',                '2026-07-07', '13:00'),
  -- Quartas (4 jogos) — 09 e 11/07
  (97,  N'Gillette Stadium',        '2026-07-09', '16:00'),
  (98,  N'SoFi Stadium',            '2026-07-10', '12:00'),
  (99,  N'Hard Rock Stadium',       '2026-07-11', '17:00'),
  (100, N'Arrowhead Stadium',       '2026-07-11', '20:00'),
  -- Semis (2 jogos) — 14 e 15/07
  (101, N'AT&T Stadium',            '2026-07-14', '14:00'),
  (102, N'Mercedes-Benz Stadium',   '2026-07-15', '15:00'),
  -- 3o lugar — 18/07
  (103, N'Hard Rock Stadium',       '2026-07-18', '17:00'),
  -- Final — 19/07
  (104, N'MetLife Stadium',         '2026-07-19', '15:00');

-- 2) Numerar os matches do mata-mata da mesma forma que o backend faz
--    (R32: 73-88, R16: 89-96, QF: 97-100, SF: 101-102, 3rd: 103, Final: 104).
WITH numbered AS (
  SELECT
    m.id,
    m.stage,
    CASE
      WHEN m.stage = 'round_of_32'   THEN 73 + ROW_NUMBER() OVER (PARTITION BY m.stage ORDER BY m.id) - 1
      WHEN m.stage = 'round_of_16'   THEN 89 + ROW_NUMBER() OVER (PARTITION BY m.stage ORDER BY m.id) - 1
      WHEN m.stage = 'quarter_final' THEN 97 + ROW_NUMBER() OVER (PARTITION BY m.stage ORDER BY m.id) - 1
      WHEN m.stage = 'semi_final'    THEN 101 + ROW_NUMBER() OVER (PARTITION BY m.stage ORDER BY m.id) - 1
      WHEN m.stage = 'third_place'   THEN 103
      WHEN m.stage = 'final'         THEN 104
    END AS match_number
  FROM dbo.matches m
  WHERE m.stage IN ('round_of_32','round_of_16','quarter_final','semi_final','third_place','final')
)
UPDATE m
   SET m.stadium_id = s.id,
       m.date       = a.match_date,
       m.time       = a.match_time
  FROM dbo.matches m
  JOIN numbered n  ON n.id = m.id
  JOIN @alloc   a  ON a.match_number = n.match_number
  JOIN dbo.stadiums s ON s.name = a.stadium_name;

-- 3) Validacao: contagem de jogos por estadio no mata-mata
SELECT s.name AS stadium, COUNT(*) AS jogos
  FROM dbo.matches m
  JOIN dbo.stadiums s ON s.id = m.stadium_id
 WHERE m.stage IN ('round_of_32','round_of_16','quarter_final','semi_final','third_place','final')
 GROUP BY s.name
 ORDER BY jogos DESC, s.name;

PRINT 'Alocacao oficial FIFA 2026 aplicada aos 32 jogos do mata-mata.';
