with Files.Fs_Primitives.Testing;
with Files_Suite.Support.Disk;
separate (Files_Suite.History)
   --  A history journal the host will not say exists -- a refused lookup,
   --  not an absent file -- is no "no journal": it is still read, so a
   --  helper's Undo entries are never dropped for it. A transport reached
   --  through a link is refused (Unreadable), not taken for one without a
   --  journal. One gone for sure is none.
   procedure Test_Refused_Journal_Lookup_Still_Reads (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Directory : constant String := Join (Root, "history-refused");
      Undo      : Files.Undo_History.Undo_Entry_Vectors.Vector;
      Item      : Files.Undo_History.Undo_Entry;
      Model     : Files.Model.Window_Model;
   begin
      Reset_Root;
      Ada.Directories.Create_Directory (Directory);
      Item.Kind := Files.Undo_History.Undo_Delete_Created;
      Item.Redoable := False;
      Item.Items.Append
        (Files.Undo_History.Undo_Item'
           (From => To_Unbounded_String (Join (Root, "made")),
            Identity => To_Unbounded_String ("1:2"),
            Tree_Revision => To_Unbounded_String ("rev"),
            others => <>));
      Undo.Append (Item);
      Files.History_Journal.Save_Stacks
        (Directory, Undo, Files.Undo_History.Undo_Entry_Vectors.Empty_Vector,
         Mode => Files.History_Journal.Must_Commit);
      Files.Model.Initialize (Model, Root, Files.Items.Item_Vectors.Empty_Vector, Root);

      Files.Fs_Primitives.Testing.Refuse_Lookups (Join (Directory, "history"));
      Assert (Files.Model.Testing.Restore_Journal (Directory, Model),
              "a journal whose lookup is refused is still read");
      Files.Fs_Primitives.Testing.Stop_Refusing_Lookups;
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.History.Undo_Entries (Model).Length), 1, "with its Undo entry");

      if Files_Suite.Support.Disk.Create_Symlink (Directory, Join (Root, "history-link")) then
         declare
            use type Files.History_Journal.Read_Outcome;
         begin
            Assert
              (Files.Model.Testing.Merge_Journal (Join (Root, "history-link"), Model)
                 = Files.History_Journal.Unreadable,
               "a transport that is a link is a refusal, not a transport without a journal");
         end;
      end if;

      Ada.Directories.Delete_File (Join (Directory, "history"));
      Assert (not Files.Model.Testing.Restore_Journal (Directory, Model), "a journal gone for sure is none");
      declare
         use type Files.History_Journal.Read_Outcome;
      begin
         Assert
           (Files.Model.Testing.Merge_Journal (Directory, Model) = Files.History_Journal.No_Journal,
            "and reads as no journal");
      end;
      Reset_Root;
   exception
      when others =>
         Files.Fs_Primitives.Testing.Stop_Refusing_Lookups;
         raise;
   end Test_Refused_Journal_Lookup_Still_Reads;
