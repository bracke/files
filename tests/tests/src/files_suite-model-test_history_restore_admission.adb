separate (Files_Suite.Model)
   procedure Test_History_Restore_Admission
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Model : Files.Model.Window_Model;
      Undo, Redo : Files.Model.Undo_Entry_Vectors.Vector;

      function Rename_Action return Files.Model.Undo_Entry is
         Result : Files.Model.Undo_Entry;
      begin
         Result.Kind := Files.Model.Undo_Rename;
         Result.From.Append (To_Unbounded_String ("/missing/new-name"));
         Result.To.Append (To_Unbounded_String ("/missing/old-name"));
         Result.Created_Identities.Append (To_Unbounded_String ("persisted-identity"));
         Result.Created_Tree_Revisions.Append (Null_Unbounded_String);
         return Result;
      end Rename_Action;

      Good_Undo : Files.Model.Undo_Entry := Rename_Action;
      Good_Redo : constant Files.Model.Undo_Entry := Rename_Action;
      Short_Targets : Files.Model.Undo_Entry := Rename_Action;
      Foreign_Marker : Files.Model.Undo_Entry := Rename_Action;
      Bad_Metadata : Files.Model.Undo_Entry := Rename_Action;
      Bad_Restore : Files.Model.Undo_Entry := Rename_Action;
      Bad_Copy_Records : Files.Model.Undo_Entry := Rename_Action;
      Relative_From : Files.Model.Undo_Entry := Rename_Action;
      Nul_Target : Files.Model.Undo_Entry := Rename_Action;
      Relative_Forward : Files.Model.Undo_Entry := Rename_Action;
      Relative_Restore : Files.Model.Undo_Entry := Rename_Action;
      Relative_Copy_Record : Files.Model.Undo_Entry := Rename_Action;
      Undo_Only_Redo : Files.Model.Undo_Entry := Rename_Action;
   begin
      Good_Undo.Reverse_Completed.Append (Good_Undo.From.First_Element);

      Short_Targets.To.Clear;

      Foreign_Marker.Reverse_Completed.Append
        (To_Unbounded_String ("/missing/not-in-action"));

      Bad_Metadata.Kind := Files.Model.Undo_Set_Permissions;
      Bad_Metadata.To.Replace_Element
        (Bad_Metadata.To.First_Index, To_Unbounded_String ("not-a-mode"));
      Bad_Metadata.Forward.Append (To_Unbounded_String ("420"));

      Bad_Restore.Redoable := False;
      Bad_Restore.Restore_Trash.Append (To_Unbounded_String ("/missing/trash-entry"));

      Bad_Copy_Records.Kind := Files.Model.Undo_Delete_Created;
      Bad_Copy_Records.To.Clear;
      Bad_Copy_Records.Forward.Append (To_Unbounded_String ("/missing/source"));
      Bad_Copy_Records.Create_Kind := Files.Model.Create_Copy;
      Bad_Copy_Records.Copy_Records.Append (To_Unbounded_String ("incomplete-group"));

      Relative_From.From.Replace_Element
        (Relative_From.From.First_Index, To_Unbounded_String ("relative-new-name"));

      Nul_Target.To.Replace_Element
        (Nul_Target.To.First_Index,
         To_Unbounded_String ("/missing/old" & Character'Val (0) & "name"));

      Relative_Forward.Kind := Files.Model.Undo_Delete_Created;
      Relative_Forward.To.Clear;
      Relative_Forward.Forward.Append (To_Unbounded_String ("relative-source"));
      Relative_Forward.Create_Kind := Files.Model.Create_Symbolic_Link;

      Relative_Restore.Redoable := False;
      Relative_Restore.Kind := Files.Model.Undo_Move;
      Relative_Restore.Restore_Trash.Append
        (To_Unbounded_String ("/missing/trash-entry"));
      Relative_Restore.Restore_Identities.Append
        (To_Unbounded_String ("persisted-trash-identity"));
      Relative_Restore.Restore_Targets.Append
        (To_Unbounded_String ("relative-restore-target"));

      Relative_Copy_Record.Kind := Files.Model.Undo_Delete_Created;
      Relative_Copy_Record.To.Clear;
      Relative_Copy_Record.Forward.Append
        (To_Unbounded_String ("/missing/source"));
      Relative_Copy_Record.Create_Kind := Files.Model.Create_Copy;
      Relative_Copy_Record.Copy_Records.Append
        (To_Unbounded_String ("source-identity"));
      Relative_Copy_Record.Copy_Records.Append
        (To_Unbounded_String ("source-revision"));
      Relative_Copy_Record.Copy_Records.Append
        (To_Unbounded_String ("content-digest"));
      Relative_Copy_Record.Copy_Records.Append
        (To_Unbounded_String ("relative-copied-path"));
      Relative_Copy_Record.Copy_Records.Append
        (To_Unbounded_String ("destination-identity"));
      Relative_Copy_Record.Copy_Records.Append
        (To_Unbounded_String ("destination-revision"));

      Undo_Only_Redo.Redoable := False;

      Undo.Append (Short_Targets);
      Undo.Append (Good_Undo);
      Undo.Append (Foreign_Marker);
      Undo.Append (Bad_Metadata);
      Undo.Append (Bad_Restore);
      Undo.Append (Bad_Copy_Records);
      Undo.Append (Relative_From);
      Undo.Append (Nul_Target);
      Undo.Append (Relative_Forward);
      Undo.Append (Relative_Restore);
      Undo.Append (Relative_Copy_Record);
      Redo.Append (Undo_Only_Redo);
      Redo.Append (Good_Redo);

      Files.Model.Set_History (Model, Undo, Redo);

      Assert
        (Natural (Files.Model.Undo_History (Model).Length) = 1
         and then Files.Model.Undo_History (Model).First_Element = Good_Undo,
         "only the structurally and path-valid Undo action and its partial progress survive");
      Assert
        (Natural (Files.Model.Redo_History (Model).Length) = 1
         and then Files.Model.Redo_History (Model).First_Element = Good_Redo,
         "Redo filters undo-only entries but retains a valid action with stale paths");
      Assert
        (Files.Model.Undo_History (Model).First_Element.Created_Identities.First_Element =
           To_Unbounded_String ("persisted-identity"),
         "sanitizing restored history does not recapture or discard its identity snapshot");
   end Test_History_Restore_Admission;
