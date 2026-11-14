with Files.Fonts;
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
         Files.Rendering.Text.Ensure_Loaded
           (Runtime.Text, Files.Fonts.Default_Font_Path, Runtime.Font_Pixel_Size, Ada.Real_Time.Clock);

         declare
            --  Without text (no font yet, a failed load) the frame is
            --  still drawn: a window with no labels, not a blank one.
            --  Unchanged text reuses its glyphs; the renderer uploads the
            --  atlas only when its version moved (or an earlier present
            --  failed).
            Glyphs : constant Files.Rendering.Text.Text_Render_Result :=
              Files.Rendering.Text.Glyphs_For (Runtime.Text, Frame, Ada.Real_Time.Clock);
         begin
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

               --  Surfaced in the FILES_DIAGNOSTICS trace: a frame Vulkan did not
               --  present, and glyphs the fonts could not draw.
               if Runtime.Last_Present_Status /= Guikit.Vulkan.Vulkan_Presented then
                  Runtime.Fallback_Frames := Runtime.Fallback_Frames + 1;
                  Files.Diagnostics.Trace
                    ("Files.Application.Windows",
                     "fallback_frames=" & Natural'Image (Runtime.Fallback_Frames)
                     & ",status=" & Guikit.Vulkan.Vulkan_Status'Image (Runtime.Last_Present_Status));
               else
                  Files.Diagnostics.Trace
                    ("Files.Application.Windows",
                     "presented=" & Natural'Image (Guikit.Vulkan.Diagnostics (Runtime.Vulkan).Submitted_Frames)
                     & ",missing_glyphs=" & Natural'Image (Runtime.Last_Missing_Glyph_Count));
               end if;
            end;
         end;
      end;
   end Present;
