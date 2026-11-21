with Files.Fs_Primitives.Testing;
with Files_Suite.Support.Timing;
separate (Files_Suite.Recovery)
   --  A stage record is the only pointer to a partial staged copy in the
   --  user's folder. While the host refuses to say whether the staged entry
   --  is there (the volume not ready, a stale handle), cleanup must not take
   --  that for "gone" and forget the record, stranding the copy.
   procedure Test_Refused_Stage_Lookup_Keeps_Record (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Job       : Files.Jobs.Process.Session;
      Transport : Files.Types.UString;
      Stage     : Files.Types.UString;

      --  How many stage records the transport holds.
      function Records return Natural is
         Stages : constant String := Join (To_String (Transport), "stages");
         Count  : Natural := 0;
         Search : Ada.Directories.Search_Type;
         Item   : Ada.Directories.Directory_Entry_Type;
      begin
         if not Ada.Directories.Exists (Stages) then
            return 0;
         end if;
         Ada.Directories.Start_Search (Search, Stages, "", [Ada.Directories.Directory => True, others => False]);
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Item);
            if Ada.Directories.Simple_Name (Item) not in "." | ".." then
               Count := Count + 1;
            end if;
         end loop;
         Ada.Directories.End_Search (Search);
         return Count;
      end Records;
   begin
      Reset_Root;
      Files.Jobs.Process.Reserve (Job);
      Transport := To_Unbounded_String (Files.Jobs.Process.Path (Job, ""));
      Files.Jobs.Context.Initialize (To_String (Transport));
      Stage := To_Unbounded_String (Files.Jobs.Context.Create_Stage (Root));
      Write_Binary_File (Join (To_String (Stage), "partial"), "partial");
      Files_Suite.Support.Assert_Equal (Records, 1, "the stage has its record");

      --  The host will not say whether the staged copy is there. Cleanup may
      --  still remove it (the refusal may have passed by then), but the
      --  record goes only with it: never a record forgotten, copy left.
      Files.Fs_Primitives.Testing.Refuse_Lookups (To_String (Stage));
      Files.Jobs.Process.Clean_Stages (Job);
      Files.Fs_Primitives.Testing.Stop_Refusing_Lookups;
      Assert
        (Records = 1 or else not Ada.Directories.Exists (To_String (Stage)),
         "a refused lookup never forgets the record of a staged copy still there");

      --  Once the host answers, the stage goes with its record.
      Files.Jobs.Process.Clean_Stages (Job);
      Assert (not Ada.Directories.Exists (To_String (Stage)), "a later pass removes the staged copy");
      Files_Suite.Support.Assert_Equal (Records, 0, "and then its record");
      Files.Jobs.Context.Initialize ("");
      Files.Jobs.Process.Reset (Job);
      for Attempt in Files_Suite.Support.Timing.Polling loop
         exit when not Ada.Directories.Exists (To_String (Transport));
      end loop;
   exception
      when others =>
         Files.Fs_Primitives.Testing.Stop_Refusing_Lookups;
         Files.Jobs.Context.Initialize ("");
         raise;
   end Test_Refused_Stage_Lookup_Keeps_Record;
