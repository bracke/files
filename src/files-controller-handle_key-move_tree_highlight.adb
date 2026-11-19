separate (Files.Controller.Handle_Key)
--  Arrow keys over the visible tree rows, shared by the destination picker
--  and the side panel when it has the keyboard; Pick says whose highlight
--  moves. Up/Down step a row; Right expands the folder (loading its
--  children if needed) or steps into it; Left collapses it or steps out to
--  the parent.
function Move_Tree_Highlight (Pick : Boolean) return Controller_Result is
   Rows    : constant Files.Folder_Tree.Visible_Row_Vectors.Vector :=
     Files.Model.Tree_Panel.Visible_Rows (Model);
   Target  : constant String :=
     (if Pick then Files.Model.Tree_Panel.Pick_Target (Model) else Files.Model.Tree_Panel.Cursor (Model));
   Current : Natural := 0;

   procedure Select_Row (Index : Positive) is
   begin
      if Pick then
         Files.Model.Tree_Panel.Set_Pick_Target (Model, To_String (Rows (Index).Path));
      else
         Files.Model.Tree_Panel.Set_Cursor (Model, To_String (Rows (Index).Path));
      end if;
      Files.Model.Tree_Panel.Ensure_Row_Visible (Model, Index, Tree_Page_Rows);
   end Select_Row;
begin
   if Rows.Is_Empty then
      return Make_Result (Controller_Ignored);
   end if;
   for Idx in Rows.First_Index .. Rows.Last_Index loop
      if To_String (Rows (Idx).Path) = Target then
         Current := Idx;
         exit;
      end if;
   end loop;
   if Current = 0 then
      --  Nothing highlighted yet: the first arrow lands on the first row
      --  so the rest of the navigation has an anchor.
      Select_Row (Rows.First_Index);
      return Make_Result (Controller_Selection_Moved);
   end if;

   case Key is
      when Guikit.Input.Key_Up =>
         if Current > Rows.First_Index then
            Select_Row (Current - 1);
         end if;
      when Guikit.Input.Key_Down =>
         if Current < Rows.Last_Index then
            Select_Row (Current + 1);
         end if;
      when Guikit.Input.Key_Right =>
         if Rows (Current).Has_Children and then not Rows (Current).Expanded then
            return Toggle_Tree_Node (Model, Settings, Rows (Current).Node_Index);
         elsif Rows (Current).Expanded
           and then Rows (Current).Has_Children
           and then Current < Rows.Last_Index
           and then Rows (Current + 1).Depth > Rows (Current).Depth
         then
            --  Into the first child; an expanded folder with none
            --  keeps the highlight rather than handing it to the
            --  next sibling.
            Select_Row (Current + 1);
         end if;
      when Guikit.Input.Key_Left =>
         if Rows (Current).Expanded then
            return Toggle_Tree_Node (Model, Settings, Rows (Current).Node_Index);
         else
            for Up_Idx in reverse Rows.First_Index .. Current - 1 loop
               if Rows (Up_Idx).Depth < Rows (Current).Depth then
                  Select_Row (Up_Idx);
                  exit;
               end if;
            end loop;
         end if;
      when others =>
         null;
   end case;
   return Make_Result (Controller_Selection_Moved);
end Move_Tree_Highlight;
