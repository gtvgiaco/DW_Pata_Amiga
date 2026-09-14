-- =====================================================================================
--  ARQUIVO 5:  AS CINCO PERGUNTAS DE NEGOCIO
--  Case: Pata Amiga - rede de petshops de SC  |  MySQL 8.0
-- =====================================================================================
--  Rode depois de: 04-fato.sql
--
--  Cada pergunta e UMA consulta: um SELECT com JOIN e GROUP BY. A subconsulta
--  aparece na P2 e na P5, e serve para trazer o total da rede como denominador.
-- =====================================================================================

USE dw_pata_amiga;

-- =====================================================================================
--  P1 - ONDE ESTA O GARGALO DO PROCESSO DE ENTREGA?
-- =====================================================================================
--  Media (AVG) dos quatro intervalos ja calculados na carga, agrupada por porte
--  de loja. AVG ignora NULL - por isso a etapa nao cumprida foi gravada como NULL.
--  dias_total_ate_entrega e o processo inteiro, nao um dos quatro intervalos.
SELECT	
    ROUND(AVG(dias_integracao_separacao), 2) AS media_integracao_separacao,
    ROUND(AVG(dias_separacao_nota), 2) AS media_separacao_nota,
    ROUND(AVG(dias_nota_despacho), 2) AS media_nota_despacho,
    ROUND(AVG(dias_despacho_entrega), 2) AS media_despacho_entrega,
    ROUND(AVG(dias_total_ate_entrega), 2) AS media_pedido_entrega
FROM fato_pedido;
-- Resposta: o tempo medio em dias para uma entrega são 9 dias. O processo mais lento é Nota -> Despacho, com media de 4,11 dias.

-- O gargalo é o mesmo nos três portes de loja?
SELECT
	dl.porte AS porte_loja,
	ROUND(AVG(dias_integracao_separacao), 2) AS media_integracao_separacao,
    ROUND(AVG(dias_separacao_nota), 2) AS media_separacao_nota,
    ROUND(AVG(dias_nota_despacho), 2) AS media_nota_despacho,
    ROUND(AVG(dias_despacho_entrega), 2) AS media_despacho_entrega,
    ROUND(AVG(dias_total_ate_entrega), 2) AS media_pedido_entrega
FROM fato_pedido fp
LEFT JOIN dim_loja dl 
ON fp.sk_loja = dl.sk_loja
GROUP BY dl.porte;

-- Resposta: o gargalo é o mesmo em todos os portes de loja (nota -> despacho) mas observa-se que na loja de porte pequeno a media dessa operação é muito superior (8,53 dias) 
-- do que nas lojas de porte medio e grande (~3,3 dias). 



-- =====================================================================================
--  P2 - QUAL CATEGORIA CONCENTRA O FATURAMENTO?
-- =====================================================================================
--  Esta e a pergunta que paga a dim_categoria. Agrupe pelo nome_categoria
--  PADRONIZADO (nunca pela grafia crua). O percentual do total usa uma
--  subconsulta com o faturamento da rede como denominador.
SELECT
	dc.nome_categoria AS categoria_produto,
    SUM(fp.vl_liquido) AS faturamento,
    ROUND(SUM(fp.vl_liquido) / (SELECT SUM(vl_liquido) FROM fato_pedido), 2) * 100 AS percentual
FROM fato_pedido fp
LEFT JOIN dim_categoria dc ON fp.sk_categoria = dc.sk_categoria
GROUP BY dc.nome_categoria
ORDER BY faturamento DESC;
	
-- A categoria campeã é a mesma nos três portes de loja?
SELECT
	dl.porte AS porte_loja,
	dc.nome_categoria AS categoria_produto,
    SUM(fp.vl_liquido) AS faturamento,
    ROUND((SUM(fp.vl_liquido) / (SELECT SUM(vl_liquido) FROM fato_pedido)) * 100, 2) AS percentual
FROM fato_pedido fp
LEFT JOIN dim_categoria dc ON fp.sk_categoria = dc.sk_categoria
LEFT JOIN dim_loja dl ON fp.sk_loja = dl.sk_loja
GROUP BY dl.porte, dc.nome_categoria
ORDER BY dl.porte, faturamento DESC;

