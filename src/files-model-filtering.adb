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
      begin
         Touch_Selection (Model);
         if not Model.Selected_Item_Indexes.Is_Empty then
            for Index in reverse Model.Selected_Item_Indexes.First_Index .. Model.Selected_Item_Indexes.Last_Index loop
               declare
                  Item_Index : constant Natural := Model.Selected_Item_Indexes.Element (Index);
               begin
                  if Item_Index = Temporary_Item_Index then
                     if not Temporary_Is_Visible (Model) then
                        Model.Selected_Item_Indexes.Delete (Index);
                     end if;
                  elsif Model.Items.Is_Empty
                    or else Item_Index > Natural (Model.Items.Last_Index)
                    or else not Item_Is_Visible (Model, Model.Items.Element (Positive (Item_Index)))
                  then
                     Model.Selected_Item_Indexes.Delete (Index);
                  end if;
               end;
            end loop;
         end if;

         if Model.Selected_Item_Index = Temporary_Item_Index then
            if Temporary_Is_Visible (Model) then
               Add_Selected_Index (Model, Temporary_Item_Index);
               Reconcile_Rename_With_Selection (Model);
               return;
            end if;
         end if;

         if Model.Selected_Item_Index /= 0 then
            if not Model.Items.Is_Empty
              and then Model.Selected_Item_Index <= Natural (Model.Items.Last_Index)
              and then Item_Is_Visible (Model, Model.Items.Element (Positive (Model.Selected_Item_Index)))
            then
               Add_Selected_Index (Model, Model.Selected_Item_Index);
               Reconcile_Rename_With_Selection (Model);
               return;
            end if;
         end if;

         Model.Selected_Item_Index := 0;
         if not Model.Selected_Item_Indexes.Is_Empty then
            Model.Selected_Item_Index := Model.Selected_Item_Indexes.Element (Model.Selected_Item_Indexes.First_Index);
            Reconcile_Rename_With_Selection (Model);
            return;
         end if;

         if not Model.Items.Is_Empty then
            for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
               if Item_Is_Visible (Model, Model.Items (Index)) then
                  Model.Selected_Item_Index := Natural (Index);
                  Add_Selected_Index (Model, Model.Selected_Item_Index);
                  Reconcile_Rename_With_Selection (Model);
                  return;
               end if;
            end loop;
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
