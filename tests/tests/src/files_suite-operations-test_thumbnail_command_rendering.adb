separate (Files_Suite.Operations)
   procedure Test_Thumbnail_Command_Rendering (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;
      Cache_Home : constant String := Join (Root, "cache-home");
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      Reset_Root;
      Files_Suite.Support.Save (Environment, "XDG_CACHE_HOME");
      --  Directory listings read the thumbnail cache, so keep it inside the fixture.
      Ada.Environment_Variables.Set ("XDG_CACHE_HOME", Cache_Home);

      Write_File
        (Join (Root, "command-thumbnail.ppm"),
         "P3" & ASCII.LF
         & "2 2" & ASCII.LF
         & "255" & ASCII.LF
         & "255 0 0 255 0 0" & ASCII.LF
         & "255 0 0 255 0 0" & ASCII.LF);
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "command-thumbnail.ppm");
      Ada.Environment_Variables.Set ("XDG_CACHE_HOME", Cache_Home);
      Routed := Files.Controller.Execute_Command (Files.Commands.Generate_Thumbnails_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Routed.Command,
         Files.Commands.Generate_Thumbnails_Command,
         "thumbnail generation routes through command registry");
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Success,
         "thumbnail command succeeds");
      Assert
        (Ada.Directories.Exists (To_String (Routed.Operation.Path)),
         "thumbnail command writes a cache artifact");
      Assert
        (Project_Tools.Files.File_Contains (To_String (Routed.Operation.Path), "P6"),
         "thumbnail command writes PPM thumbnail content");
      Assert
        (Files.Model.Selected_Item (Model).Thumbnail_Available,
         "thumbnail command refresh exposes generated thumbnail in the model");
      Files_Suite.Support.Assert_Equal
        (To_String (Files.Model.Selected_Item (Model).Thumbnail_Path),
         To_String (Routed.Operation.Path),
         "thumbnail command refresh records the generated thumbnail path");
      Files.Model.Set_View_Mode (Model, Files.Types.Large_Icons);
      declare
         Thumbnail_Frame : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands
             (Files.Rendering.Build_Snapshot (Model, Settings),
              Width       => 1000,
              Height      => 800,
              Line_Height => 20);
         Empty_Text : Files.Rendering.Text_Render_Result;
         Thumbnail_Batch : Guikit.Vulkan.Submission_Batch;
         Found_Thumbnail_Command : Boolean := False;
         Found_Thumbnail_Icon    : Boolean := False;
         Thumbnail_Tile          : Natural := 0;
         Icon_Index              : Natural := 0;
      begin
         for Command of Thumbnail_Frame.Icons loop
            if Length (Command.Icon_Id) < 8
              or else Slice (Command.Icon_Id, 1, 8) /= "toolbar-"
            then
               Icon_Index := Icon_Index + 1;
            end if;
            if To_String (Command.Asset_Path) = To_String (Routed.Operation.Path) then
               Found_Thumbnail_Command := True;
               Thumbnail_Tile := Icon_Index - 1;
               if To_String (Command.Icon_Id) = "thumbnail" then
                  Found_Thumbnail_Icon := True;
               end if;
            end if;
         end loop;

         Assert
           (Found_Thumbnail_Command,
            "large-icons item icon command points at the generated thumbnail artifact");
         Assert
           (Found_Thumbnail_Icon,
            "large-icons item icon command uses a thumbnail-specific icon asset");
         Thumbnail_Batch := Guikit.Vulkan.Build_Submission
           (Rectangles         => Thumbnail_Frame.Rectangles,
            Triangles          => Thumbnail_Frame.Triangles,
            Icons              => Thumbnail_Frame.Icons,
            Overlay_Rectangles => Thumbnail_Frame.Overlay_Rectangles,
            Layout             => Thumbnail_Frame.Layout,
            Theme              => Thumbnail_Frame.Theme_Palette,
            Text               => Empty_Text);
         declare
            Pixel_Offset : constant Positive := Positive (Thumbnail_Tile * 64 * 4 + 1);
         begin
            Assert
              (Thumbnail_Batch.Icon_Atlas_Pixels.Element (Pixel_Offset) = 255,
               "vulkan icon atlas rasterizes large-icons cached thumbnail pixels: red");
            Assert
              (Thumbnail_Batch.Icon_Atlas_Pixels.Element (Pixel_Offset + 1) = 0,
               "vulkan icon atlas rasterizes large-icons cached thumbnail pixels: green");
            Assert
              (Thumbnail_Batch.Icon_Atlas_Pixels.Element (Pixel_Offset + 2) = 0,
               "vulkan icon atlas rasterizes large-icons cached thumbnail pixels: blue");
            Assert
              (Thumbnail_Batch.Icon_Atlas_Pixels.Element (Pixel_Offset + 3) = 255,
               "vulkan icon atlas rasterizes large-icons cached thumbnail pixels: alpha");
         end;
      end;
      for Mode in Files.Types.Small_Icons .. Files.Types.Details loop
         if Mode /= Files.Types.Large_Icons then
            Files.Model.Set_View_Mode (Model, Mode);
            declare
               Non_Thumbnail_Frame : constant Files.Rendering.Frame_Commands :=
                 Files.Rendering.Build_Frame_Commands
                   (Files.Rendering.Build_Snapshot (Model, Settings),
                    Width       => 1000,
                    Height      => 800,
                    Line_Height => 20);
            begin
               for Command of Non_Thumbnail_Frame.Icons loop
                  Assert
                    (To_String (Command.Icon_Id) /= "thumbnail",
                     "non-large item icon command keeps filetype icon");
                  Files_Suite.Support.Assert_Equal
                    (Command.Thumbnail_Width,
                     0,
                     "non-large item icon command does not carry thumbnail pixels: no width");
                  Files_Suite.Support.Assert_Equal
                    (Command.Thumbnail_Height,
                     0,
                     "non-large item icon command does not carry thumbnail pixels: no height");
                  Assert
                    (Command.Thumbnail_Pixels.Is_Empty,
                     "non-large item icon command does not carry thumbnail pixels: no pixels");
               end loop;
            end;
         end if;
      end loop;
   end Test_Thumbnail_Command_Rendering;
