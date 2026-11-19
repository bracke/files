separate (Files.Rendering.Build_Frame_Commands)
   procedure Add_Icon
     (Item : Item_Snapshot;
      X    : Natural;
      Y    : Natural;
      Size : Natural;
      Use_Thumbnail : Boolean := False;
      Overlay       : Boolean := False)
   is
      use type Files.File_Types.Icon_Kind;

      Base_Color : constant Render_Color := Icon_Color (Item.Kind);
      --  The icon was resolved when the snapshot was built: this draws it.
      Icon       : constant Files.File_Types.Icon_Kind := Item.Icon;
      Icon_Name  : constant String := Files.File_Types.Icon_Name (Icon);
      Thumbnail  : constant Boolean :=
        Use_Thumbnail and then Item.Thumbnail_Available and then Length (Item.Thumbnail_Path) > 0;
      Draw_Size  : constant Natural :=
        Natural'Min
          (Size,
           Natural'Min
             (Clipped_Size (X, Size, Layout.Width),
              Clipped_Size (Y, Size, Layout.Height)));
      Accent     : constant Render_Color :=
        (if Item.Kind = Files.Types.Executable_Item or else Icon = Files.File_Types.Ada_Icon
         then Icon_Program_Color
         else Selection_Color);

      function Asset_Color (Role : Icon_Asset_Color_Role) return Render_Color is
      begin
         case Role is
            when Icon_Asset_Base =>
               return Base_Color;
            when Icon_Asset_Accent =>
               return Accent;
            when Icon_Asset_Border =>
               return Border_Color;
            when Icon_Asset_Muted =>
               return Muted_Text_Color;
         end case;
      end Asset_Color;

      procedure Add_Asset_Rect
      (Asset : Icon_Asset;
       Rect  : Icon_Asset_Rect)
      is
         Rect_X : constant Natural :=
           Guikit.Layout.Saturating_Add
             (X, Bounded_Product_Divide (Value => Rect.Grid_X, Factor => Draw_Size, Denominator => Asset.Grid));
         Rect_Y : constant Natural :=
           Guikit.Layout.Saturating_Add
             (Y, Bounded_Product_Divide (Value => Rect.Grid_Y, Factor => Draw_Size, Denominator => Asset.Grid));
         Rect_W : constant Natural :=
           Natural'Max
             (1, Bounded_Product_Divide (Value => Rect.Grid_W, Factor => Draw_Size, Denominator => Asset.Grid));
         Rect_H : constant Natural :=
           Natural'Max
             (1, Bounded_Product_Divide (Value => Rect.Grid_H, Factor => Draw_Size, Denominator => Asset.Grid));
      begin
         Add_Rect (Rect_X, Rect_Y, Rect_W, Rect_H, Asset_Color (Rect.Role));
      end Add_Asset_Rect;

      procedure Add_Asset_Tri
        (Asset : Icon_Asset;
         Tri   : Icon_Asset_Tri)
      is
         function PX (G : Natural) return Float is
           (Float (Guikit.Layout.Saturating_Add
              (X, Bounded_Product_Divide (Value => G, Factor => Draw_Size, Denominator => Asset.Grid))));
         function PY (G : Natural) return Float is
           (Float (Guikit.Layout.Saturating_Add
              (Y, Bounded_Product_Divide (Value => G, Factor => Draw_Size, Denominator => Asset.Grid))));
      begin
         Add_Triangle
           (PX (Tri.X1), PY (Tri.Y1), PX (Tri.X2), PY (Tri.Y2), PX (Tri.X3), PY (Tri.Y3),
            Asset_Color (Tri.Role));
      end Add_Asset_Tri;

      function Add_Named_Asset (Name : String) return Boolean is
         Asset : constant Icon_Asset := Parsed_Icon_Asset (Name, Icon_Theme_Name);
      begin
         if not Asset.Valid then
            return False;
         end if;

         for Rect of Asset.Rectangles loop
            Add_Asset_Rect (Asset, Rect);
         end loop;
         for Tri of Asset.Triangles loop
            Add_Asset_Tri (Asset, Tri);
         end loop;
         return True;
      end Add_Named_Asset;

      procedure Add_Extension_Badge is separate;
      procedure Add_Atlas_Tile is separate;
      procedure Add_Fallback_Shape is separate;
   begin
      if Draw_Size = 0 then
         return;
      end if;

      Add_Extension_Badge;

      --  A thumbnail's pixels and an overlay icon go to the atlas.
      if Overlay or else Thumbnail then
         Add_Atlas_Tile;
      end if;

      --  Overlay icons are rasterized from the same asset, but must not
      --  also emit their vectors into the base rectangle/triangle layer or
      --  background content would paint over the drag preview.
      if Overlay then
         return;
      end if;

      if Thumbnail and then Add_Named_Asset (Files.File_Types.Thumbnail_Icon_Name) then
         return;
      elsif Add_Named_Asset (Icon_Name) then
         return;
      end if;

      Add_Fallback_Shape;
   end Add_Icon;
