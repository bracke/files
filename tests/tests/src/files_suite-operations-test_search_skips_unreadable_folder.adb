separate (Files_Suite.Operations)
   --  A folder below the search root that cannot be read is skipped: the
   --  matches around it are shown, with the notice that some went unsearched.
   procedure Test_Search_Skips_Unreadable_Folder (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Locked   : constant String := Join (Root, "locked");
      Later    : constant String := Join (Root, "zz-later");
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Search   : Files.File_System.Recursive_Search_Result;
   begin
      if not Files.File_System.Supports_Permissions then
         Files_Suite.Support.Skip ("Test_Search_Skips_Unreadable_Folder", "this host has no POSIX permissions to set");
         return;
      end if;
      Reset_Root;
      Ada.Directories.Create_Directory (Locked);
      Ada.Directories.Create_Directory (Later);
      Write_Binary_File (Join (Root, "needle-top.txt"), "needle");
      Write_Binary_File (Join (Locked, "needle-hidden.txt"), "needle");
      Write_Binary_File (Join (Later, "needle-later.txt"), "needle");
      Mutation := Files.File_System.Set_Permissions (Locked, 0);
      Assert (Mutation.Success, "make the folder unreadable");
      if Files.File_System.Load_Directory (Locked, Settings).Success then
         Mutation := Files.File_System.Set_Permissions (Locked, 8#755#);
         Files_Suite.Support.Skip ("Test_Search_Skips_Unreadable_Folder", "root reads an unreadable folder");
         return;
      end if;
      for Contents in Boolean loop
         Search := (if Contents then Files.File_System.Search_Contents (Root, "needle", Settings)
                    else Files.File_System.Search_Names (Root, "needle", Settings));
         Assert (Search.Success and then Search.Incomplete and then not Search.Truncated,
                 "an unreadable folder makes the search incomplete, not failed, contents " & Contents'Image);
         Files_Suite.Support.Assert_Equal
           (Natural (Search.Items.Length), 2,
            "the matches before and after the unreadable folder are kept, contents " & Contents'Image);
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Set_Background_Transfers (Model, False);
         Files.Model.Set_Filter (Model, "needle");
         Step := (if Contents then Files.Operations.Run_Search (Model, Settings, Files.Types.Search_Contents)
                  else Files.Operations.Run_Search (Model, Settings, Files.Types.Search_Names));
         Assert (Step.Status = Files.Operations.Operation_Success
                 and then Files.Model.Search_Results_Are_Active (Model)
                 and then Files.Model.Item_Count (Model) = 2,
                 "the view shows the other matches, contents " & Contents'Image);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Last_Error_Key (Model), "search.incomplete",
            "with the incomplete notice, contents " & Contents'Image);
      end loop;
      Mutation := Files.File_System.Set_Permissions (Locked, 8#755#);
   exception
      when others =>
         Mutation := Files.File_System.Set_Permissions (Locked, 8#755#);
         raise;
   end Test_Search_Skips_Unreadable_Folder;
