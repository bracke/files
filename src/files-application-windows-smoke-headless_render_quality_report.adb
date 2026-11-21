with Files.Preference_Types;
with Files.File_Types;
with Guikit.Shared_Bytes;

with Files.Diagnostics;
separate (Files.Application.Windows.Smoke)
   function Headless_Render_Quality_Report
     (Startup : Startup_Result;
      Width   : Natural := Files.Rendering.Layouts.Default_Window_Width;
      Height  : Natural := Files.Rendering.Layouts.Default_Window_Height)
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
      --  A window whose frame raised before its check was taken still has
      --  one, a failed one, so Windows lines up with the startup windows.
      procedure Note_Failed_Window is
      begin
         if Natural (Result.Windows.Length) < Result.Frame_Count then
            Result.Windows.Append (Window_Frame_Check'(others => <>));
         end if;
      end Note_Failed_Window;
   begin
      if Startup.Windows.Is_Empty then
         Result.Error_Key := To_Unbounded_String ("runtime.smoke.no_windows");
         return Result;
      end if;

      for Startup_Window of Startup.Windows loop
         Result.Frame_Count := Result.Frame_Count + 1;

         --  The handler inside the block does not cover its own declarative
         --  part (snapshot, frame and text setup); count a failure there as a
         --  failed frame too rather than crashing the smoke run.
         begin
            declare
               --  As the window draws it: grouped, with the host's samples, at
               --  the settings' font size.
               Line_Height : constant Positive := Line_Height_For (Startup.Settings);
               Snapshot : constant Files.Rendering.View_Snapshot :=
                 Files.Rendering.Build_Snapshot
                   (Sampled (Files.Model.Grouped (Startup_Window.Model, Startup.Settings)), Startup.Settings);
               Frame    : constant Files.Rendering.Frame_Commands :=
                 Files.Rendering.Build_Frame_Commands
                   (Snapshot    => Snapshot,
                    Width       => Width,
                    Height      => Height,
                    Line_Height => Line_Height);
               Drag_Snapshot : Files.Rendering.View_Snapshot := Snapshot;
               Check  : constant Window_Frame_Check := Frame_Check (Snapshot, Frame, Startup.Settings, Width, Height);
            begin
               Result.Windows.Append (Check);
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
                        Full_Path          => To_Unbounded_String ("quality-drag.txt"),
                        Filetype           => To_Unbounded_String ("text/plain"),
                        Filetype_Detail    => To_Unbounded_String ("text"),
                        Icon               => Files.File_Types.Text_Icon,
                        Kind               => Files.Types.Regular_File_Item,
                        Size_Available     => False,
                        Size               => 0,
                        Creation_Available => False,
                        Creation_Time      => Files.Types.Unknown_Time,
                        Modified_Available => False,
                        Modified_Time      => Files.Types.Unknown_Time,
                        Permissions        => Null_Unbounded_String,
                        Thumbnail_Available => False,
                        Thumbnail_Path      => Null_Unbounded_String,
                        Thumbnail_Width     => 0,
                        Thumbnail_Height    => 0,
                        Thumbnail           => (Pixels => Guikit.Shared_Bytes.Empty),
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
                        Label              => Files.Preference_Types.No_Label));
               end if;

               declare
                  Drag_Frame : constant Files.Rendering.Frame_Commands :=
                    Files.Rendering.Build_Frame_Commands
                      (Snapshot        => Drag_Snapshot,
                       Width           => Width,
                       Height          => Height,
                       Line_Height     => Line_Height,
                       Pointer =>
                         (Hover_X => Natural'Min (Width, 96),
                          Hover_Y => Natural'Min (Height, 96),
                          Has_Hover => Width > 0 and then Height > 0,
                          Drag_Item_Index => Drag_Snapshot.Items.First_Element.Visible_Index,
                          Dragging => Width > 0 and then Height > 0,
                          others => <>));
               begin
                  if Natural (Drag_Frame.Icons.Length) > Natural (Frame.Icons.Length)
                    and then Natural (Drag_Frame.Overlay_Rectangles.Length) >
                      Natural (Frame.Overlay_Rectangles.Length)
                  then
                     Result.Drag_Preview_Frames := Result.Drag_Preview_Frames + 1;
                  end if;
               end;

               Result.Missing_Glyph_Count := Result.Missing_Glyph_Count + Check.Missing_Glyphs;
               if Check.Text_Rendered then
                  Result.Text_Glyph_Frames := Result.Text_Glyph_Frames + 1;
               else
                  Result.Failed_Frames := Result.Failed_Frames + 1;
               end if;
            exception
               when Swallowed : others =>
                  Files.Diagnostics.Note (Swallowed, "Files.Application.Windows.Smoke");
                  Result.Failed_Frames := Result.Failed_Frames + 1;
                  Note_Failed_Window;
            end;
         exception
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.Application.Windows.Smoke");
               Result.Failed_Frames := Result.Failed_Frames + 1;
               Note_Failed_Window;
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
