separate (Files_Suite.Operations)
   procedure Test_Recovery_Registry_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Registry : constant String :=
        Join (Join (Join (Ada.Environment_Variables.Value ("FILES_TEST_TEMP"), "data"), "files"),
              "recovery-index");
      Victim   : constant String := Join (Root, "created.txt");
      Stale    : constant String := Join (Registry, ".files-recovery-9999");

      function Record_Count return Natural is
         Search : Ada.Directories.Search_Type;
         Item   : Ada.Directories.Directory_Entry_Type;
         Count  : Natural := 0;
      begin
         if not Ada.Directories.Exists (Registry) then
            return 0;
         end if;
         Ada.Directories.Start_Search
           (Search, Registry, ".files-recovery-*", [Ada.Directories.Directory => True, others => False]);
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Item);
            Count := Count + 1;
         end loop;
         Ada.Directories.End_Search (Search);
         return Count;
      end Record_Count;

      Before : Natural;
   begin
      Reset_Root;
      Write_Binary_File (Victim, "created");
      Before := Record_Count;
      Assert
        (Files.File_System.Delete_Created_Entry
           (Victim, Files.File_Identities.Token (Victim), Files.File_System.Tree_Revision (Victim)).Success,
         "a verified delete of a created entry succeeds");
      Assert (not Ada.Directories.Exists (Victim), "the created entry is gone");
      Files_Suite.Support.Assert_Equal
        (Record_Count,
         Before,
         "a verified delete unregisters the backup it preserved instead of leaking a record");

      --  A rollback deletes against the revision captured when the copy was
      --  published: a file added to it since keeps the whole tree.
      Ada.Directories.Create_Path (Join (Root, "published-copy"));
      Write_Binary_File (Join (Join (Root, "published-copy"), "copied.txt"), "copied");
      declare
         Copy     : constant String := Join (Root, "published-copy");
         Identity : constant String := Files.File_Identities.Token (Copy);
         Revision : constant String := Files.File_System.Tree_Revision (Copy);
      begin
         Write_Binary_File (Join (Copy, "added-since.txt"), "someone else's");
         Assert (not Files.File_System.Delete_Created_Entry (Copy, Identity, Revision).Success,
                 "a copy changed since it was published is not rolled back");
         Assert (Ada.Directories.Exists (Join (Copy, "added-since.txt")), "the file added since is kept");
         Assert (Files.File_System.Delete_Created_Entry
                   (Copy, Identity, Files.File_System.Tree_Revision (Copy)).Success,
                 "the same copy at its current revision is deleted");
      end;

      --  A record whose stage is gone (as leaked by older builds) is reclaimed
      --  by the payload scan rather than accumulating forever.
      if not Ada.Directories.Exists (Stale) then
         Ada.Directories.Create_Path (Stale);
         declare
            Leaked : constant String := Join (Join (Root, ".files-recovery-404"), "payload");
            File   : Ada.Streams.Stream_IO.File_Type;
         begin
            Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Join (Stale, "record"));
            String'Output (Ada.Streams.Stream_IO.Stream (File), "files-recovery-registry-v1");
            String'Output (Ada.Streams.Stream_IO.Stream (File), Leaked);
            String'Output (Ada.Streams.Stream_IO.Stream (File), "");
            Ada.Streams.Stream_IO.Close (File);
         end;
      end if;
      declare
         Payloads : constant Files.Types.String_Vectors.Vector :=
           Files.File_System.Registered_Recovery_Payloads;
         pragma Unreferenced (Payloads);
      begin
         null;
      end;
      Assert (not Ada.Directories.Exists (Stale),
              "a registry record whose stage no longer exists is reclaimed");

      --  Reused stage names left many records for one payload; the scan keeps one.
      declare
         Stage  : constant String := Join (Root, ".files-recovery-77");
         Shared : constant String := Join (Stage, "payload");
         Copies : constant array (1 .. 2) of String (1 .. 4) := ["9997", "9998"];
         Left   : Natural := 0;
      begin
         Ada.Directories.Create_Path (Stage);
         for Copy of Copies loop
            declare
               Dir  : constant String := Join (Registry, ".files-recovery-" & Copy);
               File : Ada.Streams.Stream_IO.File_Type;
            begin
               Ada.Directories.Create_Path (Dir);
               Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Join (Dir, "record"));
               String'Output (Ada.Streams.Stream_IO.Stream (File), "files-recovery-registry-v1");
               String'Output (Ada.Streams.Stream_IO.Stream (File), Shared);
               String'Output (Ada.Streams.Stream_IO.Stream (File), "");
               Ada.Streams.Stream_IO.Close (File);
            end;
         end loop;
         declare
            Payloads : constant Files.Types.String_Vectors.Vector :=
              Files.File_System.Registered_Recovery_Payloads;
            pragma Unreferenced (Payloads);
         begin
            null;
         end;
         for Copy of Copies loop
            if Ada.Directories.Exists (Join (Registry, ".files-recovery-" & Copy)) then
               Left := Left + 1;
            end if;
         end loop;
         Files_Suite.Support.Assert_Equal (Left, 1, "duplicate records for one payload collapse to a single record");
      end;
   end Test_Recovery_Registry_Bounded;
