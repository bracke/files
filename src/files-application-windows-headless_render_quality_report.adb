separate (Files.Application.Windows)
   function Headless_Render_Quality_Report
     (Startup : Startup_Result;
      Width   : Natural := 1024;
      Height  : Natural := 768)
      return Headless_Render_Quality_Result
   is
      Result : Headless_Render_Quality_Result :=
        (Window_Count => Natural (Startup.Windows.Length),
         others       => <>);

      function Has_Toolbar_Icon
        (Frame : Files.Rendering.Frame_Commands)
         return Boolean is
      begin
         for Icon of Frame.Icons loop
            if Ada.Strings.Fixed.Index (To_String (Icon.Icon_Id), "toolbar-") = 1 then
               return True;
            end if;
         end loop;

         return False;
      end Has_Toolbar_Icon;
   begin
      if Startup.Windows.Is_Empty then
         Result.Error_Key := To_Unbounded_String ("runtime.smoke.no_windows");
         return Result;
      end if;

      for Startup_Window of Startup.Windows loop
         Result.Frame_Count := Result.Frame_Count + 1;

         declare
            Snapshot : constant Files.Rendering.View_Snapshot :=
              Files.Rendering.Build_Snapshot (Startup_Window.Model, Startup.Settings);
            Frame    : constant Files.Rendering.Frame_Commands :=
              Files.Rendering.Build_Frame_Commands
                (Snapshot    => Snapshot,
                 Width       => Width,
                 Height      => Height,
                 Line_Height => 20);
            Drag_Snapshot : Files.Rendering.View_Snapshot := Snapshot;
            Text     : Files.Rendering.Text_Renderer;
            Text_Status : constant Files.Rendering.Text_Render_Status :=
              Files.Rendering.Initialize_Text
                (Renderer    => Text,
                 Font_Path   => Files.Rendering.Font_Path_For_Frame (Frame),
                 Pixel_Size  => 16,
                 Cell_Width  => 12,
                 Cell_Height => 20);
            Glyphs : Files.Rendering.Text_Render_Result;
         begin
            if Frame.Layout.Width = Width
              and then Frame.Layout.Height = Height
              and then not Frame.Rectangles.Is_Empty
            then
               Result.Nonblank_Frames := Result.Nonblank_Frames + 1;
            end if;

            if not Frame.Icons.Is_Empty then
               Result.Icon_Frames := Result.Icon_Frames + 1;
            end if;

            if Has_Toolbar_Icon (Frame) then
               Result.Toolbar_Icon_Frames := Result.Toolbar_Icon_Frames + 1;
            end if;

            if Drag_Snapshot.Items.Is_Empty then
               Drag_Snapshot.Items.Append
                 (Files.Rendering.Item_Snapshot'
                    (Name               => To_Unbounded_String ("quality-drag.txt"),
                     Name_Lower         => To_Unbounded_String ("quality-drag.txt"),
                     Filetype           => To_Unbounded_String ("text/plain"),
                     Filetype_Detail    => To_Unbounded_String ("text"),
                     Icon_Id            => To_Unbounded_String ("text"),
                     Kind               => Files.Types.Regular_File_Item,
                     Size_Available     => False,
                     Size               => 0,
                     Creation_Available => False,
                     Creation_Time      => Ada.Calendar.Time_Of (1901, 1, 1),
                     Modified_Available => False,
                     Modified_Time      => Ada.Calendar.Time_Of (1901, 1, 1),
                     Permissions        => Null_Unbounded_String,
                     Filetype_Extra     => Null_Unbounded_String,
                     Thumbnail_Available => False,
                     Thumbnail_Path      => Null_Unbounded_String,
                     Thumbnail_Width     => 0,
                     Thumbnail_Height    => 0,
                     Thumbnail           => (Pixels => Files.Types.Byte_Vectors.Empty_Vector),
                     Metadata_Error     => False,
                     Error_Key          => Null_Unbounded_String,
                     Selected           => True,
                     Visible_Index      => 1,
                     Cut_Pending        => False,
                     Renaming           => False,
                     Rename_Value       => Null_Unbounded_String,
                     Rename_Cursor      => 0,
                     Is_Group_Header    => False,
                     Group_Label        => Null_Unbounded_String,
                     Is_Favorite        => False,
                     Label              => Files.Types.No_Label));
            end if;

            declare
               Drag_Frame : constant Files.Rendering.Frame_Commands :=
                 Files.Rendering.Build_Frame_Commands
                   (Snapshot        => Drag_Snapshot,
                    Width           => Width,
                    Height          => Height,
                    Line_Height     => 20,
                    Hover_X         => Natural'Min (Width, 96),
                    Hover_Y         => Natural'Min (Height, 96),
                    Has_Hover       => Width > 0 and then Height > 0,
                    Drag_Item_Index => Drag_Snapshot.Items.First_Element.Visible_Index,
                    Drag_X          => Natural'Min (Width, 96),
                    Drag_Y          => Natural'Min (Height, 96),
                    Has_Drag        => Width > 0 and then Height > 0);
            begin
               if Natural (Drag_Frame.Icons.Length) > Natural (Frame.Icons.Length)
                 and then Natural (Drag_Frame.Rectangles.Length) > Natural (Frame.Rectangles.Length)
               then
                  Result.Drag_Preview_Frames := Result.Drag_Preview_Frames + 1;
               end if;
            end;

            if Text_Status = Files.Rendering.Text_Render_Success then
               Glyphs := Files.Rendering.Build_Text_Glyphs (Text, Frame);
               Result.Missing_Glyph_Count :=
                 Result.Missing_Glyph_Count + Glyphs.Missing_Glyph_Count;
               if Glyphs.Status = Files.Rendering.Text_Render_Success and then not Glyphs.Glyphs.Is_Empty then
                  Result.Text_Glyph_Frames := Result.Text_Glyph_Frames + 1;
               else
                  Result.Failed_Frames := Result.Failed_Frames + 1;
               end if;
            else
               Result.Failed_Frames := Result.Failed_Frames + 1;
            end if;
         exception
            when others =>
               Result.Failed_Frames := Result.Failed_Frames + 1;
         end;
      end loop;

      Result.Passed :=
        Result.Frame_Count = Result.Window_Count
        and then Result.Window_Count > 0
        and then Result.Failed_Frames = 0
        and then Result.Nonblank_Frames = Result.Window_Count
        and then Result.Text_Glyph_Frames = Result.Window_Count
        and then Result.Icon_Frames = Result.Window_Count
        and then Result.Toolbar_Icon_Frames = Result.Window_Count
        and then Result.Drag_Preview_Frames = Result.Window_Count
        and then Result.Missing_Glyph_Count = 0;

      Result.Error_Key :=
        To_Unbounded_String ((if Result.Passed then "runtime.smoke.ready" else "runtime.smoke.text_failed"));
      return Result;
   end Headless_Render_Quality_Report;
