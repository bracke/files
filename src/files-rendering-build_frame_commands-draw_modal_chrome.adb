separate (Files.Rendering.Build_Frame_Commands)
   procedure Draw_Modal_Chrome
     (X, Y, Panel_W, Panel_H : Natural;
      Fill                   : Render_Color;
      Role                   : Accessibility_Role;
      Name                   : UString;
      Description            : UString := Null_Unbounded_String;
      Backdrop               : Boolean := False) is
   begin
      Result.Accessibility.Clear;
      if Backdrop then
         Add_Overlay_Rect (0, 0, Width, Height, Modal_Backdrop_Color);
      end if;
      Add_Overlay_Drop_Shadow (X, Y, Panel_W, Panel_H);
      Add_Overlay_Rect (X, Y, Panel_W, Panel_H, Fill);
      Add_Overlay_Border (X, Y, Panel_W, Panel_H, Border_Color);
      Add_Accessibility_Node (Role, X, Y, Panel_W, Panel_H, Name, Description);
   end Draw_Modal_Chrome;
