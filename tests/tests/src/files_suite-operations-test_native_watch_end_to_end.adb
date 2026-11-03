with Hostkit.Watch;
separate (Files_Suite.Operations)
   --  The watch, end to end through its helper process: once up, the helper
   --  reports everything the listing shows on every host -- from the host's
   --  watch where it hears files being written, from its own re-reads of the
   --  folder's signature where not -- so the window re-reads every 10 s only.
   --  A new file, and then a write into it, both reach Poll_Watch.
   procedure Test_Native_Watch_End_To_End (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Folder  : constant String := Join (Root, "watched");
      Watch   : Files.Refresh_Jobs.Watch_Session;
      Noticed : Boolean := False;
      Native  : Boolean := False;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Folder);
      Files.Refresh_Jobs.Watch_Path (Watch, Folder);
      --  The helper registers its watch once it is running.
      for Attempt in Files_Suite.Support.Polling (Limit => Seconds (Launch_Limit)) loop
         Native := Files.Refresh_Jobs.Watch_Is_Native (Watch);
         exit when Native;
      end loop;
      Assert (Native, "the helper says it reports changes, on every host");
      --  Give the helper time to have its watch in place before the change.
      for Attempt in Files_Suite.Support.Polling (Limit => 0.5) loop
         null;
      end loop;
      Write_Binary_File (Join (Folder, "new.txt"), "new");
      for Attempt in Files_Suite.Support.Polling (Limit => Seconds (Launch_Limit)) loop
         Noticed := Files.Refresh_Jobs.Poll_Watch (Watch);
         exit when Noticed;
      end loop;
      Assert (Noticed, "a file made in the watched folder reaches the window");

      --  A download growing: the host's watch hears it where it can
      --  (Hostkit.Watch.Sees_File_Writes), the helper's re-read elsewhere.
      for Attempt in Files_Suite.Support.Polling (Limit => 0.3) loop
         Noticed := Files.Refresh_Jobs.Poll_Watch (Watch);
      end loop;
      Write_Binary_File (Join (Folder, "new.txt"), "new, and grown");
      Noticed := False;
      for Attempt in Files_Suite.Support.Polling (Limit => Seconds (Launch_Limit)) loop
         Noticed := Files.Refresh_Jobs.Poll_Watch (Watch);
         exit when Noticed;
      end loop;
      Files.Refresh_Jobs.Release_Watch (Watch);
      Assert
        (Noticed,
         "a write into a file already there reaches the window too"
         & (if Hostkit.Watch.Sees_File_Writes then " (from the watch)" else " (from the helper's re-read)"));
   exception
      when others =>
         Files.Refresh_Jobs.Release_Watch (Watch);
         raise;
   end Test_Native_Watch_End_To_End;
