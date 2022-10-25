-- dbo.FACTACTIVESALESPRICEV2 source

ALTER VIEW [dbo].[FACTACTIVESALESPRICEV2] AS
--THIS VIEW IS ONLY FOR REFERENCE
--ACTUAL USAGE IS USING DATAFLOW DUE TO PERFORMANCE CONCERN , PLEASE REFER TO DATAFLOW'S FACTACTIVESALESPRICE
SELECT
            A.DATAAREAID
          , a.recid
          , A.DATAAREAID + A.ITEMRELATION																AS FK_ITEMID
          , CASE WHEN A.ACCOUNTCODE = 0 THEN A.DATAAREAID + A.ACCOUNTRELATION 
				ELSE CONVERT(NVARCHAR(60), '')  
			END																							AS FK_CUSTACCOUNT 
		  , CASE WHEN A.ACCOUNTCODE = 1 THEN A.DATAAREAID + A.ACCOUNTRELATION 
				ELSE CONVERT(NVARCHAR(60), '') 
			END																							AS FK_CUSTPRICEGROUP
		   , CASE WHEN A.ACCOUNTCODE = 1 THEN A.DOT_ACCOUNTRELATIONNAME	ELSE '' END     				AS [CUSTOMER GROUP NAME]
          , CONVERT(DATE, A.FROMDATE)																	AS [FROM DATE]
          , CONVERT(DATE, ISNULL(NULLIF (A.TODATE, '1 JAN 1900'), DATEFROMPARTS(2099, 12, 31)))			AS [TO DATE]
          , A.CURRENCY
		  , A.UNITID                                                                                      AS [UNIT]
          , A.AMOUNT                                                                                      AS [SALES PRICE]
		  , ROUND(INVENT.DOTAPPROVALBASEPRICE * ISNULL(NULLIF (SALE_UOM_FACTOR.FACTOR, 0), 1), 2)         AS [BASE COST PRICE FOR APPROVAL]  
		  , CASE 
				WHEN INVENT.DOTAPPROVALBASEPRICE = 0 THEN 1
				ELSE  ROUND(A.AMOUNT  /
						ROUND(INVENT.DOTAPPROVALBASEPRICE *
							ISNULL(NULLIF (SALE_UOM_FACTOR.FACTOR, 0), 1)
							, 2)	
						- 1 
					  ,4)
			END																							 AS [MARKUP%]  --ACTUAL MARKUP
			
		  , ROUND( B.DOT_MINMARKUPPCT /100  , 4)                                                         AS [MINIMUM MARKUP%]
		  , CASE WHEN 
		  		--GET ACTUAL MARKUP 
				CASE 
					WHEN INVENT.DOTAPPROVALBASEPRICE = 0 THEN 1
					ELSE  ROUND(A.AMOUNT  /
							ROUND(INVENT.DOTAPPROVALBASEPRICE *
								ISNULL(NULLIF (SALE_UOM_FACTOR.FACTOR, 0), 1)
								, 2)	
							- 1 
						  ,4)
				END		
			    > ROUND( B.DOT_MINMARKUPPCT /100  , 4) --GET MINIMUM MARKUP
			THEN 'OK'
			ELSE 'NOT-OK' END AS [IS MARKUP OK]
		  , ROUND(INVENT.DOTAPPROVALBASEPRICE * ISNULL(NULLIF (SALE_UOM_FACTOR.FACTOR, 0), 1) 
					/ ISNULL(NULLIF ((1 - B.DOT_MINMARKUPPCT / 100), 0), 1), 2)							  AS [MINIMUM SALES PRICE]
          
		 , CASE 
				WHEN A.AMOUNT = 0 THEN 1
				ELSE  ROUND(1- (
							ROUND(INVENT.DOTAPPROVALBASEPRICE *
								ISNULL(NULLIF (SALE_UOM_FACTOR.FACTOR, 0), 1)
								, 2)	
							/ A.AMOUNT )	, 4)				  
			END																							  AS [MARGIN%]
          , CONVERT(DECIMAL, ISNULL(NULLIF (SALE_UOM_FACTOR.FACTOR, 0), 1))                               AS [UNIT CONVERSION]
          , INVENT.UNITID                                                                                 AS [INVENTORY UNIT]
          , CASE WHEN --GET ACTUAL MARGIN COMPARED WITH STD MARKUP
				CASE 
				WHEN A.AMOUNT = 0 THEN 1
				ELSE  ROUND(1- (
							ROUND(INVENT.DOTAPPROVALBASEPRICE *
								ISNULL(NULLIF (SALE_UOM_FACTOR.FACTOR, 0), 1)
								, 2)	
							/ A.AMOUNT )	, 4)
				END 	> ROUND( B.DOT_MINMARKUPPCT /100  , 4) --GET MINIMUM MARKUP			  
			THEN 'OK'
			ELSE 'NOT-OK' END AS [IS MARGIN OK]
          , A.PRICEUNIT
            
          
          , B.DOT_MINSALESPRICE
          , INVENT.DOTAPPROVALBASEPRICE
            /*,SALES.PRICEDATE AS SALES_BASEPRICEDATE */
		, dateadd(MINUTE, datediff(MINUTE, 0, getdate() ), 0) as dwDateTimeStamp
		, (select top 1 X.label  from FXBISVR.AXEDWH.DBO.axbaseenum   x where x.ENUMNAME = 'tablegroupall'and x.value = A.ACCOUNTCODE) as [ACCOUNT CODE]
		, (select top 1 X.label  from FXBISVR.AXEDWH.DBO.AXBASEENUM   x where x.ENUMNAME = 'tablegroupall'and x.value = A.ITEMCODE) as [ITEM CODE]
		, COALESCE(C.FK_HCMWORKER, C2.FK_HCMWORKER) AS FK_HCMWORKER
		