-- Resposta: A racao tem o maior faturamento em todos os portes de lojas


-- =====================================================================================
--  P3 - O DESCONTO FUNCIONA IGUAL EM TODO CANAL?
-- =====================================================================================
--  Aqui NAO ha JOIN: desconto e canal foram padronizados na carga e moram na
--  propria fato. Compare o TICKET MEDIO com e sem desconto DENTRO de cada canal.
--  Confira se o WhatsApp aparece - se nao, o CASE do arquivo 04 testou APP antes
--  de WHATS.
-- P3 : O desconto funciona igual em todo canal? Compare o ticket médio COM e SEM desconto dentro de cada canal de venda (App, Site, Loja Física, Telefone, WhatsApp).
-- Se o desconto derruba o ticket em um canal e não em outro, a política não deveria ser a mesma nos dois. Diga também quanto cada canal representa do faturamento.

SELECT 
	canal_pedido AS canal_venda,
    ROUND(AVG(CASE WHEN houve_desconto = 'Sim' THEN vl_liquido END), 2) AS ticket_medio_com_desconto,
    ROUND(AVG(CASE when houve_desconto = 'Nao' THEN vl_liquido END), 2) AS ticket_medio_sem_desconto,
    SUM(vl_liquido) AS faturamento,
    ROUND(SUM(vl_liquido) / (SELECT SUM(vl_liquido) FROM fato_pedido) * 100, 2) AS percentual_canal
FROM fato_pedido
GROUP BY canal_pedido
ORDER BY faturamento DESC;

-- RESPOSTA: o desconto derruba o ticket medio de todos os canais de venda.
-- APP: 30.79% / SITE: 25,13% / LOJA FISICA: 20,11% / WHATSAPP: 10,525% / TEL: 6,88% / N/I: 6,57%


-- =====================================================================================
--  P4 - QUAL PRACA DE ATENDIMENTO CONCENTRA O FATURAMENTO?
-- =====================================================================================
--  Esta e a pergunta que paga a dim_praca e a ponte.
--  Caminho: fato_pedido -> dim_loja -> bridge_loja_praca -> dim_praca (a ponte
--  entra pelo cod_loja). O JOIN com a ponte DUPLICA a linha do pedido, uma por
--  praca - isso esta certo. Multiplique por b.fator_publico para o faturamento
--  nao ser contado duas vezes.
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

-- A praca que mais faturou e Vale do Itajai.
-- OBS: deu uma diferença de R$ 58047,36 entre o faturamento desse Select e o faturamento do SELECT SUM(vl_liquido) FROM fato_pedido; Essa diferença é referente ap lojas com codigo e nome nao informados.

-- =====================================================================================
--  P5 - ONDE ABRIR A PROXIMA LOJA, E O QUE OS DADOS NAO PERMITEM AFIRMAR?
-- =====================================================================================
--  (a) Ranqueie as lojas por itens POR MIL HABITANTES (numerador na fato,
--      denominador na dimensao), calculado AQUI na consulta - nunca gravado
--      pronto. Cruze com o tempo medio de entrega.
--  (b) Mostre o faturamento por faixa de franquia e explique por que ele NAO
--      responde "quanto veio de lojas que JA ERAM Ouro na data do pedido": o
--      cadastro so tem a foto de hoje.
--  (c) Meca o que ficou de fora: pedidos sem loja, entregas nao concluidas,
--      itens e valores em branco.

-- P5 : Onde abrir a próxima loja, e o que os dados NÃO permitem afirmar? 
-- Ranqueie as lojas por itens vendidos por mil habitantes da cidade  não em valor absoluto  e cruze com o tempo médio de entrega. 
SELECT 
	dl.nome_loja,
    SUM(fp.qt_itens) AS total_itens_vendidos,
    ROUND(SUM(fp.qt_itens) / (dl.populacao_cidade / 100), 2) AS itens_por_mil_habitantes,
    ROUND(AVG(dias_total_ate_entrega), 2) AS dias_total_ate_entrega
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
