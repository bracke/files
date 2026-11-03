with Hostkit.Watch;
separate (Files_Suite.Operations)
   --  The native watch, end to end through its helper process: where the
   --  host's watch also hears file writes, the helper says so (the window
   --  then re-reads its folder every 10 s only), and a change in the folder
   --  reaches Poll_Watch promptly. Where it does not, the helper keeps quiet
   --  about it, so the window keeps its 1 s re-read.
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
      Files_Suite.Support.Assert_Equal
        (Native, Hostkit.Watch.Sees_File_Writes,
         "the helper reports a native watch exactly where it hears file writes");
      --  Give the helper time to have its watch in place before the change.
      for Attempt in Files_Suite.Support.Polling (Limit => 0.5) loop
         null;
      end loop;
      Write_Binary_File (Join (Folder, "new.txt"), "new");
      for Attempt in Files_Suite.Support.Polling (Limit => Seconds (Launch_Limit)) loop
         Noticed := Files.Refresh_Jobs.Poll_Watch (Watch);
         exit when Noticed;
      end loop;
      Files.Refresh_Jobs.Release_Watch (Watch);
      Assert (Noticed, "a file made in the watched folder reaches the window");
   exception
      when others =>
         Files.Refresh_Jobs.Release_Watch (Watch);
         raise;
   end Test_Native_Watch_End_To_End;
