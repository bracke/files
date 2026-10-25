separate (Files_Suite.Rendering)
   procedure Test_Drag_Preview_Uses_Overlay
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Snap : constant View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
      Base : constant Frame_Commands := Build_Frame_Commands (Snap, 640, 480, 20);
      Drag : constant Frame_Commands :=
        Build_Frame_Commands
          (Snap, 640, 480, 20,
           Drag_Item_Index => 1,
           Drag_X          => 620,
           Drag_Y          => 460,
           Has_Drag        => True);
      Found_Icon : Boolean := False;
      Found_Name : Boolean := False;
      Widths  : constant array (Positive range <>) of Natural := [1, 7, 40, 120, 640];
      Heights : constant array (Positive range <>) of Natural := [1, 7, 20, 44, 100];
   begin
      Files_Suite.Support.Assert_Equal
        (Natural (Drag.Rectangles.Length),
         Natural (Base.Rectangles.Length),
         "the drag preview adds no panel geometry to the base layer");
      Assert
        (Natural (Drag.Overlay_Rectangles.Length) > Natural (Base.Overlay_Rectangles.Length),
         "the drag preview panel is emitted in the overlay layer");
      for Icon of Drag.Icons loop
         Found_Icon := Found_Icon or else Icon.Overlay;
      end loop;
      for Command of Drag.Overlay_Text loop
         Found_Name := Found_Name or else To_String (Command.Text) = "item 1";
      end loop;
      Assert (Found_Icon, "the dragged item's icon is emitted in the overlay layer");
      Assert (Found_Name, "the dragged item's name is emitted in the overlay layer");

      for Width of Widths loop
         for Height of Heights loop
            declare
               Frame : constant Frame_Commands :=
                 Build_Frame_Commands
                   (Snap, Width, Height, 20,
                    Drag_Item_Index => 1,
                    Drag_X          => Width - 1,
                    Drag_Y          => Height - 1,
                    Has_Drag        => True);
            begin
               for Rect of Frame.Overlay_Rectangles loop
                  Files_Suite.Support.Assert_Fits
                    (Rect.X, Rect.Y, Rect.Width, Rect.Height, Width, Height,
                     "compact drag-preview rectangles stay inside the framebuffer");
               end loop;
               for Icon of Frame.Icons loop
                  if Icon.Overlay then
                     Assert
                       (Icon.X + Icon.Size <= Width and then Icon.Y + Icon.Size <= Height,
                        "compact drag-preview icons stay inside the framebuffer");
                  end if;
               end loop;
               for Command of Frame.Overlay_Text loop
                  Assert
                    (Command.X + Command.Width <= Width
                     and then Command.Y + Command.Height <= Height,
                     "compact drag-preview text stays inside the framebuffer");
               end loop;
            end;
         end loop;
      end loop;
   end Test_Drag_Preview_Uses_Overlay;
