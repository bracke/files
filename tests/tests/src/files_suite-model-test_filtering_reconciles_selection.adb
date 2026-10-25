separate (Files_Suite.Model)
   procedure Test_Filtering_Reconciles_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings     : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model        : Files.Model.Window_Model := Sample_Model;
      Missing_Item : Files.File_System.Directory_Item;
      Result       : Files.Controller.Controller_Result;
   begin
      Missing_Item := Files.Model.Visible_Item (Model, 99);
      Files_Suite.Support.Assert_Equal
        (To_String (Missing_Item.Name),
         "",
         "invalid visible item index returns empty item");
      Assert (Missing_Item.Kind = Files.Types.Unknown_Item, "invalid visible item index returns unknown kind");
      declare
         --  Content-search hits whose names lack the query stay listed, and the
         --  drawn rows agree with the count that clicks and selection use.
         Search_Model : Files.Model.Window_Model := Sample_Model;
      begin
         Files.Model.Set_Filter (Search_Model, "zzz-not-in-any-name");
         Files.Model.Note_Search_Results (Search_Model, Files.Types.Search_Contents);
         Assert
           (Natural (Files.Model.Visible_Rows (Search_Model).Length) = Files.Model.Visible_Count (Search_Model)
            and then Files.Model.Visible_Count (Search_Model) = Files.Model.Item_Count (Search_Model),
            "search results draw every hit, matching the rows clicks map to");
      end;
      Files.Model.Select_Visible (Model, 3);
      Files.Model.Set_Filter (Model, "alp");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Visible_Count (Model),
         1,
         "filter matches item names case-insensitively");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "filtered-out selection moves to first visible item");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Name (Model),
         "Alpha.txt",
         "selection points to visible item");
      Assert (Files.Model.Is_Selected (Model, 1), "selected visible item is reported selected");
      Assert (not Files.Model.Is_Selected (Model, 2), "out-of-range visible item is not selected");
      declare
         Unicode_Items : Files.File_System.Item_Vectors.Vector := Sample_Items;
         Unicode_Model : Files.Model.Window_Model;
         Upper_Name    : constant String := Byte (16#C3#) & Byte (16#89#) & "t"
           & Byte (16#C3#) & Byte (16#A9#) & ".txt";
         Lower_Query   : constant String := Byte (16#C3#) & Byte (16#A9#) & "t"
           & Byte (16#C3#) & Byte (16#A9#);
      begin
         Unicode_Items.Append
           (Files.File_System.Make_Item (Root, Upper_Name, Files.Types.Regular_File_Item, "text/plain"));
         Files.Model.Initialize (Unicode_Model, Root, Unicode_Items, Root, Files.Types.Small_Icons);
         Files.Model.Set_Filter (Unicode_Model, Lower_Query);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Visible_Count (Unicode_Model),
            1,
            "filter matches UTF-8 Latin-1 item names case-insensitively");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selected_Name (Unicode_Model),
            Upper_Name,
            "UTF-8 Latin-1 filter selects the matching visible item");
      end;
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "single visible item movement is ignored");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "single visible item movement keeps selection");
      Files.Model.Clear_Filter (Model);
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files.Model.Toggle_Visible_Selection (Model, 3);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         3,
         "filter reconciliation starts from multi-selection");
      Files.Model.Set_Filter (Model, "beta");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Visible_Count (Model),
         1,
         "multi-selection filter leaves one visible item");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         1,
         "filter reconciliation drops invisible multi-selected items");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Name (Model),
         "Beta.txt",
         "filter reconciliation keeps visible multi-selected item primary");
      Files.Model.Set_Filter (Model, "zzz");
      Files_Suite.Support.Assert_Equal (Files.Model.Visible_Count (Model), 0, "unmatched filter hides all items");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         0,
         "selection becomes empty when no items are visible");
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Down);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         0,
         "moving selection with no visible items stays empty");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "empty visible selection movement is ignored");
   end Test_Filtering_Reconciles_Selection;
