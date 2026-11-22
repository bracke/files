separate (Files.Application.Windows)
   --  The dragged item's visible index, found again by its path when the rows
   --  moved since the press (Window_Policy.Drag_Source_Now): the index taken
   --  at the press would then name another item, for the drop and for the
   --  drag preview. An item gone since ends the drag (0).
   procedure Resolve_Drag_Source (Runtime : in out Runtime_Window) is
      Rows : constant Natural := Files.Model.Rows_Revision (Runtime.Model);

      function Index_Of (Path : String) return Natural is
        (Files.Model.Visible_Index_Of (Runtime.Model, Path));
   begin
      Runtime.Drag_Source_Index :=
        Files.Application.Window_Policy.Drag_Source_Now
          (Index      => Runtime.Drag_Source_Index,
           Index_Rows => Runtime.Drag_Source_Rows,
           Rows       => Rows,
           Path       => Ada.Strings.Unbounded.To_String (Runtime.Drag_Source_Path),
           Index_Of   => Index_Of'Access);
      if Runtime.Drag_Source_Index /= 0 then
         Runtime.Drag_Source_Rows := Rows;
      end if;
   end Resolve_Drag_Source;
