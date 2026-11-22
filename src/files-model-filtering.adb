with Files.Text_Case;
with Files.UI_Types;
with Files.Model.Support;

package body Files.Model.Filtering is

   use Files.Model.Support;
   use Ada.Strings.Unbounded;
   use type Files.UI_Types.Search_Scope;

   procedure Set_Filter
     (Model : in out Window_Model;
      Text  : String) is

      --  Drop any selected indexes that are no longer visible or valid after the
      --  filter changed.
      --
      --  @param Model Model whose selection is reconciled in place.
      procedure Reconcile_Selection (Model : in out Window_Model) is

         --  Whether the selection entry Item_Index is still a shown row.
         function Still_Shown (Item_Index : Natural) return Boolean is
           (if Item_Index = Temporary_Item_Index then Temporary_Is_Visible (Model)
            else Item_Index in 1 .. Natural (Model.Items.Length) and then Item_Visible_At (Model, Item_Index));

         --  The entries still shown, in their order, gathered in one pass:
         --  deleting each hidden one in place moved the rest of the list
         --  every time, quadratic after a Select All of a large folder.
         Kept : Natural_Vectors.Vector;
      begin
         Touch_Selection (Model);
         if not Model.Selected_Item_Indexes.Is_Empty then
            Kept.Reserve_Capacity (Model.Selected_Item_Indexes.Length);
            for Item_Index of Model.Selected_Item_Indexes loop
               if Still_Shown (Item_Index) then
                  Kept.Append (Item_Index);
               end if;
            end loop;
            Model.Selected_Item_Indexes.Move (Kept);
         end if;

         if Model.Selected_Item_Index = Temporary_Item_Index then
            if Temporary_Is_Visible (Model) then
               Add_Selected_Index (Model, Temporary_Item_Index);
               Reconcile_Rename_With_Selection (Model);
               return;
            end if;
         end if;

         if Model.Selected_Item_Index /= 0
           and then Model.Selected_Item_Index /= Temporary_Item_Index
           and then Still_Shown (Model.Selected_Item_Index)
         then
            Add_Selected_Index (Model, Model.Selected_Item_Index);
            Reconcile_Rename_With_Selection (Model);
            return;
         end if;

         Model.Selected_Item_Index := 0;
         if not Model.Selected_Item_Indexes.Is_Empty then
            Model.Selected_Item_Index := Model.Selected_Item_Indexes.Element (Model.Selected_Item_Indexes.First_Index);
            Reconcile_Rename_With_Selection (Model);
            return;
         end if;

         --  The first shown item, the lowest index the map holds.
         if Visible_To_Item_Index (Model, 1) /= 0 then
            Model.Selected_Item_Index := Visible_To_Item_Index (Model, 1);
            Add_Selected_Index (Model, Model.Selected_Item_Index);
            Reconcile_Rename_With_Selection (Model);
            return;
         end if;
         Reconcile_Rename_With_Selection (Model);
      end Reconcile_Selection;

   begin
      Touch (Model);
      Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
      Model.Filter.Text := To_Unbounded_String (Text);
      Model.Folded_Filter := To_Unbounded_String (Files.Text_Case.Fold_Case (Text));
      Invalidate_Visible (Model);
      Model.Filter.Cursor := Text'Length;
      Model.Main_View_Scroll := 0;
      Reconcile_Selection (Model);
   end Set_Filter;

   function Filter_Text
     (Model : Window_Model)
      return String is
     (To_String (Model.Filter.Text));

   procedure Clear_Filter
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      Set_Filter (Model, "");
      Model.Search_Scope_Value := Files.UI_Types.Filter_Here;
      Model.Search_Results_Active := False;
      Model.Results_Hide_Hidden := False;
      Invalidate_Visible (Model);
   end Clear_Filter;

   function Search_Scope_Of
     (Model : Window_Model)
      return Files.UI_Types.Search_Scope is
     (Model.Search_Scope_Value);

   procedure Set_Search_Scope
     (Model : in out Window_Model;
      Scope : Files.UI_Types.Search_Scope) is
   begin
      Touch (Model);
      Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
      Model.Search_Scope_Value := Scope;
   end Set_Search_Scope;

   function Search_Results_Are_Active
     (Model : Window_Model)
      return Boolean is
     (Model.Search_Results_Active);

   procedure Note_Search_Results
     (Model : in out Window_Model;
      Scope : Files.UI_Types.Search_Scope) is
   begin
      Touch (Model);
      Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
      Model.Search_Scope_Value := Scope;
      Model.Search_Results_Active := Scope /= Files.UI_Types.Filter_Here;
      Model.Results_Hide_Hidden := False;
      Invalidate_Visible (Model);
   end Note_Search_Results;

   procedure Clear_Search_Results
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
      Model.Search_Scope_Value := Files.UI_Types.Filter_Here;
      Model.Search_Results_Active := False;
      Model.Results_Hide_Hidden := False;
      Invalidate_Visible (Model);
   end Clear_Search_Results;

end Files.Model.Filtering;
