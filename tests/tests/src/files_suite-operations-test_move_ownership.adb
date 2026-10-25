with Files_Suite.Volumes;
separate (Files_Suite.Operations)
   procedure Test_Move_Ownership (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function Supplementary_Group return Interfaces.C.long_long
        with Import, Convention => C, External_Name => "files_test_supplementary_group";
      function Set_Group (Path : System.Address) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_set_copy_group";
      function Entry_Group (Path : System.Address) return Interfaces.C.long_long
        with Import, Convention => C, External_Name => "files_test_entry_group";
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "source");
      Remote : Files_Suite.Volumes.Remote_Directory;
      Expected : Interfaces.C.long_long;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;
      procedure Cleanup is
      begin
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
      end Cleanup;
      procedure Prepare (Path : String) is
         Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Path);
      begin
         Assert (Set_Group (Name'Address) = 1, "set a permitted supplementary owning group");
      end Prepare;
      procedure Check (Path : String) is
         Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Path);
      begin
         Assert (Entry_Group (Name'Address) = Expected, "preserve the owning group without following links");
      end Check;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip ("Test_Move_Ownership", "Hostkit.Host.Current /= Hostkit.Host.Linux");
         return;
      end if;
      Expected := Supplementary_Group;
      if Expected < 0 then
         Files_Suite.Support.Skip ("Test_Move_Ownership", "Expected < 0");
         return;
      end if;
      Remote.Create ("files-test-move-ownership-");
      if Remote.Path = "" then
         Files_Suite.Support.Skip ("Test_Move_Ownership", Files_Suite.Volumes.No_Other_Volume);
         return;
      end if;
      for Background in Boolean loop
         Reset_Root;
         Ada.Directories.Create_Directory (Source);
         Write_Binary_File (Join (Source, "child"), "group protected bytes");
         Assert (Hostkit.Fs.Create_Link ("child", Join (Source, "link")), "prepare a symlink ownership fixture");
         Prepare (Source);
         Prepare (Join (Source, "child"));
         Prepare (Join (Source, "link"));
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Operations.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Actions.Clear;
         Actions.Append (Files.Paste.Resolved_Action'
           (To_Unbounded_String (Source), To_Unbounded_String (Join (Remote.Path, "source")), False, False));
         Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Move, False);
         Step := Complete_Operation (Model, Settings, Files.Operations.Advance_Paste_Execution (Model, Settings, 1));
         Await_View (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Step.Status,
            Files.Operations.Operation_Success,
            "move the ownership tree across filesystems");
         for Cycle in 1 .. 2 loop
            Check (Join (Remote.Path, "source"));
            Check (Join (Remote.Path, "source/child"));
            Check (Join (Remote.Path, "source/link"));
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Success,
               "Undo the ownership-preserving move");
            Check (Source);
            Check (Join (Source, "child"));
            Check (Join (Source, "link"));
            Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Await_View (Model, Settings);
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Success,
               "Redo the ownership-preserving move");
         end loop;
         Project_Tools.Files.Delete_Tree (Join (Remote.Path, "source"));
      end loop;
      Cleanup;
   exception
      when others => Cleanup; raise;
   end Test_Move_Ownership;
