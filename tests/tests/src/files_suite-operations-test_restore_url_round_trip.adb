separate (Files_Suite.Operations)
   procedure Test_Restore_Url_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Trash_Home   : constant String := Root & "_restore_url_xdg";
      Trash_File   : constant String := Join (Join (Trash_Home, "Trash"), "files");
      --  A name with a space and a literal percent: the .trashinfo Path is
      --  percent-encoded on the way in, so restoring it back to this exact path
      --  exercises the Url_Decode round-trip (%20 -> space, %25 -> %), which
      --  only the encoder side was previously covered for.
      Special_Name : constant String := "a b%c.txt";
      Source_Path  : constant String := Join (Root, Special_Name);
      Trashed_Path : constant String := Join (Trash_File, Special_Name);
      Had_Xdg_Data : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Backend  : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Xdg_Data : Unbounded_String;
      Old_Backend  : Unbounded_String;
      Mutation     : Files.File_System.Mutation_Result;

      procedure Restore_Environment is
      begin
         if Had_Xdg_Data then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", To_String (Old_Xdg_Data));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;
         if Had_Backend then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", To_String (Old_Backend));
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
   begin
      if Had_Xdg_Data then
         Old_Xdg_Data := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_DATA_HOME"));
      end if;
      if Had_Backend then
         Old_Backend := To_Unbounded_String (Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND"));
      end if;

      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");

      Write_File (Source_Path, "round trip payload");
      Mutation := Files.File_System.Move_To_Trash (Source_Path);
      Assert (Mutation.Success, "a name with a space and percent trashes");
      Assert (not Ada.Directories.Exists (Source_Path), "trashing removes the source");
      Assert (Ada.Directories.Exists (Trashed_Path), "the trashed payload keeps its literal name");

      Mutation := Files.File_System.Restore_From_Trash (Trashed_Path);
      Assert (Mutation.Success, "restoring the percent/space name succeeds");
      Assert
        (Ada.Directories.Exists (Source_Path)
         and then Project_Tools.Files.File_Contains (Source_Path, "round trip payload"),
         "the decoded original path round-trips exactly through Url_Decode");

      Project_Tools.Files.Delete_Tree (Trash_Home);
      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Restore_Url_Round_Trip;
