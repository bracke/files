separate (Files_Suite.Rendering)
   --  An item icon the vector layer draws (in the theme's colours) gets no
   --  atlas tile as well: the tile, in fixed colours, was painted over it.
   procedure Test_Item_Icons_Drawn_Once (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      for Mode in Files.Types.View_Mode loop
         declare
            Frame : constant Frame_Commands := Build_Frame_Commands
              (Sample_Snapshot (6, Mode), Width => 1200, Height => 800, Line_Height => 20);
         begin
            Assert (not Frame.Rectangles.Is_Empty, "the frame draws its icons as vectors");
            for Icon of Frame.Icons loop
               declare
                  Id : constant String := To_String (Icon.Icon_Id);
               begin
                  Assert
                    (Icon.Overlay
                     or else not Icon.Thumbnail_Pixels.Is_Empty
                     or else (Id'Length > 8 and then Id (Id'First .. Id'First + 7) = "toolbar-"),
                     "an atlas tile only for what vectors cannot draw, not " & Id);
               end;
            end loop;
         end;
      end loop;
   end Test_Item_Icons_Drawn_Once;
