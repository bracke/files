separate (Files_Suite.Model)
   procedure Test_History_Restore_Admission
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Model : Files.Model.Window_Model;
      Undo, Redo : Files.Undo.History.Undo_Entry_Vectors.Vector;

      function Rename_Action return Files.Undo.History.Undo_Entry is
         Result : Files.Undo.History.Undo_Entry;
      begin
         Result.Kind := Files.Undo.History.Undo_Rename;
         Result.Items.Append
           (Files.Undo.History.Undo_Item'
              (From          => To_Unbounded_String ("/missing/new-name"),
               To            => To_Unbounded_String ("/missing/old-name"),
               Identity      => To_Unbounded_String ("persisted-identity"),
               others        => <>));
         return Result;
      end Rename_Action;

      --  Admission gives each entry its Sequence; everything else is kept.
      function Same_Action (Admitted, Given : Files.Undo.History.Undo_Entry) return Boolean is
         Expected : Files.Undo.History.Undo_Entry := Given;
      begin
         Expected.Sequence := Admitted.Sequence;
         return Admitted = Expected and then Admitted.Sequence > 0;
      end Same_Action;

      Good_Undo : Files.Undo.History.Undo_Entry := Rename_Action;
      Good_Redo : constant Files.Undo.History.Undo_Entry := Rename_Action;
      Short_Targets : Files.Undo.History.Undo_Entry := Rename_Action;
      Foreign_Marker : Files.Undo.History.Undo_Entry := Rename_Action;
      Bad_Metadata : Files.Undo.History.Undo_Entry := Rename_Action;
      Bad_Restore : Files.Undo.History.Undo_Entry := Rename_Action;
      Bad_Copy_Records : Files.Undo.History.Undo_Entry := Rename_Action;
      Relative_From : Files.Undo.History.Undo_Entry := Rename_Action;
      Nul_Target : Files.Undo.History.Undo_Entry := Rename_Action;
      Relative_Forward : Files.Undo.History.Undo_Entry := Rename_Action;
      Relative_Restore : Files.Undo.History.Undo_Entry := Rename_Action;
      Relative_Copy_Record : Files.Undo.History.Undo_Entry := Rename_Action;
      Undo_Only_Redo : Files.Undo.History.Undo_Entry := Rename_Action;
   begin
      Good_Undo.Reverse_Completed.Append (Good_Undo.Items.First_Element.From);

      Short_Targets.Items (1).To := Null_Unbounded_String;

      Foreign_Marker.Reverse_Completed.Append
        (To_Unbounded_String ("/missing/not-in-action"));

      Bad_Metadata.Kind := Files.Undo.History.Undo_Set_Permissions;
      Bad_Metadata.Items (1).To := To_Unbounded_String ("not-a-mode");
      Bad_Metadata.Items (1).Forward := To_Unbounded_String ("420");

      Bad_Restore.Redoable := False;
      Bad_Restore.Replaced.Append
        (Files.Undo.History.Replaced_Original'(Trash => To_Unbounded_String ("/missing/trash-entry"), others => <>));

      Bad_Copy_Records.Kind := Files.Undo.History.Undo_Delete_Created;
      Bad_Copy_Records.Items (1).To := Null_Unbounded_String;
      Bad_Copy_Records.Items (1).Forward := To_Unbounded_String ("/missing/source");
      Bad_Copy_Records.Create_Kind := Files.Undo.History.Create_Copy;
      Bad_Copy_Records.Copy_Records.Append (To_Unbounded_String ("incomplete-group"));

      Relative_From.Items (1).From := To_Unbounded_String ("relative-new-name");

      Nul_Target.Items (1).To := To_Unbounded_String ("/missing/old" & Character'Val (0) & "name");

      Relative_Forward.Kind := Files.Undo.History.Undo_Delete_Created;
      Relative_Forward.Items (1).To := Null_Unbounded_String;
      Relative_Forward.Items (1).Forward := To_Unbounded_String ("relative-source");
      Relative_Forward.Create_Kind := Files.Undo.History.Create_Symbolic_Link;

      Relative_Restore.Redoable := False;
      Relative_Restore.Kind := Files.Undo.History.Undo_Move;
      Relative_Restore.Replaced.Append
        (Files.Undo.History.Replaced_Original'
           (Trash    => To_Unbounded_String ("/missing/trash-entry"),
            Identity => To_Unbounded_String ("persisted-trash-identity"),
            Target   => To_Unbounded_String ("relative-restore-target")));

      Relative_Copy_Record.Kind := Files.Undo.History.Undo_Delete_Created;
      Relative_Copy_Record.Items (1).To := Null_Unbounded_String;
      Relative_Copy_Record.Items (1).Forward := To_Unbounded_String ("/missing/source");
      Relative_Copy_Record.Create_Kind := Files.Undo.History.Create_Copy;
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

      Files.Model.History.Restore (Model, Undo, Redo);

      Assert
        (Natural (Files.Model.History.Undo_Entries (Model).Length) = 1
         and then Same_Action (Files.Model.History.Undo_Entries (Model).First_Element, Good_Undo),
         "only the structurally and path-valid Undo action and its partial progress survive");
      Assert
        (Natural (Files.Model.History.Redo_Entries (Model).Length) = 1
         and then Same_Action (Files.Model.History.Redo_Entries (Model).First_Element, Good_Redo),
         "Redo filters undo-only entries but retains a valid action with stale paths");
      Assert
        (Files.Model.History.Undo_Entries (Model).First_Element.Items.First_Element.Identity =
           To_Unbounded_String ("persisted-identity"),
         "sanitizing restored history does not recapture or discard its identity snapshot");
   end Test_History_Restore_Admission;
