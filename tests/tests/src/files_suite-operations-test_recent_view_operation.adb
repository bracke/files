separate (Files_Suite.Operations)
   procedure Test_Recent_View_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir       : constant String := Join (Root, "recent-dir");
      File_Name : constant String := Join (Root, "recent-file.txt");
      Missing   : constant String := Join (Root, "recent-gone.txt");
      Settings  : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Items     : Files.File_System.Item_Vectors.Vector;
      Model     : Files.Model.Window_Model;
      Result    : Files.Operations.Operation_Result;
      Dir_Index : Natural := 0;

      function Find_Visible (Name : String) return Natural is
      begin
         for I in 1 .. Files.Model.Item_Count (Model) loop
            if Files.Model.Visible_Item (Model, I).Name = To_Unbounded_String (Name) then
               return I;
            end if;
         end loop;
         return 0;
      end Find_Visible;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_File (File_Name);

      --  Seed the recent list: folder, then file, then a now-missing path. The
      --  missing entry must be skipped when the view materializes.
      Files.Settings.Note_Recent (Settings, Ada.Directories.Full_Name (Dir));
      Files.Settings.Note_Recent (Settings, Ada.Directories.Full_Name (File_Name));
      Files.Settings.Note_Recent (Settings, Missing);

      --  Start from an ordinary directory so entering the view records history.
      Items.Append (Files.File_System.Make_Item (Root, "recent-dir", Files.Types.Directory_Item, "inode/directory"));
      Files.Model.Initialize (Model, Root, Items, Root);

      Result := Files.Operations.Navigate_Recent (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Navigated, "entering the recent view navigates");
      Assert (Files.Model.In_Recent_View (Model), "the recent view is active after Navigate_Recent");
      Assert (Files.Model.Item_Count (Model) = 2, "the missing recent path is skipped from the listing");
      Assert (Find_Visible ("recent-file.txt") > 0, "the recent file is listed");
      Assert (Find_Visible ("recent-dir") > 0, "the recent folder is listed");
      Assert (Files.Model.Can_Go_Back (Model), "entering the recent view records back history");

      --  Double-click the folder: it opens (navigates in) and leaves the view.
      Dir_Index := Find_Visible ("recent-dir");
      declare
         Routed : constant Files.Controller.Controller_Result :=
           Files.Controller.Handle_Item_Click
             (Model, Settings, Visible_Index => Dir_Index, Activate => True);
      begin
         Assert (Routed.Operation.Status = Files.Operations.Operation_Navigated,
                 "double-clicking a recent folder opens it");
         Assert (not Files.Model.In_Recent_View (Model), "opening a folder leaves the recent view");
         Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (Dir),
                 "opening a recent folder navigates into it");
      end;

      --  Re-enter, then clear: the view rebuilds empty.
      Result := Files.Operations.Navigate_Recent (Model, Settings);
      Assert (Files.Model.Item_Count (Model) = 2, "re-entering the recent view relists the items");
      Files.Settings.Clear_Recent (Settings);
      Result := Files.Operations.Navigate_Recent (Model, Settings);
      Assert (Files.Model.In_Recent_View (Model), "the view stays active after clearing");
      Assert (Files.Model.Item_Count (Model) = 0, "clearing empties the recent listing");
   end Test_Recent_View_Operation;
