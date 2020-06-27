
CREATE TABLE [dbo].[EventTypes](
	[eventType] nvarchar(100) not null,
	[eventCategory] nvarchar(100) not null,
	[description] nvarchar(500) not null,
	[showInApp] bit not null default 1,
	primary key ([eventCategory],[eventType])
)
GO

CREATE TABLE [dbo].[Events](
	[eventId] uniqueidentifier not null primary key,
	[eventCategory] nvarchar(100) not null,
	[eventType] nvarchar(100) not null,
	[userToken] nvarchar(255) not null,
	[eventDesc] nvarchar(max) not null,
	[lat] decimal(8,5) not null,
	[lon] decimal(8,5) not null,
	[reportedDt] bigint not null
)
GO
ALTER TABLE [dbo].[Events]
   ADD CONSTRAINT FK_eventType FOREIGN KEY (eventCategory, eventType)
      REFERENCES [dbo].[EventTypes] (eventCategory, eventType)
GO

CREATE TABLE [dbo].[EventResponses](
	[key] bigint identity(1,1) not null primary key,
	[eventId] uniqueidentifier not null,
	[userToken] nvarchar(255) not null,
	[reportedActive] bit not null,
	[responseDt] bigint not null
)
ALTER TABLE [dbo].[EventResponses]
   ADD CONSTRAINT FK_responses_eventId FOREIGN KEY (eventId)
      REFERENCES [dbo].[Events] (eventId)
GO

/****** Object:  UserDefinedFunction [dbo].[GetEvents]    Script Date: 6/20/2020 5:37:14 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		LikeWater
-- Create date: 
-- Description:	Gets the list of active events based on a 
--		Lat/Lon and a radius in miles.
-- =============================================
CREATE FUNCTION [dbo].[GetEvents] 
(	
	-- Add the parameters for the function here
	@userLat decimal(8,5),
	@userLon decimal(8,5),
	@radiusFeet bigint,
	@userToken nvarchar(255)
)
RETURNS @return table (
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
	[lastDismissDt] [bigint],
	[distance] decimal
)
AS	
begin 
	---- Debug inputs to function
	--Declare @userLat decimal(8,5) = 38.78713;
	--Declare @userLon decimal(8,5) = -78.78141;
	--declare @radiusFeet bigint = 1095369;
	--declare @userToken nvarchar(255) = 'STMS111';
	---- end debug inputs

	-- define additional variables needed
	declare @confirmExtendRate bigint = 600000; -- 10 minutes
	declare @dismissReduceRate bigint = 300000; -- 5 minutes
	declare @autoDismissInterval bigint = 3600000; -- 60 minutes

	declare @initialDayFilter bigint; -- current date - 1 day, just used to improve query performance with large data
	select @initialDayFilter = (cast(DATEDIFF(s, '1970-01-01', GETUTCDATE()) as bigint)*1000+datepart(ms,getutcdate())) - 86400000;
	declare @currentDate bigint;
	select @currentDate = (cast(DATEDIFF(s, '1970-01-01', GETUTCDATE()) as bigint)*1000+datepart(ms,getutcdate()));


	-- first find the events that have been entered in the last 1 days along with the number of confirms/dimsisses
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
	insert into @recenEvents(eventId, eventType, userToken, eventDesc, lat, lon, reportedDt, [confirmCount], [dismissCount], [lastConfirmDt], [lastDismissDt])
	select distinct e.eventId, 
		e.eventType, 
		e.userToken, 
		e.eventDesc, 
		e.lat, 
		e.lon, 
		e.reportedDt,
		confirms.confirmCount,
		dismisses.dismissCount,
		confirms.lastConfirmDt,
		dismisses.lastDismissDt
	from Events e
		outer apply (select count([key]) over (partition by eventId) confirmCount,
			max(responseDt) over (partition by eventId) lastConfirmDt
			from EventResponses
			where eventId = e.eventId
			and reportedActive = 1)confirms
		outer apply (select count([key]) over (partition by eventId) dismissCount,
			max(responseDt) over (partition by eventId) lastDismissDt
			from EventResponses
			where eventId = e.eventId
			and reportedActive = 0) dismisses
	where e.reportedDt > @initialDayFilter -- Only look at stuff greater than 2 days ago, this is done only for performance reasons

	--select * from  @recenEvents;

	-- now take the reduced data and apply the show/hide logic based on time since creation, confirm aggrigate details, and dismiss aggrigate details
	-- calculation: reportedTime > (currentTime - autoDismiss - (confirmExtendRate * confirmCount) + (dismissReduceRate * dismissCount))
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
	insert into @activeEvents([eventId], [eventType], [userToken], [eventDesc], [lat], [lon], [reportedDt], [confirmCount], [dismissCount], [lastConfirmDt], [lastDismissDt])
	select [eventId], [eventType], [userToken], [eventDesc], [lat], [lon], [reportedDt], [confirmCount], [dismissCount], [lastConfirmDt], [lastDismissDt]
	from @recenEvents
	where reportedDt > (@currentDate - @autoDismissInterval - (@confirmExtendRate * ISNULL(confirmCount, 0)) + (@dismissReduceRate * ISNULL(dismissCount, 0)))

	--select * from @activeEvents

	-- now return the set that is within the the givin radius
	-- also remove any records already dismissed by the given user
	insert into @return([eventId], [eventType], [userToken], [eventDesc], [lat], [lon], [reportedDt], [confirmCount], [dismissCount], [lastConfirmDt], [lastDismissDt], [distance])
	SELECT ae.[eventId], [eventType], ae.[userToken], [eventDesc], [lat], [lon], [reportedDt], [confirmCount], [dismissCount], [lastConfirmDt], [lastDismissDt], 
		-- currently distance is in miles, need to have this in feet
		-- TBD
		(3963.0 * acos((sin(radians(@userLat)) * sin(radians(lat))) + cos(radians(@userLat)) * cos(radians(lat)) * cos(radians(lon) - radians(@userLon)))) * 5280 distance
	FROM @activeEvents ae
		left join EventResponses er -- left join onto er to remove the report from return if the current user has already dismissed the report
		on er.eventId = ae.eventId
		and reportedActive = 0
		and er.userToken = @userToken
	where er.eventId is null
		and (3963.0 * acos((sin(radians(@userLat)) * sin(radians(lat))) + cos(radians(@userLat)) * cos(radians(lat)) * cos(radians(lon) - radians(@userLon))) * 5280) <= @radiusFeet

	return
end
GO