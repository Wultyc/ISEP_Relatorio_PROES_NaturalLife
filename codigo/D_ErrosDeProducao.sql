USE [NaturalLife]
GO
/****** Object:  StoredProcedure [dbo].[ErrosProducao]    Script Date: 16/07/2019 08:47:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		NaturalLife
-- Create date: 03-07-2019
-- Description:	Alerta erros de produção
-- =============================================
ALTER PROCEDURE [dbo].[ErrosProducao]
AS
BEGIN
	
	IF EXISTS(SELECT
					recolhas.id,
					recolhas.data_recolha,
					recolhas.peso,
					SUM(producao.peso_cera + producao.peso_chapa + producao.peso_plastico)
				FROM producao
				INNER JOIN recolhas
					ON	recolhas.id = producao.recolhas_id
				WHERE (producao.peso_cera + producao.peso_chapa + producao.peso_plastico) > recolhas.peso
					AND producao.created_at > GETDATE()-1
				GROUP BY recolhas.id, recolhas.data_recolha, recolhas.peso)
	BEGIN
		--Declara as variaveis
		DECLARE @HTMLBody NVARCHAR(MAX),
				@tableBody NVARCHAR(MAX)

		--Cria a tabela HTML
		SET @tableBody = CONVERT(NVARCHAR(MAX), (SELECT
			(SELECT '' FOR XML PATH(''), TYPE) AS 'caption',
			(SELECT 
				'ID Recolha' AS th,
				'Data de Recolha' AS th,
				'Peso de Recolha' AS th,
				'Peso de Produção' AS th 
				FOR XML RAW('tr'), ELEMENTS, TYPE) AS 'thead',
			(

			--Inicio da Query
			SELECT
				recolhas.id AS td,
				recolhas.data_recolha AS td,
				recolhas.peso AS td,
				SUM(producao.peso_cera + producao.peso_chapa + producao.peso_plastico) AS td
			FROM producao
			INNER JOIN recolhas
				ON	recolhas.id = producao.recolhas_id
			WHERE (producao.peso_cera + producao.peso_chapa + producao.peso_plastico) > recolhas.peso
				AND producao.created_at > GETDATE()-1
			GROUP BY recolhas.id, recolhas.data_recolha, recolhas.peso
			ORDER BY recolhas.id DESC
			--Fim da Query
    
			FOR XML RAW('tr'), ELEMENTS, TYPE
			) AS 'tbody'
		FOR XML PATH(''), ROOT('table')));


		--Corpo do HTML
		SET @HTMLBody = '<html><head><style>
			table, th, td {
				border: 1px solid black;
			}
			table {
				width: 100%;
				border-collapse: collapse;
			}
			th {
				width: 25%;
				background-color: #99CCFF;
			}
			tr {
				width: 25%;
				background-color: #F1F1F1;
			}
		</style><title>Registo de Produção maior que Registo de Recolha</title></head><body>'
		--SET @HTMLBody = @HTMLBody + 'Os seguintes registos de produção superaram o peso da recolha associada<br/>'
		SET @HTMLBody = @HTMLBody + @tableBody + '</body></html>'

		--envia o email
		EXEC msdb.dbo.sp_send_dbmail 
		@profile_name = 'NaturalLife', 
		@recipients = 'naturallife@outlook.pt', 
		@subject = '[ALERTA] Registo de Produção maior que Registo de Recolha', 
		@body = @HTMLBody, 
		@body_format = 'HTML'
	END

END
