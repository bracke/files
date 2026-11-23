separate (Files.Refresh)
   procedure Apply_Reloaded_Items
     (Model : in out Files.Model.Window_Model;
      Work  : Request;
      Items : Files.Items.Item_Vectors.Vector)
   is
      use type Files.UI_Types.Search_Scope;
      Previous_Selection : constant Files.Types.String_Vectors.Vector :=
        Files.Model.Selection.Selected_Paths (Model);
      --  The primary item as the info pane shows it, details and all.
      Previous_Item    : constant Files.Items.Directory_Item := Files.Model.Selection.Selected_Item (Model);
      Previous_Primary : constant Files.Types.UString := Previous_Item.Full_Path;
      Previous_Info    : constant Natural := Files.Model.Info_Pane.Info_Pane_Scroll_Lines (Model);
      --  A refresh of the folder in view keeps where the user was: its
      --  scroll, and a Quick Look whose item is still there.
      Previous_Scroll  : constant Natural := Files.Model.Main_View_Scroll_Lines (Model);
      Previewing       : constant Boolean := Files.Model.Quick_Look.Is_Open (Model);
      Previewed        : constant String := Files.Model.Quick_Look.Path (Model);
      Previous_Preview : constant Files.Quick_Look.Quick_Look_Content :=
        Files.Model.Quick_Look.Content_Of (Model);
   begin
      if Work.Recent then
         Files.Model.Navigate_Recent (Model, Items);
      else
         Files.Model.Replace_Items (Model, Items);
         if Work.Searched = Files.UI_Types.Filter_Here then
            Files.Model.Filtering.Clear_Search_Results (Model);
         else
            --  Searched again: the items are results still.
            Files.Model.Filtering.Note_Search_Results (Model, Work.Searched);
         end if;
      end if;
      if Length (Work.Select_Path) > 0 then
         Files.Model.Selection.Restore
           (Model, Files.Types.String_Vectors.To_Vector (Work.Select_Path, 1), To_String (Work.Select_Path));
      elsif Length (Work.Selection) > 0 then
         declare
            Selected : constant Boolean :=
              Files.Model.Selection.Select_By_Name (Model, To_String (Work.Selection));
            pragma Unreferenced (Selected);
         begin
            null;
         end;
      else
         Files.Model.Selection.Restore
           (Model, Previous_Selection, To_String (Previous_Primary));
      end if;
      if not Work.Recent then
         Files.Model.Set_Main_View_Scroll_Lines (Model, Previous_Scroll);
      end if;
      --  So does the info pane, on the same item: its scroll, and the
      --  details read for it unless a forced reload (a settings change,
      --  an explicit refresh) may have changed what they depend on.
      Files.Model.Info_Pane.Keep_Info_Pane (Model, Previous_Item, Previous_Info, Keep_Extra => not Work.Force);
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
   end Apply_Reloaded_Items;
