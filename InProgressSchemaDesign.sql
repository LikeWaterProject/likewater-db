---- =========================================================
---- Create Inline Function Template for Azure SQL Database
---- =========================================================
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO
---- =============================================
---- Author:		<Author,,Name>
---- Create date: <Create Date,,>
---- Description:	<Description,,>
---- =============================================
--CREATE FUNCTION <Inline_Function_Name, sysname, FunctionName> 
--(	
--	-- Add the parameters for the function here
--	<@param1, sysname, @p1> <Data_Type_For_Param1, , int>, 
--	<@param2, sysname, @p2> <Data_Type_For_Param2, , char>
--)
--RETURNS TABLE 
--AS
--RETURN 
--(
	-- Debug inputs to function
	Declare @userLat decimal(8,5) = 34.00553;
	Declare @userLon decimal(8,5) = -117.00974;
	declare @radiusMiles integer = 2;
	-- end debug inputs

	-- define additional variables needed
	declare @confirmExtendRateMinutes integer = 0;
	declare @dismissReduceRateMinutes integer = 0;
	declare @autoDismissIntervalMinutes integer = 60;

	declare @initialDayFilter bigint;
	select @initialDayFilter = (cast(DATEDIFF(s, '1970-01-01', GETUTCDATE()) as bigint)*1000+datepart(ms,getutcdate())) - 86400000;


	-- first find the events that have been entered in the last 2 days along with the number of confirms/dimsisses
	-- the two day filter is used to provide an initial reduction in possible record count and has no impact to the main logic
	declare @recenEvents table(
		[eventId] [uniqueidentifier],
		[eventType] [nvarchar](100),
		[userToken] [nvarchar](255),
		[eventDesc] [nvarchar](max),
		[lat] [decimal](8, 5),
		[lon] [decimal](8, 5),
		[reportedDt] [bigint],
		[confirmCount] int,
		[dismissCount] int,
		[lastConfirmDt] [bigint],
		[lastDismissDt] [bigint]
	);
	insert into @recenEvents(eventId, eventType, userToken, eventDesc, lat, lon, reportedDt)
	select e.eventId, 
		e.eventType, 
		e.userToken, 
		e.eventDesc, 
		e.lat, 
		e.lon, 
		e.reportedDt,
		count(confirms.[key]) over (partition by e.eventId) confirmCount,
		count(dismisses.[key]) over (partition by e.eventId) dismissCount,
		max(confirms.responseDt) over (partition by e.eventId) lastConfirmDt,
		max(dismisses.responseDt) over (partition by e.eventId) lastDismissDt
	from Events e
		left join EventResponses confirms
			on confirms.eventId = e.eventId
			and confirms.reportedActive = 1
		left join EventResponses dismisses
			on dismisses.eventId = e.eventId
			and dismisses.reportedActive = 0
	where e.reportedDt > @initialDayFilter -- Only look at stuff greater than 2 days ago, this is done only for performance reasons

	-- now take the reduced data and apply the show/hide logic based on time since creation, confirm aggrigate details, and dismiss aggrigate details
	declare @activeEvents table(
		[eventId] [uniqueidentifier],
		[eventType] [nvarchar](100),
		[userToken] [nvarchar](255),
		[eventDesc] [nvarchar](max),
		[lat] [decimal](8, 5),
		[lon] [decimal](8, 5),
		[reportedDt] [bigint],
		[confirmCount] int,
		[dismissCount] int,
		[lastConfirmDt] [bigint],
		[lastDismissDt] [bigint]
	)
	select *
	from @recenEvents
	--where 

	-- now return the set that is within the the givin radius
	SELECT *, 
		-- currently distance is in miles, need to have this in feet
		-- TBD
		3963.0 * acos((sin(radians(@userLat)) * sin(radians(lat))) + cos(radians(@userLat)) * cos(radians(lat)) * cos(radians(lon) - radians(@userLon))) distance
	FROM Events
	-- where 
--)
--GO
