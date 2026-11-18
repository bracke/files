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
