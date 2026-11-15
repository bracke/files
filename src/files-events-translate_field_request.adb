separate (Files.Events)
   function Translate_Field_Request
     (Node_X      : Natural;
      Node_Y      : Natural;
      Node_W      : Natural;
      Node_H      : Natural;
      Width       : Natural;
      Line_Height : Positive)
      return Input_Action
   is
      Toolbar : constant Guikit.Layout.Toolbar_Layout := Guikit.Layout.Calculate_Toolbar_Layout (Width, Line_Height);
      Input_Y : constant Natural := Guikit.Layout.Toolbar_Input_Y (Line_Height);
      Input_H : constant Natural := Guikit.Layout.Toolbar_Input_Height (Line_Height);
      Path    : constant Files.Rendering.Layouts.Field_Text_Region :=
        Files.Rendering.Layouts.Path_Field_Text_Region (Toolbar, Width, Line_Height);
      Filter  : constant Files.Rendering.Layouts.Field_Text_Region :=
        Files.Rendering.Layouts.Filter_Field_Text_Region (Toolbar, Line_Height);

      function Is_Box (Region : Files.Rendering.Layouts.Field_Text_Region) return Boolean is
        (Region.Field_Width > 0
         and then Node_X = Region.Field_X and then Node_W = Region.Field_Width
         and then Node_Y = Input_Y and then Node_H = Input_H);
   begin
      if Is_Box (Path) then
         return (Kind => Command_Input_Action, Command => Files.Commands.Focus_Path_Input_Command);
      elsif Is_Box (Filter) then
         return (Kind => Command_Input_Action, Command => Files.Commands.Focus_Filter_Input_Command);
      end if;
      return No_Action;
   end Translate_Field_Request;
