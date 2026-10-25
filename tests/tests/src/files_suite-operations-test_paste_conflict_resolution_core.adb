separate (Files_Suite.Operations)
   procedure Test_Paste_Conflict_Resolution_Core (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      function Work_Item (Name : String) return Files.Paste.Work_Item is
      begin
         return
           (Source_Path => To_Unbounded_String (Join ("/src", Name)),
            Dest_Dir    => To_Unbounded_String ("/dest"),
            Dest_Name   => To_Unbounded_String (Name));
      end Work_Item;

      Items    : Files.Paste.Work_Item_Vectors.Vector;
      Existing : Files.Types.String_Vectors.Vector;
      None     : constant Files.Paste.Item_Decision_Vectors.Vector :=
        Files.Paste.Item_Decision_Vectors.Empty_Vector;
   begin
      --  a.txt and b.txt already exist at the destination; c.txt does not.
      Items.Append (Work_Item ("a.txt"));
      Items.Append (Work_Item ("b.txt"));
      Items.Append (Work_Item ("c.txt"));
      Existing.Append (To_Unbounded_String ("/dest/a.txt"));
      Existing.Append (To_Unbounded_String ("/dest/b.txt"));

      --  Replace_All: every item is written; the colliding two overwrite.
      declare
         Actions : constant Files.Paste.Resolved_Action_Vectors.Vector :=
           Files.Paste.Resolve (Items, Files.Paste.Policy_Replace_All, None, Existing);
      begin
         Assert (not Actions.Element (1).Skip and then Actions.Element (1).Replaced,
                 "replace-all overwrites the first colliding item");
         Assert (not Actions.Element (2).Skip and then Actions.Element (2).Replaced,
                 "replace-all overwrites the second colliding item");
         Assert (not Actions.Element (3).Skip, "replace-all writes the non-colliding item unchanged: not skipped");
         Assert (not Actions.Element (3).Replaced, "replace-all writes the non-colliding item unchanged: not replaced");
         Files_Suite.Support.Assert_Equal
           (To_String (Actions.Element (3).Dest_Path),
            "/dest/c.txt",
            "replace-all writes the non-colliding item unchanged: destination");
      end;

      --  Two sources with one leaf name: only the first replaces; the second
      --  must not replace the copy the batch has just written.
      declare
         Twins   : Files.Paste.Work_Item_Vectors.Vector;
         Actions : Files.Paste.Resolved_Action_Vectors.Vector;
      begin
         Twins.Append (Work_Item ("a.txt"));
         Twins.Append
           (Files.Paste.Work_Item'
              (Source_Path => To_Unbounded_String ("/other/a.txt"),
               Dest_Dir    => To_Unbounded_String ("/dest"),
               Dest_Name   => To_Unbounded_String ("a.txt")));
         Actions := Files.Paste.Resolve (Twins, Files.Paste.Policy_Replace_All, None, Existing);
         Assert (Actions.Element (1).Replaced
                   and then To_String (Actions.Element (1).Dest_Path) = "/dest/a.txt",
                 "the first same-named item replaces the existing entry");
         Assert
           (not Actions.Element (2).Replaced,
            "a second same-named item is kept under a unique name instead of replacing the first: not replaced");
         Assert
           (not Actions.Element (2).Skip,
            "a second same-named item is kept under a unique name instead of replacing the first: not skipped");
         Assert
           (To_String (Actions.Element (2).Dest_Path) /= "/dest/a.txt",
            "a second same-named item is kept under a unique name instead of replacing the first: unique destination");
      end;

      --  Skip_All: colliding ones are skipped, the free one is written.
      declare
         Actions : constant Files.Paste.Resolved_Action_Vectors.Vector :=
           Files.Paste.Resolve (Items, Files.Paste.Policy_Skip_All, None, Existing);
      begin
         Assert (Actions.Element (1).Skip, "skip-all skips the first colliding item");
         Assert (Actions.Element (2).Skip, "skip-all skips the second colliding item");
         Assert (not Actions.Element (3).Skip
                   and then To_String (Actions.Element (3).Dest_Path) = "/dest/c.txt",
                 "skip-all still writes the non-colliding item");
      end;

      --  Rename_All: colliding ones are written under uniquified names.
      declare
         Actions : constant Files.Paste.Resolved_Action_Vectors.Vector :=
           Files.Paste.Resolve (Items, Files.Paste.Policy_Rename_All, None, Existing);
      begin
         Assert (not Actions.Element (1).Skip, "rename-all uniquifies the first colliding item: not skipped");
         Assert (not Actions.Element (1).Replaced, "rename-all uniquifies the first colliding item: not replaced");
         Files_Suite.Support.Assert_Equal
           (To_String (Actions.Element (1).Dest_Path),
            "/dest/a 2.txt",
            "rename-all uniquifies the first colliding item: destination");
         Assert (not Actions.Element (2).Skip, "rename-all uniquifies the second colliding item: not skipped");
         Assert (not Actions.Element (2).Replaced, "rename-all uniquifies the second colliding item: not replaced");
         Files_Suite.Support.Assert_Equal
           (To_String (Actions.Element (2).Dest_Path),
            "/dest/b 2.txt",
            "rename-all uniquifies the second colliding item: destination");
         Files_Suite.Support.Assert_Equal
           (To_String (Actions.Element (3).Dest_Path),
            "/dest/c.txt",
            "rename-all leaves the non-colliding name alone");
      end;

      --  No conflicts: every policy writes each item to its desired path.
      declare
         Empty_Existing : Files.Types.String_Vectors.Vector;
         Actions        : constant Files.Paste.Resolved_Action_Vectors.Vector :=
           Files.Paste.Resolve (Items, Files.Paste.Policy_Ask, None, Empty_Existing);
      begin
         Assert (not Actions.Element (1).Skip and then To_String (Actions.Element (1).Dest_Path) = "/dest/a.txt",
                 "with no conflicts the first item is written to its desired path");
         Assert (not Actions.Element (2).Skip and then To_String (Actions.Element (2).Dest_Path) = "/dest/b.txt",
                 "with no conflicts the second item is written to its desired path");
         Assert (not Actions.Element (3).Skip,
                 "with no conflicts the third item is written");
      end;
   end Test_Paste_Conflict_Resolution_Core;
