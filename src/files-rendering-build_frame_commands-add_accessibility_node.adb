separate (Files.Rendering.Build_Frame_Commands)
   procedure Add_Accessibility_Node
     (Role        : Accessibility_Role;
      X           : Natural;
      Y           : Natural;
      Node_W      : Natural;
      Node_H      : Natural;
      Name        : UString;
      Description : UString := Null_Unbounded_String;
      Enabled     : Boolean := True;
      Selected    : Boolean := False;
      Focused     : Boolean := False)
   is
      Draw_W : constant Natural := Clipped_Size (X, Node_W, Layout.Width);
      Draw_H : constant Natural := Clipped_Size (Y, Node_H, Layout.Height);
   begin
      if Draw_W > 0 and then Draw_H > 0 then
         Result.Accessibility.Append
           (Accessibility_Node'
              (Role        => Role,
               X           => X,
               Y           => Y,
               Width       => Draw_W,
               Height      => Draw_H,
               Name        => Name,
               Description => Description,
               Enabled     => Enabled,
               Selected    => Selected,
               Focused     => Focused));
      end if;
   end Add_Accessibility_Node;
