separate (Files.Refresh)
   procedure Reinstall_Listing
     (Model          : in out Files.Model.Window_Model;
      Items          : Files.Items.Item_Vectors.Vector;
      Signature      : Files.File_System_Types.Directory_Signature;
      Recent         : Boolean := False;
      Searched       : Files.UI_Types.Search_Scope := Files.UI_Types.Filter_Here;
      Query          : String := "";
      New_Results    : Boolean := False;
      Select_Path    : String := "";
      Select_Name    : String := "";
      Keep_Selection : Boolean := True;
      Fresh_Details  : Boolean := False;
      Owe_Thumbnails : Boolean := False;
      Show_Hidden    : Boolean;
      Error_Line     : String := "")
   is
      use type Files.UI_Types.Search_Scope;
      Previous_Selection : constant Files.Types.String_Vectors.Vector :=
        Files.Model.Selection.Selected_Paths (Model);
      --  The primary item as the info pane shows it, details and all.
      Previous_Item    : constant Files.Items.Directory_Item := Files.Model.Selection.Selected_Item (Model);
      Previous_Primary : constant Files.Types.UString := Previous_Item.Full_Path;
      Previous_Info    : constant Natural := Files.Model.Info_Pane.Info_Pane_Scroll_Lines (Model);
      Previous_Scroll  : constant Natural := Files.Model.Main_View_Scroll_Lines (Model);
      Previewing       : constant Boolean := Files.Model.Quick_Look.Is_Open (Model);
      Previewed        : constant String := Files.Model.Quick_Look.Path (Model);
      Previous_Preview : constant Files.Quick_Look.Quick_Look_Content :=
        Files.Model.Quick_Look.Content_Of (Model);
      --  A new search's results have no place in them to keep.
      Keep_Place : constant Boolean := not New_Results;
   begin
      --  New results are the view now: a listing owed to the folder would
      --  only search them again.
      if New_Results then
         Files.Model.Clear_Owed_Refresh (Model);
      end if;
      if Recent then
         if Files.Model.Recent.In_Recent_View (Model) then
            Files.Model.Replace_Recent_Items (Model, Items);
         else
            Files.Model.Navigate_Recent (Model, Items);
         end if;
      else
         Files.Model.Replace_Items (Model, Items);
         if Searched = Files.UI_Types.Filter_Here then
            --  The folder's own listing ends any results shown; with none,
            --  the chip keeps the scope the next query searches in.
            if Files.Model.Filtering.Search_Results_Are_Active (Model) then
               Files.Model.Filtering.Clear_Search_Results (Model);
            end if;
         elsif New_Results
           or else not Files.Model.Filtering.Search_Results_Are_Active (Model)
           or else Files.Model.Filtering.Search_Scope_Of (Model) /= Searched
         then
            Files.Model.Filtering.Note_Search_Results (Model, Searched, Query);
         end if;
         --  Searched again, the items are results still, kept as the window
         --  showed them.
      end if;
      if Select_Path /= "" then
         Files.Model.Selection.Restore
           (Model, Files.Types.String_Vectors.To_Vector (To_Unbounded_String (Select_Path), 1), Select_Path);
      end if;
      --  A path is exact (search results may list two items of one name);
      --  the name stands in when the path is gone or none was given.
      if Select_Path /= "" and then Files.Model.Selection.Selected_Count (Model) > 0 then
         null;
      elsif Select_Name /= "" then
         declare
            Selected : constant Boolean := Files.Model.Selection.Select_By_Name (Model, Select_Name);
            pragma Unreferenced (Selected);
         begin
            null;
         end;
      elsif Keep_Selection and then Keep_Place then
         Files.Model.Selection.Restore (Model, Previous_Selection, To_String (Previous_Primary));
      end if;
      if Keep_Place then
         if not Recent then
            Files.Model.Set_Main_View_Scroll_Lines (Model, Previous_Scroll);
         end if;
         --  The info pane on the same item keeps its scroll, and the details
         --  read for it unless they are to be read afresh.
         Files.Model.Info_Pane.Keep_Info_Pane
           (Model, Previous_Item, Previous_Info, Keep_Extra => not Fresh_Details);
         if Previewing
           and then Previewed /= ""
           and then To_String (Files.Model.Selection.Selected_Item (Model).Full_Path) = Previewed
         then
            --  Prepared afresh when the change being picked up is to it;
            --  otherwise the preview it had, image and all, comes back.
            Files.Model.Quick_Look.Open
              (Model,
               (if Files.Quick_Look.Source_Stamp_Of (Files.Model.Selection.Selected_Item (Model))
                   = Previous_Preview.Source_Stamp
                then Previous_Preview
                else Files.Quick_Look.Preparation.Prepare (Files.Model.Selection.Selected_Item (Model))));
         end if;
      end if;
      Settle_Listed (Model, Items, Signature, Owe_Thumbnails, Error_Line, Show_Hidden);
   end Reinstall_Listing;
