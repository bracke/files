with Files.Model.Support;

package body Files.Model.Context_Menu is

   use Files.Model.Support;

   procedure Open
     (Model      : in out Window_Model;
      X          : Natural;
      Y          : Natural;
      Target     : Context_Menu_Target;
      Item_Index : Natural := 0) is
   begin
      Touch (Model);
      Claim_Overlay_Input (Model);
      --  No keyboard highlight until the user arrows; a mouse-opened menu shows
      --  none pre-selected.
      Model.Context_Menu :=
        (Open => True, X => X, Y => Y, Target => Target, Item_Index => Item_Index, Highlight => 0);
   end Open;

   procedure Close
     (Model : in out Window_Model)
     renames Files.Model.Support.Close_Context_Menu;

   function Is_Open
     (Model : Window_Model)
      return Boolean is
     (Model.Context_Menu.Open);

   function X
     (Model : Window_Model)
      return Natural is
     (Model.Context_Menu.X);

   function Y
     (Model : Window_Model)
      return Natural is
     (Model.Context_Menu.Y);

   function Target_Of
     (Model : Window_Model)
      return Context_Menu_Target is
     (Model.Context_Menu.Target);

   function Item_Index
     (Model : Window_Model)
      return Natural is
     (Model.Context_Menu.Item_Index);

   procedure Set_Highlight
     (Model : in out Window_Model;
      Row   : Natural) is
   begin
      Touch (Model);
      Model.Context_Menu.Highlight := Row;
   end Set_Highlight;

   function Highlight
     (Model : Window_Model)
      return Natural is
     (Model.Context_Menu.Highlight);

end Files.Model.Context_Menu;
