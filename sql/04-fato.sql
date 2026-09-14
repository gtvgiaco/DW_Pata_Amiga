-- =====================================================================================
--  ARQUIVO 4:  A TABELA FATO
--  Case: Pata Amiga - rede de petshops de SC  |  MySQL 8.0
-- =====================================================================================
--  Rode depois de: 03-dimensoes.sql
--
--  UMA fato, UM unico INSERT ... SELECT. A tabela ja existe, vazia (arquivo 02).
--  4.044 linhas = 4.044 pedidos.
--
--  Regra geral: a limpeza dos dados fica nas dimensoes; a fato apenas procura a
--  linha correta (por JOIN). Nenhuma FK fica nula: quando o dado falta, ela
--  aponta para a linha -1 (CASE WHEN ... IS NULL THEN -1).
--
--  Sugestao: comece pelo esqueleto (numero_pedido + as duas FKs de tempo +
--  FROM), rode e confira 4.044 linhas; depois acrescente as colunas aos poucos.
-- =====================================================================================

USE dw_pata_amiga;

-- >>> ESCREVA AQUI o INSERT INTO fato_pedido (...) SELECT ... FROM stg_pedido ...INSERT INTO fato_pedido(numero_pedido, sk_tempo_pedido, sk_tempo_entrega, sk_loja, sk_categoria, houve_desconto, canal_pedido, dt_pedido, qt_itens, vl_liquido, dias_integracao_separacao, dias_separacao_nota, dias_nota_despacho, dias_despacho_entrega, dias_total_ate_entrega)
INSERT INTO fato_pedido(
	numero_pedido,
    sk_tempo_pedido,
    sk_tempo_entrega,
    sk_loja,
    sk_categoria,
    houve_desconto,
    canal_pedido,
    dt_pedido,
    qt_itens,
    vl_liquido,
    dias_integracao_separacao,
    dias_separacao_nota,
    dias_nota_despacho,
    dias_despacho_entrega,
    dias_total_ate_entrega)
