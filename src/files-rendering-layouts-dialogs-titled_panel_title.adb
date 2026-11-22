separate (Files.Rendering.Layouts.Dialogs)
   procedure Titled_Panel_Title
     (Panel_X, Panel_Y, Panel_W : Natural;
      Line_Height               : Positive;
      Title_X, Title_Y, Title_W : out Natural)
   is
      Margin : constant Natural := Titled_Panel_Padding (Line_Height);
   begin
      Title_X := Guikit.Layout.Saturating_Add (Panel_X, Margin);
      Title_Y := Guikit.Layout.Saturating_Add (Panel_Y, Guikit.Layout.Panel_Edge_Inset (Line_Height));
      --  As the guikit panels title theirs: clear of the close button.
      Title_W :=
        (if Panel_W > Guikit.Layout.Saturating_Add (Margin, Guikit.Layout.Close_Button_Reserve (Line_Height))
         then Panel_W - Margin - Guikit.Layout.Close_Button_Reserve (Line_Height)
         else 0);
   end Titled_Panel_Title;