FROM
            FXSQLSVR.AXDB.DBO.PRICEDISCTABLE A WITH (NOLOCK)
            INNER JOIN
              FXSQLSVR.AXDB.DBO.INVENTTABLE B WITH (NOLOCK)
                        ON
                                    B.DATAAREAID    = A.DATAAREAID
                                    AND B.ITEMID    = A.ITEMRELATION
                                    AND b.PARTITION = A.PARTITION
            INNER JOIN
                        FXSQLSVR.AXDB.DBO.INVENTTABLEMODULE INVENT WITH (NOLOCK)
                        ON
                                    INVENT.DATAAREAID     = B.DATAAREAID
                                    AND INVENT.ITEMID     = B.ITEMID
                                    AND INVENT.PARTITION  = B.PARTITION
                                    AND INVENT.MODULETYPE = 0
			
            INNER JOIN
                        FXSQLSVR.AXDB.DBO.UNITOFMEASURE UOMINVENT WITH (NOLOCK)
                        ON
                                    UOMINVENT.SYMBOL        = INVENT.UNITID
                                    AND UOMINVENT.PARTITION = INVENT.PARTITION
            INNER JOIN
                        FXSQLSVR.AXDB.DBO.INVENTTABLEMODULE SALES WITH (NOLOCK)
                        ON
                                    SALES.DATAAREAID     = B.DATAAREAID
                                    AND SALES.ITEMID     = B.ITEMID
                                    AND SALES.MODULETYPE = 2
                                    AND SALES.PARTITION  = B.PARTITION
            INNER JOIN
                        FXSQLSVR.AXDB.DBO.UNITOFMEASURE UOMSALE WITH (NOLOCK)
                        ON
                                    UOMSALE.SYMBOL = A.UNITID
            OUTER APPLY
                        (
                               SELECT
                                      TOP 1 FACTOR
                               FROM
                                      FXSQLSVR.AXDB.DBO.UNITOFMEASURECONVERSION UOMFACTSALES WITH (NOLOCK)
                               WHERE
                                      UOMFACTSALES.FROMUNITOFMEASURE   = UOMSALE.RECID
                                      AND UOMFACTSALES.TOUNITOFMEASURE = UOMINVENT.RECID
                                      AND UOMFACTSALES. PRODUCT        = B. PRODUCT
                                      AND UOMFACTSALES.PARTITION       = B.PARTITION
                        )
                        AS SALE_UOM_FACTOR
           OUTER APPLY (SELECT TOP 1 C.DOT_CUSTOMERSERVICEWORKER AS FK_HCMWORKER FROM  
                        FXSQLSVR.AXDB.DBO.CUSTTABLE C  WITH (NOLOCK)
                        WHERE 
                                    C.DATAAREAID     = A.DATAAREAID
                                    AND C.ACCOUNTNUM = A.ACCOUNTRELATION
                                    AND C.PARTITION  = A.PARTITION
									AND A.ACCOUNTCODE = 0 ) AS C
			OUTER APPLY( 
						SELECT TOP 1 CT.DOT_CUSTOMERSERVICEWORKER AS FK_HCMWORKER FROM  FXSQLSVR.AXDB.DBO.CUSTTABLE CT  WITH (NOLOCK)
								WHERE CT.DOT_CUSTOMERSERVICEWORKER <> 0 
								AND CT.PRICEGROUP = A.ACCOUNTRELATION 
								AND A.ACCOUNTCODE = 1 
									ORDER BY CT.RECID DESC )AS  C2
						

WHERE
            A.ITEMCODE = 0
            AND MODULE   = 1	
            AND RELATION = 4
            AND
            (
                        A.TODATE     = '1 JAN 1900'
                        OR A.TODATE >= CONVERT(DATE, GETDATE())
            );