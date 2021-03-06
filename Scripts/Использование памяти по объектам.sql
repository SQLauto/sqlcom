-- Использование памяти по Базам Данных

WITH AggregateBufferPoolUsage
	AS
	(SELECT DB_NAME(database_id) AS [Database Name],
	CAST(COUNT(*) * 8/1024.0 AS DECIMAL (10,2))  AS [CachedSize]
	FROM sys.dm_os_buffer_descriptors WITH (NOLOCK)
	WHERE database_id > 4 -- system databases
	AND database_id <> 32767 -- ResourceDB
	GROUP BY DB_NAME(database_id))
	SELECT ROW_NUMBER() OVER(ORDER BY CachedSize DESC) AS [Buffer Pool Rank], [Database Name], CachedSize AS [Cached Size (MB)],
		   CAST(CachedSize / SUM(CachedSize) OVER() * 100.0 AS DECIMAL(5,2)) AS [Buffer Pool Percent]
	FROM AggregateBufferPoolUsage
	ORDER BY [Buffer Pool Rank] OPTION (RECOMPILE);
  
-- Использование памяти по таблицам

  SELECT
	objects.name AS object_name,
	objects.type_desc AS object_type_description,
	COUNT(*) AS buffer_cache_pages,
	COUNT(*) * 8 / 1024  AS buffer_cache_used_MB
	FROM sys.dm_os_buffer_descriptors
	INNER JOIN sys.allocation_units
	ON allocation_units.allocation_unit_id = dm_os_buffer_descriptors.allocation_unit_id
	INNER JOIN sys.partitions
	ON ((allocation_units.container_id = partitions.hobt_id AND type IN (1,3))
	OR (allocation_units.container_id = partitions.partition_id AND type IN (2)))
	INNER JOIN sys.objects
	ON partitions.object_id = objects.object_id
	WHERE allocation_units.type IN (1,2,3)
	AND objects.is_ms_shipped = 0
	AND dm_os_buffer_descriptors.database_id = DB_ID()
	GROUP BY objects.name,
			 objects.type_desc
	ORDER BY COUNT(*) DESC;
  
-- Использование памяти по индексам

	SELECT
		indexes.name AS index_name,
		objects.name AS object_name,
		objects.type_desc AS object_type_description,
		COUNT(*) AS buffer_cache_pages,
		COUNT(*) * 8 / 1024  AS buffer_cache_used_MB
	FROM sys.dm_os_buffer_descriptors
	INNER JOIN sys.allocation_units
	ON allocation_units.allocation_unit_id = dm_os_buffer_descriptors.allocation_unit_id
	INNER JOIN sys.partitions
	ON ((allocation_units.container_id = partitions.hobt_id AND type IN (1,3))
	OR (allocation_units.container_id = partitions.partition_id AND type IN (2)))
	INNER JOIN sys.objects
	ON partitions.object_id = objects.object_id
	INNER JOIN sys.indexes
	ON objects.object_id = indexes.object_id
	AND partitions.index_id = indexes.index_id
	WHERE allocation_units.type IN (1,2,3)
	AND objects.is_ms_shipped = 0
	AND dm_os_buffer_descriptors.database_id = DB_ID()
	GROUP BY indexes.name,
			 objects.name,
			 objects.type_desc
	ORDER BY COUNT(*) DESC;
