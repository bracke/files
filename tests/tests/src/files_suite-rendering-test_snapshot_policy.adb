with Files.Snapshot_Policy;
separate (Files_Suite.Rendering)
   --  When a window reuses, patches or rebuilds its snapshot.
   procedure Test_Snapshot_Policy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Files.Snapshot_Policy;

      function Act
        (Valid, Minute, Revision, Settings, Scroll : Boolean := True;
         Rows : Boolean := False;
         Row_Settings : Boolean := True;
         Pasting, Elapsed : Boolean := False) return Snapshot_Action is
        (Action_For (Valid, Minute, Revision, Settings, Scroll, Rows, Row_Settings, Pasting, Elapsed));
   begin
      Assert (Act = Reuse, "nothing changed: reuse");
      Assert (Act (Scroll => False) = Patch_Scroll, "only a scroll offset moved: patch it, no rebuild");
      Assert (Act (Valid => False) = Rebuild, "never built: build");
      Assert (Act (Minute => False) = Rebuild, "a new minute: rebuild (relative times)");
      Assert (Act (Revision => False) = Rebuild, "the model changed: rebuild");
      Assert
        (Act (Revision => False, Rows => True) = Patch_Rows,
         "only the selection changed: keep the rows, set their flags");
      Assert
        (Act (Revision => False, Rows => True, Scroll => False) = Patch_Rows,
         "and a scroll with it is taken from the model as well");
      Assert (Act (Revision => False, Rows => True, Minute => False) = Rebuild, "a new minute still rebuilds");
      Assert
        (Act (Settings => False, Rows => True) = Patch_Rows,
         "a column drag changes settings the rows do not read: keep them");
      Assert
        (Act (Settings => False, Rows => True, Row_Settings => False) = Rebuild,
         "settings the rows read (favorites, labels, grouping) rebuild");
      Assert
        (Act (Settings => False, Row_Settings => False, Scroll => False) = Rebuild,
         "the settings changed: rebuild, scroll or not");
      Assert (Act (Pasting => True) = Reuse, "a paste's progress is not redrawn more than ten times a second");
      Assert (Act (Pasting => True, Elapsed => True) = Rebuild, "but is redrawn once the interval passed");
      Assert (Act (Elapsed => True) = Reuse, "the interval means nothing without a paste");
   end Test_Snapshot_Policy;
