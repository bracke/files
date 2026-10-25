separate (Files_Suite.Model)
   procedure Test_Runtime_Sort_State (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Controller.Controller_Result;

      function Item
        (Name     : String;
         Filetype : String;
         Size     : Long_Long_Integer;
         Created  : Ada.Calendar.Time;
         Changed  : Ada.Calendar.Time)
         return Files.File_System.Directory_Item
      is
         Value : Files.File_System.Directory_Item :=
           Files.File_System.Make_Item (Root, Name, Files.Types.Regular_File_Item, Filetype);
      begin
         Value.Size_Available := True;
         Value.Size := Size;
         Value.Creation_Available := True;
         Value.Creation_Time := Created;
         Value.Modified_Available := True;
         Value.Modified_Time := Changed;
         return Value;
      end Item;

      function Snapshot_Name (Index : Positive) return String is
         Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
      begin
         return To_String (Snapshot.Items.Element (Index).Name);
      end Snapshot_Name;
   begin
      Items.Append
        (Item
           ("bravo.txt",
            "text/plain",
            20,
            Ada.Calendar.Time_Of (2024, 1, 2),
            Ada.Calendar.Time_Of (2024, 1, 5)));
      Items.Append
        (Item
           ("alpha.md",
            "text/markdown",
            30,
            Ada.Calendar.Time_Of (2024, 1, 3),
            Ada.Calendar.Time_Of (2024, 1, 4)));
      Items.Append
        (Item
           ("charlie.bin",
            "application/octet-stream",
            10,
            Ada.Calendar.Time_Of (2024, 1, 1),
            Ada.Calendar.Time_Of (2024, 1, 6)));
      Items.Append
        (Files.File_System.Make_Item
           (Root,
            "zulu",
            Files.Types.Directory_Item,
            "inode/directory"));
      Files.Model.Initialize (Model, Root, Items, Root);
      --  Startup applies the persisted sort right after Initialize
      --  (Apply_Persisted_UI_State); the drawn order is the model's order.
      Files.Model.Apply_Sort (Model, Files.Types.Sort_Name, Ascending => True);

      Files_Suite.Support.Assert_Equal

        (Files.Model.Sort_Field_Of (Model),

         Files.Types.Sort_Name,

         "default runtime sort field is name");
      Assert (Files.Model.Sort_Is_Ascending (Model), "default runtime sort direction is ascending");
      Files_Suite.Support.Assert_Equal (Snapshot_Name (1), "alpha.md", "default snapshot sorts by name ascending");
      Files_Suite.Support.Assert_Equal
        (Snapshot_Name (4),
         "zulu",
         "default snapshot does not group directories before files");

      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Sort_Menu_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Toggle_Sort_Menu_Command,
         "sort menu command is routed");
      Assert (Files.Model.Sort_Menu_Is_Open (Model), "sort menu opens");

      Result := Files.Controller.Execute_Command (Files.Commands.Sort_By_Size_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Sort_By_Size_Command,
         "sort-by-size command is routed");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Sort_Field_Of (Model),
         Files.Types.Sort_Size,
         "sort-by-size selects size field");
      Assert (Files.Model.Sort_Is_Ascending (Model), "new sort field starts ascending");
      Assert (not Files.Model.Sort_Menu_Is_Open (Model), "selecting a sort field closes the menu");
      Files_Suite.Support.Assert_Equal (Snapshot_Name (1), "charlie.bin", "size ascending sorts smallest file first");

      Result := Files.Controller.Execute_Command (Files.Commands.Sort_By_Size_Command, Model, Settings);
      Assert (not Files.Model.Sort_Is_Ascending (Model), "selecting same sort field toggles descending");
      Files_Suite.Support.Assert_Equal (Snapshot_Name (1), "alpha.md", "size descending sorts largest file first");

      Result := Files.Controller.Execute_Command (Files.Commands.Sort_By_Type_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Sort_Field_Of (Model),
         Files.Types.Sort_Type,
         "sort-by-type selects type field");
      Assert (Files.Model.Sort_Is_Ascending (Model), "different sort field resets to ascending");
      Files_Suite.Support.Assert_Equal (Snapshot_Name (1), "charlie.bin", "type ascending sorts by filetype token");

      Result := Files.Controller.Execute_Command (Files.Commands.Sort_By_Created_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Sort_Field_Of (Model),
         Files.Types.Sort_Created,
         "sort-by-created selects creation field");
      Files_Suite.Support.Assert_Equal
        (Snapshot_Name (1),
         "charlie.bin",
         "created ascending sorts oldest creation time first");

      Result := Files.Controller.Execute_Command (Files.Commands.Sort_By_Changed_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Sort_Field_Of (Model),
         Files.Types.Sort_Changed,
         "sort-by-changed selects modified field");
      Files_Suite.Support.Assert_Equal
        (Snapshot_Name (1),
         "alpha.md",
         "changed ascending sorts oldest modified time first");
   end Test_Runtime_Sort_State;
