with Files.File_System.Permissions.Testing;
with Ada.Containers.Indefinite_Ordered_Sets;
with Ada.Strings.Fixed;
with Files.File_System.Permissions;
with Files.Job_Drivers.Helpers.Testing;
with Files_Suite.Support.Timing;
with Files_Suite.Support.Disk;
separate (Files_Suite.Recovery)
   procedure Test_Stage_Record_Cleanup (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Transport_Job : Files.Jobs.Process.Session;
      Transport_Path : Files.Types.UString;
      function Transport return String is (To_String (Transport_Path));
      Unrelated : constant String := Join (Root, "unrelated");
      Unowned   : constant String := Join (Root, Files.Protocol_Names.Work_Stage_Prefix & "9001");
      Link      : constant String := Join (Root, Files.Protocol_Names.Work_Stage_Prefix & "9002");
      Saved     : constant String := Join (Root, "saved-stage");
      Stage     : Files.Types.UString;
      Identity  : Files.Types.UString;
      File      : Ada.Streams.Stream_IO.File_Type;
      Linked    : Boolean;
      Record_Linked : Boolean := False;
      Record_Alias : constant String := Join (Root, "stage-record-hardlink");
      Children_Before : Files.Types.UString;
      --  Linux lists each thread's children in /proc (with
      --  CONFIG_PROC_CHILDREN); other hosts have no such list.
      Lists_Children : constant Boolean :=
        Hostkit.Host.Current = Hostkit.Host.Linux and then Ada.Directories.Exists ("/proc/thread-self/children");

      --  This process's children, whichever of its threads started them (a
      --  cleanup worker may be started by the orphan reaper's task, not by
      --  the test's thread): the pids of every /proc/self/task/*/children,
      --  sorted and joined.
      function Process_Children return String is
         package Pid_Sets is new Ada.Containers.Indefinite_Ordered_Sets (String);
         Pids   : Pid_Sets.Set;
         Search : Ada.Directories.Search_Type;
         Item   : Ada.Directories.Directory_Entry_Type;
         Result : Files.Types.UString;

         --  The list, read as text: /proc gives its files no size, so a
         --  read by size sees none. A thread that ended since the search
         --  began has no list.
         function Read_List (Path : String) return String is
            List   : Ada.Text_IO.File_Type;
            Result : Files.Types.UString;
         begin
            Ada.Text_IO.Open (List, Ada.Text_IO.In_File, Path);
            while not Ada.Text_IO.End_Of_File (List) loop
               Append (Result, Ada.Text_IO.Get_Line (List) & " ");
            end loop;
            Ada.Text_IO.Close (List);
            return To_String (Result);
         exception
            when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error | Ada.IO_Exceptions.End_Error =>
               if Ada.Text_IO.Is_Open (List) then
                  Ada.Text_IO.Close (List);
               end if;
               return To_String (Result);
         end Read_List;
      begin
         Ada.Directories.Start_Search
           (Search, "/proc/self/task", "*", [Ada.Directories.Directory => True, others => False]);
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Item);
            declare
               Name : constant String := Ada.Directories.Simple_Name (Item);
            begin
               if Name /= "." and then Name /= ".." then
                  declare
                     List  : constant String := Read_List (Ada.Directories.Full_Name (Item) & "/children");
                     First : Positive := List'First;
                  begin
                     for Index in List'First .. List'Last + 1 loop
                        if Index > List'Last or else List (Index) = ' ' then
                           if Index > First then
                              Pids.Include (List (First .. Index - 1));
                           end if;
                           First := Index + 1;
                        end if;
                     end loop;
                  end;
               end if;
            end;
         end loop;
         Ada.Directories.End_Search (Search);
         for Pid of Pids loop
            Append (Result, Pid & " ");
         end loop;
         return To_String (Result);
      end Process_Children;

      --  The children in Now that Before did not list: a child an earlier
      --  test left may end meanwhile, so only new ones count.
      function Children_Added (Before, Now : String) return String is
         Result : Files.Types.UString;
         First  : Positive := Now'First;
      begin
         for Index in Now'Range loop
            if Now (Index) = ' ' then
               if Index > First
                 and then Ada.Strings.Fixed.Index (" " & Before, " " & Now (First .. Index)) = 0
               then
                  Append (Result, Now (First .. Index));
               end if;
               First := Index + 1;
            end if;
         end loop;
         return To_String (Result);
      end Children_Added;
      Transport_Identity : Files.Types.UString;
      Before    : Instant;

      procedure Add_Stage_Record
        (Record_Name, Path, Expected_Identity : String;
         Corrupt : Boolean := False;
         Oversized : Boolean := False)
      is
         Record_Directory : constant String :=
           Join (Join (Transport, "stages"), Record_Name);
         Record_File : Ada.Streams.Stream_IO.File_Type;
      begin
         if not Ada.Directories.Exists (Record_Directory) then
            Ada.Directories.Create_Path (Record_Directory);
         elsif Hostkit.Fs.Is_Link (Record_Directory)
           or else Ada.Directories.Kind (Record_Directory) /=
             Ada.Directories.Directory
         then
            raise Ada.Directories.Use_Error;
         end if;
         Ada.Streams.Stream_IO.Create
           (Record_File, Ada.Streams.Stream_IO.Out_File, Join (Record_Directory, "data"));
         String'Output
           (Ada.Streams.Stream_IO.Stream (Record_File),
            (if Corrupt then "damaged-stage-record" else "files-stage-3"));
         if Oversized then
            --  String'Output encodes these two bounds before the payload.
            --  A malformed record must be rejected before attempting the
            --  allocation described by its forged upper bound.
            Integer'Output (Ada.Streams.Stream_IO.Stream (Record_File), 1);
            Integer'Output
              (Ada.Streams.Stream_IO.Stream (Record_File), Integer'Last);
         elsif not Corrupt then
            String'Output (Ada.Streams.Stream_IO.Stream (Record_File), Path);
            String'Output (Ada.Streams.Stream_IO.Stream (Record_File), Expected_Identity);
         end if;
         Ada.Streams.Stream_IO.Close (Record_File);
      end Add_Stage_Record;
   begin
      Reset_Root;
      Files.Jobs.Process.Reserve (Transport_Job);
      Transport_Path := To_Unbounded_String (Files.Jobs.Process.Path (Transport_Job, ""));
      Transport_Identity := To_Unbounded_String (Files.File_Identities.Token (Transport));
      Ada.Directories.Create_Directory (Unrelated);
      Ada.Directories.Create_Directory (Unowned);
      Write_Binary_File (Join (Unrelated, "keep"), "unrelated");
      Files.Jobs.Context.Initialize (Transport);

      Stage := To_Unbounded_String (Files.Jobs.Context.Create_Stage (Root));
      Write_Binary_File (Join (To_String (Stage), "partial"), "partial");
      --  Simulate termination after the owner marker was published but before
      --  the write-ahead record was finalized with its identity.
      Ada.Streams.Stream_IO.Create
        (File, Ada.Streams.Stream_IO.Out_File,
         Join (Join (Join (Transport, "stages"), "stage-1"), "data"));
      String'Output (Ada.Streams.Stream_IO.Stream (File), "files-stage-3");
      String'Output (Ada.Streams.Stream_IO.Stream (File), To_String (Stage));
      String'Output (Ada.Streams.Stream_IO.Stream (File), "");
      Ada.Streams.Stream_IO.Close (File);
      Ada.Streams.Stream_IO.Open
        (File, Ada.Streams.Stream_IO.Append_File,
         Join (Join (Join (Transport, "stages"), "stage-1"), "data"));
      String'Output (Ada.Streams.Stream_IO.Stream (File), "trailing");
      Ada.Streams.Stream_IO.Close (File);
      Files.Jobs.Process.Clean_Stages (Transport_Job);
      Assert
        (Ada.Directories.Exists (To_String (Stage))
         and then not Ada.Directories.Exists
           (Join (Join (Transport, "stages"), "stage-1")),
         "stage cleanup discards a trailing-data record without deleting its named entry");
      Add_Stage_Record
        ("stage-trailing-retry", To_String (Stage), "");
      Linked := Hostkit.Fs.Create_Link (Unrelated, Link);
      Add_Stage_Record ("stage-unrelated", Unrelated, Files.File_Identities.Token (Unrelated));
      Record_Linked := Hostkit.Fs.Create_Hard_Link
        (Join (Join (Join (Transport, "stages"), "stage-unrelated"), "data"),
         Record_Alias);
      if not Record_Linked then
         Files_Suite.Support.Disk.Link_Not_Made ("Test_Stage_Record_Cleanup", Files_Suite.Support.Disk.Hard_Link);
      end if;
      Add_Stage_Record ("stage-unowned", Unowned, Files.File_Identities.Token (Unowned));
      Add_Stage_Record ("stage-absent", Join (Root, Files.Protocol_Names.Work_Stage_Prefix & "8000"), "");
      Add_Stage_Record ("stage-relative", Files.Protocol_Names.Work_Stage_Prefix & "relative", "");
      if Linked then
         Add_Stage_Record ("stage-link", Link, Files.File_Identities.Token (Link));
      else
         Files_Suite.Support.Disk.Link_Not_Made ("Test_Stage_Record_Cleanup", Files_Suite.Support.Disk.Symbolic_Link);
      end if;
      Add_Stage_Record ("stage-corrupt", "", "", Corrupt => True);
      Add_Stage_Record ("stage-oversized", "", "", Oversized => True);
      Add_Stage_Record ("stage-truncated", "", "");
      Write_Binary_File
        (Join (Join (Join (Transport, "stages"), "stage-truncated"), "data"),
         "truncated");
      Files.Jobs.Process.Clean_Stages (Transport_Job);
      Assert (not Ada.Directories.Exists (To_String (Stage)), "cleanup removes its own partial staging directory");
      Files_Suite.Support.Assert_Equal
        (Project_Tools.Files.Read_Raw_File (Join (Unrelated, "keep")),
         "unrelated",
         "cleanup preserves unrelated data");
      Assert (Ada.Directories.Exists (Unowned), "cleanup refuses an unowned staging-shaped pathname");
      Assert (not Linked or else Hostkit.Fs.Is_Link (Link), "cleanup never follows or deletes a substituted symlink");
      Assert
        (not Record_Linked
         or else not Ada.Directories.Exists
           (Join (Join (Transport, "stages"), "stage-unrelated")),
         "stage cleanup rejects and discards a multiply-linked record");
      if Record_Linked and then Ada.Directories.Exists (Record_Alias) then
         Ada.Directories.Delete_File (Record_Alias);
      end if;
      Assert
        (not Ada.Directories.Exists (Join (Join (Transport, "stages"), "stage-corrupt")),
         "malformed and allocation-sized stage records are discarded without trusting their contents"
         & ": corrupt record discarded");
      Assert
        (not Ada.Directories.Exists (Join (Join (Transport, "stages"), "stage-oversized")),
         "malformed and allocation-sized stage records are discarded without trusting their contents"
         & ": oversized record discarded");
      Assert
        (not Ada.Directories.Exists (Join (Join (Transport, "stages"), "stage-truncated")),
         "malformed and allocation-sized stage records are discarded without trusting their contents"
         & ": truncated record discarded");
      Assert
        (not Ada.Directories.Exists (Join (Join (Transport, "stages"), "stage-relative")),
         "malformed and allocation-sized stage records are discarded without trusting their contents"
         & ": relative record discarded");
      Assert (not Ada.Directories.Exists (Join (Join (Transport, "stages"), "stage-absent")),
              "a write-ahead reservation with no created pathname is discarded safely");
      Assert
        (not Files.Job_Drivers.Helpers.Testing.Run_Cleanup
           (Transport, To_String (Transport_Identity), Attempt_Limit => 1,
            Initial_Retry_Delay => 0.0, Maximum_Retry_Delay => 0.0)
         and then Ada.Directories.Exists (Join (Transport, "stages")),
         "bounded cleanup cannot consume stage records while the creator is live");
      Files.Jobs.Process.Testing.Release_Owner (Transport_Job);
      if Hostkit.Host.Current = Hostkit.Host.Linux
        and then not Hostkit.Host.Is_Elevated
      then
         declare
            Data : constant String :=
              Join (Join (Join (Transport, "stages"), "stage-unreadable"), "data");
            Result : Files.File_System.Mutation_Result;
            Outcome : Files.Jobs.Cleanup.Cleanup_Outcome;
            use type Files.Jobs.Cleanup.Cleanup_Outcome;
         begin
            Add_Stage_Record
              ("stage-unreadable", Join (Root, Files.Protocol_Names.Work_Stage_Prefix & "missing"), "");
            Result := Files.File_System.Permissions.Testing.Set_Permissions (Data, 0);
            Assert (Result.Success, "make a stage record temporarily unreadable");
            Outcome := Files.Jobs.Cleanup.Run
              (Transport, To_String (Transport_Identity),
               Attempt_Limit => 1, Unreadable => Files.Jobs.Cleanup.Keep_Unreadable);
            Assert
              (Outcome = Files.Jobs.Cleanup.Cleanup_Failed
               and then Ada.Directories.Exists
                 (Join (Join (Transport, "stages"), "stage-unreadable")),
               "one fallback pass keeps an unreadable stage record for later retry");
            Result := Files.File_System.Permissions.Testing.Set_Permissions (Data, 8#600#);
            Assert (Result.Success, "restore stage record access for cleanup");
         end;
      end if;
      Before := Now;
      declare
         Cleaned : constant Boolean := Files.Job_Drivers.Helpers.Testing.Run_Cleanup
           (Transport, To_String (Transport_Identity), Attempt_Limit => 2,
            Initial_Retry_Delay => 0.001, Maximum_Retry_Delay => 0.001);
      begin
         Assert_Within (Before, Prompt_Limit, "bounded cleanup gives up on malformed stage records without waiting");
         Assert
           (not Cleaned,
            "bounded cleanup does not retry permanently malformed stage records: not reported as cleaned");
         Assert
           (not Ada.Directories.Exists (Join (Join (Transport, "stages"), "stage-corrupt")),
            "bounded cleanup does not retry permanently malformed stage records: corrupt record gone");
         Assert
           (not Ada.Directories.Exists (Join (Join (Transport, "stages"), "stage-truncated")),
            "bounded cleanup does not retry permanently malformed stage records: truncated record gone");
      end;
      Files.Jobs.Context.Initialize ("");
      Stage := To_Unbounded_String (Files.Jobs.Context.Create_Stage (Root));
      Write_Binary_File (Join (To_String (Stage), "partial"), "foreground partial");
      Assert (Files.Jobs.Context.Discard_Stage (To_String (Stage))
              and then not Ada.Directories.Exists (To_String (Stage)),
              "foreground staging records its identity and cleans through the same guarded path");
      Stage := To_Unbounded_String (Files.Jobs.Context.Create_Stage (Root));
      Identity := To_Unbounded_String (Files.File_Identities.Token (To_String (Stage)));
      if Lists_Children then
         Children_Before := To_Unbounded_String (Process_Children);
      end if;
      declare
         Owner_Directory : Files.Types.UString;
      begin
         Ada.Streams.Stream_IO.Open
           (File, Ada.Streams.Stream_IO.In_File, Join (To_String (Stage), Files.Protocol_Names.Stage_Owner_File));
         Files_Suite.Support.Assert_Equal
           (String'Input (Ada.Streams.Stream_IO.Stream (File)),
            Files.Protocol_Names.Stage_Owner_Header,
            "foreground stage publishes its owner marker atomically");
         Owner_Directory := To_Unbounded_String (String'Input (Ada.Streams.Stream_IO.Stream (File)));
         Ada.Streams.Stream_IO.Close (File);
         Ada.Directories.Rename (To_String (Stage), Saved);
         Ada.Directories.Create_Directory (To_String (Stage));
         Ada.Streams.Stream_IO.Create
           (File, Ada.Streams.Stream_IO.Out_File, Join (To_String (Stage), Files.Protocol_Names.Stage_Owner_File));
         String'Output (Ada.Streams.Stream_IO.Stream (File), Files.Protocol_Names.Stage_Owner_Header);
         String'Output (Ada.Streams.Stream_IO.Stream (File), To_String (Owner_Directory));
         String'Output (Ada.Streams.Stream_IO.Stream (File), To_String (Identity));
         Ada.Streams.Stream_IO.Close (File);
         Assert (not Files.Jobs.Context.Discard_Stage (To_String (Stage))
                 and then Ada.Directories.Exists (To_String (Stage)),
                 "foreground cleanup refuses a replacement and schedules its owned stage for retry");
         Ada.Directories.Delete_File (Join (To_String (Stage), Files.Protocol_Names.Stage_Owner_File));
         Ada.Directories.Delete_Directory (To_String (Stage));
         Ada.Directories.Rename (Saved, To_String (Stage));
         for Attempt in Files_Suite.Support.Timing.Polling loop
            exit when not Ada.Directories.Exists (To_String (Stage))
              and then not Ada.Directories.Exists (To_String (Owner_Directory));
         end loop;
         Assert (not Ada.Directories.Exists (To_String (Stage))
                 and then not Ada.Directories.Exists (To_String (Owner_Directory)),
                 "idle foreground cleanup retries its durable record and removes its transport");
         if Lists_Children then
            for Attempt in Files_Suite.Support.Timing.Polling loop
               exit when Children_Added (To_String (Children_Before), Process_Children) = "";
            end loop;
            Files_Suite.Support.Assert_Equal
              (Children_Added (To_String (Children_Before), Process_Children),
               "",
               "idle cleanup leaves no child process waiting for a later job API call");
         else
            Files_Suite.Support.Skip
              ("Test_Stage_Record_Cleanup", "the leftover-child half needs Linux's /proc children lists");
         end if;
      end;
      --  Cleanup rightly refuses the unowned and linked records planted
      --  above, so it could never finish this transport. Remove them, then
      --  release the transport and wait for its cleanup child, so no
      --  cleanup outlives this test.
      declare
         Unowned_Record : constant Files.File_System.Mutation_Result :=
           Files.File_System.Delete_Permanently (Join (Join (Transport, "stages"), "stage-unowned"));
         Link_Record : constant Files.File_System.Mutation_Result :=
           Files.File_System.Delete_Permanently (Join (Join (Transport, "stages"), "stage-link"));
         pragma Unreferenced (Unowned_Record, Link_Record);
      begin
         null;
      end;
      Files.Jobs.Process.Reset (Transport_Job);
      for Attempt in Files_Suite.Support.Timing.Polling loop
         exit when not Ada.Directories.Exists (Transport);
      end loop;
      Assert
        (not Ada.Directories.Exists (Transport),
         "the released transport is cleaned up once its planted records are gone");
   exception
      when others => Files.Jobs.Context.Initialize (""); raise;
   end Test_Stage_Record_Cleanup;
