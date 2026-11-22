separate (Files.Application.Windows)
   --  The dragged item's visible index, found again by its path when the rows
   --  moved since the press (a watched refresh reordering the list mid-drag):
   --  the index taken at the press would then name another item, for the drop
   --  and for the drag preview. An item gone since ends the drag (0).
   procedure Resolve_Drag_Source (Runtime : in out Runtime_Window) is
      Rows : constant Natural := Files.Model.Rows_Revision (Runtime.Model);
   begin
      if Runtime.Drag_Source_Index /= 0 and then Runtime.Drag_Source_Rows /= Rows then
         Runtime.Drag_Source_Index :=
           Files.Model.Visible_Index_Of (Runtime.Model, Ada.Strings.Unbounded.To_String (Runtime.Drag_Source_Path));
         Runtime.Drag_Source_Rows := Rows;
      end if;
   end Resolve_Drag_Source;
