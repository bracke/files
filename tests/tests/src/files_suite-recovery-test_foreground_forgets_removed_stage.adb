separate (Files_Suite.Recovery)
   --  A foreground stage removed from outside, rather than discarded, used
   --  to stay on the job context's list of stages awaiting their discard,
   --  so the foreground cleanup -- which runs once that list is empty --
   --  never ran again in the process. Discarding a later stage now forgets
   --  the vanished one with it: both records go, and the transport is
   --  cleaned up and released.
   procedure Test_Foreground_Forgets_Removed_Stage (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Previous  : constant String := Files.Job_Context.Directory;
      First     : Files.Types.UString;
      Second    : Files.Types.UString;
      Transport : Files.Types.UString;
      Removed   : Files.File_System.Mutation_Result;

      --  The transport a foreground stage's owner marker names.
      function Owner_Of (Stage : String) return String is
         File : Ada.Streams.Stream_IO.File_Type;
      begin
         Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Join (Stage, ".files-owner"));
         declare
            Header : constant String := String'Input (Ada.Streams.Stream_IO.Stream (File));
            Owner  : constant String := String'Input (Ada.Streams.Stream_IO.Stream (File));
         begin
            Ada.Streams.Stream_IO.Close (File);
            Assert (Header = "files-stage-owner-1", "a foreground stage names its owner");
            return Owner;
         end;
      end Owner_Of;

      --  The stage records the transport holds (none once its cleanup,
      --  which may already be running, removed it).
      function Record_Count return Natural is
         Stages : constant String := Join (To_String (Transport), "stages");
         Search : Ada.Directories.Search_Type;
         Found  : Ada.Directories.Directory_Entry_Type;
         Count  : Natural := 0;
      begin
         if not Ada.Directories.Exists (Stages) then
            return 0;
         end if;
         Ada.Directories.Start_Search
           (Search, Stages, "", [Ada.Directories.Directory => True, others => False]);
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Found);
            if Ada.Directories.Simple_Name (Found) not in "." | ".." then
               Count := Count + 1;
            end if;
         end loop;
         Ada.Directories.End_Search (Search);
         return Count;
      exception
         when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error =>
            if Ada.Directories.Exists (Stages) then
               raise;
            end if;
            return 0;
      end Record_Count;
   begin
      Reset_Root;
      --  Foreground staging, from no stage of an earlier test: whatever one
      --  left goes to the reaper, as at the executable's shutdown.
      Files.Job_Context.Shutdown;
      Files.Job_Context.Initialize ("");

      First := To_Unbounded_String (Files.Job_Context.Create_Stage (Root));
      Transport := To_Unbounded_String (Owner_Of (To_String (First)));
      --  Removed from outside: never discarded.
      Removed := Files.File_System.Delete_Permanently (To_String (First));
      Assert (Removed.Success, "the first stage is removed from outside");

      Second := To_Unbounded_String (Files.Job_Context.Create_Stage (Root));
      Assert (Owner_Of (To_String (Second)) = To_String (Transport), "both stages share the foreground transport");
      Files_Suite.Support.Assert_Equal (Record_Count, 2, "each stage has its record");

      Assert (Files.Job_Context.Discard_Stage (To_String (Second)), "the second stage is discarded");
      Assert (not Ada.Directories.Exists (To_String (Second)), "and is gone");
      Files_Suite.Support.Assert_Equal (Record_Count, 0, "the removed stage's record goes with the discarded one's");
      for Attempt in Files_Suite.Support.Polling loop
         exit when not Ada.Directories.Exists (To_String (Transport));
      end loop;
      Assert (not Ada.Directories.Exists (To_String (Transport)),
              "the foreground cleanup ran: the transport is released and removed");

      Files.Job_Context.Initialize (Previous);
      Reset_Root;
   end Test_Foreground_Forgets_Removed_Stage;