SELECT
    sp.`NumeroPedido` AS numero_pedido,
    COALESCE(CAST(
		DATE_FORMAT(    
			STR_TO_DATE(sp.DtHoraPedido, '%m/%d/%Y %h:%i %p'), -- extraindo Ano, mes e dia da coluna DtHoraPedido e transformando em inteiro
            '%Y%m%d') AS SIGNED), -1) AS sk_tempo_pedido, -- FK para dim_tempo  quando o cliente fez o pedido.
	CASE 
		WHEN sp.DtEntregaCliente IS NULL OR TRIM(sp.DtEntregaCliente) IN ('', '-') THEN -1
		ELSE CAST(DATE_FORMAT(DATE(sp.DtEntregaCliente), '%Y%m%d') AS SIGNED)
	END AS sk_tempo_entrega,
	COALESCE(dl.sk_loja, -1) as sk_loja, -- Se nao houver sk_loja, insere -1.
	COALESCE(dc.sk_categoria, -1) as sk_categoria, -- FK para dim_tempo  quando chegou ao cliente. Vale -1 se a entrega ainda não aconteceu (1.953 pedidos).
    CASE
		WHEN UPPER(TRIM(sp.HouveDesconto)) IN ('S', 'SIM', '1', 'X', 'TRUE', 'V') THEN 'Sim'
        WHEN UPPER(TRIM(sp.HouveDesconto)) IN ('N', 'NAO', '0', 'FALSE', 'F') THEN 'Nao'
        ELSE 'Nao informado'
	END AS houve_desconto,
    CASE
		WHEN UPPER(sp.CanalPedido) LIKE '%WHATS%' THEN 'WhatsApp'
        WHEN UPPER(sp.CanalPedido) LIKE '%APP%' THEN 'App'
        WHEN UPPER(sp.CanalPedido) LIKE '%SITE%' THEN 'Site'
        WHEN UPPER(sp.CanalPedido) LIKE '%LOJA%' THEN 'Loja Fisica'
        WHEN UPPER(sp.CanalPedido) LIKE '%TEL%' THEN 'Tel'
        ELSE 'Nao informado'
	END AS canal_pedido,
    STR_TO_DATE(sp.DtHoraPedido, '%m/%d/%Y %h:%i %p') AS dt_pedido,
    CASE 
		WHEN sp.`QTD.Itens` IN ('','-') OR sp.`QTD.Itens` IS NULL THEN NULL
        ELSE CAST(TRIM(sp.`QTD.Itens`) AS SIGNED) 
	END AS qt_itens,
    CASE 
		WHEN TRIM(REPLACE(sp.`ValorLiquidoPedido(R$)`, 'R$', '')) IN ('','-') THEN NULL
		WHEN sp.`ValorLiquidoPedido(R$)` LIKE '%,%'
          THEN CAST(REPLACE(REPLACE(REPLACE(REPLACE(sp.`ValorLiquidoPedido(R$)`,'R$',''),' ',''),'.',''),',','.')
               AS DECIMAL(15,2))
		ELSE CAST(REPLACE(REPLACE(sp.`ValorLiquidoPedido(R$)`,'R$',''),' ','') AS DECIMAL(15,2)) 
	END AS vl_liquido,
    
    CASE 
		WHEN sp.`DtHoraIntegracaoERP` IN ('','-') OR sp.`DtHoraIntegracaoERP` IS NULL
			OR sp.`Dt Separacao Estoque` IN ('','-') OR sp.`Dt Separacao Estoque` IS NULL THEN NULL
        ELSE DATEDIFF(
			DATE(sp.`Dt Separacao Estoque`), DATE(STR_TO_DATE(sp.`DtHoraIntegracaoERP`, '%m/%d/%Y %h:%i %p'))) 
	END AS dias_integracao_separacao,
     
    
    CASE
		WHEN sp.`DtNotaFiscal` IN ('','-') OR sp.`DtNotaFiscal` IS NULL
        OR sp.`Dt Separacao Estoque` IN ('','-') OR sp.`Dt Separacao Estoque` IS NULL THEN NULL
        ELSE DATEDIFF(DATE(sp.`DtNotaFiscal`), DATE(sp.`Dt Separacao Estoque`))
	END AS dias_separacao_nota,
	CASE
		WHEN sp.`DtNotaFiscal` IN ('','-') OR sp.`DtNotaFiscal` IS NULL
        OR sp.`Dt_Despacho_Transportadora` IN ('','-') OR sp.`Dt_Despacho_Transportadora` IS NULL THEN NULL
        ELSE DATEDIFF(DATE(sp.`Dt_Despacho_Transportadora`), DATE(sp.`DtNotaFiscal`))
	END AS dias_nota_despacho,
    CASE
		WHEN sp.`DtEntregaCliente` IN ('','-') OR sp.`DtEntregaCliente` IS NULL
        OR sp.`Dt_Despacho_Transportadora` IN ('','-') OR sp.`Dt_Despacho_Transportadora` IS NULL THEN NULL
        ELSE DATEDIFF(DATE(sp.`DtEntregaCliente`), DATE(sp.`Dt_Despacho_Transportadora`))
	END AS dias_despacho_entrega,
	CASE
		WHEN sp.`DtEntregaCliente` IN ('','-') OR sp.`DtEntregaCliente` IS NULL
        OR sp.`DtHoraIntegracaoERP` IN ('','-') OR sp.`DtHoraIntegracaoERP` IS NULL THEN NULL
        ELSE DATEDIFF(DATE(sp.`DtEntregaCliente`), DATE(STR_TO_DATE(sp.`DtHoraIntegracaoERP`, '%m/%d/%Y %h:%i %p')))
	END AS dias_total_ate_entrega
FROM stg_pedido sp
LEFT JOIN dim_categoria dc ON sp.CategoriaProduto = dc.categoria_origem
LEFT JOIN dim_loja dl ON dl.nome_loja = 
	CASE TRIM(REPLACE(REPLACE(sp.`Loja-Nome`, '/SC', ''), '  ', ' ')) -- substituindo /SC por vazio e espaços duplos por espaços simples.
		WHEN 'BLUMENAL' THEN 'Blumenau'
        WHEN 'FLORIPA' THEN 'Florianopolis'
        WHEN 'JGUA DO SUL' THEN 'Jaragua do Sul'
		ELSE TRIM(REPLACE(REPLACE(sp.`Loja-Nome`, '/SC', ''), '  ', ' ')) -- Para as cidades que estão com nome corretos após a limpeza:
	END;

