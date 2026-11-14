with Files.Folder_Tree;
with Files.Quick_Look;
with Guikit.Shared_Bytes;
with Files.Model.Command_Palette;
with Files.Model.Context_Menu;
with Files.Model.Quick_Look;
with Files.Model.Root_Selector;
with Files.Model.Settings_Pane;
with Files.Model.Sort_Menu;
with Files.Model.Tree_Panel;

separate (Files.Application.Windows.Smoke)
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
               Files.Model.Selection.Select_Visible (Runtime.Model, 1);
            end if;

         when Scenario_Scrolled =>
            Files.Model.Replace_Items
              (Runtime.Model, Scenario_Overflow_Items (Runtime.Model));
            Files.Model.Set_Main_View_Scroll_Lines
              (Runtime.Model, Scenario_Scroll_Lines);

         when Scenario_Context_Menu =>
            Files.Model.Context_Menu.Open
              (Model      => Runtime.Model,
               X          => 64,
               Y          => 96,
               Target     =>
                 (if Has_Item then Files.Types.Context_Menu_Item
                  else Files.Types.Context_Menu_Empty),
               Item_Index => (if Has_Item then 1 else 0));

         when Scenario_Palette =>
            Files.Model.Command_Palette.Open (Runtime.Model);

         when Scenario_Root_Selector =>
            declare
               Roots : Files.Types.String_Vectors.Vector;
            begin
               Roots.Append (To_Unbounded_String ("/"));
               Roots.Append (To_Unbounded_String ("/home"));
               Files.Model.Root_Selector.Open (Runtime.Model, Roots);
            end;

         when Scenario_Sort_Menu =>
            Files.Model.Sort_Menu.Toggle (Runtime.Model);

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
               Files.Model.Tree_Panel.Seed (Runtime.Model, Seeds);
               Files.Model.Tree_Panel.Open (Runtime.Model);
               --  As Tab leaves it: the tree has the keyboard, its highlight
               --  on a row other than the current folder.
               Files.Model.Tree_Panel.Give_Keyboard (Runtime.Model);
               Files.Model.Tree_Panel.Set_Cursor (Runtime.Model, "/home");
            end;

         when Scenario_Settings =>
            Files.Model.Settings_Pane.Begin_Edit
              (Runtime.Model, Files.Settings.Make_Draft (Runtime.Settings));

         when Scenario_Settings_Tab_2 .. Scenario_Settings_Tab_7 =>
            Files.Model.Settings_Pane.Begin_Edit
              (Runtime.Model, Files.Settings.Make_Draft (Runtime.Settings));
            Files.Model.Settings_Pane.Set_Active_Section
              (Runtime.Model,
               2 + Live_Smoke_Scenario'Pos (Scenario) - Live_Smoke_Scenario'Pos (Scenario_Settings_Tab_2));

         when Scenario_Settings_Light =>
            Runtime.Settings.Theme := Files.Settings.Theme_Light;
            Files.Model.Note_Settings_Changed (Runtime.Model);
            Files.Model.Settings_Pane.Begin_Edit
              (Runtime.Model, Files.Settings.Make_Draft (Runtime.Settings));

         when Scenario_Settings_Large_Font =>
            Runtime.Settings.Font_Pixel_Size := Large_Font;
            Files.Model.Note_Settings_Changed (Runtime.Model);
            Runtime.Font_Pixel_Size := Scaled_Font_Size (Runtime);
            Files.Model.Settings_Pane.Begin_Edit
              (Runtime.Model, Files.Settings.Make_Draft (Runtime.Settings));

         when Scenario_Settings_Keyboard =>
            --  The run drives the keys itself once the window is prepared.
            null;

         when Scenario_Large_Font =>
            --  Jump to a size the baseline is not already using so the scaling
            --  path is exercised and the frame provably differs from default.
            declare
               Target : constant Positive :=
                 (if Runtime.Settings.Font_Pixel_Size >= Large_Font
                  then Files.Settings.Min_Font_Pixel_Size
                  else Large_Font);
            begin
               --  In framebuffer pixels, as everywhere: a 2x runner draws it twice as big.
               Runtime.Settings.Font_Pixel_Size := Target;
               Files.Model.Note_Settings_Changed (Runtime.Model);
               Runtime.Font_Pixel_Size := Scaled_Font_Size (Runtime);
            end;

         when Scenario_Light_Theme =>
            Runtime.Settings.Theme := Files.Settings.Theme_Light;
            Files.Model.Note_Settings_Changed (Runtime.Model);

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
               Files.Model.Selection.Select_Visible (Runtime.Model, 1);
               Files.Model.Quick_Look.Toggle (Runtime.Model);
            end if;

         when Scenario_Quick_Look_Image =>
            --  Open Quick Look on a synthetic high-resolution image so the large
            --  icon-atlas tile and overlay image pass are exercised end to end
            --  (no real file or image library needed).
            if Has_Item then
               Files.Model.Selection.Select_Visible (Runtime.Model, 1);
               declare
                  Dim     : constant := 256;
                  Content : Files.Quick_Look.Quick_Look_Content;
                  Pixels  : Files.Types.Byte_Vectors.Vector;
               begin
                  Content.Kind := Files.Quick_Look.Image_Content;
                  Content.Image_Width := Dim;
                  Content.Image_Height := Dim;
                  for Y in 0 .. Dim - 1 loop
                     for X in 0 .. Dim - 1 loop
                        Pixels.Append (Interfaces.Unsigned_8 (X mod 256));
                        Pixels.Append (Interfaces.Unsigned_8 (Y mod 256));
                        Pixels.Append (128);
                        Pixels.Append (255);
                     end loop;
                  end loop;
                  Content.Image_Pixels := Guikit.Shared_Bytes.To_Shared (Pixels);
                  Files.Model.Quick_Look.Open (Runtime.Model, Content);
               end;
            end if;
      end case;
   end Apply_Scenario;
