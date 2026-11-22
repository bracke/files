with Files.Rendering.Layouts.Menus;
separate (Files.Rendering.Build_Frame_Commands.Draw_Popups)
   --  Shown where the click hit-test finds its rows: a menu laid out with
   --  no width (no sort button) is neither drawn nor hit.
   procedure Draw_Sort_Menu is
      Menu      : constant Files.Rendering.Layouts.Menus.Sort_Menu_Layout :=
        Files.Rendering.Layouts.Menus.Calculate_Sort_Menu_Layout (Width, Height, Snapshot.Sort_Field, Line_Height);
   begin
      if Menu.Width > 0 then
         declare
            Row_H     : constant Natural := Menu.Row_Height;
            Rows_H    : constant Natural := Saturating_Multiply (Row_H, Menu.Row_Count);
            Menu_H    : constant Natural := Menu.Height;
            Menu_X    : constant Natural := Menu.X;
            Menu_Y    : constant Natural := Menu.Y;
            Menu_W    : constant Natural := Menu.Width;
            Rows_Y    : constant Natural := Menu.Rows_Y;
            Row_X     : constant Natural := Guikit.Layout.Saturating_Add (Menu_X, 1);
            Row_W     : constant Natural := (if Menu_W > 2 then Menu_W - 2 else 0);
         begin
            --  Keyboard and pointer routing are confined to the open menu;
            --  publish the same scope to assistive technology.
            Draw_Modal_Chrome
              (Menu_X, Menu_Y, Menu_W, Menu_H, Overlay_Color, Role_List, Localized ("command.sort.menu"));

            declare
               --  Row backgrounds and label text are the shared list geometry --
               --  delegate them to Guikit.List_Panel. The chrome, 1px inter-row
               --  separators and the richer accessibility stay here. The sort menu
               --  has no selected accent bar, so each row's accent is set to the
               --  selection colour, which renders Draw_Palette_Row's accent
               --  invisible against a selected row's background.
               type Sort_Row is record
                  Field    : Files.Types.Sort_Field;
                  Y        : Natural;
                  Selected : Boolean;
                  Enabled  : Boolean;
                  Label    : UString;
               end record;
               --  Each row worked out once, for its fill and then for its
               --  separator and accessibility node drawn over the fills.
               Rows : array (1 .. Menu.Row_Count) of Sort_Row;
               List_Rows    : Guikit.List_Panel.List_Panel_Row_Vectors.Vector;
               Discard_A11y : Guikit.Draw.Accessibility_Node_Vectors.Vector;
               Config : constant Guikit.List_Panel.List_Panel_Configuration :=
                 (Line_Height         => Line_Height,
                  Text_Padding        => Files.Rendering.Layouts.Field_Padding (Line_Height),
                  Show_Alternate_Rows => False,
                  others              => <>);
            begin
               for Row in Rows'Range loop
                  declare
                     Field    : constant Files.Types.Sort_Field :=
                       Files.Rendering.Layouts.Menus.Sort_Menu_Row_Field (Row);
                     Selected : constant Boolean := Field = Snapshot.Sort_Field;
                  begin
                     Rows (Row) :=
                       (Field    => Field,
                        Y        => Files.Rendering.Layouts.Menus.Sort_Menu_Row_Top (Menu, Row),
                        Selected => Selected,
                        Enabled  => Snapshot.Command_Enabled (Sort_Field_Command (Field)),
                        Label    =>
                          To_Unbounded_String
                            (Sort_Field_Label (Field)
                             & (if Selected then " " & Direction_Text (Snapshot.Sort_Ascending) else "")));
                  end;
               end loop;

               for Row in Rows'Range loop
                  declare
                     This        : Sort_Row renames Rows (Row);
                     Hovered     : constant Boolean :=
                       Is_Hovered (Menu_X, This.Y, Menu_W, Row_H);
                     Highlighted : constant Boolean := Row = Snapshot.Sort_Menu_Highlight;
                     Pressed     : constant Boolean := Is_Pressed (Menu_X, This.Y, Menu_W, Row_H);
                  begin
                     List_Rows.Append
                       (Guikit.List_Panel.List_Panel_Row'
                          (Label            => This.Label,
                           Selected         => This.Selected,
                           Enabled          => This.Enabled,
                           Label_Color      => (if This.Enabled then Text_Color else Disabled_Text_Color),
                           Accent_Color     => Selection_Color,
                           Has_Background   => not This.Selected,
                           Background_Color =>
                             (if Pressed then Pressed_Color
                              elsif Hovered or else Highlighted then Hover_Color
                              else Overlay_Color),
                           others           => <>));
                  end;
               end loop;

               Guikit.List_Panel.Draw_Frame
                 (Rectangles    => Result.Overlay_Rectangles,
                  Text          => Result.Overlay_Text,
                  Accessibility => Discard_A11y,
                  Clip_Width    => Layout.Width,
                  Clip_Height   => Layout.Height,
                  Region_X      => Row_X,
                  Region_Y      => Rows_Y,
                  Region_Width  => Row_W,
                  Region_Height => Rows_H,
                  Config        => Config,
                  Rows          => List_Rows,
                  Draw_Chrome   => False,
                  Row_Height    => Row_H);

               for Row in Rows'Range loop
                  if Row > Rows'First then
                     Add_Overlay_Rect (Row_X, Rows (Row).Y, Row_W, 1, Border_Color);
                  end if;
                  Add_Accessibility_Node
                    (Role_List_Item,
                     Menu_X,
                     Rows (Row).Y,
                     Menu_W,
                     Row_H,
                     Rows (Row).Label,
                     Localized (Files.Commands.Description_Key (Sort_Field_Command (Rows (Row).Field))),
                     Enabled  => Rows (Row).Enabled,
                     Selected => Rows (Row).Selected);
               end loop;
            end;
         end;
      end if;
   end Draw_Sort_Menu;
