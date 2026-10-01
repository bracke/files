with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with Files.File_System;
with Files.Durable_Writes;
with Files.Private_Directories;
with Files.Process_Jobs;
with Hostkit.Durability;
with Hostkit.Fs;
with Files.File_Identities;

package body Files.Job_Context is
   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;
   use type Files.Private_Directories.Create_Result;
   use type Hostkit.Durability.Outcome;

   Stage_Record_Header : constant String := "files-stage-3";
   Foreground_Job : Files.Process_Jobs.Session;
   Foreground_Paths : Files.Types.String_Vectors.Vector;
   Foreground_Records : Files.Types.String_Vectors.Vector;

   procedure Sync_Journal (Path : String) is
   begin
      if Hostkit.Durability.Sync_File (Path) = Hostkit.Durability.Synced then
         declare
            Outcome : constant Hostkit.Durability.Outcome :=
              Hostkit.Durability.Sync_Directory (Ada.Directories.Containing_Directory (Path));
            pragma Unreferenced (Outcome);
         begin
            null;
         end;
      end if;
   exception
      when others => null;
   end Sync_Journal;

   procedure Register_Stage_Internal
     (Path, Identity, Record_Directory : String);

   procedure Remove_Record (Record_Directory : String) is
   begin
      if Record_Directory /= ""
        and then not Hostkit.Fs.Is_Link (Record_Directory)
        and then Ada.Directories.Exists (Record_Directory)
      then
         Ada.Directories.Delete_Tree (Record_Directory);
      end if;
   exception
      when others => null;
   end Remove_Record;

   procedure Initialize (Directory : String) is
   begin
      Current := To_Unbounded_String (Directory);
   end Initialize;

   procedure Shutdown is
   begin
      Files.Process_Jobs.Release_For_Shutdown (Foreground_Job);
      Foreground_Paths.Clear;
      Foreground_Records.Clear;
   end Shutdown;

   function Directory return String is (To_String (Current));

   function Cancelled return Boolean is
     (Files.Process_Jobs.Cancellation_Requested (To_String (Current)));

   procedure Create_Private_Directory (Path : String) is
   begin
      Files.Private_Directories.Create (Path);
   end Create_Private_Directory;

   function Stage_Owner_Directory return String is
   begin
      if Length (Current) > 0 then
         return To_String (Current);
      end if;
      if not Files.Process_Jobs.Active (Foreground_Job) then
         Files.Process_Jobs.Reserve (Foreground_Job);
      end if;
      return Files.Process_Jobs.Path (Foreground_Job, "");
   end Stage_Owner_Directory;

   procedure Write_Stage_Record
     (Record_Directory, Path, Identity : String)
   is
      File : Ada.Streams.Stream_IO.File_Type;
      Data : constant String := Hostkit.Fs.Join (Record_Directory, "data");
      Temp : constant String := Hostkit.Fs.Join (Record_Directory, "data.tmp");
   begin
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Temp);
      String'Output (Ada.Streams.Stream_IO.Stream (File), Stage_Record_Header);
      String'Output (Ada.Streams.Stream_IO.Stream (File), Path);
      String'Output (Ada.Streams.Stream_IO.Stream (File), Identity);
      Ada.Streams.Stream_IO.Close (File);
      if not Files.Durable_Writes.Publish (Temp, Data) then
         raise Ada.Directories.Use_Error;
      end if;
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            begin
               Ada.Streams.Stream_IO.Close (File);
            exception
               when others => null;
            end;
         end if;
         begin
            if Ada.Directories.Exists (Temp) then
               Ada.Directories.Delete_File (Temp);
            end if;
         exception
            when others => null;
         end;
         raise;
   end Write_Stage_Record;

   function Begin_Stage_Record (Path : String) return String is
      Owner_Directory : constant String := Stage_Owner_Directory;
      Stages : constant String := Hostkit.Fs.Join (Owner_Directory, "stages");
   begin
      if Files.Private_Directories.Try_Create (Stages) =
        Files.Private_Directories.Collision
        and then (Hostkit.Fs.Is_Link (Stages) or else not Ada.Directories.Exists (Stages)
          or else Ada.Directories.Kind (Stages) /= Ada.Directories.Directory)
      then
         raise Ada.Directories.Use_Error;
      end if;
      for N in 1 .. 9_999 loop
         declare
            Image : constant String := Natural'Image (N);
            Record_Directory : constant String :=
              Hostkit.Fs.Join (Stages, "stage-" & Image (2 .. Image'Last));
         begin
            if Files.Private_Directories.Try_Create (Record_Directory) =
              Files.Private_Directories.Collision
            then
               goto Continue;
            end if;
            begin
               --  Publish the intended pathname before creating it. A crash
               --  can therefore leave an unfinished record, never an
               --  undiscoverable staging directory.
               Write_Stage_Record (Record_Directory, Path, "");
               return Record_Directory;
            exception
               when others =>
                  Remove_Record (Record_Directory);
                  raise;
            end;
            <<Continue>>
         end;
      end loop;
      raise Ada.Directories.Use_Error;
   end Begin_Stage_Record;

   function Create_Stage (Parent : String) return String is
   begin
      for N in 1 .. 9_999 loop
         declare
            Image : constant String := Natural'Image (N);
            Candidate : constant String := Hostkit.Fs.Join (Parent, ".files-work-" & Image (2 .. Image'Last));
            Identity : Files.Types.UString;
            Record_Directory : Files.Types.UString;
         begin
            Record_Directory := To_Unbounded_String (Begin_Stage_Record (Candidate));
            if Files.Private_Directories.Try_Create (Candidate) =
              Files.Private_Directories.Collision
            then
               Remove_Record (To_String (Record_Directory));
               goto Continue;
            end if;
            begin
               Identity := To_Unbounded_String (Files.File_Identities.Token (Candidate));
               if Length (Identity) = 0 then
                  raise Ada.Directories.Use_Error;
               end if;
            exception
               when others =>
                  begin
                     Ada.Directories.Delete_Directory (Candidate);
                     Remove_Record (To_String (Record_Directory));
                  exception
                     when others => null;
                  end;
                  raise;
            end;
            begin
               Register_Stage_Internal
                 (Candidate, To_String (Identity), To_String (Record_Directory));
            exception
               when others =>
                  declare
                     Removed : constant Files.File_System.Mutation_Result :=
                       Files.File_System.Delete_Staging_Entry
                         (Candidate, To_String (Identity));
                     pragma Unreferenced (Removed);
                  begin
                     null;
                  end;
                  if not (Ada.Directories.Exists (Candidate) or else Hostkit.Fs.Is_Link (Candidate)) then
                     Remove_Record (To_String (Record_Directory));
                  end if;
                  raise;
            end;
            if Length (Current) = 0 then
               Foreground_Paths.Append (To_Unbounded_String (Candidate));
               Foreground_Records.Append (Record_Directory);
            end if;
            return Candidate;
            <<Continue>>
         end;
      end loop;
      raise Ada.Directories.Use_Error;
   exception
      when others =>
         if Length (Current) = 0 and then Foreground_Paths.Is_Empty
           and then Files.Process_Jobs.Active (Foreground_Job)
         then
            Files.Process_Jobs.Reset (Foreground_Job);
         end if;
         raise;
   end Create_Stage;

   procedure Append_Record (Name, Header, Destination, Source, Identity : String);

   function Creation_Snapshot_Matches
     (Path, Identity, Tree_Revision : String) return Boolean
   is
      Is_Link : Boolean;
   begin
      if Identity = "" or else Files.File_Identities.Token (Path) /= Identity then
         return False;
      end if;
      Is_Link := Hostkit.Fs.Is_Link (Path);
      return
        (if Is_Link then Tree_Revision = ""
         else Tree_Revision /= ""
           and then Files.File_System.Tree_Revision (Path) = Tree_Revision);
   exception
      when others =>
         return False;
   end Creation_Snapshot_Matches;

   procedure Record_Created (Destination : String; Source : String := "") is
   begin
      Record_Created (Destination, Source, Files.File_Identities.Token (Destination));
   end Record_Created;

   procedure Record_Created (Destination, Source, Identity : String) is
   begin
      Record_Created (Destination, Source, Identity, Files.File_System.Tree_Revision (Destination));
   end Record_Created;

   procedure Record_Created (Destination, Source, Identity, Tree_Revision : String) is
      File : Ada.Streams.Stream_IO.File_Type;
   begin
      if Length (Current) = 0
        or else not Creation_Snapshot_Matches (Destination, Identity, Tree_Revision)
      then
         return;
      end if;
      declare
         Journal : constant String := Hostkit.Fs.Join (To_String (Current), "created");
      begin
         if Ada.Directories.Exists (Journal) then
            Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.Append_File, Journal);
         else
            Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Journal);
            String'Output (Ada.Streams.Stream_IO.Stream (File), "files-created-3");
         end if;
         String'Output (Ada.Streams.Stream_IO.Stream (File), Destination);
         String'Output (Ada.Streams.Stream_IO.Stream (File), Source);
         String'Output (Ada.Streams.Stream_IO.Stream (File), Identity);
         String'Output (Ada.Streams.Stream_IO.Stream (File), Tree_Revision);
         Ada.Streams.Stream_IO.Close (File);
         Sync_Journal (Journal);
      end;
   exception
      when others =>
         --  Publication already succeeded; retain its normal result even if
         --  this crash-recovery journal cannot be extended.
         if Ada.Streams.Stream_IO.Is_Open (File) then
            begin
               Ada.Streams.Stream_IO.Close (File);
            exception
               when others => null;
            end;
         end if;
   end Record_Created;

   procedure Record_Moved (Destination, Source, Identity : String) is
   begin
      Append_Record ("moved", "files-moved-1", Destination, Source, Identity);
   end Record_Moved;

   procedure Append_Record (Name, Header, Destination, Source, Identity : String) is
      File : Ada.Streams.Stream_IO.File_Type;
   begin
      if Length (Current) = 0 then
         return;
      end if;
      declare
         Journal : constant String := Hostkit.Fs.Join (To_String (Current), Name);
      begin
         if Ada.Directories.Exists (Journal) then
            Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.Append_File, Journal);
         else
            Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Journal);
            String'Output (Ada.Streams.Stream_IO.Stream (File), Header);
         end if;
         String'Output (Ada.Streams.Stream_IO.Stream (File), Destination);
         String'Output (Ada.Streams.Stream_IO.Stream (File), Source);
         String'Output (Ada.Streams.Stream_IO.Stream (File), Identity);
         Ada.Streams.Stream_IO.Close (File);
         Sync_Journal (Journal);
      end;
   exception
      when others =>
         --  Called after publication: a journal failure must not turn a
         --  completed creation or move into a failed filesystem operation.
         if Ada.Streams.Stream_IO.Is_Open (File) then
            begin
               Ada.Streams.Stream_IO.Close (File);
            exception
               when others => null;
            end;
         end if;
   end Append_Record;

   procedure Read_Records
     (Directory, Name, Header : String;
      Destinations : out Files.Types.String_Vectors.Vector;
      Sources : out Files.Types.String_Vectors.Vector;
      Identities : out Files.Types.String_Vectors.Vector)
   is
      File : Ada.Streams.Stream_IO.File_Type;
   begin
      Destinations.Clear;
      Sources.Clear;
      Identities.Clear;
      if not Ada.Directories.Exists (Hostkit.Fs.Join (Directory, Name)) then
         return;
      end if;
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Hostkit.Fs.Join (Directory, Name));
      if String'Input (Ada.Streams.Stream_IO.Stream (File)) /= Header then
         Ada.Streams.Stream_IO.Close (File);
         return; --  Older journals have no trustworthy identity snapshot.
      end if;
      while not Ada.Streams.Stream_IO.End_Of_File (File) loop
         declare
            Destination : constant String := String'Input (Ada.Streams.Stream_IO.Stream (File));
            Source      : constant String := String'Input (Ada.Streams.Stream_IO.Stream (File));
            Identity    : constant String := String'Input (Ada.Streams.Stream_IO.Stream (File));
         begin
            Destinations.Append (To_Unbounded_String (Destination));
            Sources.Append (To_Unbounded_String (Source));
            Identities.Append (To_Unbounded_String (Identity));
         end;
      end loop;
      Ada.Streams.Stream_IO.Close (File);
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
   end Read_Records;

   procedure Read_Created
     (Directory : String;
      Destinations, Sources, Identities, Tree_Revisions : out Files.Types.String_Vectors.Vector)
   is
      File : Ada.Streams.Stream_IO.File_Type;
   begin
      Destinations.Clear;
      Sources.Clear;
      Identities.Clear;
      Tree_Revisions.Clear;
      if not Ada.Directories.Exists (Hostkit.Fs.Join (Directory, "created")) then
         return;
      end if;
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Hostkit.Fs.Join (Directory, "created"));
      if String'Input (Ada.Streams.Stream_IO.Stream (File)) /= "files-created-3" then
         Ada.Streams.Stream_IO.Close (File);
         return;
      end if;
      while not Ada.Streams.Stream_IO.End_Of_File (File) loop
         declare
            Destination : constant String := String'Input (Ada.Streams.Stream_IO.Stream (File));
            Source      : constant String := String'Input (Ada.Streams.Stream_IO.Stream (File));
            Identity    : constant String := String'Input (Ada.Streams.Stream_IO.Stream (File));
            Revision    : constant String := String'Input (Ada.Streams.Stream_IO.Stream (File));
         begin
            Destinations.Append (To_Unbounded_String (Destination));
            Sources.Append (To_Unbounded_String (Source));
            Identities.Append (To_Unbounded_String (Identity));
            Tree_Revisions.Append (To_Unbounded_String (Revision));
         end;
      end loop;
      Ada.Streams.Stream_IO.Close (File);
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
   end Read_Created;

   procedure Read_Moved
     (Directory : String;
      Destinations, Sources, Identities : out Files.Types.String_Vectors.Vector) is
   begin
      Read_Records (Directory, "moved", "files-moved-1", Destinations, Sources, Identities);
   end Read_Moved;

   procedure Register_Stage_Internal
     (Path, Identity, Record_Directory : String)
   is
      File : Ada.Streams.Stream_IO.File_Type;
      Owner : constant String := Hostkit.Fs.Join (Path, ".files-owner");
      Owner_Temp : constant String := Hostkit.Fs.Join (Path, ".files-owner.tmp");
      Owner_Directory : constant String := Stage_Owner_Directory;
   begin
      if Identity = "" or else Record_Directory = "" then
         raise Ada.Directories.Use_Error;
      end if;
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Owner_Temp);
      String'Output (Ada.Streams.Stream_IO.Stream (File), "files-stage-owner-1");
      String'Output (Ada.Streams.Stream_IO.Stream (File), Owner_Directory);
      String'Output (Ada.Streams.Stream_IO.Stream (File), Identity);
      Ada.Streams.Stream_IO.Close (File);
      if not Files.Durable_Writes.Publish (Owner_Temp, Owner) then
         raise Ada.Directories.Use_Error;
      end if;
      Write_Stage_Record (Record_Directory, Path, Identity);
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            begin
               Ada.Streams.Stream_IO.Close (File);
            exception
               when others => null;
            end;
         end if;
         begin
            if Ada.Directories.Exists (Owner_Temp) then
               Ada.Directories.Delete_File (Owner_Temp);
            end if;
         exception
            when others => null;
         end;
         raise;
   end Register_Stage_Internal;

   procedure Read_Owner
     (Path : String;
      Directory, Identity : out Files.Types.UString;
      Valid : out Boolean)
   is
      File : Ada.Streams.Stream_IO.File_Type;
      Owner : constant String := Hostkit.Fs.Join (Path, ".files-owner");
   begin
      Directory := Null_Unbounded_String;
      Identity := Null_Unbounded_String;
      Valid := False;
      if Hostkit.Fs.Is_Link (Owner) or else not Ada.Directories.Exists (Owner) then
         return;
      end if;
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Owner);
      if String'Input (Ada.Streams.Stream_IO.Stream (File)) = "files-stage-owner-1" then
         Directory := To_Unbounded_String (String'Input (Ada.Streams.Stream_IO.Stream (File)));
         Identity := To_Unbounded_String (String'Input (Ada.Streams.Stream_IO.Stream (File)));
         Valid := Length (Identity) > 0;
      end if;
      Ada.Streams.Stream_IO.Close (File);
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         Directory := Null_Unbounded_String;
         Identity := Null_Unbounded_String;
         Valid := False;
   end Read_Owner;

   function Owner_Matches
     (Path, Directory, Expected_Identity : String) return Boolean
   is
      Recorded_Directory, Recorded_Identity : Files.Types.UString;
      Valid : Boolean;
   begin
      Read_Owner (Path, Recorded_Directory, Recorded_Identity, Valid);
      return Valid
        and then To_String (Recorded_Directory) = Directory
        and then To_String (Recorded_Identity) = Expected_Identity;
   end Owner_Matches;

   function Discard_Stage (Path : String) return Boolean is
      Directory, Identity : Files.Types.UString;
      Owner_Valid : Boolean;
      Foreground : constant Boolean := Length (Current) = 0;
      Foreground_Index : Natural := 0;
      Record_Directory : Files.Types.UString;
      Removed : Boolean := False;

      procedure Release_Foreground is
      begin
         if not Foreground or else Foreground_Index = 0 then
            return;
         end if;
         if Removed then
            Remove_Record (To_String (Record_Directory));
         end if;
         Foreground_Paths.Delete (Foreground_Index);
         Foreground_Records.Delete (Foreground_Index);
         if Foreground_Paths.Is_Empty and then Files.Process_Jobs.Active (Foreground_Job) then
            Files.Process_Jobs.Clean_Stages (Foreground_Job);
            --  Failed records remain in the transport directory. Releasing the
            --  session launches the normal cleanup helper and retains it for
            --  retry instead of abandoning a foreground stage.
            Files.Process_Jobs.Reset (Foreground_Job);
         end if;
      end Release_Foreground;
   begin
      if Foreground then
         for Index in Foreground_Paths.First_Index .. Foreground_Paths.Last_Index loop
            if To_String (Foreground_Paths (Index)) = Path then
               Foreground_Index := Index;
               Record_Directory := Foreground_Records (Index);
               exit;
            end if;
         end loop;
         if Foreground_Index = 0 or else not Files.Process_Jobs.Active (Foreground_Job) then
            return False;
         end if;
      end if;
      if not (Ada.Directories.Exists (Path) or else Hostkit.Fs.Is_Link (Path)) then
         Removed := True;
         Release_Foreground;
         return True;
      end if;
      Read_Owner (Path, Directory, Identity, Owner_Valid);
      if Owner_Valid
        and then To_String (Directory) =
          (if Foreground then Files.Process_Jobs.Path (Foreground_Job, "") else To_String (Current))
      then
         Removed := Files.File_System.Delete_Staging_Entry
           (Path, To_String (Identity)).Success;
      end if;
      Release_Foreground;
      return Removed;
   exception
      when others =>
         Release_Foreground;
         return False;
   end Discard_Stage;

   procedure Clean_Stages
     (Directory          : String;
      Owner              : Files.Job_Transports.Lease;
      Discard_Unreadable : Boolean := False)
   is
      Stages : constant String := Hostkit.Fs.Join (Directory, "stages");
      Search : Ada.Directories.Search_Type;
      Item : Ada.Directories.Directory_Entry_Type;
      Records : Files.Types.String_Vectors.Vector;

      procedure Clean_Record (Record_Directory : String) is
         File : Ada.Streams.Stream_IO.File_Type;
         Data : constant String := Hostkit.Fs.Join (Record_Directory, "data");
         Path, Expected : Files.Types.UString;
         Recorded_Directory, Owner_Identity : Files.Types.UString;
         Owner_Valid : Boolean;
         Removed : Boolean := False;
      begin
         if Hostkit.Fs.Is_Link (Record_Directory)
           or else not Ada.Directories.Exists (Record_Directory)
           or else Ada.Directories.Kind (Record_Directory) /= Ada.Directories.Directory
         then
            return;
         end if;
         --  No published data means creation stopped before the staging
         --  pathname could be created, so this empty reservation is disposable.
         if not Ada.Directories.Exists (Data) then
            Remove_Record (Record_Directory);
            return;
         end if;
         if Hostkit.Fs.Is_Link (Data)
           or else Ada.Directories.Kind (Data) /= Ada.Directories.Ordinary_File
         then
            --  A published record is always an ordinary file.  Discard the
            --  record without inspecting an injected object or trusting it
            --  as a pathname.
            Remove_Record (Record_Directory);
            return;
         end if;
         begin
            --  Opening can fail transiently (for example because a scanner
            --  holds the file on Windows), so leave that case for retry.
            Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Data);
         exception
            when others =>
               if Discard_Unreadable then
                  --  The bounded cleanup worker has exhausted its retries.
                  --  Remove only this private record; its untrusted contents
                  --  cannot authorize touching an external pathname.
                  Remove_Record (Record_Directory);
               end if;
               return;
         end;
         begin
            if String'Input (Ada.Streams.Stream_IO.Stream (File)) /= Stage_Record_Header then
               Ada.Streams.Stream_IO.Close (File);
               Remove_Record (Record_Directory);
               return;
            end if;
            Path := To_Unbounded_String (String'Input (Ada.Streams.Stream_IO.Stream (File)));
            Expected := To_Unbounded_String (String'Input (Ada.Streams.Stream_IO.Stream (File)));
            Ada.Streams.Stream_IO.Close (File);
         exception
            when others =>
               if Ada.Streams.Stream_IO.Is_Open (File) then
                  begin
                     Ada.Streams.Stream_IO.Close (File);
                  exception
                     when others => null;
                  end;
               end if;
               --  Data is published by atomic replacement and is never
               --  subsequently edited.  Once it can be opened, a truncated
               --  or undecodable stream cannot become valid on a later pass.
               --  Drop only its private journal record; no decoded pathname
               --  is used and no external entry is touched.
               Remove_Record (Record_Directory);
               return;
         end;
         if Length (Path) = 0 then
            Remove_Record (Record_Directory);
            return;
         end if;
         if not (Ada.Directories.Exists (To_String (Path))
                 or else Hostkit.Fs.Is_Link (To_String (Path)))
         then
            Remove_Record (Record_Directory);
            return;
         end if;
         if Length (Expected) = 0 then
            --  The write-ahead record may precede finalization. An atomically
            --  published owner marker supplies the creation identity without
            --  trusting the identity currently found at the pathname.
            Read_Owner (To_String (Path), Recorded_Directory, Owner_Identity, Owner_Valid);
            if Owner_Valid and then To_String (Recorded_Directory) = Directory then
               Expected := Owner_Identity;
            end if;
         end if;
         declare
            Name : constant String := Ada.Directories.Simple_Name (To_String (Path));
            Valid : constant Boolean :=
              Name'Length > 12
              and then Name (Name'First .. Name'First + 11) = ".files-work-"
              and then Length (Expected) > 0
              and then not Hostkit.Fs.Is_Link (To_String (Path))
              and then Files.File_Identities.Token (To_String (Path)) = To_String (Expected)
              and then Owner_Matches (To_String (Path), Directory, To_String (Expected));
         begin
            if Valid then
               Removed := Files.File_System.Delete_Staging_Entry
                 (To_String (Path), To_String (Expected)).Success;
            end if;
         end;
         if Removed then
            Remove_Record (Record_Directory);
         end if;
      exception
         when others =>
            if Ada.Streams.Stream_IO.Is_Open (File) then
               Ada.Streams.Stream_IO.Close (File);
            end if;
            --  Keep only this record for retry; damage cannot hide later
            --  independent records as it could in the append-only journal.
      end Clean_Record;
   begin
      if not Files.Job_Transports.Holds (Owner, Directory) then
         return;
      end if;
      if not Ada.Directories.Exists (Stages) or else Hostkit.Fs.Is_Link (Stages)
        or else Ada.Directories.Kind (Stages) /= Ada.Directories.Directory
      then
         return;
      end if;
      Ada.Directories.Start_Search
        (Search, Stages, "stage-*", [Ada.Directories.Directory => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         Records.Append (To_Unbounded_String (Ada.Directories.Full_Name (Item)));
      end loop;
      Ada.Directories.End_Search (Search);
      for Record_Directory of Records loop
         Clean_Record (To_String (Record_Directory));
      end loop;
      begin
         Ada.Directories.Delete_Directory (Stages);
      exception
         when Ada.Directories.Use_Error => null;
      end;
   exception
      when others =>
         begin
            Ada.Directories.End_Search (Search);
         exception
            when others => null;
         end;
   end Clean_Stages;
end Files.Job_Context;
