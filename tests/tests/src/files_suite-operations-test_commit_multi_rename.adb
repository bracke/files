separate (Files_Suite.Operations)
   procedure Test_Commit_Multi_Rename (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Operations.Operation_Result;
      Changed  : Boolean;
   begin
      --  Two files renamed together: appending "Z" before each extension gives
      --  each field a distinct new name via a single broadcast.
      Reset_Root;
      Write_File (Join (Root, "aaa.txt"));
      Write_File (Join (Root, "bbb.txt"));
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files.Model.Toggle_Rename (Model);
      Assert (Files.Model.Rename_Field_Count (Model) = 2, "multi-rename opens a field per selected file");
      Changed := Files.Model.Rename_Insert_At_Carets (Model, "Z");
      Assert (Changed, "broadcast insert edits both rename fields");

      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "committing both renames reports success");
      Assert (Ada.Directories.Exists (Join (Root, "aaaZ.txt")), "the first item is renamed on disk");
      Assert (Ada.Directories.Exists (Join (Root, "bbbZ.txt")), "the second item is renamed on disk");
      Assert (not Ada.Directories.Exists (Join (Root, "aaa.txt")), "the first old name is gone");
      Assert (not Ada.Directories.Exists (Join (Root, "bbb.txt")), "the second old name is gone");
      Assert
        (Natural (Files.Model.Undo_From_Paths (Model).Length) = 2,
         "committing two renames records a two-entry undo");

      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Result.Status = Files.Operations.Operation_Success, "one undo reverses the whole multi-rename");
      Assert (Ada.Directories.Exists (Join (Root, "aaa.txt")), "undo restores the first original name");
      Assert (Ada.Directories.Exists (Join (Root, "bbb.txt")), "undo restores the second original name");
      Assert (not Ada.Directories.Exists (Join (Root, "aaaZ.txt")), "undo removes the first renamed file");
      Assert (not Ada.Directories.Exists (Join (Root, "bbbZ.txt")), "undo removes the second renamed file");

      --  Best-effort: one target collides with an existing file, the other
      --  succeeds. The collision is reported but does not block the good rename.
      Reset_Root;
      Write_File (Join (Root, "one.txt"));
      Write_File (Join (Root, "two.txt"));
      Write_File (Join (Root, "oneZ.txt"), "occupied");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      --  Select only one.txt and two.txt (leave the colliding oneZ.txt out).
      Select_Name (Model, "one.txt");
      declare
         One_Visible : constant Natural := Files.Model.Selected_Index (Model);
      begin
         Files.Model.Select_Visible (Model, One_Visible);
      end;
      --  two.txt sorts after one.txt and oneZ.txt; add it to the selection.
      for Index in 1 .. Files.Model.Visible_Count (Model) loop
         if To_String (Files.Model.Visible_Item (Model, Index).Name) = "two.txt" then
            Files.Model.Toggle_Visible_Selection (Model, Index);
         end if;
      end loop;
      Files.Model.Toggle_Rename (Model);
      Assert (Files.Model.Rename_Field_Count (Model) = 2, "best-effort rename opens two fields");
      Changed := Files.Model.Rename_Insert_At_Carets (Model, "Z");
      Assert (Changed, "broadcast insert edits both best-effort fields");

      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Success,
         "a partial multi-rename still reports overall success");
      Assert
        (To_String (Result.Error_Key) = "error.rename.partial",
         "a partial multi-rename reports the partial error key");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.rename.partial",
         "a partial multi-rename records the partial error key");
      Assert (Ada.Directories.Exists (Join (Root, "twoZ.txt")), "the non-colliding rename lands");
      Assert (not Ada.Directories.Exists (Join (Root, "two.txt")), "the renamed source is gone");
      Assert (Ada.Directories.Exists (Join (Root, "one.txt")), "the colliding source is left in place");
      Assert
        (Ada.Strings.Fixed.Index (Project_Tools.Files.Read_Raw_File (Join (Root, "oneZ.txt")), "occupied") > 0,
         "the collision preserves the pre-existing destination file");
      Assert
        (Natural (Files.Model.Undo_From_Paths (Model).Length) = 1,
         "a partial multi-rename records undo only for the successful rename");
   end Test_Commit_Multi_Rename;
