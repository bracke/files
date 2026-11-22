separate (Files.Rendering.Build_Frame_Commands)
   function Tooltip_At
     (Point_X : Natural;
      Point_Y : Natural)
      return UString is
   begin
      for Command of reverse Result.Tooltips loop
         if Contains_Point (Command.X, Command.Y, Command.Width, Command.Height, Point_X, Point_Y) then
            return Command.Text;
         end if;
      end loop;

      return Null_Unbounded_String;
   end Tooltip_At;
