separate (Files_Suite.Operations)
   procedure Test_Navigate_Parent_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Parent_Dir  : constant String := Join (Root, "nav-parent");
      Child_Dir   : constant String := Join (Parent_Dir, "child");
      Settings    : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load        : Files.File_System.Directory_Load_Result;
      Model       : Files.Model.Window_Model;
      Result      : Files.Controller.Controller_Result;
      Full_Parent : constant String := Ada.Directories.Full_Name (Parent_Dir);
      Full_Child  : constant String := Ada.Directories.Full_Name (Child_Dir);
      --  Its own trash, not whichever an earlier test left configured.
      Trash_Home  : constant String := Root & "_nav_parent_xdg";
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Ada.Directories.Create_Path (Files.File_System.Trash_Files_Directory);
      Ada.Directories.Create_Path (Child_Dir);
      Write_File (Join (Child_Dir, "leaf.txt"));
      Write_File (Join (Parent_Dir, "sibling.txt"));
      Load := Files.File_System.Load_Directory (Full_Child, Settings);
      Files.Model.Initialize (Model, Full_Child, Load.Items, Full_Child);

      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Navigate_Parent_Command, Model),
         "navigate-parent is enabled in a nested directory");

      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Parent_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Navigated,
         "navigate-parent navigates to the parent");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Full_Parent,
         "navigate-parent moves to the parent directory");
      Assert (Files.Model.Can_Go_Back (Model), "navigate-parent records history for back");

      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Back_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "back returns after navigate-parent");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Full_Child,
         "back restores the origin child directory");
      Assert (Files.Model.Can_Go_Forward (Model), "back leaves the way forward");

      Result := Files.Controller.Execute_Command (Files.Commands.Navigate_Forward_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "forward goes where back came from");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model), Full_Parent, "forward returns to the parent");
      Assert (not Files.Model.Can_Go_Forward (Model), "and nothing is ahead of it");
      Assert (Files.Model.Can_Go_Back (Model), "and the child is behind it again");

      --  At a filesystem root the command is disabled and navigating up is a
      --  safe no-op that leaves the current path untouched.
      declare
         Root_Model : Files.Model.Window_Model;
         Root_Op    : Files.Operations.Operation_Result;
      begin
         Files.Model.Initialize
           (Root_Model, "/", Files.File_System.Item_Vectors.Empty_Vector, Full_Child);
         Assert
           (not Files.Commands.Is_Enabled (Files.Commands.Navigate_Parent_Command, Root_Model),
            "navigate-parent is disabled at the filesystem root");
         Root_Op := Files.Operations.Navigate_Parent (Root_Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Root_Op.Status,
            Files.Operations.Operation_Disabled,
            "navigate-parent at the root is a safe no-op");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Current_Path (Root_Model),
            "/",
            "root navigate-parent keeps the current path");
      end;

      --  In the trash payload view the command is disabled like other
      --  directory-context commands.
      if Files.File_System.Trash_Files_Directory /= "" then
         declare
            Trash_Dir   : constant String := Files.File_System.Trash_Files_Directory;
            Trash_Load  : constant Files.File_System.Directory_Load_Result :=
              Files.File_System.Load_Directory (Trash_Dir, Settings);
            Trash_Model : Files.Model.Window_Model;
            Source_Load : constant Files.File_System.Item_Load_Result :=
              Files.File_System.Load_Item (Join (Full_Child, "leaf.txt"), Settings);
            Trash_Items : Files.File_System.Item_Vectors.Vector;
            Trash_Sources : Files.Types.String_Vectors.Vector;
            Trash_Result  : Files.Operations.Operation_Result;
         begin
            Assert (Trash_Load.Success and then Source_Load.Success, "the test's trash and item load");
            if Trash_Load.Success and then Source_Load.Success then
               Trash_Items.Append (Source_Load.Item);
               Files.Model.Initialize
                 (Trash_Model, To_String (Trash_Load.Path), Trash_Items, Full_Child);
               Files.Operations.Settle_Current_Is_Trash (Trash_Model);
               Files.Model.Select_Visible (Trash_Model, 1);
               Assert
                 (not Files.Commands.Is_Enabled (Files.Commands.Navigate_Parent_Command, Trash_Model),
                  "navigate-parent is disabled in the trash view");
               Assert
                 (Files.File_System.Is_Trash_Files_Directory
                    (Files.Model.Current_Path (Trash_Model)),
                  "the shared identity check recognizes the active trash payload directory");
               Trash_Result := Files.Operations.Navigate_Parent (Trash_Model, Settings);
               Assert
                 (Trash_Result.Status = Files.Operations.Operation_Disabled
                  and then Files.Model.Current_Path (Trash_Model) = To_String (Trash_Load.Path),
                  "direct parent navigation cannot expose trash metadata beside the payload directory");
               Trash_Result := Files.Operations.Open_Terminal (Trash_Model, Settings);
               Files_Suite.Support.Assert_Equal
                 (Trash_Result.Status,
                  Files.Operations.Operation_Disabled,
                  "direct terminal launch is rejected in the trash payload directory");
               Trash_Sources.Append (To_Unbounded_String (Join (Full_Child, "leaf.txt")));
               Files.Model.Set_Clipboard
                 (Trash_Model, Trash_Sources, Files.Model.Clipboard_Copy);
               Assert
                 (not Files.Commands.Is_Enabled (Files.Commands.Create_File_Command, Trash_Model),
                  "create and paste commands are disabled in the trash payload view: create file disabled");
               Assert
                 (not Files.Commands.Is_Enabled (Files.Commands.New_Folder_Command, Trash_Model),
                  "create and paste commands are disabled in the trash payload view: new folder disabled");
               Assert
                 (not Files.Commands.Is_Enabled (Files.Commands.Paste_Items_Command, Trash_Model),
                  "create and paste commands are disabled in the trash payload view: paste disabled");
               Assert
                 (not Files.Commands.Is_Enabled (Files.Commands.Delete_Selected_Items_Command, Trash_Model),
                  "commands that would desynchronize trash metadata are disabled: delete disabled");
               Assert
                 (not Files.Commands.Is_Enabled (Files.Commands.Cut_Selected_Items_Command, Trash_Model),
                  "commands that would desynchronize trash metadata are disabled: cut disabled");
               Assert
                 (not Files.Commands.Is_Enabled (Files.Commands.Duplicate_Selected_Command, Trash_Model),
                  "commands that would desynchronize trash metadata are disabled: duplicate disabled");
               Assert
                 (not Files.Commands.Is_Enabled (Files.Commands.Compress_Zip_Command, Trash_Model),
                  "commands that would desynchronize trash metadata are disabled: compress disabled");
               Assert
                 (not Files.Commands.Is_Enabled (Files.Commands.Rename_Selected_Items_Command, Trash_Model),
                  "commands that would desynchronize trash metadata are disabled: rename disabled");
               Files.Model.Set_Background_Transfers (Trash_Model, True);
               Trash_Result := Files.Operations.Delete_Selected (Trash_Model, Settings);
               Assert
                 (Trash_Result.Status = Files.Operations.Operation_Disabled
                  and then not Files.Process_Jobs.Active
                    (Files.Model.Background_Operation (Trash_Model)),
                  "direct delete cannot re-trash a trash payload or launch a helper");
               Trash_Result := Files.Operations.Duplicate_Selected (Trash_Model, Settings);
               Assert
                 (Trash_Result.Status = Files.Operations.Operation_Disabled
                  and then not Files.Process_Jobs.Active
                    (Files.Model.Background_Operation (Trash_Model)),
                  "direct duplicate cannot create an orphaned trash payload");
               Trash_Result :=
                 Files.Operations.Compress_Selected
                   (Trash_Model, Settings, Files.Operations.Zip_Archive);
               Assert
                 (Trash_Result.Status = Files.Operations.Operation_Disabled
                  and then not Files.Process_Jobs.Active
                    (Files.Model.Background_Operation (Trash_Model)),
                  "direct compression cannot create an orphaned trash payload");
               Trash_Result := Files.Operations.Extract_Selected (Trash_Model, Settings);
               Assert
                 (Trash_Result.Status = Files.Operations.Operation_Disabled
                  and then not Files.Process_Jobs.Active
                    (Files.Model.Background_Operation (Trash_Model)),
                  "direct extraction cannot create an orphaned trash payload");
               Trash_Result := Files.Operations.Create_Symlink_Selected (Trash_Model, Settings);
               Files_Suite.Support.Assert_Equal
                 (Trash_Result.Status,
                  Files.Operations.Operation_Disabled,
                  "direct link creation cannot create an orphaned trash payload");
               Files.Model.Toggle_Rename (Trash_Model);
               Files.Model.Set_Rename_Text (Trash_Model, "renamed-payload");
               Trash_Result := Files.Operations.Commit_Rename (Trash_Model, Settings);
               Files_Suite.Support.Assert_Equal
                 (Trash_Result.Status,
                  Files.Operations.Operation_Disabled,
                  "direct rename cannot desynchronize a trash payload from its metadata");
               Trash_Result :=
                 Files.Operations.Begin_Paste_To
                   (Trash_Model, Settings, Trash_Sources, Trash_Dir);
               Assert
                 (Trash_Result.Status = Files.Operations.Operation_Disabled
                  and then Files.Model.Last_Error_Key (Trash_Model) = "error.drop.invalid_destination",
                  "direct paste cannot create an orphaned trash payload");
               Trash_Sources.Clear;
               Trash_Sources.Append
                 (To_Unbounded_String (Join (Trash_Dir, "untracked-payload")));
               Trash_Result :=
                 Files.Operations.Begin_Paste_To
                   (Trash_Model, Settings, Trash_Sources, Full_Child,
                    Files.File_System.Drop_Move, From_Clipboard => False);
               Assert
                 (Trash_Result.Status = Files.Operations.Operation_Disabled
                  and then Files.Model.Last_Error_Key (Trash_Model) = "error.drop.invalid_source",
                  "direct move cannot detach a trash payload from its metadata");
               Files.Model.Begin_Create_File (Trash_Model, "orphaned-payload");
               Trash_Result := Files.Operations.Commit_Create_File (Trash_Model, Settings);
               Assert
                 (Trash_Result.Status = Files.Operations.Operation_Disabled
                  and then Files.Model.Last_Error_Key (Trash_Model) = "error.file.parent_missing",
                  "direct create cannot create an orphaned trash payload");
            end if;
         end;
      end if;

      Project_Tools.Files.Delete_Tree (Parent_Dir);
      Project_Tools.Files.Delete_Tree (Trash_Home);
   end Test_Navigate_Parent_Operation;
