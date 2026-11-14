separate (Files.Application.Windows.Render_Window.Present_Frame)
   procedure Present (Frame : Files.Rendering.Frame_Commands) is
   begin
      --  The screen reader gets the frame as shown, overlays included --
      --  the command palette and settings panel are merged in by the
      --  caller, not into the cached frame -- when it or an overlay
      --  changed. The provider announces only what differs from its
      --  last tree.
      if Frame_Rebuilt or else Overlay_Changed then
         Files.Accessibility.Publish (Runtime.A11y_Key, Frame);
         Runtime.Shown_Accessibility := Frame.Accessibility;
      end if;
      --  A title change is a round trip to the window system.
      if Snapshot.Current_Path /= Runtime.Shown_Title then
         Glfw.Windows.Set_Title (As_Window (Runtime.Handle), To_String (Snapshot.Current_Path));
         Runtime.Shown_Title := Snapshot.Current_Path;
      end if;

      Guikit.Vulkan.Ensure_Ready
        (Renderer => Runtime.Vulkan,
         Window   => As_Window (Runtime.Handle),
         Width    => Natural (Width),
         Height   => Natural (Height));

      begin
         --  Loaded once per window (a pooled renderer per size, so this is
         --  cheap when another window already has the size); a failure
         --  is retried after a pause, not every frame.
         if not Runtime.Text_Ready
           and then (Runtime.Text_Failed_Size /= Runtime.Font_Pixel_Size
                     or else Ada.Real_Time.Clock >= Runtime.Text_Failed_At + Text_Retry_Interval)
         then
            declare
               Status : constant Files.Rendering.Text_Render_Status :=
                 Files.Rendering.Initialize_Text
                   (Renderer    => Runtime.Text,
                    Font_Path   => Files.Rendering.Default_Font_Path,
                    Pixel_Size  => Runtime.Font_Pixel_Size,
                    Cell_Width  => Cell_Width_For (Runtime.Font_Pixel_Size),
                    Cell_Height => Cell_Height_For (Runtime.Font_Pixel_Size));
            begin
               Runtime.Text_Ready := Status = Files.Rendering.Text_Render_Success;
               Runtime.Glyph_Text_Valid := False;
               Runtime.Text_Failed_Size := (if Runtime.Text_Ready then 0 else Runtime.Font_Pixel_Size);
               Runtime.Text_Failed_At := Ada.Real_Time.Clock;
            end;
         end if;

         declare
            --  Without text (no font yet, a failed load) the frame is
            --  still drawn: a window with no labels, not a blank one.
            Glyphs : Files.Rendering.Text_Render_Result;
         begin
            if Runtime.Text_Ready then
               --  Unchanged text reuses its glyphs; the renderer uploads
               --  the atlas only when its version moved (or an earlier
               --  present failed).
               if Runtime.Glyph_Text_Valid
                 and then Runtime.Glyph_Text = Frame.Text
                 and then Runtime.Glyph_Overlay_Text = Frame.Overlay_Text
                 and then Runtime.Text_Glyphs.Status = Files.Rendering.Text_Render_Success
                 and then Files.Rendering.Text_Glyphs_Current (Runtime.Text, Runtime.Text_Glyphs)
               then
                  Glyphs := Runtime.Text_Glyphs;
               else
                  Glyphs := Files.Rendering.Build_Text_Glyphs (Runtime.Text, Frame);
                  Runtime.Text_Glyphs := Glyphs;
                  Runtime.Glyph_Text := Frame.Text;
                  Runtime.Glyph_Overlay_Text := Frame.Overlay_Text;
                  Runtime.Glyph_Text_Valid := True;
                  --  Its pooled fonts went to another size and did not
                  --  load again: a failure like the first, retried after
                  --  the same pause, not on every frame (nor never).
                  if not Files.Rendering.Text_Loaded (Runtime.Text) then
                     Runtime.Text_Ready := False;
                     Runtime.Glyph_Text_Valid := False;
                     Runtime.Text_Failed_Size := Runtime.Font_Pixel_Size;
                     Runtime.Text_Failed_At := Ada.Real_Time.Clock;
                  end if;
               end if;
            end if;

            declare
               Batch : constant Guikit.Vulkan.Submission_Batch :=
                 Guikit.Vulkan.Build_Submission
                   (Rectangles         => Frame.Rectangles,
                    Triangles          => Frame.Triangles,
                    Icons              => Frame.Icons,
                    Overlay_Rectangles => Frame.Overlay_Rectangles,
                    Layout             => Frame.Layout,
                    Theme              => Frame.Theme_Palette,
                    Text               => Glyphs);
            begin
               Runtime.Last_Glyph_Count := Natural (Glyphs.Glyphs.Length);
               Runtime.Last_Missing_Glyph_Count := Glyphs.Missing_Glyph_Count;
               Runtime.Last_Present_Status :=
                 Guikit.Vulkan.Present_Frame
                   (Renderer => Runtime.Vulkan,
                    Batch    => Batch,
                    Width    => Natural (Width),
                    Height   => Natural (Height));

               if Runtime.Last_Present_Status /= Guikit.Vulkan.Vulkan_Presented then
                  Runtime.Fallback_Frames := Runtime.Fallback_Frames + 1;
               else
                  Files.Diagnostics.Trace
                    ("Files.Application.Windows",
                     "presented=" & Natural'Image (Guikit.Vulkan.Diagnostics (Runtime.Vulkan).Submitted_Frames));
               end if;
            end;
         end;
      end;
   end Present;
