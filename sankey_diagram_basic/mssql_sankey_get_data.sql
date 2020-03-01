  ;WITH ev AS
  (
		  -- Already existing events --
		  SELECT 
		  cus.customerId
		  ,ce.eventName
		  ,ce.eventTime 
		  FROM DB.Customers cus 
		  LEFT JOIN DB.CustomerEvents ce 
		  ON cus.customerId=ce.customerId
		  WHERE ce.eventName IN ('Registration','EmailVerified','RepositoryCreated')
  
		  UNION ALL

		  -- Commits --
		  SELECT 
		  cus.customerId
		  ,CASE WHEN cmt.commitTime IS NOT NULL THEN 'Contributed' ELSE 'notContributed' END AS eventName
		  ,ISNULL(cmt.commitTime,'') as eventTime
		  FROM DB.Customers cus 
		  LEFT JOIN
		  (
			  SELECT 
			  customerId
			  ,commitId
			  ,commitTime
			  ,RANK() OVER
			  (PARTITION BY c.customerId ORDER BY commmitTime ASC) AS Rank 
			  FROM DB.Commits c
		  ) AS cmt on cus.customerId=cmt.customerId AND cmt.Rank=1 
  )
 
 ,ranked AS 
 (
 SELECT ev.*
  ,RANK() OVER
  (PARTITION BY customerId ORDER BY eventTime ASC) AS Rank 
 FROM ev
 )
 
 
 ,final AS (
   SELECT 
   fromEvent
   ,toEvent
   ,COUNT(*) AS cnt
   FROM 
   (
  	 SELECT 
  	 ranked.customerId
  	 ,ranked.eventName AS fromEvent
  	 ,LEAD(ranked.eventName) OVER (ORDER BY ranked.customerId,Rank) AS toEvent
  	 ,ranked.eventTime
  	 ,ranked.Rank
  	 FROM ranked 
   ) AS d 
   WHERE d.toEvent != 'Registration' -- hence LEAD() will put this first event as the last as well, we should exclude the last row
   GROUP BY fromEvent, toEvent
 )
 
 SELECT * 
 FROM final
 ORDER BY fromEvent