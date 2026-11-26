CREATE TABLE jogadores (
    id_jogador SERIAL PRIMARY KEY,
    nickname VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    senha TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ativo',

    CHECK (status IN ('ativo', 'inativo'))
);

CREATE TABLE jogos (
    id_jogo SERIAL PRIMARY KEY,
    titulo VARCHAR(100) NOT NULL,
    categoria VARCHAR(50) NOT NULL
);

CREATE TABLE partidas (
    id_partida SERIAL PRIMARY KEY,
    titulo_partida VARCHAR(100) NOT NULL,
    id_jogador INT NOT NULL,
    id_jogo INT NOT NULL,
    data_agendamento TIMESTAMP NOT NULL,
    data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL DEFAULT 'agendada',

    FOREIGN KEY (id_jogador)
        REFERENCES jogadores(id_jogador),

    FOREIGN KEY (id_jogo)
        REFERENCES jogos(id_jogo),

    CHECK (status IN ('agendada', 'em andamento', 'finalizada'))
);

CREATE TABLE historico_partidas (
    id_historico SERIAL PRIMARY KEY,
    id_partida INT NOT NULL,
    descricao TEXT NOT NULL,
    data_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (id_partida)
        REFERENCES partidas(id_partida)
);

-- 2. INSERIR OS DADOS

INSERT INTO jogadores (nickname, email, senha, status)
VALUES
('XXGamertentacion', 'Michel01@email.com', '676767', 'ativo'),
('VitinhoXJ', 'Victor67@email.com', '123843', 'ativo'),
('ShadowoEmo', 'shadowemo@email.com', '108456', 'inativo');

INSERT INTO jogos (titulo, categoria)
VALUES
('League of Legends', 'MOBA'),
('Counter Strike 2', 'FPS'),
('Valorant', 'FPS');

INSERT INTO partidas
(titulo_partida, id_jogador, id_jogo, data_agendamento, status)
VALUES
('Final do Campeonato', 1, 1, '2026-12-10 14:00:00', 'agendada'),
('Semifinal de CS2', 2, 2, '2026-12-15 16:00:00', 'agendada'),
('Disputa de Valorant', 1, 3, '2026-12-20 18:00:00', 'finalizada');

INSERT INTO historico_partidas (id_partida, descricao)
VALUES
(1, 'Partida cadastrada no sistema'),
(2, 'Partida cadastrada no sistema'),
(3, 'Partida cadastrada no sistema');

-- 3. FUNCAO DE BUSCA DE JOGADORES

CREATE OR REPLACE FUNCTION fn_buscar_jogadores(
    termo TEXT
)
RETURNS TABLE (
    id_jogador INT,
    nickname VARCHAR(50),
    email VARCHAR(100),
    status VARCHAR(20)
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        j.id_jogador,
        j.nickname,
        j.email,
        j.status
    FROM jogadores j
    WHERE
        j.nickname ILIKE '%' || termo || '%'
        OR j.email ILIKE '%' || termo || '%';
END;
$$;

-- 4. VIEW DO PAINEL PRINCIPAL

CREATE OR REPLACE VIEW vw_painel_principal AS
SELECT
    j.nickname,
    p.titulo_partida,
    g.categoria,
    p.data_agendamento,
    p.status
FROM partidas p
INNER JOIN jogadores j
    ON p.id_jogador = j.id_jogador
INNER JOIN jogos g
    ON p.id_jogo = g.id_jogo;
	
-- 5. FUNCAO DE VALIDACAO DA PARTIDA

CREATE OR REPLACE FUNCTION fn_validar_partida()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM jogadores
        WHERE id_jogador = NEW.id_jogador
        AND status = 'ativo'
    ) THEN
        RAISE EXCEPTION
        'O jogador informado nao existe ou esta inativo!';
    END IF;
    NEW.data_criacao := CURRENT_TIMESTAMP;
    RETURN NEW;

END;
$$;

-- 6. TRIGGER DE VALIDACAO

CREATE TRIGGER trg_validar_partida
BEFORE INSERT ON partidas
FOR EACH ROW
EXECUTE FUNCTION fn_validar_partida();

-- 7. FUNCAO PARA REGISTRAR O HISTORICO

CREATE OR REPLACE FUNCTION fn_registrar_historico()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    INSERT INTO historico_partidas
    (id_partida, descricao, data_registro)
    VALUES
    (
        NEW.id_partida,
        'Nova partida cadastrada automaticamente.',
        CURRENT_TIMESTAMP
    );

    RETURN NEW;

END;
$$;

-- 8. TRIGGER DE HISTORICO

CREATE TRIGGER trg_historico_partidas
AFTER INSERT ON partidas
FOR EACH ROW
EXECUTE FUNCTION fn_registrar_historico();

-- 9. VIEW DO CRONOGRAMA DE PARTIDAS

CREATE OR REPLACE VIEW vw_cronograma_partidas AS
SELECT
    p.id_partida,
    p.titulo_partida,
    j.nickname,
    p.data_agendamento,
    p.status,

    GREATEST(
        0,
        CEIL(
            EXTRACT(
                EPOCH FROM
                (p.data_agendamento - CURRENT_TIMESTAMP)
            ) / 86400
        )
    ) AS dias_restantes

FROM partidas p

INNER JOIN jogadores j
    ON p.id_jogador = j.id_jogador

ORDER BY p.data_agendamento ASC;

-- 10. TESTAR AS FUNCIONALIDADES

SELECT * FROM jogadores;
SELECT * FROM jogos;
SELECT * FROM partidas;
SELECT * FROM historico_partidas;
SELECT * FROM fn_buscar_jogadores('Player');
SELECT * FROM vw_painel_principal;
SELECT * FROM vw_cronograma_partidas;
INSERT INTO partidas
(titulo_partida, id_jogador, id_jogo, data_agendamento, status)
VALUES
('Nova partida de teste', 1, 1, '2026-12-25 15:00:00', 'agendada');
SELECT * FROM historico_partidas;