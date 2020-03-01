# Disclaimer
All materials presented in this repository are created for learning purposes only and do not represent the real data or real user behavior patterns.

# Customer Journey analysis - Approach #1
In order to analyze customer journey and identify not effective customer flows as an example Git SaaS product generic flow will be used.

Method: Sankey Diagram.

[Approach #1](https://github.com/data-anna/data-analysis-customer/tree/master/sankey_diagram_basic) tools used: 
- MS SQL for extracting the data from DB;
- PowerBI for visualization using custom visual available at [Microsoft AppSource](https://appsource.microsoft.com/en-us/product/power-bi-visuals/WA104380777?src=office&tab=Reviews#).


# About Sankey Diagram

A Sankey Diagram is a visualization technique that allows to display flows. Several entities are  represented by rectangles or text and linked with arrow that have a width proportional to the importance of the flow.

1) Sankey is a type of flow diagram in which the width of the series is in proportion to the quantity of the flow. Use it to find major contributions to an overall flow.

2) Value of link is set in dataset; value of node is calculated based on values of links of this node.

3) Every node can be source node, target node or can be both.

4) If node is source and target in this visual, it means that it is source of one row and is target of another row of the dataset.

# Input Data Structure

In real world not all the data already prepared in the format for easy visualization. Therefore, let's imagine that data points needed for Sankey Diagram are distributed between different tables. For example, some data points already exist in so-called 'CustomerEvents' tracking table, whereas the information of commits and user's contribution to repositories actions are in 'Commits' table.

Standard Customer(User) Journey on our imaginary Git SaaS Product looks in the following way:

1. Customer Registered on webpage.
2. It is important that Customer verifies email.
3. Customer creates a Repository.
4. Customer contributes to Repository.

Of course, we can decompose the steps above and analyze them in detail, but for the sole purpose of visualization example let's simplify the steps to be used.

# MS SQL Example

As mentioned above, some data already stored in the table with columns CustomerId-EventName-Timestamp whereas the rest of events should be derived from another tables.

```sql

SELECT
    cus.customerId,
    ce.eventName,
    ce.eventTime
FROM
    DB.Customers cus
    LEFT JOIN DB.CustomerEvents ce ON cus.customerId = ce.customerId
WHERE
    ce.eventName IN(
        'Registration',
        'EmailVerified',
        'RepositoryCreated'
    )
```

| customerId | eventName | eventTime |
| --- | --- | --- |
| 12345 | Registration | 2020-02-01 00:02:13.00 |
| 12345 | EmailVerified | 2020-02-01 00:06:15.00 |
| 12345 | RepositoryCreated | 2020-02-01 00:22:01.00 |
| 12346 | Registration | 2020-02-01 00:14:17.00 |
| 12346 | EmailVerified | 2020-02-01 00:18:03.00 |
| 12347 | Registration | 2020-02-01 00:19:10.00 |

```sql

-- Commit attempts --

  SELECT
    cus.customerId,
CASE
        WHEN cmt.commitTime IS NOT NULL THEN 'Contributed'
        ELSE 'notContributed'
    END AS eventName,
    ISNULL(cmt.commitTime, '') as eventTime
FROM
    DB.Customers cus
    LEFT JOIN (
        SELECT
            customerId,
            commitId,
            commitTime,
            RANK() OVER (
                PARTITION BY c.customerId
                ORDER BY
                    commmitTime ASC
            ) AS Rank
        FROM
            DB.Commits c
    ) AS cmt on cus.customerId = cmt.customerId
    AND cmt.Rank = 1

```

| customerId | eventName | eventTime |
| --- | --- | --- |
| 12345 | Contributed | 2020-02-01 00:02:13.00 |
| 12346 | Contributed | 2020-02-01 00:06:15.00 |
| 12347 | Contributed | 2020-02-01 00:22:01.00 |
| 12348 | Contributed | 2020-02-01 00:14:17.00 |
| 12349 | Contributed | 2020-02-01 00:18:03.00 |







As a result of UNION of the abovementioned tables we will get the detailed table by each customerId (at this point think about modelling techiniquest and suggest an alternative for building the same inside a Data Warehouse):

| customerId | fromEvent | toEvent | eventTime | Rank |
| --- | --- | --- | --- | --- |
| 12345 | Registration | EmailVerified | 2020-02-01 00:02:13.00 | 1 |
| 12345 | EmailVerified | RepositoryCreated | 2020-02-01 00:06:15.00 | 2 |
| 12345 | RepositoryCreated | Contributed | 2020-02-01 00:22:01.00 | 3 |
| 12346 | Registration | EmailVerified | 2020-02-01 00:14:17.00 | 1 |
| 12346 | EmailVerified | RepositoryCreated | 2020-02-01 00:18:03.00 | 2 |
| 12347 | Registration | EmailVerified | 2020-02-01 00:19:10.00 | 1 |



