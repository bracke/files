separate (Files.Rendering.Layouts)
   function Tree_Pick_Buttons
     (Panel       : Tree_Panel_Layout;
      Line_Height : Positive)
      return Tree_Pick_Button_Layout
   is
      pragma Unreferenced (Line_Height);
      Height : constant Natural := Panel.Row_Height;
      Half   : constant Natural := Panel.Width / 2;
   begin
      --  Need room for the title band, at least one row, and the button bar.
      if Panel.Width = 0
        or else Height = 0
        or else Panel.Height <= Saturating_Multiply (Height, 2)
      then
         return (others => <>);
      end if;

      return
        (Visible      => True,
         Choose_X     => Panel.X,
         Cancel_X     => Guikit.Layout.Saturating_Add (Panel.X, Half),
         Y            => Guikit.Layout.Saturating_Add (Panel.Y, Panel.Height - Height),
         Button_Width => Half,
         Height       => Height);
   end Tree_Pick_Buttons;
