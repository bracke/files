separate (Files.Rendering.Build_Frame_Commands.Add_Icon)
   --  No definition could be drawn (a broken .icon file): a plain shape for
   --  the same icon, so the item is never left without one.
   procedure Add_Fallback_Shape is
      Fold       : constant Natural := Natural'Max (1, Draw_Size / 4);
      Stripe_W   : constant Natural := Natural'Max (1, Draw_Size / 5);
      Body_Y     : constant Natural := Guikit.Layout.Saturating_Add (Y, Natural'Max (1, Draw_Size / 4));
      Body_H     : constant Natural :=
        (if Draw_Size > Body_Y - Y then Draw_Size - (Body_Y - Y) else Draw_Size);

      function Scale (Numerator : Natural; Denominator : Positive) return Natural is
      begin
         return Bounded_Product_Divide (Draw_Size, Numerator, Denominator);
      end Scale;

      function X_Offset (Offset : Natural) return Natural is
      begin
         return Guikit.Layout.Saturating_Add (X, Offset);
      end X_Offset;

      function Y_Offset (Offset : Natural) return Natural is
      begin
         return Guikit.Layout.Saturating_Add (Y, Offset);
      end Y_Offset;
   begin
      case Icon is
         when Files.File_Types.Folder_Icon =>
            Add_Rect
              (X,
               Y_Offset (Scale (1, 6)),
               Natural'Max (1, Scale (1, 2)),
               Natural'Max (1, Scale (1, 5)),
               Base_Color);
            Add_Rect (X, Body_Y, Draw_Size, Body_H, Base_Color);
            if Draw_Size > 4 then
               Add_Rect (X_Offset (1), Guikit.Layout.Saturating_Add (Body_Y, 1), Draw_Size - 2, 1, Border_Color);
            end if;

         when Files.File_Types.Executable_Icon =>
            Add_Rect (X, Y, Draw_Size, Draw_Size, Icon_Document_Color);
            Add_Rect (X_Offset (Draw_Size - Fold), Y, Fold, Fold, Muted_Text_Color);
            Add_Rect (X, Y, Stripe_W, Draw_Size, Accent);
            if Draw_Size > 6 then
               Add_Rect
                 (X_Offset (Scale (1, 2)),
                  Y_Offset (Scale (1, 3)),
                  Stripe_W,
                  Scale (1, 3),
                  Accent);
               Add_Rect
                 (X_Offset (Guikit.Layout.Saturating_Add (Scale (1, 2), Stripe_W)),
                  Y_Offset (Scale (1, 2)),
                  Stripe_W,
                  Stripe_W,
                  Accent);
            end if;

         when Files.File_Types.Link_Icon =>
            Add_Rect (X, Y, Draw_Size, Draw_Size, Icon_Document_Color);
            Add_Rect (X_Offset (Draw_Size - Fold), Y, Fold, Fold, Muted_Text_Color);
            if Draw_Size > 5 then
               Add_Rect
                 (X_Offset (Scale (1, 5)),
                  Y_Offset (Scale (1, 2)),
                  Scale (1, 2),
                  Natural'Max (1, Scale (1, 6)),
                  Selection_Color);
               Add_Rect
                 (X_Offset (Scale (1, 2)),
                  Y_Offset (Scale (1, 3)),
                  Scale (1, 4),
                  Natural'Max (1, Scale (1, 6)),
                  Selection_Color);
               Add_Rect
                 (X_Offset (Scale (1, 2)),
                  Y_Offset (Scale (2, 3)),
                  Scale (1, 4),
                  Natural'Max (1, Scale (1, 6)),
                  Selection_Color);
            end if;

         when Files.File_Types.Text_Icon | Files.File_Types.Markdown_Icon | Files.File_Types.Ada_Icon
            | Files.File_Types.Image_Icon | Files.File_Types.Unknown_Icon
         =>
            Add_Rect (X, Y, Draw_Size, Draw_Size, Base_Color);
            Add_Rect (X_Offset (Draw_Size - Fold), Y, Fold, Fold, Muted_Text_Color);
            if Draw_Size > 7 then
               if Icon = Files.File_Types.Image_Icon then
                  Add_Rect
                    (X_Offset (Scale (1, 5)),
                     Y_Offset (Scale (1, 3)),
                     Scale (3, 5),
                     Scale (1, 3),
                     Selection_Color);
                  Add_Rect
                    (X_Offset (Scale (1, 4)),
                     Y_Offset (Scale (1, 2)),
                     Scale (1, 5),
                     Scale (1, 6),
                     Border_Color);
                  Add_Rect
                    (X_Offset (Scale (1, 2)),
                     Y_Offset (Scale (1, 2)),
                     Scale (1, 4),
                     Scale (1, 6),
                     Border_Color);
               elsif Icon = Files.File_Types.Ada_Icon then
                  Add_Rect
                    (X_Offset (Scale (1, 5)),
                     Y_Offset (Scale (1, 3)),
                     Scale (1, 5),
                     Scale (1, 2),
                     Icon_Program_Color);
                  Add_Rect
                    (X_Offset (Scale (3, 5)),
                     Y_Offset (Scale (1, 3)),
                     Scale (1, 5),
                     Scale (1, 2),
                     Icon_Program_Color);
                  Add_Rect
                    (X_Offset (Scale (1, 4)),
                     Y_Offset (Scale (1, 2)),
                     Scale (1, 2),
                     Natural'Max (1, Scale (1, 6)),
                     Selection_Color);
               elsif Icon = Files.File_Types.Markdown_Icon then
                  Add_Rect
                    (X_Offset (Scale (1, 5)),
                     Y_Offset (Scale (1, 3)),
                     Scale (1, 5),
                     Scale (1, 2),
                     Border_Color);
                  Add_Rect
                    (X_Offset (Scale (2, 5)),
                     Y_Offset (Scale (1, 2)),
                     Scale (1, 5),
                     Scale (1, 3),
                     Border_Color);
                  Add_Rect
                    (X_Offset (Scale (3, 5)),
                     Y_Offset (Scale (1, 3)),
                     Scale (1, 5),
                     Scale (1, 2),
                     Border_Color);
               elsif Icon = Files.File_Types.Unknown_Icon then
                  Add_Rect
                    (X_Offset (Scale (1, 3)),
                     Y_Offset (Scale (1, 4)),
                     Scale (1, 3),
                     Natural'Max (1, Scale (1, 6)),
                     Border_Color);
                  Add_Rect
                    (X_Offset (Scale (1, 2)),
                     Y_Offset (Scale (1, 3)),
                     Natural'Max (1, Scale (1, 6)),
                     Scale (1, 3),
                     Border_Color);
                  Add_Rect
                    (X_Offset (Scale (1, 2)),
                     Y_Offset (Scale (3, 4)),
                     Natural'Max (1, Scale (1, 6)),
                     1,
                     Border_Color);
               else
                  Add_Rect (X_Offset (Scale (1, 5)), Y_Offset (Scale (1, 2)), Scale (3, 5), 1, Border_Color);
                  Add_Rect
                    (X_Offset (Scale (1, 5)),
                     Y_Offset (Guikit.Layout.Saturating_Add (Scale (1, 2), Scale (1, 5))),
                     Scale (1, 2),
                     1,
                     Border_Color);
                  Add_Rect
                    (X_Offset (Scale (1, 5)),
                     Y_Offset (Scale (1, 2) - Scale (1, 5)),
                     Scale (1, 2),
                     1,
                     Border_Color);
               end if;
            end if;
      end case;
   end Add_Fallback_Shape;
