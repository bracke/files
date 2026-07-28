separate (Files.Application.Windows)
   procedure Apply_Scenario
     (Runtime  : in out Runtime_Window;
      Scenario : Live_Smoke_Scenario)
   is
      Large_Font : constant Positive := Files.Settings.Max_Font_Pixel_Size - 1;
      Has_Item   : constant Boolean := Files.Model.Visible_Count (Runtime.Model) >= 1;
   begin
      case Scenario is
         when Scenario_Default =>
            null;

         when Scenario_Selection =>
            if Has_Item then
               Files.Model.Select_Visible (Runtime.Model, 1);
            end if;

         when Scenario_Scrolled =>
            Files.Model.Replace_Items
              (Runtime.Model, Scenario_Overflow_Items (Runtime.Model));
            Files.Model.Set_Main_View_Scroll_Lines
              (Runtime.Model, Scenario_Scroll_Lines);

         when Scenario_Context_Menu =>
            Files.Model.Open_Context_Menu
              (Model      => Runtime.Model,
               X          => 64,
               Y          => 96,
               Target     =>
                 (if Has_Item then Files.Model.Context_Menu_Item
                  else Files.Model.Context_Menu_Empty),
               Item_Index => (if Has_Item then 1 else 0));

         when Scenario_Palette =>
            Files.Model.Open_Command_Palette (Runtime.Model);

         when Scenario_Root_Selector =>
            declare
               Roots : Files.Types.String_Vectors.Vector;
            begin
               Roots.Append (To_Unbounded_String ("/"));
               Roots.Append (To_Unbounded_String ("/home"));
               Files.Model.Open_Root_Selector (Runtime.Model, Roots);
            end;

         when Scenario_Sort_Menu =>
            Files.Model.Toggle_Sort_Menu (Runtime.Model);

         when Scenario_Tree_Panel =>
            declare
               Seeds : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
            begin
               Seeds.Append
                 (Files.Folder_Tree.Entry_Seed'
                    (Path => To_Unbounded_String ("/"),
                     Name => To_Unbounded_String ("Root")));
               Seeds.Append
                 (Files.Folder_Tree.Entry_Seed'
                    (Path => To_Unbounded_String ("/home"),
                     Name => To_Unbounded_String ("Home")));
               Files.Model.Seed_Tree (Runtime.Model, Seeds);
               Files.Model.Open_Tree_Panel (Runtime.Model);
            end;

         when Scenario_Settings =>
            Files.Model.Begin_Settings_Edit
              (Runtime.Model, Files.Settings.Make_Draft (Runtime.Settings));

         when Scenario_Large_Font =>
            --  Jump to a size the baseline is not already using so the scaling
            --  path is exercised and the frame provably differs from default.
            declare
               Target : constant Positive :=
                 (if Runtime.Font_Pixel_Size >= Large_Font
                  then Files.Settings.Min_Font_Pixel_Size
                  else Large_Font);
            begin
               Runtime.Font_Pixel_Size := Target;
               Runtime.Settings.Font_Pixel_Size := Target;
            end;

         when Scenario_Light_Theme =>
            Runtime.Settings.Theme := Files.Settings.Theme_Light;

         when Scenario_Details_View =>
            --  Render the details layout, unless the startup already uses it
            --  (a user default), in which case switch to a large-icons layout
            --  so the view-mode relayout still provably changes the frame.
            if Files.Model.View_Mode_Of (Runtime.Model) = Files.Types.Details then
               Files.Model.Set_View_Mode (Runtime.Model, Files.Types.Large_Icons);
            else
               Files.Model.Set_View_Mode (Runtime.Model, Files.Types.Details);
            end if;

         when Scenario_Quick_Look =>
            --  Preview the first item: Quick Look opens an overlay panel drawn on
            --  top of the grid, exercising the overlay icon/text/rect passes.
            if Has_Item then
               Files.Model.Select_Visible (Runtime.Model, 1);
               Files.Model.Toggle_Quick_Look (Runtime.Model);
            end if;

         when Scenario_Quick_Look_Image =>
            --  Open Quick Look on a synthetic high-resolution image so the large
            --  icon-atlas tile and overlay image pass are exercised end to end
            --  (no real file or image library needed).
            if Has_Item then
               Files.Model.Select_Visible (Runtime.Model, 1);
               declare
                  Dim     : constant := 256;
                  Content : Files.Quick_Look.Quick_Look_Content;
               begin
                  Content.Kind := Files.Quick_Look.Image_Content;
                  Content.Image_Width := Dim;
                  Content.Image_Height := Dim;
                  for Y in 0 .. Dim - 1 loop
                     for X in 0 .. Dim - 1 loop
                        Content.Image_Pixels.Append (Interfaces.Unsigned_8 (X mod 256));
                        Content.Image_Pixels.Append (Interfaces.Unsigned_8 (Y mod 256));
                        Content.Image_Pixels.Append (128);
                        Content.Image_Pixels.Append (255);
                     end loop;
                  end loop;
                  Files.Model.Open_Quick_Look (Runtime.Model, Content);
               end;
            end if;
      end case;
   end Apply_Scenario;