--  Roteiro das colunas:
--
--  * sk_tempo_pedido / sk_tempo_entrega: a chave e a data no formato AAAAMMDD.
--    Monte com CAST(DATE_FORMAT(<a data>, '%Y%m%d') AS SIGNED). A data do PEDIDO
--    vem no formato americano com AM/PM: a mascara e '%m/%d/%Y %h:%i %p'
--    (STR_TO_DATE). Usar '%d/%m/%Y' NAO da erro - ela devolve NULL e datas
--    erradas em silencio, que e pior. Os marcos da entrega ja vem em ISO:
--    DATE() basta. Entrega em branco -> -1.
--
--  * sk_loja, sk_categoria: vem de LEFT JOIN; se nao achou par, -1.
--
--  * LOJA (LEFT JOIN dim_loja): limpe o nome no ON. REPLACE tira '/SC' e o espaco
--    duplo; um CASE resolve 3 grafias (digitacao, apelido, abreviacao). Acento e
--    maiuscula nao atrapalham: a collation padrao do MySQL trata 'Timbo', 'TIMBO'
--    e 'Timbo' com acento como o mesmo texto.
--
--  * CATEGORIA (LEFT JOIN dim_categoria): uma linha so -
--    ON dc.categoria_origem = p.`CategoriaProduto`.
--
--  * houve_desconto e canal_pedido: padronize com CASE e grave na PROPRIA fato
--    (nao ha dimensao para eles). O de-para completo dos dois campos esta no
--    ENUNCIADO, na secao 7 ("Como padronizar o desconto e o canal").
--    A ordem importa: 'WHATSAPP' contem 'APP',
--    entao teste WHATS antes de APP.
--
--  * dinheiro e itens: '' e '-' viram NULL; tire "R$" e trate o milhar.
--
--  * os lags em dias: DATEDIFF(<fim>, <inicio>). Etapa nao cumprida grava NULL,
--    nunca 0. Use DATE() em volta da integracao (ela tem hora).

-- =====================================================================================
--  Confira o resultado com o 00-conferencia.sql (bloco "DEPOIS DO 04").
-- =====================================================================================
-- P4 : Qual praça de atendimento concentra o faturamento? Atenção: uma loja entrega em mais de uma praça. O rateio precisa ser feito pelo percentual do público,
-- e a soma por praça tem de fechar com o faturamento da rede. Cruze o faturamento rateado com o número de domicílios com pet de cada praça.

SELECT 
	dp.nome_praca,
	dp.domicilios_com_pet,
	ROUND(SUM(fp.vl_liquido * b.fator_publico), 2) AS faturamento
FROM fato_pedido fp
LEFT JOIN dim_loja dl ON fp.sk_loja = dl.sk_loja
LEFT JOIN bridge_loja_praca b ON dl.cod_loja = b.cod_loja
LEFT JOIN dim_praca dp ON b.sk_praca = dp.sk_praca
GROUP BY dp.nome_praca, dp.domicilios_com_pet
ORDER BY faturamento DESC;


-- P5 : Onde abrir a próxima loja, e o que os dados NÃO permitem afirmar? 
-- Ranqueie as lojas por itens vendidos por mil habitantes da cidade  não em valor absoluto  e cruze com o tempo médio de entrega. 
SELECT 
	dl.nome_loja,
    SUM(fp.qt_itens) AS total_itens_vendidos,
    SUM(fp.qt_itens) / (dl.populacao_cidade / 100) AS itens_por_mil_habitantes,
    AVG(dias_total_ate_entrega)
FROM fato_pedido fp
JOIN dim_loja dl ON fp.sk_loja = dl.sk_loja
GROUP BY dl.nome_loja, dl.populacao_cidade
ORDER BY itens_por_mil_habitantes DESC;
 
-- A faixa de franquia no cadastro é a de hoje: o passado foi sobrescrito. Mostre o faturamento por faixa ATUAL e explique por que isso não responde “quanto veio de lojas que JÁ ERAM Ouro na data do pedido”.

SELECT 
    dl.faixa_franquia,
    SUM(fp.vl_liquido) AS faturamento,
    ROUND((SUM(fp.vl_liquido) / (SELECT SUM(vl_liquido) FROM fato_pedido)) * 100, 2) AS percentual
FROM fato_pedido fp
JOIN dim_loja dl ON fp.sk_loja = dl.sk_loja
GROUP BY dl.faixa_franquia
ORDER BY faturamento DESC;

-- Meça o que ficou de fora: pedidos sem loja identificada, entregas ainda não concluídas, itens e valores em branco.
SELECT
	SUM(CASE WHEN sk_loja = '-1' THEN 1 ELSE 0 END) AS pedidos_sem_loja,
    SUM(CASE WHEN sk_tempo_entrega = '-1' THEN 1 ELSE 0 END) AS entregas_nao_concluidas,
    SUM(CASE WHEN qt_itens IS NULL THEN 1 ELSE 0 END) AS itens_em_branco,
    SUM(CASE WHEN vl_liquido IS NULL THEN 1 ELSE 0 END) AS valores_em_branco
FROM fato_pedido;