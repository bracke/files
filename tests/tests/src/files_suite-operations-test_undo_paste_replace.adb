separate (Files_Suite.Operations)
   procedure Test_Undo_Paste_Replace (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings    : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Trash_Home  : constant String := Root & "_replace_xdg";
      Had_Xdg     : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Home    : constant Boolean := Ada.Environment_Variables.Exists ("HOME");
      Had_Backend : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Xdg     : Unbounded_String;
      Old_Home    : Unbounded_String;
      Old_Backend : Unbounded_String;

      procedure Restore_Environment is
      begin
         if Had_Xdg then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", To_String (Old_Xdg));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;

         if Had_Home then
            Ada.Environment_Variables.Set ("HOME", To_String (Old_Home));
         else
            Ada.Environment_Variables.Clear ("HOME");
         end if;

         if Had_Backend then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", To_String (Old_Backend));
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Save (Environment, "HOME");
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      if Had_Xdg then
         Old_Xdg := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_DATA_HOME"));
      end if;
      if Had_Home then
         Old_Home := To_Unbounded_String (Ada.Environment_Variables.Value ("HOME"));
      end if;
      if Had_Backend then
         Old_Backend := To_Unbounded_String (Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND"));
      end if;

      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      --  Sandbox the trash so Clear_Replaced_Destination can trash the overwritten
      --  original into a scratch location and the undo can restore it from there.
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");

      --  Copy-replace: the destination holds "old"; pasting "new" over it overwrites
      --  the file, and undo must bring "old" back (not merely delete the pasted copy).
      declare
         Src_Dir  : constant String := Join (Root, "rep-copy-src");
         Dest_Dir : constant String := Join (Root, "rep-copy-dest");
         Source   : constant String := Join (Src_Dir, "report.txt");
         Dest     : constant String := Join (Dest_Dir, "report.txt");
         Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
         Load     : Files.File_System.Directory_Load_Result;
         Model    : Files.Model.Window_Model;
         Step     : Files.Operations.Operation_Result;
      begin
         Ada.Directories.Create_Path (Src_Dir);
         Ada.Directories.Create_Path (Dest_Dir);
         Write_File (Source, "new");
         Write_File (Dest, "old");
         Actions.Append
           (Files.Paste.Resolved_Action'
              (Source_Path => To_Unbounded_String (Source),
               Dest_Path   => To_Unbounded_String (Dest),
               Skip        => False,
               Replaced    => True));

         Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
         Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
         Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);
         Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 8);
         Assert (not Files.Model.Paste_Execution_Is_Active (Model), "the copy-replace paste finalizes");
         Files_Suite.Support.Assert_Equal
           (Files.File_System.Read_Preview_Text (Dest, 3),
            "new",
            "the copy-replace overwrites the destination with the pasted content");

         Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         if Step.Status = Files.Operations.Operation_Success then
            Assert
              (Ada.Directories.Exists (Dest)
                 and then Files.File_System.Read_Preview_Text (Dest, 3) = "old",
               "undo of a copy-replace restores the overwritten original at the destination");
            Assert
              (not Files.Model.Redo_Available (Model),
               "a copy paste that replaced an existing file is not redoable");
         end if;
      end;

      --  Move-replace: same overwrite, but the source is relocated. Undo must both
      --  return the source and restore the overwritten original at the destination.
      declare
         Src_Dir  : constant String := Join (Root, "rep-move-src");
         Dest_Dir : constant String := Join (Root, "rep-move-dest");
         Source   : constant String := Join (Src_Dir, "report.txt");
         Dest     : constant String := Join (Dest_Dir, "report.txt");
         Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
         Load     : Files.File_System.Directory_Load_Result;
         Model    : Files.Model.Window_Model;
         Step     : Files.Operations.Operation_Result;
      begin
         Ada.Directories.Create_Path (Src_Dir);
         Ada.Directories.Create_Path (Dest_Dir);
         Write_File (Source, "new");
         Write_File (Dest, "old");
         Actions.Append
           (Files.Paste.Resolved_Action'
              (Source_Path => To_Unbounded_String (Source),
               Dest_Path   => To_Unbounded_String (Dest),
               Skip        => False,
               Replaced    => True));

         Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
         Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
         Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Move);
         Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 8);
         Assert (not Files.Model.Paste_Execution_Is_Active (Model), "the move-replace paste finalizes");
         Assert
           (Files.File_System.Read_Preview_Text (Dest, 3) = "new"
              and then not Ada.Directories.Exists (Source),
            "the move-replace overwrites the destination and consumes the source");

         Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         if Step.Status = Files.Operations.Operation_Success then
            Assert
              (Ada.Directories.Exists (Source)
                 and then Files.File_System.Read_Preview_Text (Source, 3) = "new",
               "undo of a move-replace returns the source to its origin");
            Assert
              (Ada.Directories.Exists (Dest)
                 and then Files.File_System.Read_Preview_Text (Dest, 3) = "old",
               "undo of a move-replace restores the overwritten original at the destination");
            Assert
              (not Files.Model.Redo_Available (Model),
               "a move paste that replaced an existing file is not redoable");
         end if;
      end;

      Restore_Environment;
      Project_Tools.Files.Delete_Tree (Trash_Home);
   end Test_Undo_Paste_Replace;
