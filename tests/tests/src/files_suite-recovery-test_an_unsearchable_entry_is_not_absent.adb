with Hostkit.Fs;
with Files.IO.Fs_Primitives;
with Files.File_System.Permissions;
separate (Files_Suite.Recovery)
   --  A cleanup that takes "nothing there" as done must not take a refusal
   --  for it: an entry inside a folder that may not be searched is not
   --  absent, so the removal is retried instead of forgotten.
   procedure Test_An_Unsearchable_Entry_Is_Not_Absent (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Locked   : constant String := Join (Root, "unsearchable-absence");
      Inside   : constant String := Join (Locked, "inside");
      Mutation : Files.File_System.Mutation_Result;
      Refused  : Boolean := False;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Locked);
      Write_Binary_File (Inside, "here");
      Assert (not Files.IO.Fs_Primitives.Entry_Is_Absent (Inside), "a readable entry is not absent");
      Assert (Files.IO.Fs_Primitives.Entry_Is_Absent (Join (Locked, "nothing")), "nothing there is absent");
      if not Files.File_System.Permissions.Supports_Permissions then
         Files_Suite.Support.Skip
           ("Test_An_Unsearchable_Entry_Is_Not_Absent", "this host has no POSIX permissions to set");
         Reset_Root;
         return;
      end if;
      Mutation := Files.File_System.Permissions.Set_Permissions (Locked, 0);
      Assert (Mutation.Success, "the folder is made unsearchable");
      if Mutation.Success then
         begin
            declare
               Unused : constant Ada.Directories.File_Size := Hostkit.Fs.Size_Of (Inside);
            begin
               null;
            end;
         exception
            when Ada.Directories.Use_Error =>
               Refused := True;
         end;
         --  Where the host really refuses (not Windows, not a privileged
         --  account), neither the entry nor a name with nothing behind it
         --  may be reported absent: the host cannot say.
         if Refused then
            Assert (not Files.IO.Fs_Primitives.Entry_Is_Absent (Inside), "a refused lookup is not absence");
            Assert
              (not Files.IO.Fs_Primitives.Entry_Is_Absent (Join (Locked, "nothing")),
               "nor is a refused lookup of a name that is not there");
         else
            --  Counted and named, so a host that stops refusing is seen
            --  rather than passing in silence.
            Files_Suite.Support.Skip
              ("Test_An_Unsearchable_Entry_Is_Not_Absent",
               "this host answers for an entry in a folder that may not be searched");
         end if;
         Mutation := Files.File_System.Permissions.Set_Permissions (Locked, 8#755#);
         Assert (Mutation.Success, "the folder is opened again");
      end if;
      Reset_Root;
   exception
      when others =>
         Mutation := Files.File_System.Permissions.Set_Permissions (Locked, 8#755#);
         raise;
   end Test_An_Unsearchable_Entry_Is_Not_Absent;