Despite the details, an aggregated final dataset will be used for import into PowerBI data model:

| fromEvent | toEvent | cnt |
| --- | --- | --- |
| RepositoryCreated | notContributed | 56301 |
| RepositoryCreated | Contributed | 14030 |
| Registration | RepositoryCreated | 3261 |
| Registration | notContributed | 8519 |
| Registration | EmailVerified | 71620 |
| EmailVerified | RepositoryCreated | 46967 |
| EmailVerified | Contributed | 6205 |
| EmailVerified | notContributed | 2346 |

Full MS SQL query using CTE is below. 
```
;

WITH ev AS (
	-- Already existing events --
	SELECT
		cus.customerId,
		ce.eventName,
		ce.eventTime
	FROM DB.Customers cus
		LEFT JOIN DB.CustomerEvents ce ON cus.customerId = ce.customerId
	WHERE
		ce.eventName IN (
			'Registration',
			'EmailVerified',
			'RepositoryCreated'
		)
	UNION
	ALL 
	-- Commits --
	SELECT
		cus.customerId,
		CASE
			WHEN cmt.commitTime IS NOT NULL THEN 'Contributed'
			ELSE 'notContributed'
		END AS eventName,
		ISNULL(cmt.commitTime, '') as eventTime
	FROM DB.Customers cus
		LEFT JOIN (
			SELECT
				customerId,
				commitId,
				commitTime,
				RANK() OVER ( PARTITION BY c.customerId
					ORDER BY commmitTime ASC ) AS Rank
			FROM DB.Commits c
		) AS cmt on cus.customerId = cmt.customerId
		AND cmt.Rank = 1
),
ranked AS (
	SELECT
		ev.*,
		RANK() OVER (
			PARTITION BY customerId
			ORDER BY
				eventTime ASC
		) AS Rank
	FROM
		ev
),
final AS (
	SELECT
		fromEvent,
		toEvent,
		COUNT(*) AS cnt
	FROM
		(
			SELECT
				ranked.customerId,
				ranked.eventName AS fromEvent,
				LEAD(ranked.eventName) OVER (
					ORDER BY
						ranked.customerId,
						Rank
				) AS toEvent,
				ranked.eventTime,
				ranked.Rank
			FROM
				ranked
		) AS d
	WHERE
		d.toEvent != 'Registration' -- hence LEAD() will put this first event as the last as well, we should exclude the last row
	GROUP BY
		fromEvent,
		toEvent
)
SELECT 	*
FROM final
ORDER BY fromEvent
```


# Visualization Example in PowerBI

You can use custom visual available at marketplace called 'Sankey 2.0.1'.
In this project PowerBI report already [available](https://github.com/data-anna/data-analysis-customer/blob/master/sankey_diagram_basic/SankeyDiagram.GitCustomerFlow.pbix) so you can download and use it.

![Dashboard](https://github.com/data-anna/data-analysis-customer/blob/master/sankey_diagram_basic/images/dashboard_unfiltered.PNG)

How to derive value?

First example below shows that there are some customers who, according to our research, after Registration created a repository right away. Therefore, we should question ourselves: is this is a real picture and we had issues in the customer flow? Or maybe the event of email verification wasn't populated in DB.CustomerEvents in a correct way.

![Example1](https://github.com/data-anna/data-analysis-customer/blob/master/sankey_diagram_basic/images/dashboard_example1.PNG)

Second example (below) shows that 6205 customers who verified their email somehow present in the DB.Commits table and made a commit. This looks like logical mistake hence it is not possible to make a commit without creating a repository, therefore we should question ourselves about the data quality in the DB.Commits table.

![Example2](https://github.com/data-anna/data-analysis-customer/blob/master/sankey_diagram_basic/images/dashboard_example2.PNG)

# Next steps

There are few options on how you can create such types of vizualizations:

1. Using connection to existing DataWarehouse via visualization tool (ex. PowerBI);
2. Using Python for both retrieving the data and visualization (see an example using plotly library here);
3. Using library Data-Driven Documents (d3.js) if you are familiar with JavaScript (tutorial [here](https://davidwalsh.name/learning-d3)).

# Question yourself

How would you design a Data Warehouse in order to enable a Report user to see the Customer Journey for all customers and at the same time to be able to filter exact customerId and see full journey of only 1 customer?

# Useful links
[https://github.com/microsoft/powerbi-visuals-sankey](https://github.com/microsoft/powerbi-visuals-sankey)