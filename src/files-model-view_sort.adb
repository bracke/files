with Ada.Calendar;
with Files.Grouping;
with Files.Model.Support;

separate (Files.Model)
package body View_Sort is

   function View_Mode_Of
     (Model : Window_Model)
      return Files.Types.View_Mode is
   begin
      return Model.View_Value;
   end View_Mode_Of;

   procedure Set_View_Mode
     (Model : in out Window_Model;
      Mode  : Files.Types.View_Mode) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.View_Value := Mode;
      Model.Main_View_Scroll := 0;
   end Set_View_Mode;

   function Sort_Field_Of
     (Model : Window_Model)
      return Sort_Field is
   begin
      return Model.Sort_Field_Value;
   end Sort_Field_Of;

   function Sort_Is_Ascending
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Sort_Ascending;
   end Sort_Is_Ascending;

   procedure Select_Sort_Field
     (Model : in out Window_Model;
      Field : Sort_Field) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Model.Sort_Field_Value = Field then
         Model.Sort_Ascending := not Model.Sort_Ascending;
      else
         Model.Sort_Field_Value := Field;
         Model.Sort_Ascending := True;
      end if;

      Model.Sort_Menu_Open := False;
      Model.Main_View_Scroll := 0;
      Resort_Items (Model);
   end Select_Sort_Field;

   procedure Apply_Sort
     (Model     : in out Window_Model;
      Field     : Sort_Field;
      Ascending : Boolean) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Sort_Field_Value := Field;
      Model.Sort_Ascending   := Ascending;
      Resort_Items (Model);
   end Apply_Sort;

   procedure Sync_Grouping
     (Model    : in out Window_Model;
      Settings : Files.Settings.Settings_Model)
   is
      use type Ada.Calendar.Time;
      use type Files.Settings.Path_Label_Vectors.Vector;
      use type Files.Types.Group_Mode;
      use type Files.Types.View_Mode;
      Mode : constant Files.Types.Group_Mode :=
        (if Model.View_Value = Files.Types.Details then Settings.Group_By else Files.Types.No_Grouping);
      Today : constant Ada.Calendar.Time :=
        (if Mode = Files.Types.Group_By_Modified
         then Files.Grouping.Day_Start (Ada.Calendar.Clock)
         else Model.Group_Day);
      Was_Grouped : constant Boolean := Model.Group_Mode_Value /= Files.Types.No_Grouping;
      Inputs_Changed : constant Boolean :=
        Mode /= Model.Group_Mode_Value
        or else (Mode = Files.Types.Group_By_Label and then Settings.Labels /= Model.Group_Labels)
        or else Today /= Model.Group_Day;
   begin
      if not Inputs_Changed and then Model.Revision_Value = Model.Group_Synced_Revision then
         return;
      end if;
      if Inputs_Changed then
         Model.Group_Mode_Value := Mode;
         Model.Group_Day := Today;
         if Mode = Files.Types.Group_By_Label then
            Model.Group_Labels := Settings.Labels;
         else
            Model.Group_Labels.Clear;
         end if;
      end if;
      --  A changed grouping re-sorts, so each band holds the plain sort order
      --  and leaving a grouping restores it; the Recent view keeps its recency
      --  order and is only partitioned. Otherwise only a reload or edit that
      --  broke the band order needs regrouping, and a reload already sorted.
      if Inputs_Changed
        and then (Was_Grouped or else Mode /= Files.Types.No_Grouping)
        and then not Model.Recent_View_Active
      then
         Resort_Items (Model);
      elsif not Items_In_Group_Order (Model) then
         Resort_Items (Model, Field_Sort => False);
      end if;
      Model.Group_Synced_Revision := Model.Revision_Value;
   end Sync_Grouping;

   procedure Toggle_Sort_Menu
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Sort_Menu_Open := not Model.Sort_Menu_Open;
      --  Open the menu with the keyboard highlight on the current sort field
      --  (rows 1 .. 5 mirror Sort_Field'Val 0 .. 4).
      if Model.Sort_Menu_Open then
         Claim_Overlay_Input (Model);
         Model.Sort_Menu_Highlight_Value := Sort_Field'Pos (Model.Sort_Field_Value) + 1;
      end if;
   end Toggle_Sort_Menu;

   procedure Move_Sort_Menu_Highlight
     (Model : in out Window_Model;
      Delta_Value : Integer) is
      Current : constant Natural :=
        (if Model.Sort_Menu_Highlight_Value = 0 then 1 else Model.Sort_Menu_Highlight_Value);
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Sort_Menu_Highlight_Value :=
        Integer'Max (1, Integer'Min (5, Current + Delta_Value));
   end Move_Sort_Menu_Highlight;

   function Sort_Menu_Highlight
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Sort_Menu_Highlight_Value;
   end Sort_Menu_Highlight;

   function Sort_Menu_Highlight_Field
     (Model : Window_Model)
      return Sort_Field is
   begin
      if Model.Sort_Menu_Highlight_Value in 1 .. 5 then
         return Sort_Field'Val (Model.Sort_Menu_Highlight_Value - 1);
      else
         return Sort_Name;
      end if;
   end Sort_Menu_Highlight_Field;

   procedure Close_Sort_Menu
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Sort_Menu_Open := False;
   end Close_Sort_Menu;

   function Sort_Menu_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Sort_Menu_Open;
   end Sort_Menu_Is_Open;

end View_Sort;
