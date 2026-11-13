with Files.Model.Support;

package body Files.Model.Sort_Menu is

   use Files.Model.Support;

   procedure Toggle
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      Model.Sort_Menu.Open := not Model.Sort_Menu.Open;
      --  Open the menu with the keyboard highlight on the current sort field
      --  (rows 1 .. 5 mirror Sort_Field'Val 0 .. 4).
      if Model.Sort_Menu.Open then
         Claim_Overlay_Input (Model);
         Model.Sort_Menu.Highlight := Files.Types.Sort_Field'Pos (Model.Sort_Field_Value) + 1;
      end if;
   end Toggle;

   procedure Close
     (Model : in out Window_Model)
     renames Files.Model.Support.Close_Sort_Menu;

   function Is_Open
     (Model : Window_Model)
      return Boolean is
     (Model.Sort_Menu.Open);

   procedure Move_Highlight
     (Model : in out Window_Model;
      Delta_Value : Integer) is
      Current : constant Natural :=
        (if Model.Sort_Menu.Highlight = 0 then 1 else Model.Sort_Menu.Highlight);
   begin
      Touch (Model);
      Model.Sort_Menu.Highlight :=
        Integer'Max (1, Integer'Min (5, Current + Delta_Value));
   end Move_Highlight;

   function Highlight
     (Model : Window_Model)
      return Natural is
     (Model.Sort_Menu.Highlight);

   function Highlight_Field
     (Model : Window_Model)
      return Files.Types.Sort_Field is
   begin
      if Model.Sort_Menu.Highlight in 1 .. 5 then
         return Files.Types.Sort_Field'Val (Model.Sort_Menu.Highlight - 1);
      else
         return Files.Types.Sort_Name;
      end if;
   end Highlight_Field;

end Files.Model.Sort_Menu;
