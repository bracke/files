separate (Files_Suite.History)
   --  The journal writes an entry's records as columns and reads them back as
   --  the same records: each item with its own target and identity, each
   --  replaced original with its trash path, identity and target, each kept
   --  copy with its identity and tree revision.
   procedure Test_History_Journal_Keeps_Records (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      History_Directory : constant String := Join (Root, "history-records");
      Undo  : Files.Model.Undo_Entry_Vectors.Vector;
      Model : Files.Model.Window_Model;
      Given : Files.Model.Undo_Entry;

      function U (Text : String) return Unbounded_String renames To_Unbounded_String;
   begin
      Reset_Root;
      Ada.Directories.Create_Directory (History_Directory);
      --  A failed paste-move: undo-only, with a kept copy and a replaced original.
      Given.Kind := Files.Model.Undo_Move;
      Given.Redoable := False;
      for Name in Character range '1' .. '2' loop
         Given.Items.Append
           (Files.Model.Undo_Item'
              (From          => U (Join (Root, "moved-" & Name)),
               To            => U (Join (Root, "source-" & Name)),
               Identity      => U ("1:" & Name),
               others        => <>));
      end loop;
      Given.Replaced.Append
        (Files.Model.Replaced_Original'
           (Trash    => U (Join (Root, "stage/payload")),
            Identity => U ("2:payload"),
            Target   => U (Join (Root, "moved-1-original"))));
      Given.Kept.Append
        (Files.Model.Kept_Copy'
           (Path          => U (Join (Root, "kept-copy")),
            Identity      => U ("3:kept"),
            Tree_Revision => U ("kept-revision")));
      Given.Reverse_Completed.Append (U (Join (Root, "kept-copy")));
      Given.Sequence := 1;
      Undo.Append (Given);
      Files.History_Journal.Save_Stacks
        (History_Directory, Undo, Files.Model.Undo_Entry_Vectors.Empty_Vector, Required => True);
      Files.Model.Initialize (Model, Root, Files.Items.Item_Vectors.Empty_Vector, Root);
      Assert (Files.History_Journal.Restore (History_Directory, Model), "the journal is saved and reads back");
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.History.Undo_Entries (Model).Length), 1, "the entry is admitted");
      declare
         Read : Files.Model.Undo_Entry := Files.Model.History.Undo_Entries (Model).First_Element;
      begin
         Read.Sequence := Given.Sequence;
         Assert (Files.Model."=" (Read, Given), "every record comes back as it was written");
      end;
      Reset_Root;
   end Test_History_Journal_Keeps_Records;
