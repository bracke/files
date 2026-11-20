with Ada.Streams;
with Files.Types;
with Hostkit.Durability;

--  Crash-safe publication of a completely written temporary file.
package Files.Durable_Writes is
   type Publication_Result is
     (Not_Published,
      Published_Not_Durable,
      Published_Durable);

   --  Sync Temporary, atomically replace Target, then sync Target's directory.
   --  Directory syncing may be unsupported on hosts that journal directory
   --  entries themselves; an explicit failure is never accepted.
   --  @param Temporary Complete file to sync and publish.
   --  @param Target Destination atomically replaced by Temporary.
   --  @return Whether publication did not happen, happened without a confirmed
   --    directory sync, or completed durably. A caller must not retry a
   --    Published_Not_Durable write as though Target were unchanged.
   function Publish (Temporary, Target : String) return Publication_Result;

   --  The step a publication stopped at: for saying why it failed.
   type Publication_Step is (Completed, File_Sync_Failed, Replace_Failed, Raised);

   --  Publish, and the step it stopped at.
   --  @param Temporary Complete file to sync and publish.
   --  @param Target Destination atomically replaced by Temporary.
   --  @param Step Completed, or the step that failed.
   --  @return As Publish.
   function Publish
     (Temporary, Target : String;
      Step              : out Publication_Step)
      return Publication_Result;

   --  @param Result Publication outcome to inspect.
   --  @return True when Target was replaced, even if directory sync failed.
   function Published (Result : Publication_Result) return Boolean is
     (Result /= Not_Published);

   --  @param Result Publication outcome to inspect.
   --  @return True when publication reached the host's durability boundary.
   function Durable (Result : Publication_Result) return Boolean is
     (Result = Published_Durable);

   --  Every temporary file files writes before it publishes or keeps it is
   --  made here, under one rule for what is removed when anything fails: the
   --  file this call created, and nothing else. Creating it exclusively
   --  proves it is ours at that moment; afterwards its identity token does.
   --  So a file whose identity cannot be read is removed by its path at
   --  once, before anyone else could have put something there, and a file
   --  that failed later is removed only while its identity still matches.

   --  Write a private file to be published: create Temporary anew (never
   --  over an entry already there), owner-only, write it through Write,
   --  flush and close it, and check it is still the file created. Raises on
   --  any failure -- Ada.Directories.Use_Error where this refuses (the cause
   --  recorded with Files.Io_Errors.Capture), Ada.IO_Exceptions.Data_Error
   --  past Max_Bytes, or the writer's own error -- having removed what it
   --  created. The caller checks the paths beforehand and publishes after.
   --
   --  @param Temporary Path to create; nothing may exist there.
   --  @param Write Writes the record to the stream given.
   --  @param Identity Set to the file's identity token, for Remove_Owned.
   --  @param Max_Bytes The most the record may hold.
   procedure Write_Private_File
     (Temporary : String;
      Write     : not null access procedure (Stream : not null access Ada.Streams.Root_Stream_Type'Class);
      Identity  : out Files.Types.UString;
      Max_Bytes : Long_Long_Integer := Long_Long_Integer'Last);

   --  Write_Private_File, telling a name already taken from every other
   --  failure: when the exclusive create is refused and an entry (any kind,
   --  a link included) is then seen at Temporary, it returns with Name_Taken
   --  set, nothing created or written. Every other failure raises as
   --  Write_Private_File does.
   --
   --  @param Temporary Path to create.
   --  @param Write Writes the record to the stream given.
   --  @param Identity Set to the file's identity token, for Remove_Owned;
   --    empty when the name was taken.
   --  @param Name_Taken True only when the create was refused and an entry
   --    was then seen at Temporary. A lookup that is itself refused is not
   --    a taken name: the create's failure is raised as it is.
   --  @param Max_Bytes The most the record may hold.
   procedure Write_Private_File
     (Temporary  : String;
      Write      : not null access procedure (Stream : not null access Ada.Streams.Root_Stream_Type'Class);
      Identity   : out Files.Types.UString;
      Name_Taken : out Boolean;
      Max_Bytes  : Long_Long_Integer := Long_Long_Integer'Last);

   --  Write_Private_File at a fixed temporary name the caller holds alone
   --  (a record staged in a directory only it writes): an entry already
   --  there was left by a writer that died, or whose own clean-up the host
   --  refused, and is removed first so that it does not refuse this write
   --  and every later one; one that vanishes meanwhile is no obstacle.
   --  Raises as Write_Private_File does, and Ada.Directories.Use_Error when
   --  the host refuses to remove the leftover, its reason recorded with
   --  Files.Io_Errors.
   --
   --  @param Temporary Path to create, the caller's own fixed name.
   --  @param Write Writes the record to the stream given.
   --  @param Identity Set to the file's identity token, for Remove_Owned.
   --  @param Max_Bytes The most the record may hold.
   procedure Write_Fixed_Private_File
     (Temporary : String;
      Write     : not null access procedure (Stream : not null access Ada.Streams.Root_Stream_Type'Class);
      Identity  : out Files.Types.UString;
      Max_Bytes : Long_Long_Integer := Long_Long_Integer'Last);

   --  Write_Private_File at the first free temporary name beside Base:
   --  Base & ".tmp", then ".tmp-2" up to ".tmp-9999", so a temporary another
   --  writer still holds (or a stale one, or a hostile link) is passed over,
   --  never followed or truncated.
   --
   --  @param Base The path the temporary is named after (the target).
   --  @param Write Writes the file to the stream given.
   --  @param Temporary Set to the path created.
   --  @param Identity Set to its identity token, for Remove_Owned.
   procedure Write_Private_Temporary
     (Base      : String;
      Write     : not null access procedure (Stream : not null access Ada.Streams.Root_Stream_Type'Class);
      Temporary : out Files.Types.UString;
      Identity  : out Files.Types.UString);

   --  Write a file and publish it over Target: Write_Private_Temporary
   --  beside Target, then Publish. Target must be absent or a plain file,
   --  never a link (one is not replaced, since the publish would put the
   --  file in the link's place and a reader of the link would lose its
   --  target); anything else, or a Target that cannot be looked at, raises
   --  Ada.Directories.Use_Error before anything is written. A temporary a
   --  crash or a stopped helper left there is passed over, never followed,
   --  truncated or removed, so it never stops a later save. A temporary
   --  that is not published is removed (Remove_Owned). Raises as
   --  Write_Private_Temporary does, having removed the temporary; Publish
   --  itself never raises. When the publish fails, the code recorded with
   --  Files.Io_Errors is the one the failing step gave (zero when it gave
   --  none), never one recorded before; when it succeeds, the code recorded
   --  before stands.
   --
   --  @param Target The file to replace or create.
   --  @param Write Writes the file to the stream given.
   --  @return As Publish.
   function Write_And_Publish
     (Target : String;
      Write  : not null access procedure (Stream : not null access Ada.Streams.Root_Stream_Type'Class))
      return Publication_Result;

   --  Remove the temporaries a crash or a killed process left beside Base:
   --  each entry named as Write_Private_Temporary names them (Base & ".tmp",
   --  or ".tmp-" and a number) that is a regular file, not a link, private
   --  to this user (see below), and last written more than a minute before
   --  this process started -- so a temporary another running writer (a
   --  background job) wrote to within that margin is never taken from it;
   --  one written to earlier and still unpublished (a writer stalled that
   --  long in its sync, say) is swept, its publish then fails and its
   --  target is left as it was. That start is reckoned by the folder's own
   --  clock, not this machine's (a share's server may be far off from it):
   --  when there is anything to sweep, a fresh temporary is written there,
   --  its modification time read and the file removed again, and the time
   --  this process has run taken from it. When that marker cannot be
   --  written or its time read, nothing is removed. Each is removed only
   --  while its identity is still the one checked (Remove_Owned), and only
   --  when the host shows it private to this user
   --  (Hostkit.Metadata.Private_To_Current_User: mode bits and uid, or
   --  owner and access list). Never raises.
   --
   --  @param Base The path the temporaries are named after (the target).
   procedure Sweep_Stale_Temporaries (Base : String);

   --  Remove Temporary if it is still the file Write_Private_File made
   --  (Identity matches), after a refused publish; never raises.
   --
   --  @param Temporary The written file's path.
   --  @param Identity The identity Write_Private_File returned; "" does nothing.
   procedure Remove_Owned (Temporary : String; Identity : String);

private
   function Outcome_Of
     (File_Sync      : Hostkit.Durability.Outcome;
      Replaced       : Boolean;
      Directory_Sync : Hostkit.Durability.Outcome)
      return Publication_Result;
end Files.Durable_Writes;
