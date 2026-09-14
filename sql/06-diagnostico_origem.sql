-- ARQUIVO 6 -- DIAGNOSTICO DE ORIGEM
USE dw_pata_amiga;


SELECT
    COUNT(DISTINCT `Loja-Nome`) AS total_grafias_loja,    
    COUNT(DISTINCT CategoriaProduto) AS total_grafias_categoria,
    COUNT(CASE WHEN `Cod Loja` IS NULL OR TRIM(`Cod Loja`) = '' THEN 1 END) AS pedidos_sem_cod_loja,
    COUNT(CASE WHEN `Loja-Nome` IS NULL OR TRIM(`Loja-Nome`) = '' THEN 1 END) AS pedidos_sem_nome_loja
FROM stg_pedido;

-- Quantos marcos de processo estão em branco? 
SELECT 
	SUM(CASE WHEN `Dt Separacao Estoque` IS NULL OR `Dt Separacao Estoque` = '' THEN 1 ELSE 0 END) AS em_branco_separacao_estoque,
	SUM(CASE WHEN `DtNotaFiscal` IS NULL OR `DtNotaFiscal` = '' THEN 1 ELSE 0 END) AS em_branco_emissao_nf,
    SUM(CASE WHEN `Dt_Despacho_Transportadora` IS NULL OR `Dt_Despacho_Transportadora` = '' THEN 1 ELSE 0 END) AS em_branco_despacho_transportadora,
    SUM(CASE WHEN `DtEntregaCliente` IS NULL OR `DtEntregaCliente` = '' THEN 1 ELSE 0 END) AS em_branco_entrega_cliente	
FROM stg_pedido;


