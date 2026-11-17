with Files.Fs_Primitives.Testing;
separate (Files_Suite.History)
   --  A history journal the host will not say exists -- a refused lookup,
   --  not an absent file -- is no "no journal": it is still read, so a
   --  helper's Undo entries are never dropped for it. One gone for sure is
   --  none.
   procedure Test_Refused_Journal_Lookup_Still_Reads (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Directory : constant String := Join (Root, "history-refused");
      Undo      : Files.Model.Undo_Entry_Vectors.Vector;
      Item      : Files.Model.Undo_Entry;
      Model     : Files.Model.Window_Model;
   begin
      Reset_Root;
      Ada.Directories.Create_Directory (Directory);
      Item.Kind := Files.Model.Undo_Delete_Created;
      Item.Redoable := False;
      Item.Items.Append
        (Files.Model.Undo_Item'
           (From => To_Unbounded_String (Join (Root, "made")),
            Identity => To_Unbounded_String ("1:2"),
            Tree_Revision => To_Unbounded_String ("rev"),
            others => <>));
      Undo.Append (Item);
      Files.History_Journal.Save_Stacks
        (Directory, Undo, Files.Model.Undo_Entry_Vectors.Empty_Vector, Required => True);
      Files.Model.Initialize (Model, Root, Files.Items.Item_Vectors.Empty_Vector, Root);

      Files.Fs_Primitives.Testing.Refuse_Lookups (Join (Directory, "history"));
      Assert (Files.History_Journal.Restore (Directory, Model),
              "a journal whose lookup is refused is still read");
      Files.Fs_Primitives.Testing.Stop_Refusing_Lookups;
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.History.Undo_Entries (Model).Length), 1, "with its Undo entry");

      Ada.Directories.Delete_File (Join (Directory, "history"));
      Assert (not Files.History_Journal.Restore (Directory, Model), "a journal gone for sure is none");
      Reset_Root;
   exception
      when others =>
         Files.Fs_Primitives.Testing.Stop_Refusing_Lookups;
         raise;
   end Test_Refused_Journal_Lookup_Still_Reads;
