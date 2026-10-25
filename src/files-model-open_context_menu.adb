separate (Files.Model)
procedure Open_Context_Menu
  (Model      : in out Window_Model;
   X          : Natural;
   Y          : Natural;
   Target     : Context_Menu_Target;
   Item_Index : Natural := 0) is
begin
   Model.Revision_Value := Model.Revision_Value + 1;
   Claim_Overlay_Input (Model);
   --  No keyboard highlight until the user arrows; a mouse-opened menu shows
   --  none pre-selected.
   Model.Context_Menu :=
     (Open => True, X => X, Y => Y, Target => Target, Item_Index => Item_Index, Highlight => 0);
end Open_Context_Menu;
