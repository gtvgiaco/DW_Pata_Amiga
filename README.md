## Data Warehouse - Case Pata Amiga

Este projeto é uma atividade avaliativa do curso de análise de dados do SCTEC, módulo 2. 
O objeto é implementar um Data warehouse para a rede de petshops **Pata Amiga**.

O projeto contempla a modelagem dimensional, tratamento de dados de staging, carga da tabela fato/dimensões e respostas orientadas a perguntas de negócio usando o MySQL.


##  Sumário
1. [Sobre o Case](#-sobre-o-case)
2. [Arquitetura e Modelo Dimensional](#-arquitetura-e-modelo-dimensional)
3. [Diagnóstico da Origem (Tarefa 1)](#-diagnóstico-da-origem-tarefa-1)
4. [Ordem de Execução dos Scripts SQL](#-ordem-de-execução-dos-scripts-sql)
5. [Respostas às Perguntas de Negócio](#-respostas-às-perguntas-de-negócio)

---

## Sobre o Case

A **Pata Amiga** é uma rede varejista do setor pet. O objetivo deste projeto é consolidar os dados operacionais dispersos em uma arquitetura dimensional otimizada em MySQL 8.0, permitindo análises precisas sobre faturamento, logística de entregas, desempenho de canais de vendas, impacto de descontos e expansão geográfica.

---

##  Arquitetura e Modelo Dimensional

O modelo adotado é o **Star Schema (Esquema Estrela)** centrado na tabela fato de pedidos (`fato_pedido`), operando no grão **1 linha = 1 pedido** (totalizando 4.044 registros válidos).

### Características Principais do Modelo:

- A tabela `dim_tempo` é conectada duas vezes à fato (`sk_tempo_pedido` e `sk_tempo_entrega`), permitindo analisar independentemente a data da compra e a data de conclusão da entrega.

- Como uma loja atende a múltiplas praças com diferentes pesos de atendimento, utiliza-se a tabela `bridge_loja_praca` ligada pelo código natural da loja (`cod_loja`) para realizar o rateio proporcional correto sem distorcer o modelo.

- Nenhuma chave estrangeira (FK) na tabela fato assume valores nulos; registros ausentes ou corrompidos apontam para a linha padrão `-1` ("Não Informado").

> **Diagrama do Modelo Estrela:**
> ![Modelo Dimensional](./diagrama_estrela.png)
> *(Nota: Certifique-se de salvar a imagem do seu diagrama com o nome `diagrama_estrela.png` na mesma pasta do README no GitHub).*

---

## Diagnóstico da Origem (Tarefa 1)


As tabelas de staging estão com vários problemas nos dados.

- **Grafias de Lojas e Categorias:** Existiam variações de digitação, abreviações (ex: *Blumenal*, *Floripa*, *Jgua do Sul*) e inclusão de sufixos de estado (`/SC`) que necessitaram de padronização via regras condicionais (`CASE WHEN` e `REPLACE`).
* **Marcos de Processo em Branco:** Foram mapeados diversos registros com etapas operacionais pendentes na origem, traduzidos adequadamente para valores nulos (`NULL`) para não corromper os cálculos de *lags* em dias:
  * Separação de Estoque em branco: **1.077** pedidos.
  * Emissão de Nota Fiscal em branco: **1.338** pedidos.
  * Despacho na Transportadora em branco: **1.665** pedidos.
  * Entrega ao Cliente em branco: **1.953** pedidos (pedidos em andamento).

---

## Ordem de Execução dos Scripts SQL

Para reproduzir o banco de dados do zero em um ambiente MySQL 8.0, execute os arquivos na seguinte sequência lógica:

1. **`01-carga-staging.sql`** *(Fornecido pelo case)*: Cria o banco de dados `dw_pata_amiga` e carrega as tabelas de staging brutas (`stg_pedido`).
2. **`02-dimensoes-e-estruturas.sql`**: Configura a `dim_tempo` (já populada), a `dim_loja` e inicializa as estruturas vazias das tabelas `dim_categoria`, `dim_praca`, `bridge_loja_praca` e `fato_pedido`.
3. **`03-carga-dimensoes.sql`**: Popula as dimensões auxiliares aplicando as limpezas de texto e regras de negócio.
4. **`04-carga-fato.sql`**: Executa a carga única (`INSERT INTO ... SELECT`) da tabela `fato_pedido`, aplicando as conversões de datas americanas, formatação de valores monetários, tratamento de nulos para `-1` e cálculo dos tempos de processo (`DATEDIFF`).

---

## Respostas às Perguntas de Negócio

### P1: Onde está o gargalo da entrega?
* **Tempo médio geral:** O ciclo completo de ponta a ponta (do pedido na base até a casa do cliente) leva em média **9 dias**.
* **Intervalo mais lento:** O processo mais crítico é a etapa de **Nota Fiscal → Despacho**, com uma média de **4,11 dias**.
* **Análise por Porte:** O gargalo permanece sendo o mesmo em todos os portes de loja, porém as **lojas de porte pequeno** sofrem com uma lentidão severa nessa mesma etapa (média de **8,53 dias**, contra ~3,3 dias nas médias e grandes).

### P2: Qual categoria concentra o faturamento?
* **Categoria Campeã:** A categoria de **Ração** lidera de forma absoluta o faturamento da rede em **todos os três portes de loja** (Pequena, Média e Grande).

### P3: O desconto funciona igual em todo canal?
* **Impacto do Desconto:** Os dados provam que a aplicação de descontos **derruba o ticket médio em todos os canais de venda** da rede, indicando que a política atual carece de revisão estratégica.
* **Participação por Canal:**
  * **App:** 30,79% do faturamento (Ticket médio com vs. sem desconto)
  * **Site:** 25,13% do faturamento
  * **Loja Física:** 20,11% do faturamento
  * **WhatsApp:** 10,53% do faturamento
  * **Telefone:** 6,88% do faturamento
  * **Não Informado / Outros:** 6,57% do faturamento

### P4: Qual praça de atendimento concentra o faturamento?
* **Praça Líder:** A região do **Vale do Itajaí** concentra o maior faturamento rateado.
* **Nota de Auditoria:** Houve uma diferença de **R$ 58.047,36** entre o faturamento total da rede bruta (R$ 1.793.308,51) e a soma do rateio por praças (R$ 1.735.261,16). Essa variação ocorre estritamente devido a pedidos oriundos de lojas sem código e nome identificados na origem, que portanto não encontraram correspondência na tabela ponte.

### P5: Onde abrir a próxima loja e limitações analíticas
* **Ranking de Expansão:** O ranqueamento por itens vendidos por mil habitantes cruzado com o tempo de entrega aponta as praças com maior densidade de consumo per capita e eficiência logística.
* **Limitação da Faixa de Franquia (SCD Tipo 1):** Analisar o faturamento pela faixa atual de franquia **não** responde "quanto veio de lojas que já eram Ouro na data do pedido", pois o banco sofre de sobrescrita de histórico (o cadastro guarda apenas o status atual, mascarando o porte que a loja possuía no momento da venda no passado).
* **Auditoria de Exclusões:**
  * Pedidos sem loja identificada (chave `-1`): **0** (tratados na carga).
  * Entregas não concluídas (`sk_tempo_entrega = -1`): **1.953** pedidos.
  * Itens em branco/nulos: **0** (validados/tratados).
  * Valores em branco/nulos: **0** (validados/tratados).

### TAREFA 1 - DIAGNÓSTICO DA ORIGEM

Quantas grafias de loja existem? 
- Existem 50 grafias diferentes. Sao 32 lojas, portanto existem grafias diferentes para a mesma loja.

SELECT COUNT(distinct `Loja-Nome`) from stg_pedido;

Quantas de categoria?
- Existem 18 grafias diferentes. 
Sendo 4 para Medicamento, 3 para Racao, 2 para Acessorio, 2 para Servico, 2 para Brinquedo, 3 para Higiene e 2 para Petisco.

SELECT COUNT(distinct CategoriaProduto) from stg_pedido;
SELECT distinct CategoriaProduto from stg_pedido;

Quantos pedidos vieram sem código de loja? 
- Existem 1575 pedidos que estão sem o código da loja.

Select count(*) from stg_pedido
where `Cod Loja` = '';

Quantos sem nome de loja? 
- 3 pedidos estão sem nome da Loja.

Select count(*) from stg_pedido
where `Loja-Nome`= '';

Quantos marcos de processo estão em branco? 
- 	-- Resposta: 
	-- separacaçao estoque = 1077 em branco
	-- emissao nf = 1338
	-- despacho transportadora = 1665 em branco
	-- entrega gratis = 1953 em branco

SELECT 
	SUM(CASE WHEN `Dt Separacao Estoque` IS NULL OR `Dt Separacao Estoque` = '' THEN 1 ELSE 0 END) AS em_branco_separacao_estoque,
	SUM(CASE WHEN `DtNotaFiscal` IS NULL OR `DtNotaFiscal` = '' THEN 1 ELSE 0 END) AS em_branco_emissao_nf,
    SUM(CASE WHEN `Dt_Despacho_Transportadora` IS NULL OR `Dt_Despacho_Transportadora` = '' THEN 1 ELSE 0 END) AS em_branco_despacho_transportadora,
    SUM(CASE WHEN `DtEntregaCliente` IS NULL OR `DtEntregaCliente` = '' THEN 1 ELSE 0 END) AS em_branco_entrega_cliente	
FROM stg_pedido;




### TAREFA 2 - TRATAMENTO

#### Populando tabela dim_categoria

INSERT INTO dim_categoria VALUES
(-1, "Nao Informado", "Nao Informado", "Nao Informado");

INSERT INTO dim_categoria(categoria_origem, nome_categoria, grupo_categoria)

SELECT DISTINCT 

	CategoriaProduto as categoria_origem,
    CASE
		WHEN UPPER(CategoriaProduto) LIKE '%MED%' THEN 'Medicamento'
        WHEN UPPER(CategoriaProduto) LIKE '%PESTIC%' THEN 'Petisco'
        WHEN UPPER(CategoriaProduto) LIKE '%RA%' THEN 'Racao'
        WHEN UPPER(CategoriaProduto) LIKE '%HIG%' THEN 'Higiene'
        WHEN UPPER(CategoriaProduto) LIKE '%BRINQ%' THEN 'Brinquedo'
        WHEN UPPER(CategoriaProduto) LIKE '%ACESS%' THEN 'Acessorio'
        WHEN UPPER(CategoriaProduto) LIKE '%SERV%' THEN 'Servico'
        ELSE 'Nao informado'
	END AS nome_categoria,
    CASE
		WHEN UPPER(CategoriaProduto) LIKE '%MED%' OR UPPER(CategoriaProduto) LIKE '%HIG%' THEN 'Saude e Higiene'
        WHEN UPPER(CategoriaProduto) LIKE '%PESTIC%' OR UPPER(CategoriaProduto) LIKE '%RA%' THEN 'Alimentacao'
        WHEN UPPER(CategoriaProduto) LIKE '%BRINQ%' OR UPPER(CategoriaProduto) LIKE '%ACESS%' OR UPPER(CategoriaProduto) LIKE '%SERV%' THEN 'Bem-estar'
        ELSE 'Nao informado'
	END AS grupo_categoria
    FROM stg_pedido;

 #### Populando tabela dim_categoria 

 INSERT INTO dim_praca VALUES
(-1, '-1', 'Nao Informado', 'Nao Informado', NULL);
 
 INSERT INTO dim_praca(cod_praca, nome_praca, regional, domicilios_com_pet) 
SELECT
	CodPraca as cod_praca,
    MAX(NomePraca) as nome_praca,
    MAX(Regional) as regional,
    CAST(Replace(MAX(DomiciliosComPet), '.', '') AS SIGNED) AS domicilios_com_pet
FROM stg_loja_praca
GROUP BY CodPraca;

#### Populando a tabela bridge_loja_praca

INSERT INTO bridge_loja_praca  (cod_loja, sk_praca, fator_publico)
SELECT
	s.CodLoja as cod_loja,
    d.sk_praca as sk_praca,
    CAST(REPLACE(s.PercentualPublico, ',' , '.') AS DECIMAL(5,2)) AS fator_publico
FROM stg_loja_praca s
INNER JOIN dim_praca d 
ON s.CodPraca = d.cod_praca;

____________________________________________
### PERGUNTAS DE NEGOCIO 

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

![alt text](image.png)
