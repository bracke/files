separate (Files_Suite.Operations)
   procedure Test_Redo_Paste_Move (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "redo-move-src");
      Dest_Dir : constant String := Join (Root, "redo-move-dest");
      Source   : constant String := Join (Src_Dir, "m.txt");
      Dest     : constant String := Join (Dest_Dir, "m.txt");
      Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Step     : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      Write_File (Source, "MOVE");
      Actions.Append
        (Files.Paste.Resolved_Action'
           (Source_Path => To_Unbounded_String (Source),
            Dest_Path   => To_Unbounded_String (Dest),
            Skip        => False,
            Replaced    => False));

      Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
      Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
      Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Move);
      Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 8);
      Assert (not Files.Model.Paste_Execution_Is_Active (Model), "the move paste finalizes");
      Assert
        (Ada.Directories.Exists (Dest) and then not Ada.Directories.Exists (Source),
         "the move relocates the file to the destination");
      Assert
        (Files.Model.Undo_Kind_Of (Model) = Files.Model.Undo_Move,
         "a move paste records an Undo_Move entry");

      Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Step.Status = Files.Operations.Operation_Success, "undo of the move succeeds");
      Assert
        (Ada.Directories.Exists (Source) and then not Ada.Directories.Exists (Dest),
         "undo moves the file back to its source");
      Assert (Files.Model.Redo_Available (Model), "a move is redoable");

      Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Assert (Step.Status = Files.Operations.Operation_Success, "redo of the move succeeds");
      Assert
        (Ada.Directories.Exists (Dest) and then not Ada.Directories.Exists (Source),
         "redo re-applies the move to the destination");
      Assert (not Files.Model.Redo_Available (Model), "the redo stack empties after re-applying the move");
   end Test_Redo_Paste_Move;
