separate (Files.Rendering.Build_Frame_Commands.Add_Icon)
   --  An icon the vector layer can draw is drawn there, in the theme's
   --  colours. An atlas tile is for what it cannot: a thumbnail's pixels,
   --  and an overlay icon (a drag preview), which must sit above the base
   --  layer. Both at once painted every icon twice, the atlas's fixed
   --  colours over the theme's.
   procedure Add_Atlas_Tile is
      --  A thumbnail keeps its proportions: fitted into the icon's
      --  square and centred in it, rather than stretched to fill it.
      Thumb_W : constant Natural := (if Use_Thumbnail then Item.Thumbnail_Width else 0);
      Thumb_H : constant Natural := (if Use_Thumbnail then Item.Thumbnail_Height else 0);
      Longest : constant Natural := Natural'Max (Thumb_W, Thumb_H);
      Fit_W   : constant Natural :=
        (if Longest = 0 or else Thumb_W = Thumb_H then 0
         else Positive'Max (1, Thumb_W * Draw_Size / Longest));
      Fit_H   : constant Natural :=
        (if Longest = 0 or else Thumb_W = Thumb_H then 0
         else Positive'Max (1, Thumb_H * Draw_Size / Longest));
   begin
      Result.Icons.Append
        (Icon_Command'
           (X          => (if Fit_W > 0 then X + (Draw_Size - Fit_W) / 2 else X),
            Y          => (if Fit_H > 0 then Y + (Draw_Size - Fit_H) / 2 else Y),
            Size       => Draw_Size,
            Icon_Id    =>
              To_Unbounded_String (if Thumbnail then Files.File_Types.Thumbnail_Icon_Name else Icon_Name),
            Theme_Name => To_Unbounded_String (Icon_Theme_Name),
            Thumbnail_Width  => (if Use_Thumbnail then Item.Thumbnail_Width else 0),
            Thumbnail_Height => (if Use_Thumbnail then Item.Thumbnail_Height else 0),
            Thumbnail_Pixels =>
              (if Use_Thumbnail then Item.Thumbnail.Pixels else Guikit.Shared_Bytes.Empty),
            Overlay          => Overlay,
            Draw_Width       => Fit_W,
            Draw_Height      => Fit_H,
            Base_Color       =>
              Atlas_Base_Color (if Thumbnail then Files.File_Types.Thumbnail_Icon_Name else Icon_Name),
            others           => <>));
   end Add_Atlas_Tile;
