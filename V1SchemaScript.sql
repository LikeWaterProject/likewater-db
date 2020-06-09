
CREATE TABLE [dbo].[EventTypes](
	[eventType] nvarchar(100) not null primary key,
	[description] nvarchar(500) not null,
	[showInApp] bit not null default 1
)
GO

CREATE TABLE [dbo].[Events](
	[eventId] uniqueidentifier not null primary key,
	[eventType] nvarchar(100) not null,
	[userToken] nvarchar(255) not null,
	[eventDesc] nvarchar(max) not null,
	[lat] decimal(8,5) not null,
	[lon] decimal(8,5) not null,
	[reportedDt] bigint not null
)
GO
ALTER TABLE [dbo].[Events]
   ADD CONSTRAINT FK_eventType FOREIGN KEY (eventType)
      REFERENCES [dbo].[EventTypes] (eventType)
GO

CREATE TABLE [dbo].[EventConfirms](
	[key] bigint identity(1,1) not null primary key,
	[eventId] uniqueidentifier not null,
	[userToken] nvarchar(255) not null,
	[confirmedDt] bigint not null
)
GO
ALTER TABLE [dbo].[EventConfirms]
   ADD CONSTRAINT FK_confirms_eventId FOREIGN KEY (eventId)
      REFERENCES [dbo].[Events] (eventId)
GO

CREATE TABLE [dbo].[EventDismisses](
	[key] bigint identity(1,1) not null primary key,
	[eventId] uniqueidentifier not null,
	[userToken] nvarchar(255) not null,
	[dismissedDt] bigint not null
)
GO
ALTER TABLE [dbo].[EventConfirms]
   ADD CONSTRAINT FK_dismisses_eventId FOREIGN KEY (eventId)
      REFERENCES [dbo].[Events] (eventId)
GO