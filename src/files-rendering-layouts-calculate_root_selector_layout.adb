separate (Files.Rendering.Layouts)
   function Calculate_Root_Selector_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Root_Selector_Layout
   is
      Preferred_Width : constant Natural := Natural'Max (Layout.Width / 3,
        Guikit.Layout.Saturating_Multiply (Line_Height, 18));
      Dropdown_Width  : constant Natural := Natural'Min (Layout.Width, Preferred_Width);
      Row_Height      : constant Natural :=
        Guikit.Layout.Saturating_Add
          (Guikit.Layout.Saturating_Add (Line_Height,
            Guikit.Layout.Saturating_Multiply (Field_Padding (Line_Height), 2)),
           Guikit.Layout.Saturating_Multiply (Root_Selector_Padding (Line_Height), 2));
      Wanted_Height   : constant Natural :=
        Guikit.Layout.Saturating_Add
          (Guikit.Layout.Saturating_Multiply (Natural (Snapshot.Roots.Length), Row_Height),
           Guikit.Layout.Saturating_Multiply (Root_Selector_Padding (Line_Height), 2));
      Dropdown_Height : constant Natural := Natural'Min (Layout.Main_Height, Wanted_Height);
   begin
      if not Snapshot.Root_Selector_Open then
         return (others => <>);
      end if;

      return
        (X          => 0,
         Y          => Layout.Toolbar_Height,
         Width      => Dropdown_Width,
         Height     => Dropdown_Height,
         Row_Height => Row_Height,
         Padding    => Root_Selector_Padding (Line_Height),
         Close_Button =>
           Panel_Close_Button (0, Layout.Toolbar_Height, Dropdown_Width, Dropdown_Height, Line_Height));
   end Calculate_Root_Selector_Layout;
