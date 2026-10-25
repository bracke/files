separate (Files_Suite.Rendering)
   procedure Test_Compact_Frame_Commands_Bounded
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Widths  : constant array (Positive range <>) of Natural :=
        [0, 1, 7, 40, 119, 279, 280, 639, 640];
      Heights : constant array (Positive range <>) of Natural :=
        [0, 1, 7, 8, 9, 20, 39, 40, 41, 72, 73, 100];
      Snap    : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
   begin
      --  Exercise both the filled-star triangles and the toolbar asset icons.
      Snap.Current_Path_Is_Favorite := True;
      for Width of Widths loop
         for Height of Heights loop
            declare
               Frame : constant Frame_Commands :=
                 Build_Frame_Commands (Snap, Width, Height, 20);
            begin
               for Command of Frame.Rectangles loop
                  Files_Suite.Support.Assert_Fits
                    (Command.X, Command.Y, Command.Width, Command.Height, Width, Height,
                     "rectangle commands stay inside the compact framebuffer");
               end loop;
               for Command of Frame.Text loop
                  Files_Suite.Support.Assert_Fits
                    (Command.X, Command.Y, Command.Width, Command.Height, Width, Height,
                     "text commands stay inside the compact framebuffer");
               end loop;
               for Tip of Frame.Tooltips loop
                  Files_Suite.Support.Assert_Fits
                    (Tip.X, Tip.Y, Tip.Width, Tip.Height, Width, Height,
                     "tooltip regions stay inside the compact framebuffer");
               end loop;
               for Node of Frame.Accessibility loop
                  Files_Suite.Support.Assert_Fits
                    (Node.X, Node.Y, Node.Width, Node.Height, Width, Height,
                     "accessibility nodes stay inside the compact framebuffer");
               end loop;
               for Icon of Frame.Icons loop
                  declare
                     Draw_W : constant Natural :=
                       (if Icon.Draw_Width > 0 then Icon.Draw_Width else Icon.Size);
                     Draw_H : constant Natural :=
                       (if Icon.Draw_Height > 0 then Icon.Draw_Height else Icon.Size);
                  begin
                     Files_Suite.Support.Assert_Fits
                       (Icon.X, Icon.Y, Draw_W, Draw_H, Width, Height,
                        "icon commands stay inside the compact framebuffer");
                  end;
               end loop;
               for Triangle of Frame.Triangles loop
                  Files_Suite.Support.Assert_Between
                    (Triangle.X1, 0.0, Float (Width), "triangle commands stay inside the compact framebuffer (X1)");
                  Files_Suite.Support.Assert_Between
                    (Triangle.X2, 0.0, Float (Width), "triangle commands stay inside the compact framebuffer (X2)");
                  Files_Suite.Support.Assert_Between
                    (Triangle.X3, 0.0, Float (Width), "triangle commands stay inside the compact framebuffer (X3)");
                  Files_Suite.Support.Assert_Between
                    (Triangle.Y1, 0.0, Float (Height), "triangle commands stay inside the compact framebuffer (Y1)");
                  Files_Suite.Support.Assert_Between
                    (Triangle.Y2, 0.0, Float (Height), "triangle commands stay inside the compact framebuffer (Y2)");
                  Files_Suite.Support.Assert_Between
                    (Triangle.Y3, 0.0, Float (Height), "triangle commands stay inside the compact framebuffer (Y3)");
               end loop;
            end;
         end loop;
      end loop;
   end Test_Compact_Frame_Commands_Bounded;
