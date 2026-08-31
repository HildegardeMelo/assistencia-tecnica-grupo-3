-- ========================================================
-- BANCO DE DADOS: ASSISTÊNCIA TÉCNICA (TECHFIX OS)
-- ========================================================

-- 1. TABELA DE CLIENTES
CREATE TABLE clientes (
    id_cliente INT AUTO_INCREMENT PRIMARY KEY,
    nome_completo VARCHAR(150) NOT NULL,
    cpf VARCHAR(14) UNIQUE NOT NULL,
    email VARCHAR(100) NOT NULL,
    telefone VARCHAR(20) NOT NULL,
    endereco VARCHAR(255),
    data_cadastro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. TABELA DE TÉCNICOS / ATENDENTES
CREATE TABLE usuarios (
    id_usuario INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    senha_hash VARCHAR(255) NOT NULL,
    perfil ENUM('Atendente', 'Tecnico', 'Gerente') DEFAULT 'Tecnico'
);

-- 3. TABELA DE ORDENS DE SERVIÇO (OS)
CREATE TABLE ordens_servico (
    id_os INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    id_tecnico INT,
    tipo_servico ENUM('Express_1h', 'Analise_Completa') NOT NULL,
    equipamento VARCHAR(100) NOT NULL,
    num_serie_imei VARCHAR(100),
    relato_cliente TEXT,
    laudo_tecnico TEXT,
    
    -- Status do fluxo de atendimento
    status ENUM(
        'Aguardando_Analise', 
        'Orcamento_Pendente', 
        'Aprovado', 
        'Recusado', 
        'Aguardando_Peca', 
        'Em_Reparo', 
        'Pronto', 
        'Finalizado_Entregue', 
        'Arquivado'
    ) DEFAULT 'Aguardando_Analise',
    
    -- Financeiro e Prazos
    valor_mao_de_obra DECIMAL(10, 2) DEFAULT 0.00,
    valor_pecas DECIMAL(10, 2) DEFAULT 0.00,
    valor_total DECIMAL(10, 2) DEFAULT 0.00,
    pago BOOLEAN DEFAULT FALSE,
    link_pagamento VARCHAR(255),
    nota_fiscal_num VARCHAR(50),
    
    -- Garantia Legal e Arquivamento (90 dias)
    data_abertura TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_aprova_orcamento TIMESTAMP NULL,
    data_entrega TIMESTAMP NULL,
    data_expira_garantia DATE NULL, -- Calculado: data_entrega + 90 dias
    
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    FOREIGN KEY (id_tecnico) REFERENCES usuarios(id_usuario)
);

-- 4. CHECKLIST DE ENTRADA DO APARELHO
CREATE TABLE os_checklist (
    id_checklist INT AUTO_INCREMENT PRIMARY KEY,
    id_os INT NOT NULL,
    riscos_marcas BOOLEAN DEFAULT FALSE,
    tela_trincada BOOLEAN DEFAULT FALSE,
    sinais_oxidacao BOOLEAN DEFAULT FALSE,
    liga_sem_imagem BOOLEAN DEFAULT FALSE,
    observacoes_vistoria TEXT,
    FOREIGN KEY (id_os) REFERENCES ordens_servico(id_os) ON DELETE CASCADE
);

-- 5. FOTOS E VÍDEOS DA OS (ENTRADA E CONCLUSÃO)
CREATE TABLE os_midias (
    id_midia INT AUTO_INCREMENT PRIMARY KEY,
    id_os INT NOT NULL,
    tipo_midia ENUM('Foto_Entrada', 'Foto_Conclusao', 'Video_Teste') NOT NULL,
    url_arquivo VARCHAR(255) NOT NULL,
    data_upload TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_os) REFERENCES ordens_servico(id_os) ON DELETE CASCADE
);

-- 6. ITENS DO ORÇAMENTO E PEÇAS
CREATE TABLE os_itens_orcamento (
    id_item INT AUTO_INCREMENT PRIMARY KEY,
    id_os INT NOT NULL,
    descricao VARCHAR(150) NOT NULL,
    origem_peca ENUM('Loja', 'Importacao', 'Fornecida_Pelo_Cliente') DEFAULT 'Loja',
    valor_unitario DECIMAL(10, 2) NOT NULL,
    dias_garantia_peca INT DEFAULT 90, -- Peça do cliente fica com 0 dias loja
    FOREIGN KEY (id_os) REFERENCES ordens_servico(id_os) ON DELETE CASCADE
);

-- 7. LOJA DE ACESSÓRIOS (VITRINE DO CHECKOUT)
CREATE TABLE acessorios (
    id_acessorio INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    compatibilidade_modelo VARCHAR(100) NOT NULL, -- Ex: 'iPhone 13', 'Notebook Dell'
    preco DECIMAL(10, 2) NOT NULL,
    estoque INT DEFAULT 0
);

-- ========================================================
-- AUTOMAÇÃO DE ARQUIVAMENTO AUTOMÁTICO (DIA 91)
-- ========================================================

-- Evento agendado diariamente para arquivar OS com garantia vencida (> 90 dias)
DELIMITER //
CREATE EVENT IF NOT EXISTS arquivar_os_vencidas
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_DATE
DO
BEGIN
    UPDATE ordens_servico
    SET status = 'Arquivado'
    WHERE status = 'Finalizado_Entregue'
      AND data_expira_garantia < CURRENT_DATE();
END//
DELIMITER ;
