separate (Files.Rendering.Build_Snapshot_Into)
   --  The overlays, the command states, the roots, the folder tree and the
   --  breadcrumbs.
   procedure Snapshot_Overlays is
   begin
      --  The command palette owns its query/selection/results and renders itself
      --  (Guikit.Command_Palette, merged at the window layer); the snapshot only
      --  records that it is open, for overlay hit-testing.
      Snapshot.Command_Palette_Open :=
        Files.Model.Window_Overlay_Shown (Model, Files.UI_Types.Command_Palette_Overlay);
      --  The root selector remains logically open while the palette temporarily
      --  takes focus, but must not be painted underneath it: overlay rectangles
      --  and overlay text are separate GPU passes, so its text would otherwise
      --  bleed through the palette panel.
      Snapshot.Root_Selector_Open :=
        Files.Model.Root_Selector.Is_Open (Model)
        and then not Snapshot.Command_Palette_Open;
      Snapshot.Root_Selected_Index := Files.Model.Root_Selector.Selected_Index (Model);

      Snapshot.Label_Picker_Open := Files.Model.Label_Picker.Is_Open (Model);
      Snapshot.Label_Picker_Highlight := Files.Model.Label_Picker.Highlight (Model);
      if Files.Model.Quick_Look.Is_Open (Model) then
         declare
            Content : constant Files.Quick_Look.Quick_Look_Content :=
              Files.Model.Quick_Look.Content_Of (Model);
            Item    : constant Files.Items.Directory_Item :=
              Files.Model.Selection.Selected_Item (Model);
         begin
            Snapshot.Quick_Look :=
              (Open           => True,
               Kind           => Content.Kind,
               Name           => Content.Name,
               Filetype       => Content.Filetype,
               Icon           =>
                 Files.File_Types.Resolve_Icon
                   (Item.Kind, To_String (Content.Filetype), To_String (Content.Icon_Id)),
               Size_Available => Content.Size_Available,
               Size           => Content.Size,
               Text_Lines     => Content.Text_Lines,
               Text_Truncated => Content.Text_Truncated,
               others         => <>);
            --  Prefer the original image decoded at preview resolution; fall
            --  back to the item's small thumbnail when decoding was unavailable.
            if Content.Kind = Files.Quick_Look.Image_Content
              and then Complete_RGBA_Image
                (Content.Image_Width, Content.Image_Height,
                 Ada.Containers.Count_Type (Guikit.Shared_Bytes.Length (Content.Image_Pixels)))
            then
               Snapshot.Quick_Look.Image_Width  := Content.Image_Width;
               Snapshot.Quick_Look.Image_Height := Content.Image_Height;
               Snapshot.Quick_Look.Image_Pixels := Content.Image_Pixels;
            elsif Content.Kind = Files.Quick_Look.Image_Content
              and then Item.Thumbnail_Available
            then
               Snapshot.Quick_Look.Image_Width  := Item.Thumbnail_Width;
               Snapshot.Quick_Look.Image_Height := Item.Thumbnail_Height;
               Snapshot.Quick_Look.Image_Pixels := Item.Thumbnail_Pixels;
            end if;
         end;
      end if;

      for Id in Files.Commands.Registered_Command_Id loop
         Snapshot.Command_Enabled (Id) := Files.Commands.Status.Is_Enabled (Id, Model);
      end loop;

      for Index in 1 .. Files.Model.Root_Selector.Count (Model) loop
         Snapshot.Roots.Append
           (Root_Row'
              (Path  => To_Unbounded_String (Files.Model.Root_Selector.Path (Model, Index)),
               Label =>
                 To_Unbounded_String
                   (Files.Root_Labels.Display_Label (Files.Model.Root_Selector.Entry_At (Model, Index)))));
      end loop;

      Snapshot.Tree_Panel_Open := Files.Model.Tree_Panel.Is_Open (Model);
      Snapshot.Tree_Panel_Scroll_Rows :=
        Files.Model.Tree_Panel.Scroll_Rows (Model);
      Snapshot.Tree_Pick_Active := Files.Model.Tree_Panel.Pick_Is_Active (Model);
      --  Rows only for a tree on screen: a closed one is not walked on every
      --  keystroke's rebuild.
      if Snapshot.Tree_Panel_Open or else Snapshot.Tree_Pick_Active then
         Snapshot.Tree_Rows := Files.Model.Tree_Panel.Visible_Rows (Model);
      else
         Snapshot.Tree_Rows.Clear;
      end if;
      Snapshot.Tree_Pick_Moving :=
        Files.Model.Tree_Panel.Pick_Mode_Of (Model) = Files.Model.Pick_Move;
      Snapshot.Tree_Pick_Target := To_Unbounded_String (Files.Model.Tree_Panel.Pick_Target (Model));
      Snapshot.Tree_Keyboard_Active := Files.Model.Tree_Panel.Has_Keyboard (Model);
      Snapshot.Tree_Cursor := To_Unbounded_String (Files.Model.Tree_Panel.Cursor (Model));
      Snapshot.Breadcrumb_Segments :=
        Files.Breadcrumbs.Segments (Files.Model.Current_Path (Model));
   end Snapshot_Overlays;
